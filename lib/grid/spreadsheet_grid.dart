import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../formula/references.dart';
import '../l10n/l10n.dart';
import '../sheet/cell_address.dart';
import '../sheet/chart.dart';
import '../sheet/workbook.dart';
import '../shell/platform.dart';
import '../workbook/selection.dart';
import '../workbook/workbook_controller.dart';
import 'cell_editing.dart';
import 'chart_frame.dart';
import 'chart_kinds.dart';
import 'chart_painter.dart';
import 'grid_axis.dart';
import 'grid_painter.dart';

const columnHeaderHeight = 24.0;
const _resizeGrip = 4.0;
const _scrollbarThickness = 10.0;

enum _Drag { none, cells, fill, columns, rows, columnSize, rowSize, reference }

/// The cells of the active sheet: painting, mouse, keyboard and the text
/// editor over the cell being typed in.
class SpreadsheetGrid extends StatefulWidget {
  const SpreadsheetGrid({
    required this.controller,
    required this.editing,
    required this.focusNode,
    required this.zoom,
    required this.onZoom,
    required this.onContextMenu,
    super.key,
  });

  final WorkbookController controller;
  final CellEditing editing;
  final FocusNode focusNode;
  final double zoom;
  final ValueChanged<double> onZoom;

  /// A right click, with where it happened on the screen.
  final ValueChanged<Offset> onContextMenu;

  @override
  State<SpreadsheetGrid> createState() => SpreadsheetGridState();
}

class SpreadsheetGridState extends State<SpreadsheetGrid> {
  final _textCache = TextCache();
  final Map<int, Offset> _scrolls = {};
  var _scroll = Offset.zero;
  var _size = Size.zero;
  var _drag = _Drag.none;
  int? _resizing;
  CellRange? _fillPreview;
  var _cursor = SystemMouseCursors.basic as MouseCursor;
  var _sheet = 0;

