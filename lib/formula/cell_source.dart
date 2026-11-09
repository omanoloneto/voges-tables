import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';

/// Read access to the workbook's current values, as the evaluator needs it.
abstract interface class CellSource {
  /// -1 when no sheet has that name.
  int sheetIndex(String name);
  CellValue valueAt(int sheet, CellAddress address);
  Iterable<CellAddress> storedAddresses(int sheet);
  int storedCount(int sheet);

  /// The last used column and row (not necessarily one cell); null when the
  /// sheet holds nothing.
  CellAddress? usedCorner(int sheet);
}

/// A rectangle of cells read through a [CellSource]. Iteration stops at the
/// sheet's used area, so whole columns cost only what the sheet holds.
class RangeView {
  RangeView(this.source, this.sheet, this.range);

  final CellSource source;
  final int sheet;
  final CellRange range;

  int get rows => range.rows;
  int get columns => range.columns;
  int get area => rows * columns;

  /// Rows from the top that may hold something; the rest are empty.
  int get usedRows {
    final corner = source.usedCorner(sheet);
    if (corner == null) return 0;
    return (corner.row - range.first.row + 1).clamp(0, rows);
  }

  int get usedColumns {
    final corner = source.usedCorner(sheet);
    if (corner == null) return 0;
    return (corner.column - range.first.column + 1).clamp(0, columns);
  }

  CellValue at(int row, int column) => source.valueAt(
    sheet,
    CellAddress(range.first.column + column, range.first.row + row),
  );

  /// The non-empty values, row by row.
  Iterable<CellValue> get values sync* {
    final rows = usedRows, columns = usedColumns;
    if (rows * columns <= source.storedCount(sheet)) {
      for (var row = 0; row < rows; row++) {
        for (var column = 0; column < columns; column++) {
          final value = at(row, column);
          if (value is! EmptyValue) yield value;
        }
      }
      return;
    }
    final inside = source.storedAddresses(sheet).where(range.contains).toList()
      ..sort();
    for (final address in inside) {
      final value = source.valueAt(sheet, address);
      if (value is! EmptyValue) yield value;
    }
  }

  /// The same top-left corner with another size, as SUMIF's sum range.
  RangeView resized(int rows, int columns) {
    final last = CellAddress(
      (range.first.column + columns - 1).clamp(0, CellAddress.maxColumns - 1),
      (range.first.row + rows - 1).clamp(0, CellAddress.maxRows - 1),
    );
    return RangeView(source, sheet, CellRange(range.first, last));
  }
}
