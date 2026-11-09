import 'cell_address.dart';
import 'cell_style.dart';
import 'cell_value.dart';

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
  final Map<CellAddress, Cell> cells = {};
  final Map<int, double> columnWidths = {};
  final Map<int, double> rowHeights = {};
  int frozenRows = 0;
  int frozenColumns = 0;

  static const defaultColumnWidth = 88.0;
  static const defaultRowHeight = 24.0;

  Cell cellAt(CellAddress address) => cells[address] ?? const Cell();

  void setCell(CellAddress address, Cell cell) {
    if (cell.isEmpty) {
      cells.remove(address);
    } else {
      cells[address] = cell;
    }
  }

  double columnWidth(int column) => columnWidths[column] ?? defaultColumnWidth;
  double rowHeight(int row) => rowHeights[row] ?? defaultRowHeight;

  /// The last used row and column, or null for an empty sheet.
  CellRange? get usedRange {
    if (cells.isEmpty) return null;
    var maxColumn = 0, maxRow = 0;
    for (final address in cells.keys) {
      if (address.column > maxColumn) maxColumn = address.column;
      if (address.row > maxRow) maxRow = address.row;
    }
    return CellRange(const CellAddress(0, 0), CellAddress(maxColumn, maxRow));
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