  WorkbookController get controller => widget.controller;
  CellEditing get editing => widget.editing;
  double get zoom => widget.zoom;
  Sheet get sheet => controller.sheet;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onWorkbook);
    editing.addListener(_onEditing);
  }

  @override
  void didUpdateWidget(SpreadsheetGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_onWorkbook);
      controller.addListener(_onWorkbook);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onWorkbook);
    editing.removeListener(_onEditing);
    _textCache.dispose();
    super.dispose();
  }

  void _onWorkbook() {
    _sizesChanged();
    if (_sheet != controller.activeSheet) {
      _scrolls[_sheet] = _scroll;
      _sheet = controller.activeSheet;
      _scroll = _scrolls[_sheet] ?? Offset.zero;
      _chart = null;
    }
    if ((_chart ?? -1) >= sheet.charts.length) _chart = null;
    setState(() {});
  }

  // Charts.

  int? _chart;
  final _snapshots = <SheetChart, ChartSnapshot>{};
  var _snapshotsRevision = -1;

  /// Selects the chart at [index] and scrolls to it, as after inserting it.
  void selectChart(int index) {
    if (index < 0 || index >= sheet.charts.length) return;
    setState(() => _chart = index);
    ensureVisible(sheet.charts[index].from.cell);
  }

  ChartSnapshot _snapshotOf(SheetChart chart) {
    if (_snapshotsRevision != controller.revision) {
      _snapshots.clear();
      _snapshotsRevision = controller.revision;
    }
    return _snapshots[chart] ??= ChartSnapshot.of(controller, chart);
  }

  /// The chart's frame in logical pixels on the screen.
  Rect _chartRect(SheetChart chart) {
    final columns = _columns, rows = _rows;
    return Rect.fromLTRB(
      columns.screenStart(chart.from.cell.column) + chart.from.dx,
      rows.screenStart(chart.from.cell.row) + chart.from.dy,
      columns.screenStart(chart.to.cell.column) + chart.to.dx,
      rows.screenStart(chart.to.cell.row) + chart.to.dy,
    );
  }

  /// The cell and offset under a logical point on the screen.
  ChartPoint _pointAt(Offset p) {
    final columns = _columns, rows = _rows;
    final column =
        columns.indexAtScreen(math.max(p.dx, columns.headerSize)) ??
        columns.firstScrolled;
    final row =
        rows.indexAtScreen(math.max(p.dy, rows.headerSize)) ??
        rows.firstScrolled;
    return ChartPoint(
      CellAddress(column, row),
      dx: math.max(0, p.dx - columns.screenStart(column)),
      dy: math.max(0, p.dy - rows.screenStart(row)),
    );
  }

  void _chartMoved(int index, Rect screen) {
    final logical = Rect.fromLTRB(
      screen.left / zoom,
      screen.top / zoom,
      screen.right / zoom,
      screen.bottom / zoom,
    );
    final chart = sheet.charts[index];
    controller.updateChart(
      index,
      chart.copyWith(
        from: _pointAt(logical.topLeft),
        to: _pointAt(logical.bottomRight),
      ),
    );
  }

  Widget _charts(AppLocalizations l10n) {
    final charts = sheet.charts;
    final left = _rowHeaderWidth, top = columnHeaderHeight;
    final view = Rect.fromLTRB(
      left,
      top,
      _logicalSize.width,
      _logicalSize.height,
    );
    final children = <Widget>[];
    for (var i = 0; i < charts.length; i++) {
      final rect = _chartRect(charts[i]);
      if (!rect.overlaps(view) && i != _chart) continue;
      final screen = Rect.fromLTRB(
        (rect.left - left) * zoom,
        (rect.top - top) * zoom,
        (rect.right - left) * zoom,
        (rect.bottom - top) * zoom,
      );
      children.add(
        ChartFrame(
          key: ObjectKey(charts[i]),
          rect: screen,
          snapshot: _snapshotOf(charts[i]),
          selected: i == _chart,
          zoom: zoom,
          emptyText: l10n.chartNoData,
          onSelect: () {
            if (editing.active) editing.commit(EditMove.none);
            widget.focusNode.requestFocus();
            if (_chart != i) setState(() => _chart = i);
          },
          onChanged: (moved) =>
              _chartMoved(i, moved.translate(left * zoom, top * zoom)),
        ),
      );
    }
    if (_chart case final index?) {
      final rect = _chartRect(charts[index]);
      children.add(
        Positioned(
          right: math.max(0, (_logicalSize.width - rect.right) * zoom),
          top: math.max(0, (rect.top - top) * zoom - 40),
          child: _ChartToolbar(
            chart: charts[index],
            onChanged: (chart) => controller.updateChart(index, chart),
            onDelete: () => controller.deleteChart(index),
          ),
        ),
      );
    }
    return Positioned(
      left: left * zoom,
      top: top * zoom,
      right: _scrollbarThickness,
      bottom: _scrollbarThickness,
      child: ClipRect(
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }

  void _onEditing() => setState(() {});

  // Layout.

  double get _rowHeaderWidth {
    final digits =
        '${_rowsAxis.indexAt(_scroll.dy + _logicalSize.height) + 1}'.length;
    return math.max(40.0, 14.0 + digits * 8.0);
  }

  Size get _logicalSize => Size(
    math.max(0, _size.width - _scrollbarThickness) / zoom,
    math.max(0, _size.height - _scrollbarThickness) / zoom,
  );

  GridAxis? _columnsCache, _rowsCache;

  /// Built once per frame: hovering and painting ask for positions many
  /// times, and building sorts the changed sizes.
  GridAxis get _columnsAxis => _columnsCache ??= GridAxis(
    defaultSize: Sheet.defaultColumnWidth,
    sizes: sheet.columnWidths,
    count: CellAddress.maxColumns,
    frozen: sheet.frozenColumns,
  );

  GridAxis get _rowsAxis => _rowsCache ??= GridAxis(
    defaultSize: Sheet.defaultRowHeight,
    sizes: sheet.rowHeights,
    count: CellAddress.maxRows,
    frozen: sheet.frozenRows,
  );

  void _sizesChanged() {
    _columnsCache = null;
    _rowsCache = null;
  }

  AxisView get _columns => AxisView(
    _columnsAxis,
    scroll: _scroll.dx,
    headerSize: _rowHeaderWidth,
    extent: _logicalSize.width,
  );

  AxisView get _rows => AxisView(
    _rowsAxis,
    scroll: _scroll.dy,
    headerSize: columnHeaderHeight,
    extent: _logicalSize.height,
  );

  int get _usedColumns => (sheet.usedRange?.last.column ?? 0) + 1;
  int get _usedRows => (sheet.usedRange?.last.row ?? 0) + 1;

  void _scrollTo(Offset offset) {
    final columns = _columns, rows = _rows;
    final selection = controller.selection.range.last;
    final maxX = math.max(
      columns.maxScroll(math.max(_usedColumns, selection.column + 1)),
      0.0,
    );
    final maxY = math.max(
      rows.maxScroll(math.max(_usedRows, selection.row + 1)),
      0.0,
    );
    final next = Offset(offset.dx.clamp(0, maxX), offset.dy.clamp(0, maxY));
    if (next != _scroll) setState(() => _scroll = next);
  }

  /// Scrolls just enough for [cell] to show, as moving with the keyboard does.
  void ensureVisible(CellAddress cell) {
    final columns = _columns, rows = _rows;
    var dx = _scroll.dx, dy = _scroll.dy;
    if (cell.column >= columns.axis.frozen) {
      final left = columns.screenStart(cell.column),
          right = columns.screenEnd(cell.column);
      final start = columns.headerSize + columns.axis.frozenExtent;
      if (left < start) dx -= start - left;
      if (right > _logicalSize.width) dx += right - _logicalSize.width;
    }
    if (cell.row >= rows.axis.frozen) {
      final top = rows.screenStart(cell.row), bottom = rows.screenEnd(cell.row);
      final start = rows.headerSize + rows.axis.frozenExtent;
      if (top < start) dy -= start - top;
      if (bottom > _logicalSize.height) dy += bottom - _logicalSize.height;
    }
    final next = Offset(math.max(0, dx), math.max(0, dy));
    if (next != _scroll) setState(() => _scroll = next);
  }

  int get _pageRows => math.max(
    1,
    ((_logicalSize.height - columnHeaderHeight) / Sheet.defaultRowHeight)
            .floor() -
        1,
  );

  // Hit testing.

  CellAddress? _cellAt(Offset local) {
    final p = local / zoom;
    final column = _columns.indexAtScreen(p.dx),
        row = _rows.indexAtScreen(p.dy);
    if (column == null || row == null) return null;
    return CellAddress(column, row);
  }

  /// The cell under [local], or the nearest one when the pointer left the
  /// cells while dragging.
  CellAddress _cellNear(Offset local) {
    final p = local / zoom;
    final columns = _columns, rows = _rows;
    final column =
        columns.indexAtScreen(math.max(p.dx, columns.headerSize)) ?? 0;
    final row = rows.indexAtScreen(math.max(p.dy, rows.headerSize)) ?? 0;
    return CellAddress(column, row);
  }

  bool _onFillHandle(Offset local) {
    final painter = _painter();
    final corner =
        painter.rangeRect(controller.selection.range).bottomRight * zoom;
    return (local - corner).distance <= GridPainter.fillHandleSize;
  }

  int? _columnBorderAt(Offset local) {
    final p = local / zoom;
    if (p.dy > columnHeaderHeight) return null;
    final columns = _columns;
    for (final column in columns.visible) {
      if ((p.dx - columns.screenEnd(column)).abs() <= _resizeGrip / zoom) {
        return column;
      }
    }
    return null;
  }

  int? _rowBorderAt(Offset local) {
    final p = local / zoom;
    final rows = _rows;
    if (p.dx > _rowHeaderWidth) return null;
    for (final row in rows.visible) {
      if ((p.dy - rows.screenEnd(row)).abs() <= _resizeGrip / zoom) return row;
    }
    return null;
  }

  GridPainter _painter() => GridPainter(
    controller: controller,
    columns: _columns,
    rows: _rows,
    colors: GridColors.of(Theme.of(context).colorScheme),
    zoom: zoom,
    textCache: _textCache,
    editing: editing.active && editing.sheet == controller.activeSheet
        ? editing.address
        : null,
    fillPreview: _fillPreview,
  );

  // Mouse.

  void _hover(PointerHoverEvent event) {
    final cursor = _columnBorderAt(event.localPosition) != null
        ? SystemMouseCursors.resizeColumn
        : _rowBorderAt(event.localPosition) != null
        ? SystemMouseCursors.resizeRow
        : _onFillHandle(event.localPosition)
        ? SystemMouseCursors.precise
        : SystemMouseCursors.basic;
    if (cursor != _cursor) setState(() => _cursor = cursor);
  }

  void _pointerDown(PointerDownEvent event) {
    if (_chart != null) setState(() => _chart = null);
    final local = event.localPosition;
    final secondary = event.buttons == kSecondaryMouseButton;
    if (editing.active && editing.acceptsReference && !secondary) {
      final cell = _cellAt(local);
      if (cell != null) {
        _drag = _Drag.reference;
        _referenceStart = cell;
        editing.pickReference(
          _referenceText(CellRange.single(cell)),
          replace: false,
        );
        _keepEditorFocus();
        return;
      }
    }
    if (editing.active) editing.commit(EditMove.none);
    widget.focusNode.requestFocus();
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final p = local / zoom;
    if (secondary) {
      _selectForMenu(p);
      _menuAt = event.position;
      return;
    }
    if (_columnBorderAt(local) case final column?) {
      _drag = _Drag.columnSize;
      _resizing = column;
      _resizeOriginal = sheet.columnWidths[column];
      return;
    }
    if (_rowBorderAt(local) case final row?) {
      _drag = _Drag.rowSize;
      _resizing = row;
      _resizeOriginal = sheet.rowHeights[row];
      return;
    }
    if (_onFillHandle(local)) {
      _drag = _Drag.fill;
      return;
    }
    final columns = _columns, rows = _rows;
    if (p.dx < columns.headerSize && p.dy < rows.headerSize) {
      controller.selectAll();
      return;
    }
    if (p.dy < rows.headerSize) {
      final column = columns.indexAtScreen(p.dx) ?? 0;
      _drag = _Drag.columns;
      final anchor = shift ? controller.selection.anchor.column : column;
      controller.select(
        Selection(
          CellAddress(anchor, 0),
          CellAddress(column, CellAddress.maxRows - 1),
        ),
      );
      return;
    }
    if (p.dx < columns.headerSize) {
      final row = rows.indexAtScreen(p.dy) ?? 0;
      _drag = _Drag.rows;
      final anchor = shift ? controller.selection.anchor.row : row;
      controller.select(
        Selection(
          CellAddress(0, anchor),
          CellAddress(CellAddress.maxColumns - 1, row),
        ),
      );
      return;
    }
    final cell = _cellAt(local)!;
    _drag = _Drag.cells;
    controller.select(
      shift ? controller.selection.extendTo(cell) : Selection.single(cell),
    );
  }

  CellAddress? _referenceStart;
  Offset? _menuAt;

  /// A right click outside the selection selects what is under it first,
  /// whole rows or columns on the headers, as in Excel.
  void _selectForMenu(Offset p) {
    final columns = _columns, rows = _rows;
    final range = controller.selection.range;
    final column = columns.indexAtScreen(p.dx), row = rows.indexAtScreen(p.dy);
    if (column != null && row == null) {
      if (controller.wholeColumnsSelected &&
          column >= range.first.column &&
          column <= range.last.column) {
        return;
      }
      controller.select(
        Selection(
          CellAddress(column, 0),
          CellAddress(column, CellAddress.maxRows - 1),
        ),
      );
    } else if (row != null && column == null) {
      if (controller.wholeRowsSelected &&
          row >= range.first.row &&
          row <= range.last.row) {
        return;
      }
      controller.select(
        Selection(
          CellAddress(0, row),
          CellAddress(CellAddress.maxColumns - 1, row),
        ),
      );
    } else if (column != null && row != null) {
      final cell = CellAddress(column, row);
      if (!range.contains(cell)) controller.select(Selection.single(cell));
    }
  }

  String _referenceText(CellRange range) {
    final prefix = controller.activeSheet == editing.sheet
        ? ''
        : '${sheetPrefix(controller.sheet.name)}!';
    return '$prefix${range.a1}';
  }

  void _keepEditorFocus() {
    final bar = editing.barFocus.hasFocus;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => (bar ? editing.barFocus : editing.cellFocus).requestFocus(),
    );
  }

  void _pointerMove(PointerMoveEvent event) {
    final local = event.localPosition;
    final p = local / zoom;
    switch (_drag) {
      case _Drag.none:
        return;
      case _Drag.reference:
        final start = _referenceStart;
        if (start != null) {
          editing.pickReference(
            _referenceText(CellRange(start, _cellNear(local))),
            replace: true,
          );
        }
      case _Drag.cells:
        controller.select(controller.selection.extendTo(_cellNear(local)));
        _autoScroll(local);
      case _Drag.columns:
        final column =
            _columns.indexAtScreen(math.max(p.dx, _columns.headerSize)) ?? 0;
        controller.select(
          Selection(
            controller.selection.anchor,
            CellAddress(column, CellAddress.maxRows - 1),
          ),
        );
      case _Drag.rows:
        final row = _rows.indexAtScreen(math.max(p.dy, _rows.headerSize)) ?? 0;
        controller.select(
          Selection(
            controller.selection.anchor,
            CellAddress(CellAddress.maxColumns - 1, row),
          ),
        );
      case _Drag.fill:
        setState(() => _fillPreview = _fillTarget(_cellNear(local)));
        _autoScroll(local);
      case _Drag.columnSize:
        final column = _resizing!;
        final width = math.max(8.0, p.dx - _columns.screenStart(column));
        sheet.columnWidths[column] = width;
        _sizesChanged();
        setState(() {});
      case _Drag.rowSize:
        final row = _resizing!;
        final height = math.max(8.0, p.dy - _rows.screenStart(row));
        sheet.rowHeights[row] = height;
        _sizesChanged();
        setState(() {});
    }
  }

  double? _resizeOriginal;

  void _pointerUp(PointerUpEvent event) {
    if (_menuAt case final position?) {
      _menuAt = null;
      widget.onContextMenu(position);
    }
    switch (_drag) {
      case _Drag.fill:
        final target = _fillPreview;
        _fillPreview = null;
        if (target != null) controller.fillTo(target);
      case _Drag.columnSize:
        final column = _resizing!;
        final width = sheet.columnWidths[column] ?? Sheet.defaultColumnWidth;
        _restore(sheet.columnWidths, column);
        if (width != (_resizeOriginal ?? Sheet.defaultColumnWidth)) {
          controller.setColumnWidth(column, width);
        }
      case _Drag.rowSize:
        final row = _resizing!;
        final height = sheet.rowHeights[row] ?? Sheet.defaultRowHeight;
        _restore(sheet.rowHeights, row);
        if (height != (_resizeOriginal ?? Sheet.defaultRowHeight)) {
          controller.setRowHeight(row, height);
        }
      case _Drag.reference:
        _keepEditorFocus();
      default:
        break;
    }
    _drag = _Drag.none;
    _resizing = null;
    setState(() {});
  }

  /// Puts back the size from before the drag, so the change is recorded
  /// once, with undo, when the mouse is released.
  void _restore(Map<int, double> sizes, int index) {
    _sizesChanged();
    final original = _resizeOriginal;
    if (original == null) {
      sizes.remove(index);
    } else {
      sizes[index] = original;
    }
  }

  /// The fill handle extends along the direction the pointer went furthest.
  CellRange? _fillTarget(CellAddress cell) {
    final range = controller.selection.range;
    if (range.contains(cell)) return null;
    final below = cell.row - range.last.row, above = range.first.row - cell.row;
    final right = cell.column - range.last.column,
        left = range.first.column - cell.column;
    final vertical = math.max(below, above), horizontal = math.max(right, left);
    if (vertical >= horizontal) {
      return below > 0
          ? CellRange(range.first, CellAddress(range.last.column, cell.row))
          : CellRange(CellAddress(range.first.column, cell.row), range.last);
    }
    return right > 0
        ? CellRange(range.first, CellAddress(cell.column, range.last.row))
        : CellRange(CellAddress(cell.column, range.first.row), range.last);
  }

  void _autoScroll(Offset local) {
    const edge = 24.0, step = 24.0;
    var dx = 0.0, dy = 0.0;
    if (local.dx > _size.width - _scrollbarThickness - edge) dx = step;
    if (local.dy > _size.height - _scrollbarThickness - edge) dy = step;
    if (local.dx < edge + _rowHeaderWidth * zoom && _scroll.dx > 0) dx = -step;
    if (local.dy < edge + columnHeaderHeight * zoom && _scroll.dy > 0) {
      dy = -step;
    }
    if (dx != 0 || dy != 0) _scrollTo(_scroll + Offset(dx, dy));
  }

  void _doubleTap(TapDownDetails details) {
    final local = details.localPosition;
    if (_columnBorderAt(local) case final column?) {
      _autoFit(column);
      return;
    }
    final cell = _cellAt(local);
    if (cell != null) {
      controller.select(Selection.single(cell));
      editing.start(controller.editCell);
    }
  }

  /// Makes the column as wide as its longest text, as a double click on the
  /// header border does.
  void _autoFit(int column) {
    var widest = 0.0;
    for (final entry in sheet.cells.entries) {
      if (entry.key.column != column) continue;
      final text = controller.displayAt(entry.key);
      if (text.isEmpty) continue;
      final width = _textCache.layout(text, entry.value.style).width;
      if (width > widest) widest = width;
    }
    controller.setColumnWidth(
      column,
      widest == 0 ? Sheet.defaultColumnWidth : widest + 10,
    );
  }

  void _signal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    if (isApplePlatform ? keys.isMetaPressed : keys.isControlPressed) {
      widget.onZoom(zoom * (event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1));
      return;
    }
    var delta = event.scrollDelta / zoom;
    if (keys.isShiftPressed && delta.dx == 0) delta = Offset(delta.dy, 0);
    _scrollTo(_scroll + delta);
  }

  var _pinch = 1.0;

  void _panZoom(PointerPanZoomUpdateEvent event) {
    if (event.scale != 1) {
      widget.onZoom(zoom * event.scale / _pinch);
      _pinch = event.scale;
      return;
    }
    _scrollTo(_scroll - event.panDelta / zoom);
  }

  // Keyboard.

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (editing.active) return _typeAhead(event);
    if (_chart case final index?) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.delete ||
          key == LogicalKeyboardKey.backspace) {
        _chart = null;
        controller.deleteChart(index);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        setState(() => _chart = null);
        return KeyEventResult.handled;
      }
    }
    final keys = HardwareKeyboard.instance;
    final command = isApplePlatform
        ? keys.isMetaPressed
        : keys.isControlPressed;
    final shift = keys.isShiftPressed;
    final key = event.logicalKey;
    final selection = controller.selection;
    CellAddress? target;
    if (key == LogicalKeyboardKey.arrowDown) {
      target = command
          ? _jump(selection.active, 0, 1)
          : _step(selection.active, 0, 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      target = command
          ? _jump(selection.active, 0, -1)
          : _step(selection.active, 0, -1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      target = command
          ? _jump(selection.active, 1, 0)
          : _step(selection.active, 1, 0);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      target = command
          ? _jump(selection.active, -1, 0)
          : _step(selection.active, -1, 0);
    } else if (key == LogicalKeyboardKey.pageDown) {
      target = selection.active.offset(0, _pageRows);
    } else if (key == LogicalKeyboardKey.pageUp) {
      target = selection.active.offset(0, -_pageRows);
    } else if (key == LogicalKeyboardKey.home) {
      target = command
          ? const CellAddress(0, 0)
          : CellAddress(0, selection.active.row);
    } else if (key == LogicalKeyboardKey.end && command) {
      target = sheet.usedRange?.last ?? const CellAddress(0, 0);
    }
    if (target != null) {
      final cell = clampAddress(target);
      controller.select(
        shift ? selection.extendTo(cell) : Selection.single(cell),
      );
      ensureVisible(cell);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _moveInside(0, shift ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _moveInside(shift ? -1 : 1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      editing.start(controller.editCell);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      controller.clearContents();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (!command &&
        !keys.isAltPressed &&
        character != null &&
        character.isNotEmpty &&
        character.codeUnitAt(0) >= 32 &&
        character.codeUnitAt(0) != 127) {
      ensureVisible(selection.active);
      editing.start(controller.editCell, replaceWith: character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Keys that arrive before the editor over the cell has the focus: typing
  /// fast right after the first letter must not lose any.
  KeyEventResult _typeAhead(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.escape) {
      return _editorKey(widget.focusNode, event);
    }
    final character = event.character;
    if (character == null ||
        character.isEmpty ||
        character.codeUnitAt(0) < 32) {
      return KeyEventResult.ignored;
    }
    final value = editing.text.value;
    final at = value.selection.isValid
        ? value.selection.baseOffset
        : value.text.length;
    final end = value.selection.isValid
        ? value.selection.extentOffset
        : value.text.length;
    final text = value.text.replaceRange(at, end, character);
    editing.text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: at + character.length),
    );
    return KeyEventResult.handled;
  }

  /// One cell over, leaving a merge from its far edge.
  CellAddress _step(CellAddress from, int dx, int dy) {
    final merge = sheet.mergeAt(from);
    if (merge == null) return from.offset(dx, dy);
    return CellAddress(
      dx > 0 ? merge.last.column + dx : merge.first.column + dx,
      dy > 0 ? merge.last.row + dy : merge.first.row + dy,
    );
  }

  void _moveInside(int columns, int rows) {
    final cell = clampAddress(
      _step(controller.selection.active, columns, rows),
    );
    controller.select(Selection.single(cell));
    ensureVisible(cell);
  }

  /// Ctrl and the arrows: to the edge of the data block, or to the next
  /// filled cell, as in Excel.
  CellAddress _jump(CellAddress from, int dx, int dy) {
    bool filled(CellAddress cell) =>
        sheet.cells[cell] != null &&
        !sheet.cells[cell]!.isEmpty &&
        controller.displayAt(cell).isNotEmpty;
    final limit = sheet.usedRange?.last ?? from;
    final maxColumn = math.max(limit.column, from.column),
        maxRow = math.max(limit.row, from.row);
    var cell = from;
    CellAddress next(CellAddress c) => c.offset(dx, dy);
    bool inside(CellAddress c) =>
        c.column >= 0 && c.row >= 0 && c.column <= maxColumn && c.row <= maxRow;
    if (!inside(next(cell))) return clampAddress(next(cell));
    if (filled(cell) && filled(next(cell))) {
      while (inside(next(cell)) && filled(next(cell))) {
        cell = next(cell);
      }
      return cell;
    }
    cell = next(cell);
    while (inside(cell) && !filled(cell)) {
      cell = next(cell);
    }
    if (!inside(cell)) {
      return dx > 0 || dy > 0
          ? CellAddress(
              dx > 0 ? maxColumn : from.column,
              dy > 0 ? maxRow : from.row,
            )
          : CellAddress(dx < 0 ? 0 : from.column, dy < 0 ? 0 : from.row);
    }
    return cell;
  }

  // Editor over the cell.

  KeyEventResult _editorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !alt) {
      _finish(shift ? EditMove.up : EditMove.down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _finish(shift ? EditMove.left : EditMove.right);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      editing.cancel();
      widget.focusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (editing.quick && !editing.acceptsReference) {
      final move = switch (key) {
        LogicalKeyboardKey.arrowDown => EditMove.down,
        LogicalKeyboardKey.arrowUp => EditMove.up,
        LogicalKeyboardKey.arrowRight => EditMove.right,
        LogicalKeyboardKey.arrowLeft => EditMove.left,
        _ => null,
      };
      if (move != null) {
        _finish(move);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _finish(EditMove move) {
    editing.commit(move);
    widget.focusNode.requestFocus();
    ensureVisible(controller.selection.active);
  }

  Widget? _editor(GridPainter painter) {
    final address = editing.address;
    if (address == null || editing.sheet != controller.activeSheet) return null;
    final rect = painter.areaRect(address);
    final style = sheet.cellAt(address).style;
    final textStyle = TextCache.textStyleOf(
      style,
    ).copyWith(fontSize: TextCache.textStyleOf(style).fontSize! * zoom);
    final minWidth = rect.width * zoom;
    final width = math.max(
      minWidth,
      (_textCache.layout('${editing.text.text}  ', style).width + 8) * zoom,
    );
    return Positioned(
      left: rect.left * zoom,
      top: rect.top * zoom,
      child: Container(
        constraints: BoxConstraints(
          minWidth: minWidth,
          minHeight: rect.height * zoom,
          maxWidth: math.max(minWidth, width),
        ),
        decoration: BoxDecoration(
          color: Color(style.fillColor ?? 0xFFFFFFFF),
          border: Border.all(color: const Color(0xFF1D6B3E), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
        ),
        child: Focus(
          onKeyEvent: _editorKey,
          child: EditableText(
            controller: editing.text,
            focusNode: editing.cellFocus,
            style: textStyle,
            cursorColor: const Color(0xFF1D6B3E),
            backgroundCursorColor: const Color(0xFF9E9E9E),
            selectionColor: const Color(0x551D6B3E),
            maxLines: null,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _sizesChanged();
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final painter = _painter();
        final editor = _editor(painter);
        return Focus(
          focusNode: widget.focusNode,
          onKeyEvent: _key,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                right: _scrollbarThickness,
                bottom: _scrollbarThickness,
                child: MouseRegion(
                  cursor: _cursor,
                  onHover: _hover,
                  child: Listener(
                    onPointerDown: _pointerDown,
                    onPointerMove: _pointerMove,
                    onPointerUp: _pointerUp,
                    onPointerSignal: _signal,
                    onPointerPanZoomStart: (_) => _pinch = 1,
                    onPointerPanZoomUpdate: _panZoom,
                    child: GestureDetector(
                      onDoubleTapDown: _doubleTap,
                      onDoubleTap: () {},
                      child: CustomPaint(painter: painter, size: Size.infinite),
                    ),
                  ),
                ),
              ),
              if (sheet.charts.isNotEmpty) _charts(context.l10n),
              ?editor,
              Positioned(
                right: 0,
                top: columnHeaderHeight * zoom,
                bottom: _scrollbarThickness,
                width: _scrollbarThickness,
                child: _ScrollThumb(
                  vertical: true,
                  position: _scroll.dy,
                  total:
                      math.max(
                        _rows.maxScroll(
                          math.max(
                            _usedRows,
                            controller.selection.range.last.row + 1,
                          ),
                        ),
                        1,
                      ) +
                      _logicalSize.height,
                  visible: _logicalSize.height,
                  onScroll: (value) => _scrollTo(Offset(_scroll.dx, value)),
                ),
              ),
              Positioned(
                left: _rowHeaderWidth * zoom,
                right: _scrollbarThickness,
                bottom: 0,
                height: _scrollbarThickness,
                child: _ScrollThumb(
                  vertical: false,
                  position: _scroll.dx,
                  total:
                      math.max(
                        _columns.maxScroll(
                          math.max(
                            _usedColumns,
                            controller.selection.range.last.column + 1,
                          ),
                        ),
                        1,
                      ) +
                      _logicalSize.width,
                  visible: _logicalSize.width,
                  onScroll: (value) => _scrollTo(Offset(value, _scroll.dy)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A thin draggable scrollbar; the grid scrolls by itself, so it does not
/// need a scrollable widget.
class _ScrollThumb extends StatelessWidget {
  const _ScrollThumb({
    required this.vertical,
    required this.position,
    required this.total,
    required this.visible,
    required this.onScroll,
  });

  final bool vertical;
  final double position;
  final double total;
  final double visible;
  final ValueChanged<double> onScroll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final track = vertical ? constraints.maxHeight : constraints.maxWidth;
        final length = math.max(
          24.0,
          track * (visible / total).clamp(0.0, 1.0),
        );
        final room = math.max(1.0, track - length);
        final range = math.max(1.0, total - visible);
        final offset = (position / range).clamp(0.0, 1.0) * room;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: vertical
              ? (d) => onScroll(position + d.delta.dy / room * range)
              : null,
          onHorizontalDragUpdate: vertical
              ? null
              : (d) => onScroll(position + d.delta.dx / room * range),
          child: ColoredBox(
            color: scheme.surfaceContainerLow,
            child: Stack(
              children: [
                Positioned(
                  left: vertical ? 2 : offset,
                  top: vertical ? offset : 2,
                  width: vertical ? _scrollbarThickness - 4 : length,
                  height: vertical ? length : _scrollbarThickness - 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.outline.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Type, title, legend and delete for the selected chart.
class _ChartToolbar extends StatelessWidget {
  const _ChartToolbar({
    required this.chart,
    required this.onChanged,
    required this.onDelete,
  });

  final SheetChart chart;
  final ValueChanged<SheetChart> onChanged;
  final VoidCallback onDelete;

  Future<void> _editTitle(BuildContext context) async {
    final l10n = context.l10n;
    final text = TextEditingController(text: chart.title ?? '');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chartTitle),
        content: TextField(
          controller: text,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: Text(l10n.apply),
          ),
        ],
      ),
    );
    text.dispose();
    if (title == null) return;
    final trimmed = title.trim();
    onChanged(chart.copyWith(title: () => trimmed.isEmpty ? null : trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<ChartKind>(
              tooltip: l10n.chartType,
              icon: Icon(chartKindIcon(chart.kind), size: 18),
              initialValue: chart.kind,
              onSelected: (kind) => onChanged(chart.copyWith(kind: kind)),
              itemBuilder: (context) => [
                for (final kind in ChartKind.values)
                  PopupMenuItem(
                    value: kind,
                    height: 36,
                    child: Row(
                      children: [
                        Icon(chartKindIcon(kind), size: 18),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            chartKindName(l10n, kind),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: l10n.chartTitle,
              icon: const Icon(Icons.title, size: 18),
              onPressed: () => _editTitle(context),
            ),
            IconButton(
              tooltip: l10n.chartLegend,
              isSelected: chart.showLegend,
              icon: const Icon(Icons.legend_toggle, size: 18),
              onPressed: () =>
                  onChanged(chart.copyWith(showLegend: !chart.showLegend)),
            ),
            IconButton(
              tooltip: l10n.deleteChart,
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
