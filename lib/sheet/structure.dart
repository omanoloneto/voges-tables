import 'cell_address.dart';

enum SheetAxis { rows, columns }

/// Rows or columns inserted ([count] > 0) or deleted ([count] < 0) at [at]
/// on the sheet [sheet].
class StructureEdit {
  const StructureEdit({
    required this.sheet,
    required this.axis,
    required this.at,
    required this.count,
  }) : assert(count != 0);

  final int sheet;
  final SheetAxis axis;
  final int at;
  final int count;

  bool get isInsert => count > 0;

  /// The first index after the deleted band.
  int get end => at - count;

  int get limit =>
      axis == SheetAxis.rows ? CellAddress.maxRows : CellAddress.maxColumns;

  StructureEdit get inverse =>
      StructureEdit(sheet: sheet, axis: axis, at: at, count: -count);

  /// Where [index] goes; null when it is deleted or pushed off the sheet.
  int? moveIndex(int index) {
    if (index < at) return index;
    if (isInsert) {
      final moved = index + count;
      return moved < limit ? moved : null;
    }
    return index < end ? null : index + count;
  }

  /// Where the span [first]..[last] goes: an insertion inside it makes it
  /// longer, a deletion shorter, and a span that loses every index is null.
  /// A span reaching the end of the sheet keeps reaching it.
  (int, int)? moveSpan(int first, int last) {
    if (last < at) return (first, last);
    if (isInsert) {
      final newFirst = first >= at ? first + count : first;
      if (newFirst >= limit) return null;
      final newLast = last + count;
      return (newFirst, newLast < limit ? newLast : limit - 1);
    }
    final newFirst = first < at ? first : (first >= end ? first + count : at);
    final newLast = last >= end ? last + count : at - 1;
    return newLast < newFirst ? null : (newFirst, newLast);
  }

  /// True when the span keeps its length and its contents, only moving.
  bool translates(int first, int last) {
    if (last < at) return true;
    if (isInsert) return first >= at && last + count < limit;
    return first >= end;
  }

  int indexOf(CellAddress cell) =>
      axis == SheetAxis.rows ? cell.row : cell.column;

  CellAddress? moveCell(CellAddress cell) {
    final moved = moveIndex(indexOf(cell));
    if (moved == null) return null;
    return axis == SheetAxis.rows
        ? CellAddress(cell.column, moved)
        : CellAddress(moved, cell.row);
  }

  CellRange? moveRange(CellRange range) {
    final rows = axis == SheetAxis.rows;
    final span = rows
        ? moveSpan(range.first.row, range.last.row)
        : moveSpan(range.first.column, range.last.column);
    if (span == null) return null;
    final (first, last) = span;
    return rows
        ? CellRange(
            CellAddress(range.first.column, first),
            CellAddress(range.last.column, last),
          )
        : CellRange(
            CellAddress(first, range.first.row),
            CellAddress(last, range.last.row),
          );
  }

  bool translatesRange(CellRange range) => axis == SheetAxis.rows
      ? translates(range.first.row, range.last.row)
      : translates(range.first.column, range.last.column);

  /// Moves the keys of a map of sizes, dropping the deleted ones.
  Map<int, V> moveKeys<V>(Map<int, V> values) => {
    for (final entry in values.entries) ?moveIndex(entry.key): entry.value,
  };

  /// How many frozen rows or columns are left.
  int moveFrozen(int frozen) {
    if (frozen == 0 || at >= frozen) return frozen;
    if (isInsert) return (frozen + count).clamp(0, limit);
    return at + (frozen > end ? frozen - end : 0);
  }
}
