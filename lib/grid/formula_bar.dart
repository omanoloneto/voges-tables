import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../sheet/cell_address.dart';
import '../workbook/selection.dart';
import '../workbook/workbook_controller.dart';
import 'cell_editing.dart';

/// The name box with the selected address, and the text of the active cell,
/// which can be edited here as well as in the cell.
class FormulaBar extends StatefulWidget {
  const FormulaBar({
    required this.controller,
    required this.editing,
    required this.gridFocus,
    super.key,
  });

  final WorkbookController controller;
  final CellEditing editing;
  final FocusNode gridFocus;

  @override
  State<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends State<FormulaBar> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode(debugLabel: 'name box');
  final _idle = TextEditingController();

  WorkbookController get controller => widget.controller;
  CellEditing get editing => widget.editing;

  @override
  void initState() {
    super.initState();
    controller.addListener(_sync);
    editing.addListener(_sync);
    widget.editing.barFocus.addListener(_barFocus);
    _sync();
  }

  @override
  void dispose() {
    controller.removeListener(_sync);
    editing.removeListener(_sync);
    widget.editing.barFocus.removeListener(_barFocus);
    _name.dispose();
    _nameFocus.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final range = controller.selection.range;
    if (!_nameFocus.hasFocus) {
      _name.text = range.isSingle
          ? range.first.a1
          : '${range.rows}L × ${range.columns}C';
    }
    if (!editing.active) {
      _idle.text = controller.editTextAt(controller.editCell);
    }
    setState(() {});
  }

  /// Clicking the bar starts editing the active cell there.
  void _barFocus() {
    if (widget.editing.barFocus.hasFocus && !editing.active) {
      editing.start(controller.editCell, inBar: true);
    }
  }

  void _goTo(String text) {
    final parts = text.trim().split(':');
    final first = CellAddress.tryParse(parts.first);
    final last = parts.length == 2 ? CellAddress.tryParse(parts[1]) : first;
    if (first != null && last != null) {
      controller.select(Selection(first, last));
    }
    widget.gridFocus.requestFocus();
    _sync();
  }

  KeyEventResult _barKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      editing.commit(shift ? EditMove.up : EditMove.down);
      widget.gridFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      editing.commit(shift ? EditMove.left : EditMove.right);
      widget.gridFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      editing.cancel();
      widget.gridFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    InputDecoration decoration(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      border: border,
      enabledBorder: border,
    );
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: TextField(
              controller: _name,
              focusNode: _nameFocus,
              style: const TextStyle(fontSize: 13),
              decoration: decoration('A1'),
              onSubmitted: _goTo,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'fx',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Focus(
              onKeyEvent: _barKey,
              child: TextField(
                controller: editing.active ? editing.text : _idle,
                focusNode: editing.barFocus,
                style: const TextStyle(fontSize: 13),
                decoration: decoration(l10n.formulaBarHint),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
