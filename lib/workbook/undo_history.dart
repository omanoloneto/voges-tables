import '../formula/formula.dart';
import '../sheet/cell_address.dart';
import '../sheet/chart.dart';
import '../sheet/structure.dart';
import '../sheet/workbook.dart';

/// Something that undo can take back.
sealed class HistoryEntry {
  int get sheet;
  bool get isEmpty;
}

/// One change that can be undone: the cells of one sheet before and after,
/// plus sizes of columns and rows.
class Change extends HistoryEntry {
  Change(this.sheet);

  @override
  final int sheet;
  final Map<CellAddress, Cell> before = {};
  final Map<CellAddress, Cell> after = {};
  final Map<int, double?> widthsBefore = {};
  final Map<int, double?> widthsAfter = {};
  final Map<int, double?> heightsBefore = {};
  final Map<int, double?> heightsAfter = {};
  List<CellRange>? mergesBefore;
  List<CellRange>? mergesAfter;
  List<SheetChart>? chartsBefore;
  List<SheetChart>? chartsAfter;

  @override
  bool get isEmpty =>
      after.isEmpty &&
      widthsAfter.isEmpty &&
      heightsAfter.isEmpty &&
      mergesAfter == null &&
      chartsAfter == null;
}

/// Rows or columns inserted or deleted, with what undo needs to put back:
/// the layout of the sheet before and what the calculator rewrote.
class StructureChange extends HistoryEntry {
  StructureChange(this.edit, this.layout, this.charts, this.result);

  final StructureEdit edit;
  final SheetLayout layout;

  /// The charts of every sheet before, as charts on other sheets can read
  /// the edited one.
  final List<List<SheetChart>> charts;
  StructureResult result;

  @override
  int get sheet => edit.sheet;

  @override
  bool get isEmpty => false;
}

/// A sheet renamed; formulas and charts that read it follow both ways.
class SheetRename extends HistoryEntry {
  SheetRename(this.sheet, this.oldName, this.newName);

  @override
  final int sheet;
  final String oldName;
  final String newName;

  @override
  bool get isEmpty => oldName == newName;
}

class UndoHistory {
  static const limit = 200;

  final List<HistoryEntry> _undo = [];
  final List<HistoryEntry> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void record(HistoryEntry change) {
    if (change.isEmpty) return;
    _undo.add(change);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  HistoryEntry? takeUndo() {
    if (_undo.isEmpty) return null;
    final change = _undo.removeLast();
    _redo.add(change);
    return change;
  }

  HistoryEntry? takeRedo() {
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
