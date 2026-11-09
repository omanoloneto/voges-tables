import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';
import '../sheet/chart.dart';
import '../sheet/workbook.dart';

/// Default size of a new chart, in the grid's logical pixels.
const newChartWidth = 480.0;
const newChartHeight = 288.0;

/// The block of filled cells around [cell], as Excel takes when a chart is
/// made from a single selected cell. Grows one row or column at a time, so
/// it never looks at more than the block and its border.
CellRange currentRegion(Sheet sheet, CellAddress cell) {
  bool filled(int column, int row) =>
      column >= 0 &&
      row >= 0 &&
      sheet.cells.containsKey(CellAddress(column, row));
  var top = cell.row, bottom = cell.row, left = cell.column;
  var right = cell.column;
  var grown = true;
  var steps = 0;
  while (grown && steps++ < 100000) {
    grown = false;
    bool anyInRow(int row) {
      for (var c = left - 1; c <= right + 1; c++) {
        if (filled(c, row)) return true;
      }
      return false;
    }

    bool anyInColumn(int column) {
      for (var r = top - 1; r <= bottom + 1; r++) {
        if (filled(column, r)) return true;
      }
      return false;
    }

    if (top > 0 && anyInRow(top - 1)) {
      top--;
      grown = true;
    }
    if (bottom < CellAddress.maxRows - 1 && anyInRow(bottom + 1)) {
      bottom++;
      grown = true;
    }
    if (left > 0 && anyInColumn(left - 1)) {
      left--;
      grown = true;
    }
    if (right < CellAddress.maxColumns - 1 && anyInColumn(right + 1)) {
      right++;
      grown = true;
    }
  }
  return CellRange(CellAddress(left, top), CellAddress(right, bottom));
}

/// A chart of [kind] for the cells in [range] of [sheet], as Excel builds
/// it: a first row of text names the series, a first column of text gives
/// the categories, and series run down the columns unless the block is
/// wider than tall. Null when there are no numbers to show.
SheetChart? buildChart({
  required Sheet sheet,
  required CellRange range,
  required ChartKind kind,
  required CellValue Function(CellAddress address) valueAt,
}) {
  final used = sheet.usedRange;
  if (used == null) return null;
  final last = CellAddress(
    range.last.column < used.last.column ? range.last.column : used.last.column,
    range.last.row < used.last.row ? range.last.row : used.last.row,
  );
  if (last.column < range.first.column || last.row < range.first.row) {
    return null;
  }
  final block = CellRange(range.first, last);
  bool isLabel(CellAddress address) => valueAt(address) is! NumberValue;
  bool isText(CellAddress address) => valueAt(address) is TextValue;

  bool labelsAlong({required bool row}) {
    final count = row ? block.columns : block.rows;
    final other = row ? block.rows : block.columns;
    if (other < 2) return false;
    var text = false;
    for (var i = 1; i < count; i++) {
      final address = row
          ? CellAddress(block.first.column + i, block.first.row)
          : CellAddress(block.first.column, block.first.row + i);
      if (!isLabel(address)) return false;
      if (isText(address)) text = true;
    }
    if (count == 1) return isText(block.first);
    return text;
  }

  final headerRow = labelsAlong(row: true);
  final labelColumn = kind == ChartKind.scatter
      ? block.columns > 1
      : labelsAlong(row: false);
  final dataFirst = CellAddress(
    block.first.column + (labelColumn ? 1 : 0),
    block.first.row + (headerRow ? 1 : 0),
  );
  if (dataFirst.column > block.last.column || dataFirst.row > block.last.row) {
    return null;
  }
  var numbers = false;
  for (var r = dataFirst.row; r <= block.last.row && !numbers; r++) {
    for (var c = dataFirst.column; c <= block.last.column; c++) {
      if (valueAt(CellAddress(c, r)) is NumberValue) {
        numbers = true;
        break;
      }
    }
  }
  if (!numbers) return null;
  final dataColumns = block.last.column - dataFirst.column + 1;
  final dataRows = block.last.row - dataFirst.row + 1;
  final byColumns = kind == ChartKind.scatter || dataRows >= dataColumns;
  final name = sheet.name;
  ChartData data(CellAddress a, CellAddress b) =>
      ChartData(name, CellRange(a, b));

  final series = <ChartSeries>[];
  ChartData? categories;
  if (byColumns) {
    if (labelColumn) {
      categories = data(
        CellAddress(block.first.column, dataFirst.row),
        CellAddress(block.first.column, block.last.row),
      );
    }
    for (var c = dataFirst.column; c <= block.last.column; c++) {
      series.add(
        ChartSeries(
          values: data(
            CellAddress(c, dataFirst.row),
            CellAddress(c, block.last.row),
          ),
          name: headerRow
              ? data(
                  CellAddress(c, block.first.row),
                  CellAddress(c, block.first.row),
                )
              : null,
        ),
      );
    }
  } else {
    if (headerRow) {
      categories = data(
        CellAddress(dataFirst.column, block.first.row),
        CellAddress(block.last.column, block.first.row),
      );
    }
    for (var r = dataFirst.row; r <= block.last.row; r++) {
      series.add(
        ChartSeries(
          values: data(
            CellAddress(dataFirst.column, r),
            CellAddress(block.last.column, r),
          ),
          name: labelColumn
              ? data(
                  CellAddress(block.first.column, r),
                  CellAddress(block.first.column, r),
                )
              : null,
        ),
      );
    }
  }
  if (kind == ChartKind.pie && series.length > 1) {
    series.removeRange(1, series.length);
  }
  final from = ChartPoint(
    CellAddress(
      (block.last.column + 2).clamp(0, CellAddress.maxColumns - 1),
      block.first.row,
    ),
  );
  return SheetChart(
    kind: kind,
    series: series,
    categories: categories,
    from: from,
    to: pointAfter(sheet, from, newChartWidth, newChartHeight),
    showLegend: series.length > 1 || kind == ChartKind.pie,
  );
}

/// The point [width] and [height] pixels right of and below [from].
ChartPoint pointAfter(
  Sheet sheet,
  ChartPoint from,
  double width,
  double height,
) {
  var column = from.cell.column;
  var dx = from.dx + width;
  while (dx >= sheet.columnWidth(column) &&
      column < CellAddress.maxColumns - 1) {
    dx -= sheet.columnWidth(column);
    column++;
  }
  var row = from.cell.row;
  var dy = from.dy + height;
  while (dy >= sheet.rowHeight(row) && row < CellAddress.maxRows - 1) {
    dy -= sheet.rowHeight(row);
    row++;
  }
  return ChartPoint(CellAddress(column, row), dx: dx, dy: dy);
}
