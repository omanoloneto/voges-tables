// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:voges_updater/voges_updater.dart'
    show LaunchResult, UpdateCheck, UpdateStatusChip, UpdaterLocalizations;
import 'package:window_manager/window_manager.dart';

import '../files/spreadsheet_files.dart';
import '../files/system_open.dart';
import '../files/workbook_codec.dart';
import '../formula/locale.dart';
import '../grid/cell_editing.dart';
import '../grid/formula_bar.dart';
import '../grid/sheet_tabs.dart';
import '../grid/spreadsheet_grid.dart';
import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';
import '../sheet/chart.dart';
import '../sheet/structure.dart';
import '../sheet/workbook.dart';
import '../shell/platform.dart';
import '../shell/ribbon_style.dart';
import '../shell/title_bar.dart';
import '../shell/window_buttons.dart';
import '../workbook/selection.dart';
import '../workbook/workbook_controller.dart';
import 'dialogs.dart';
import 'file_panel.dart';
import 'find_bar.dart';
import 'ribbon.dart';
import 'status_bar.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    required this.controller,
    required this.files,
    required this.systemOpen,
    required this.language,
    required this.launchArguments,
    this.windowButtons = WindowButtonsLayout.right,
    this.updates,
    super.key,
  });

  final WorkbookController controller;
  final SpreadsheetFiles files;
  final SystemOpen systemOpen;
  final AppLanguage language;
  final List<String> launchArguments;
  final WindowButtonsLayout windowButtons;

  /// Null off the desktop.
  final UpdateCheck? updates;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WindowListener {
  final _gridFocus = FocusNode(debugLabel: 'grid');
  final _grid = GlobalKey<SpreadsheetGridState>();
  final _findBar = GlobalKey<FindBarState>();

  /// Null while Find is closed; true with the replace row open.
  bool? _finding;
  late final CellEditing _editing;
  late final AppLifecycleListener _lifecycle;
  var _zoom = 1.0;
  var _closing = false;
  var _maximized = false;
  var _fullScreen = false;
  var _locale = FormulaLocale.en;
  String? _title;

  /// The text this app put on the clipboard: pasting it back pastes the
  /// cells with formulas and formats, not just their text.
  String? _copiedText;

  WorkbookController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _editing = CellEditing(controller);
    controller.locale = () => _locale;
    controller.addListener(_updateTitle);
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    if (isDesktopPlatform) windowManager.addListener(this);
    widget.systemOpen.listen(_openFromSystem);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _gridFocus.requestFocus();
      _updateTitle();
      if (widget.updates case final updates?) {
        updates.check().ignore();
        updates.cleanUp().ignore();
      }
      final pending = await widget.systemOpen.pending(widget.launchArguments);
      if (pending.isNotEmpty) _load(pending.first);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    widget.files.titles = FileDialogTitles(
      open: l10n.openFileTitle,
      save: l10n.saveFileTitle,
    );
    _locale = switch (Localizations.localeOf(context).languageCode) {
      'pt' => FormulaLocale.pt,
      'es' => FormulaLocale.es,
      _ => FormulaLocale.en,
    };
    controller.localeChanged();
    _updateTitle();
  }

  @override
  void dispose() {
    controller.removeListener(_updateTitle);
    _lifecycle.dispose();
    if (isDesktopPlatform) windowManager.removeListener(this);
    _gridFocus.dispose();
    _editing.dispose();
    super.dispose();
  }

  String get _name => controller.name ?? context.l10n.untitled;

  void _updateTitle() {
    if (!mounted) return;
    final title = '${controller.dirty ? '• ' : ''}$_name — Voges Tables';
    if (title == _title) return;
    _title = title;
    if (isDesktopPlatform) windowManager.setTitle(title).ignore();
  }

  Future<ui.AppExitResponse> _onExitRequested() async {
    if (_closing || await _confirmDiscard()) return ui.AppExitResponse.exit;
    return ui.AppExitResponse.cancel;
  }

  @override
  Future<void> onWindowClose() async {
    if (_closing || await _confirmDiscard()) {
      _closing = true;
      await windowManager.destroy();
    }
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  void onWindowEnterFullScreen() => setState(() => _fullScreen = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _fullScreen = false);

  /// The app closes for the updater to replace it, so unsaved work is
  /// handled first, exactly as when closing the window.
  Future<void> _startUpdate() async {
    final updates = widget.updates;
    if (updates == null || !await _confirmDiscard()) return;
    final revision = controller.revision;
    if (await updates.startUpdater() == LaunchResult.started) {
      // Windows copies the app for the updater first, and the workbook may
      // change meanwhile; if the user keeps it open, the updater waits
      if (!mounted) return;
      _finishTyping();
      if (controller.revision != revision && !await _confirmDiscard()) return;
      _closing = true;
      await windowManager.destroy();
      return;
    }
    if (!mounted) return;
    final l10n = UpdaterLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.updateLaunchFailed),
        action: SnackBarAction(
          label: l10n.updateDownloadPage,
          onPressed: () => updates.openDownloadPage().ignore(),
        ),
      ),
    );
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Typing in a cell counts as a change: it is written before anything
  /// that reads or replaces the workbook.
  void _finishTyping() {
    if (_editing.active) _editing.commit(EditMove.none);
  }

  Future<bool> _confirmDiscard() async {
    _finishTyping();
    if (!controller.dirty) return true;
    switch (await askToSave(context, _name)) {
      case UnsavedChoice.save:
        return _save();
      case UnsavedChoice.discard:
        return true;
      case UnsavedChoice.cancel:
        return false;
    }
  }

  Future<void> _newWorkbook() async {
    if (!await _confirmDiscard() || !mounted) return;
    controller.load(Workbook.blank(context.l10n.sheetName(1)));
  }

  Future<void> _open() async {
    if (!await _confirmDiscard()) return;
    final OpenedFile? file;
    try {
      file = await widget.files.pick();
    } catch (_) {
      if (mounted) _tell(context.l10n.openFailed);
      return;
    }
    if (file != null) await _load(file);
  }

  Future<void> _openFromSystem(OpenedFile file) async {
    if (await _confirmDiscard()) await _load(file);
  }

  Future<void> _load(OpenedFile file) async {
    final l10n = context.l10n;
    final Workbook workbook;
    try {
      workbook = await decodeWorkbook(
        file,
        locale: _locale,
        sheetName: l10n.sheetName(1),
      );
    } on SpreadsheetFileException catch (error) {
      _tell(isUnsupported(error) ? l10n.unsupportedFormat : l10n.openFailed);
      return;
    } catch (_) {
      _tell(l10n.openFailed);
      return;
    }
    if (!mounted) return;
    final format = SaveFormat.of(file.name);
    controller.load(
      workbook,
      name: file.name,
      path: format == null ? null : file.path,
    );
  }

  Future<bool> _save() {
    final path = controller.path;
    final format = path == null ? null : SaveFormat.of(path);
    return path == null || format == null
        ? _saveAs(SaveFormat.xlsx)
        : _write(path, format);
  }

  Future<bool> _saveAs(SaveFormat format) async {
    _finishTyping();
    final name = _name;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final String? path;
    try {
      path = await widget.files.chooseSaveLocation(
        '$base.${format.extension}',
        format,
      );
    } catch (_) {
      if (mounted) _tell(context.l10n.saveFailed);
      return false;
    }
    if (path == null) return false;
    return _write(path, format);
  }

  Future<bool> _write(String path, SaveFormat format) async {
    _finishTyping();
    final l10n = context.l10n;
    try {
      final bytes = encodeWorkbook(controller, format, locale: _locale);
      await widget.files.write(path, bytes);
      controller.markSaved(name: path.split(RegExp(r'[/\\]')).last, path: path);
      if (format == SaveFormat.csv && controller.workbook.sheets.length > 1) {
        _tell(l10n.csvOnlyActiveSheet);
      }
      return true;
    } catch (_) {
      _tell(l10n.saveFailed);
      return false;
    }
  }

  // Clipboard.

  Future<void> _copy({bool cut = false}) async {
    if (_editing.active) return;
    controller.copy(cut: cut);
    final text = controller.selectionAsText();
    _copiedText = text;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _paste() async {
    if (_editing.active) return;
    final nothing = context.l10n.nothingToPaste;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (controller.hasClip && (text == null || text == _copiedText)) {
      controller.paste();
      return;
    }
    if (text == null || text.isEmpty) {
      _tell(nothing);
      return;
    }
    controller.pasteText(text);
  }

  /// Σ: the sum of the numbers right above the active cell, or to its left,
  /// as Excel's AutoSum does; with a block selected, the sum goes under it.
  void _autoSum() {
    _finishTyping();
    final range = controller.selection.range;
    bool isNumber(CellAddress cell) => controller.valueAt(cell) is NumberValue;
    if (!range.isSingle) {
      final target = CellAddress(range.first.column, range.last.row + 1);
      for (
        var column = range.first.column;
        column <= range.last.column;
        column++
      ) {
        final below = CellAddress(column, range.last.row + 1);
        final sum = CellRange(
          CellAddress(column, range.first.row),
          CellAddress(column, range.last.row),
        );
        controller.enter(
          below,
          '=SUM(${sum.a1})'.replaceFirst('SUM', _sumName),
        );
      }
      controller.select(Selection.single(target));
      return;
    }
    final active = range.first;
    var top = active.row;
    while (top > 0 && isNumber(CellAddress(active.column, top - 1))) {
      top--;
    }
    CellRange? sum;
    if (top < active.row) {
      sum = CellRange(
        CellAddress(active.column, top),
        CellAddress(active.column, active.row - 1),
      );
    } else {
      var left = active.column;
      while (left > 0 && isNumber(CellAddress(left - 1, active.row))) {
        left--;
      }
      if (left < active.column) {
        sum = CellRange(
          CellAddress(left, active.row),
          CellAddress(active.column - 1, active.row),
        );
      }
    }
    final text = '=$_sumName(${sum?.a1 ?? ''})';
    if (sum == null) {
      _editing.start(active, replaceWith: text);
      _editing.text.selection = TextSelection.collapsed(
        offset: text.length - 1,
      );
    } else {
      controller.enter(active, text);
    }
  }

  String get _sumName => switch (_locale) {
    FormulaLocale.pt => 'SOMA',
    FormulaLocale.es => 'SUMA',
    _ => 'SUM',
  };

  Future<void> _renameSheet(int index) async {
    final name = await askSheetName(
      context,
      controller.workbook.sheets[index].name,
    );
    if (name == null || !mounted) return;
    if (!controller.renameSheet(index, name)) {
      _tell(context.l10n.sheetNameTaken);
    }
  }

  Future<void> _deleteSheet(int index) async {
    if (await confirmDeleteSheet(
      context,
      controller.workbook.sheets[index].name,
    )) {
      controller.deleteSheet(index);
    }
  }

  void _insert(SheetAxis axis) {
    _finishTyping();
    final done = axis == SheetAxis.rows
        ? controller.insertRows()
        : controller.insertColumns();
    if (!done) _tell(context.l10n.insertNoRoom);
  }

  void _delete(SheetAxis axis) {
    _finishTyping();
    if (axis == SheetAxis.rows) {
      controller.deleteRows();
    } else {
      controller.deleteColumns();
    }
  }

  /// The keyboard inserts or deletes columns only when whole columns are
  /// selected, rows otherwise.
  SheetAxis get _keyboardAxis =>
      controller.wholeColumnsSelected && !controller.wholeRowsSelected
      ? SheetAxis.columns
      : SheetAxis.rows;

  Future<void> _showCellMenu(Offset position) async {
    final l10n = context.l10n;
    PopupMenuItem<VoidCallback> item(
      IconData icon,
      String label,
      VoidCallback action,
    ) => PopupMenuItem(
      value: action,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        item(Icons.content_cut, l10n.cut, () => _copy(cut: true)),
        item(Icons.content_copy, l10n.copy, _copy),
        item(Icons.content_paste, l10n.paste, _paste),
        const PopupMenuDivider(),
        item(
          Icons.table_rows_outlined,
          l10n.insertRows,
          () => _insert(SheetAxis.rows),
        ),
        item(
          Icons.view_column_outlined,
          l10n.insertColumns,
          () => _insert(SheetAxis.columns),
        ),
        item(
          Icons.table_rows_outlined,
          l10n.deleteRows,
          () => _delete(SheetAxis.rows),
        ),
        item(
          Icons.view_column_outlined,
          l10n.deleteColumns,
          () => _delete(SheetAxis.columns),
        ),
        const PopupMenuDivider(),
        item(
          Icons.merge,
          controller.activeMerge == null ? l10n.mergeCenter : l10n.unmergeCells,
          _merge,
        ),
        item(
          Icons.backspace_outlined,
          l10n.clearContents,
          controller.clearContents,
        ),
      ],
    );
    action?.call();
    _gridFocus.requestFocus();
  }

  Future<void> _merge() async {
    _finishTyping();
    if (controller.activeMerge != null) {
      controller.unmergeSelection();
      return;
    }
    if (controller.mergeWouldClear && !await confirmMergeClearsData(context)) {
      return;
    }
    controller.mergeSelection();
  }

  void _openFind({bool replace = false}) {
    _finishTyping();
    if (_finding != null) {
      _findBar.currentState?.focus(replace: replace);
      if (replace) setState(() => _finding = true);
      return;
    }
    setState(() => _finding = replace);
  }

  void _closeFind() {
    setState(() => _finding = null);
    _gridFocus.requestFocus();
  }

  void _insertChart(ChartKind kind) {
    _finishTyping();
    final index = controller.insertChart(kind);
    if (index == null) {
      _tell(context.l10n.chartNoNumbers);
      return;
    }
    _grid.currentState?.selectChart(index);
  }

  void _bold() {
    final on = !controller.activeStyle.bold;
    controller.applyStyle((s) => s.copyWith(bold: on));
  }

  void _italic() {
    final on = !controller.activeStyle.italic;
    controller.applyStyle((s) => s.copyWith(italic: on));
  }

  void _underline() {
    final on = !controller.activeStyle.underline;
    controller.applyStyle((s) => s.copyWith(underline: on));
  }

  void _setZoom(double zoom) => setState(() => _zoom = clampZoom(zoom));

  void _showFilePanel() => showFilePanel(
    context,
    name: _name,
    language: widget.language,
    actions: FilePanelActions(
      newFile: _newWorkbook,
      open: _open,
      save: _save,
      saveAs: _saveAs,
    ),
  );

  /// Shortcuts that act on cells only while no text is being typed, so the
  /// editor keeps its own copy, paste and undo.
  VoidCallback _cells(VoidCallback action) => () {
    if (!_editing.active) action();
  };

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        shortcut(LogicalKeyboardKey.keyN): _newWorkbook,
        shortcut(LogicalKeyboardKey.keyO): _open,
        shortcut(LogicalKeyboardKey.keyS): _save,
        shortcut(LogicalKeyboardKey.keyS, shift: true): () =>
            _saveAs(SaveFormat.xlsx),
        shortcut(LogicalKeyboardKey.keyZ): _cells(controller.undo),
        shortcut(LogicalKeyboardKey.keyZ, shift: true): _cells(controller.redo),
        shortcut(LogicalKeyboardKey.keyY): _cells(controller.redo),
        shortcut(LogicalKeyboardKey.keyC): _cells(_copy),
        shortcut(LogicalKeyboardKey.keyX): _cells(() => _copy(cut: true)),
        shortcut(LogicalKeyboardKey.keyV): _cells(_paste),
        shortcut(LogicalKeyboardKey.keyA): _cells(controller.selectAll),
        shortcut(LogicalKeyboardKey.keyB): _cells(_bold),
        shortcut(LogicalKeyboardKey.keyI): _cells(_italic),
        shortcut(LogicalKeyboardKey.keyU): _cells(_underline),
        shortcut(LogicalKeyboardKey.keyF): _openFind,
        shortcut(LogicalKeyboardKey.keyH): () => _openFind(replace: true),
        shortcut(LogicalKeyboardKey.equal, shift: true): _cells(
          () => _insert(_keyboardAxis),
        ),
        shortcut(LogicalKeyboardKey.minus, shift: true): _cells(
          () => _delete(_keyboardAxis),
        ),
        shortcut(LogicalKeyboardKey.equal): () => _setZoom(_zoom + 0.1),
        shortcut(LogicalKeyboardKey.minus): () => _setZoom(_zoom - 0.1),
        shortcut(LogicalKeyboardKey.digit0): () => _setZoom(1),
      },
      child: _resizable(
        Scaffold(
          body: Column(
            children: [
              ColoredBox(
                color: RibbonColors.background,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) => AppTitleBar(
                          name: _name,
                          dirty: controller.dirty,
                          onFile: _showFilePanel,
                          isMaximized: _maximized,
                          isFullScreen: _fullScreen,
                          windowButtons: widget.windowButtons,
                          actions: QuickActions(
                            undo: controller.canUndo ? controller.undo : null,
                            redo: controller.canRedo ? controller.redo : null,
                            copy: _copy,
                            cut: () => _copy(cut: true),
                            paste: _paste,
                          ),
                        ),
                      ),
                      Ribbon(
                        controller: controller,
                        actions: RibbonActions(
                          copy: _copy,
                          cut: () => _copy(cut: true),
                          paste: _paste,
                          autoSum: _autoSum,
                          insert: _insert,
                          delete: _delete,
                          merge: _merge,
                          find: _openFind,
                          replace: () => _openFind(replace: true),
                          insertChart: _insertChart,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FormulaBar(
                controller: controller,
                editing: _editing,
                gridFocus: _gridFocus,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SpreadsheetGrid(
                        key: _grid,
                        controller: controller,
                        editing: _editing,
                        focusNode: _gridFocus,
                        zoom: _zoom,
                        onZoom: _setZoom,
                        onContextMenu: _showCellMenu,
                      ),
                    ),
                    if (_finding case final replace?)
                      Positioned(
                        top: 8,
                        right: 20,
                        child: FindBar(
                          key: _findBar,
                          controller: controller,
                          showReplace: replace,
                          onFound: (cell) =>
                              _grid.currentState?.ensureVisible(cell),
                          onClose: _closeFind,
                          onReplaced: (count) =>
                              _tell(context.l10n.replacedCount(count)),
                        ),
                      ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => SheetTabs(
                  controller: controller,
                  onRename: _renameSheet,
                  onDelete: _deleteSheet,
                ),
              ),
              StatusBar(
                controller: controller,
                locale: _locale,
                zoom: _zoom,
                onZoom: _setZoom,
                trailing: switch (widget.updates) {
                  final updates? => UpdateStatusChip(
                    check: updates,
                    onUpdate: _startUpdate,
                  ),
                  null => null,
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Without the system title bar the window needs resize edges: on Windows
  /// only the top one is missing; on Linux, with no frame, all of them are.
  Widget _resizable(Widget child) {
    if (!isDesktopPlatform || defaultTargetPlatform == TargetPlatform.macOS) {
      return child;
    }
    return DragToResizeArea(
      enableResizeEdges: _maximized || _fullScreen
          ? const []
          : defaultTargetPlatform == TargetPlatform.windows
          ? const [ResizeEdge.topLeft, ResizeEdge.top, ResizeEdge.topRight]
          : null,
      child: child,
    );
  }
}
