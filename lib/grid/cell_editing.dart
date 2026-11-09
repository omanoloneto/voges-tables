import 'package:flutter/widgets.dart';

import '../sheet/cell_address.dart';
import '../workbook/selection.dart';
import '../workbook/workbook_controller.dart';

enum EditMove { down, up, right, left, none }

/// The text being typed in a cell, shared by the editor over the cell and
/// the formula bar so both always show the same thing.
class CellEditing extends ChangeNotifier {
  CellEditing(this.workbook);

  final WorkbookController workbook;
  final text = TextEditingController();
  final cellFocus = FocusNode(debugLabel: 'cell editor');
  final barFocus = FocusNode(debugLabel: 'formula bar');

  CellAddress? _address;
  int _sheet = 0;

  /// Typing started by a key press: the arrows leave the cell, as in Excel.
  var quick = false;

  /// Where a reference picked with the mouse was put in [text].
  TextRange? pickedReference;

  CellAddress? get address => _address;
  bool get active => _address != null;
  int get sheet => _sheet;

  void start(CellAddress address, {String? replaceWith, bool inBar = false}) {
    _address = address;
    _sheet = workbook.activeSheet;
    quick = replaceWith != null;
    pickedReference = null;
    final value = replaceWith ?? workbook.editTextAt(address);
    text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    notifyListeners();
    final focus = inBar ? barFocus : cellFocus;
    focus.requestFocus();
    // the editor over the cell only exists after the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_address != null) focus.requestFocus();
    });
  }

  /// Writes the text into the cell and moves the selection like Enter, Tab
  /// and the arrows do.
  void commit(EditMove move) {
    final address = _address;
    if (address == null) return;
    _address = null;
    pickedReference = null;
    if (workbook.activeSheet != _sheet) workbook.showSheet(_sheet);
    workbook.enter(address, text.text);
    notifyListeners();
    final next = switch (move) {
      EditMove.down => address.offset(0, 1),
      EditMove.up => address.offset(0, -1),
      EditMove.right => address.offset(1, 0),
      EditMove.left => address.offset(-1, 0),
      EditMove.none => address,
    };
    workbook.select(Selection.single(next));
  }

  void cancel() {
    if (_address == null) return;
    final address = _address!;
    _address = null;
    pickedReference = null;
    if (workbook.activeSheet != _sheet) workbook.showSheet(_sheet);
    workbook.select(Selection.single(address));
    notifyListeners();
  }

  /// A formula is waiting for a reference when the caret follows an
  /// operator, a parenthesis or an argument separator.
  bool get acceptsReference {
    if (!active || !text.text.startsWith('=')) return false;
    final picked = pickedReference;
    if (picked != null && text.selection.baseOffset == picked.end) return true;
    final caret = text.selection.baseOffset;
    if (caret < 1) return false;
    final before = text.text.substring(0, caret).trimRight();
    if (before.isEmpty) return false;
    return '=(+-*/^&,;<>:'.contains(before[before.length - 1]);
  }

  /// Puts [reference] at the caret, or replaces the one picked before while
  /// the mouse is still dragging.
  void pickReference(String reference, {required bool replace}) {
    final value = text.value;
    final picked = pickedReference;
    final start = replace && picked != null
        ? picked.start
        : value.selection.baseOffset;
    final end = replace && picked != null
        ? picked.end
        : value.selection.extentOffset;
    final updated = value.text.replaceRange(start, end, reference);
    pickedReference = TextRange(start: start, end: start + reference.length);
    text.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + reference.length),
    );
  }

  @override
  void dispose() {
    text.dispose();
    cellFocus.dispose();
    barFocus.dispose();
    super.dispose();
  }
}
