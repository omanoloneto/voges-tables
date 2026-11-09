import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../sheet/cell_address.dart';
import '../workbook/find.dart';
import '../workbook/workbook_controller.dart';

/// Find and Replace over the grid, at its top right corner. Enter goes to
/// the next match, Shift+Enter to the previous one and Esc closes it.
class FindBar extends StatefulWidget {
  const FindBar({
    required this.controller,
    required this.showReplace,
    required this.onFound,
    required this.onClose,
    required this.onReplaced,
    super.key,
  });

  final WorkbookController controller;
  final bool showReplace;
  final ValueChanged<CellAddress> onFound;
  final VoidCallback onClose;
  final ValueChanged<int> onReplaced;

  @override
  State<FindBar> createState() => FindBarState();
}

class FindBarState extends State<FindBar> {
  final _find = TextEditingController();
  final _replace = TextEditingController();
  final _findFocus = FocusNode(debugLabel: 'find');
  var _matchCase = false;
  var _wholeCell = false;
  var _inFormulas = false;
  late var _showReplace = widget.showReplace;
  Timer? _counting;
  List<CellAddress>? _found;
  FindQuery? _foundFor;

  WorkbookController get controller => widget.controller;

  FindQuery get _query => FindQuery(
    _find.text,
    matchCase: _matchCase,
    wholeCell: _wholeCell,
    inFormulas: _inFormulas,
  );

  @override
  void initState() {
    super.initState();
    _findFocus.requestFocus();
    controller.addListener(_onWorkbook);
  }

  @override
  void didUpdateWidget(FindBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showReplace != oldWidget.showReplace) {
      _showReplace = widget.showReplace;
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onWorkbook);
    _counting?.cancel();
    _find.dispose();
    _replace.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  /// Brings the focus back to the search text, as Ctrl+F does when open.
  void focus({bool replace = false}) {
    if (replace && !_showReplace) setState(() => _showReplace = true);
    _findFocus.requestFocus();
    _find.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _find.text.length,
    );
  }

  void _onWorkbook() => _recount();

  /// Counting looks at every cell, so it waits for a pause in the typing.
  void _recount() {
    _counting?.cancel();
    _counting = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final query = _query;
      setState(() {
        _found = query.isEmpty ? null : controller.findAll(query);
        _foundFor = query;
      });
    });
  }

  void _next({bool backwards = false}) {
    if (_find.text.isEmpty) return;
    final found = controller.findNext(_query, backwards: backwards);
    if (found != null) widget.onFound(found);
    _counting?.cancel();
    final query = _query;
    setState(() {
      _found = controller.findAll(query);
      _foundFor = query;
    });
  }

  void _replaceNext() {
    if (_find.text.isEmpty) return;
    final found = controller.replaceNext(_query, _replace.text);
    if (found != null) widget.onFound(found);
  }

  void _replaceAll() {
    if (_find.text.isEmpty) return;
    widget.onReplaced(controller.replaceAll(_query, _replace.text));
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// "3 of 12", from the last count; nothing while a new one is pending.
  String? get _position {
    final found = _found;
    if (found == null || _foundFor != _query) return null;
    if (found.isEmpty) return context.l10n.findNone;
    final index = found.indexOf(controller.editCell);
    return context.l10n.findResult(index + 1, found.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget toggle(IconData icon, String tip, bool on, VoidCallback onTap) =>
        IconButton(
          tooltip: tip,
          isSelected: on,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 18),
          onPressed: () {
            onTap();
            _recount();
          },
        );
    Widget field(
      TextEditingController controller,
      String hint, {
      FocusNode? focus,
      required VoidCallback onSubmit,
    }) => SizedBox(
      width: 220,
      height: 34,
      child: TextField(
        controller: controller,
        focusNode: focus,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (focus != null) _recount();
        },
        onSubmitted: (_) {
          onSubmit();
          (focus ?? _findFocus).requestFocus();
        },
      ),
    );

    return Focus(
      onKeyEvent: _key,
      child: Material(
        elevation: 4,
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.replace,
                    isSelected: _showReplace,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.find_replace, size: 18),
                    onPressed: () =>
                        setState(() => _showReplace = !_showReplace),
                  ),
                  Shortcuts(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.enter, shift: true):
                          _PreviousIntent(),
                    },
                    child: Actions(
                      actions: {
                        _PreviousIntent: CallbackAction<_PreviousIntent>(
                          onInvoke: (_) => _next(backwards: true),
                        ),
                      },
                      child: field(
                        _find,
                        l10n.find,
                        focus: _findFocus,
                        onSubmit: _next,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _position ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  toggle(
                    Icons.text_fields,
                    l10n.matchCase,
                    _matchCase,
                    () => setState(() => _matchCase = !_matchCase),
                  ),
                  toggle(
                    Icons.crop_square,
                    l10n.wholeCell,
                    _wholeCell,
                    () => setState(() => _wholeCell = !_wholeCell),
                  ),
                  toggle(
                    Icons.functions,
                    l10n.lookInFormulas,
                    _inFormulas,
                    () => setState(() => _inFormulas = !_inFormulas),
                  ),
                  IconButton(
                    tooltip: l10n.findPrevious,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                    onPressed: () => _next(backwards: true),
                  ),
                  IconButton(
                    tooltip: l10n.findNext,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    onPressed: _next,
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              if (_showReplace)
                Padding(
                  padding: const EdgeInsets.only(left: 40, top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      field(_replace, l10n.replaceWith, onSubmit: _replaceNext),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _replaceNext,
                        child: Text(l10n.replace),
                      ),
                      TextButton(
                        onPressed: _replaceAll,
                        child: Text(l10n.replaceAll),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}
