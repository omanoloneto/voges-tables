import '../sheet/cell_address.dart';
import '../sheet/workbook.dart';

/// One change that can be undone: the cells of one sheet before and after,
/// plus sizes of columns and rows.
class Change {
  Change(this.sheet);

  final int sheet;
  final Map<CellAddress, Cell> before = {};
  final Map<CellAddress, Cell> after = {};
  final Map<int, double?> widthsBefore = {};
  final Map<int, double?> widthsAfter = {};
  final Map<int, double?> heightsBefore = {};
  final Map<int, double?> heightsAfter = {};

  bool get isEmpty =>
      after.isEmpty && widthsAfter.isEmpty && heightsAfter.isEmpty;
}

class UndoHistory {
  static const limit = 200;

  final List<Change> _undo = [];
  final List<Change> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void record(Change change) {
    if (change.isEmpty) return;
    _undo.add(change);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  Change? takeUndo() {
    if (_undo.isEmpty) return null;
    final change = _undo.removeLast();
    _redo.add(change);
    return change;
  }

  Change? takeRedo() {
    if (_redo.isEmpty) return null;
    final change = _redo.removeLast();
    _undo.add(change);
    return change;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
