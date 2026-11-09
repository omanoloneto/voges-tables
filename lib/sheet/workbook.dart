import 'cell_address.dart';
import 'cell_style.dart';
import 'cell_value.dart';
import 'chart.dart';
import 'structure.dart';

/// What the user typed in a cell, and its look.
///
/// A formula is kept in [input] in the canonical form: it starts with `=` and
/// uses the English function names, `,` between arguments and `.` as the
/// decimal point, exactly as `.xlsx` stores it (there without the `=`).
/// [constant] is then unused.
///
/// A constant (number, text, boolean, error) is kept in [constant], and
/// [input] is empty: the text shown to edit it again is rebuilt from the value,
/// the style and the interface language (`formula/input.dart`).
class Cell {
  const Cell({
    this.input = '',
    this.constant = const EmptyValue(),
    this.style = CellStyle.plain,
  });

  final String input;
  final CellValue constant;
  final CellStyle style;

  bool get isFormula => input.startsWith('=') && input.length > 1;
  bool get isEmpty => input.isEmpty && constant is EmptyValue && style.isPlain;

  Cell copyWith({String? input, CellValue? constant, CellStyle? style}) => Cell(
    input: input ?? this.input,
    constant: constant ?? this.constant,
    style: style ?? this.style,
  );
}

/// One tab of the workbook. Only the cells that hold something are stored.
class Sheet {
  Sheet(this.name);

  String name;
  Map<CellAddress, Cell> _cells = {};
  Map<int, double> columnWidths = {};
  Map<int, double> rowHeights = {};
  int frozenRows = 0;
  int frozenColumns = 0;
  List<SheetChart> charts = const [];

  static const defaultColumnWidth = 88.0;
  static const defaultRowHeight = 24.0;

  /// Read only: every change goes through [setCell] or [replaceCells], so
  /// [usedRange] stays cheap.
  Map<CellAddress, Cell> get cells => _cells;

  CellAddress? _corner;
  var _cornerStale = false;

  /// Merged cells, none overlapping another; the top left cell holds the
  /// content and the others stay empty.
  List<CellRange> get merges => _merges;
  set merges(List<CellRange> value) {
    _merges = List.unmodifiable(value);
    _mergesByColumn = null;
  }

  List<CellRange> _merges = const [];
  Map<int, List<CellRange>>? _mergesByColumn;

  /// The merge that covers [cell], found through an index by column, as
  /// moving around the grid asks this on every key.
  CellRange? mergeAt(CellAddress cell) {
    if (_merges.isEmpty) return null;
    final index = _mergesByColumn ??= _indexMerges();
    for (final merge in index[cell.column] ?? const <CellRange>[]) {
      if (merge.contains(cell)) return merge;
    }
    return null;
  }

  Map<int, List<CellRange>> _indexMerges() {
    final index = <int, List<CellRange>>{};
    for (final merge in _merges) {
      for (var c = merge.first.column; c <= merge.last.column; c++) {
        (index[c] ??= []).add(merge);
      }
    }
    return index;
  }

  /// [range] grown until no merge sits half inside it, as Excel selects.
  CellRange expandToMerges(CellRange range) {
    if (_merges.isEmpty) return range;
    var result = range;
    var grown = true;
    while (grown) {
      grown = false;
      for (final merge in _merges) {
        if (!merge.intersects(result)) continue;
        final union = result.union(merge);
        if (union != result) {
          result = union;
          grown = true;
        }
      }
    }
    return result;
  }

  Cell cellAt(CellAddress address) => _cells[address] ?? const Cell();

  void setCell(CellAddress address, Cell cell) {
    if (cell.isEmpty) {
      if (_cells.remove(address) == null) return;
      final corner = _corner;
      if (corner != null &&
          (address.column == corner.column || address.row == corner.row)) {
        _cornerStale = true;
      }
      return;
    }
    _cells[address] = cell;
    _grow(address);
  }

  /// Puts in a whole new set of cells, as inserting rows does.
  void replaceCells(Map<CellAddress, Cell> cells) {
    _cells = cells;
    _cornerStale = true;
  }

  void _grow(CellAddress address) {
    if (_cornerStale) return;
    final corner = _corner;
    if (corner == null) {
      _corner = address;
    } else if (address.column > corner.column || address.row > corner.row) {
      _corner = CellAddress(
        address.column > corner.column ? address.column : corner.column,
        address.row > corner.row ? address.row : corner.row,
      );
    }
  }

  /// Moves sizes, frozen panes and merges as rows or columns come and go;
  /// a merge left with one cell is gone.
  void moveLayout(StructureEdit edit) {
    if (_merges.isNotEmpty) {
      merges = [
        for (final merge in _merges) ?edit.moveRange(merge),
      ].where((merge) => !merge.isSingle).toList();
    }
    if (edit.axis == SheetAxis.rows) {
      rowHeights = edit.moveKeys(rowHeights);
      frozenRows = edit.moveFrozen(frozenRows);
    } else {
      columnWidths = edit.moveKeys(columnWidths);
      frozenColumns = edit.moveFrozen(frozenColumns);
    }
  }

  double columnWidth(int column) => columnWidths[column] ?? defaultColumnWidth;
  double rowHeight(int row) => rowHeights[row] ?? defaultRowHeight;

  /// From `A1` to the last used row and column, or null for an empty sheet.
  /// Kept up to date as cells change; only removing a cell on the edge makes
  /// the next call look at every cell again.
  CellRange? get usedRange {
    if (_cornerStale) {
      _cornerStale = false;
      _corner = null;
      var maxColumn = -1, maxRow = -1;
      for (final address in _cells.keys) {
        if (address.column > maxColumn) maxColumn = address.column;
        if (address.row > maxRow) maxRow = address.row;
      }
      if (maxColumn >= 0) _corner = CellAddress(maxColumn, maxRow);
    }
    final corner = _corner;
    if (corner == null) return null;
    return CellRange(const CellAddress(0, 0), corner);
  }
}

/// The sizes, frozen panes and merges of a sheet, as undo keeps them.
class SheetLayout {
  SheetLayout.of(Sheet sheet)
    : columnWidths = {...sheet.columnWidths},
      rowHeights = {...sheet.rowHeights},
      frozenRows = sheet.frozenRows,
      frozenColumns = sheet.frozenColumns,
      merges = sheet.merges;

  final Map<int, double> columnWidths;
  final Map<int, double> rowHeights;
  final int frozenRows;
  final int frozenColumns;
  final List<CellRange> merges;

  void restore(Sheet sheet) {
    sheet
      ..columnWidths = {...columnWidths}
      ..rowHeights = {...rowHeights}
      ..frozenRows = frozenRows
      ..frozenColumns = frozenColumns
      ..merges = merges;
  }
}

class Workbook {
  Workbook(this.sheets) : assert(sheets.isNotEmpty);

  Workbook.blank(String sheetName) : sheets = [Sheet(sheetName)];

  final List<Sheet> sheets;

  int indexOf(String name) {
    final wanted = name.toLowerCase();
    for (var i = 0; i < sheets.length; i++) {
      if (sheets[i].name.toLowerCase() == wanted) return i;
    }
    return -1;
  }
}
