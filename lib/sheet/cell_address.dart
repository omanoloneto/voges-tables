/// A cell position, zero-based: `A1` is column 0, row 0.
class CellAddress implements Comparable<CellAddress> {
  const CellAddress(this.column, this.row);

  final int column;
  final int row;

  /// Columns go up to `XFD` and rows up to 1 048 576, as in Excel.
  static const maxColumns = 16384;
  static const maxRows = 1048576;

  static final _a1 = RegExp(r'^\$?([A-Za-z]{1,3})\$?([0-9]{1,7})$');

  /// Parses `A1`, `$B$2` or `xfd1048576`; null when it is not a valid cell.
  static CellAddress? tryParse(String text) {
    final match = _a1.firstMatch(text.trim());
    if (match == null) return null;
    final column = columnIndex(match.group(1)!);
    final row = int.parse(match.group(2)!) - 1;
    if (column < 0 || column >= maxColumns || row < 0 || row >= maxRows) {
      return null;
    }
    return CellAddress(column, row);
  }

  /// `A` is 0, `Z` is 25, `AA` is 26; -1 for anything else.
  static int columnIndex(String letters) {
    var index = 0;
    for (final unit in letters.toUpperCase().codeUnits) {
      if (unit < 65 || unit > 90) return -1;
      index = index * 26 + (unit - 64);
    }
    return index - 1;
  }

  static String columnName(int column) {
    var n = column + 1;
    final buffer = StringBuffer();
    while (n > 0) {
      final rest = (n - 1) % 26;
      buffer.write(String.fromCharCode(65 + rest));
      n = (n - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  String get a1 => '${columnName(column)}${row + 1}';

  CellAddress offset(int columns, int rows) =>
      CellAddress(column + columns, row + rows);

  bool get isValid =>
      column >= 0 && column < maxColumns && row >= 0 && row < maxRows;

  @override
  int compareTo(CellAddress other) =>
      row != other.row ? row - other.row : column - other.column;

  @override
  bool operator ==(Object other) =>
      other is CellAddress && other.column == column && other.row == row;

  @override
  int get hashCode => Object.hash(column, row);

  @override
  String toString() => a1;
}

/// A rectangle of cells, both corners included.
class CellRange {
  CellRange(CellAddress a, CellAddress b)
    : first = CellAddress(
        a.column < b.column ? a.column : b.column,
        a.row < b.row ? a.row : b.row,
      ),
      last = CellAddress(
        a.column > b.column ? a.column : b.column,
        a.row > b.row ? a.row : b.row,
      );

  CellRange.single(CellAddress cell) : first = cell, last = cell;

  final CellAddress first;
  final CellAddress last;

  int get columns => last.column - first.column + 1;
  int get rows => last.row - first.row + 1;
  bool get isSingle => first == last;

  bool contains(CellAddress cell) =>
      cell.column >= first.column &&
      cell.column <= last.column &&
      cell.row >= first.row &&
      cell.row <= last.row;

  Iterable<CellAddress> get cells sync* {
    for (var row = first.row; row <= last.row; row++) {
      for (var column = first.column; column <= last.column; column++) {
        yield CellAddress(column, row);
      }
    }
  }

  String get a1 => isSingle ? first.a1 : '${first.a1}:${last.a1}';

  @override
  bool operator ==(Object other) =>
      other is CellRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => a1;
}
