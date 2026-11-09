import 'cell_address.dart';
import 'structure.dart';

enum ChartKind { column, bar, line, area, pie, scatter }

/// Cells a chart reads, on the sheet named [sheet], as `.xlsx` keeps them.
class ChartData {
  const ChartData(this.sheet, this.range);

  final String sheet;
  final CellRange range;

  ChartData withSheet(String name) => ChartData(name, range);

  @override
  bool operator ==(Object other) =>
      other is ChartData && other.sheet == sheet && other.range == range;

  @override
  int get hashCode => Object.hash(sheet, range);
}

class ChartSeries {
  const ChartSeries({required this.values, this.name, this.title});

  final ChartData values;

  /// The cell that holds the name of the series, as Excel links it.
  final ChartData? name;

  /// A name typed in the chart itself, used when there is no [name] cell.
  final String? title;
}

/// Where a point of the chart's frame sits: a cell and how far into it, in
/// the grid's logical pixels.
class ChartPoint {
  const ChartPoint(this.cell, {this.dx = 0, this.dy = 0});

  final CellAddress cell;
  final double dx;
  final double dy;

  @override
  bool operator ==(Object other) =>
      other is ChartPoint &&
      other.cell == cell &&
      other.dx == dx &&
      other.dy == dy;

  @override
  int get hashCode => Object.hash(cell, dx, dy);
}

/// A chart floating over the cells, from its top left corner [from] to its
/// bottom right corner [to]: it moves and resizes with the cells under it.
class SheetChart {
  const SheetChart({
    required this.kind,
    required this.series,
    required this.from,
    required this.to,
    this.title,
    this.categories,
    this.showLegend = true,
  });

  final ChartKind kind;
  final List<ChartSeries> series;
  final ChartPoint from;
  final ChartPoint to;
  final String? title;

  /// The labels along the axis (or of the slices of a pie).
  final ChartData? categories;
  final bool showLegend;

  SheetChart copyWith({
    ChartKind? kind,
    List<ChartSeries>? series,
    ChartPoint? from,
    ChartPoint? to,
    String? Function()? title,
    ChartData? Function()? categories,
    bool? showLegend,
  }) => SheetChart(
    kind: kind ?? this.kind,
    series: series ?? this.series,
    from: from ?? this.from,
    to: to ?? this.to,
    title: title == null ? this.title : title(),
    categories: categories == null ? this.categories : categories(),
    showLegend: showLegend ?? this.showLegend,
  );

  /// Every range the chart reads, to follow rows and columns as they move.
  Iterable<ChartData> get data sync* {
    if (categories case final categories?) yield categories;
    for (final s in series) {
      yield s.values;
      if (s.name case final name?) yield name;
    }
  }

  /// The chart after rows or columns of the sheet named [sheetName] (in
  /// lower case) moved: its frame moves and resizes with the cells, and its
  /// data follows them; a series whose cells are all deleted goes away.
  /// Null when the edit deletes every cell under the chart.
  SheetChart? moved(
    StructureEdit edit,
    String sheetName, {
    required bool onEditedSheet,
  }) {
    ChartData? data(ChartData? value) {
      if (value == null || value.sheet.toLowerCase() != sheetName) {
        return value;
      }
      final range = edit.moveRange(value.range);
      return range == null ? null : ChartData(value.sheet, range);
    }

    final newSeries = <ChartSeries>[];
    for (final s in series) {
      final values = data(s.values);
      if (values == null) continue;
      newSeries.add(
        ChartSeries(values: values, name: data(s.name), title: s.title),
      );
    }
    var newFrom = from, newTo = to;
    if (onEditedSheet) {
      final frame = edit.moveRange(CellRange(from.cell, to.cell));
      if (frame == null) return null;
      newFrom = ChartPoint(frame.first, dx: from.dx, dy: from.dy);
      newTo = ChartPoint(frame.last, dx: to.dx, dy: to.dy);
    }
    return SheetChart(
      kind: kind,
      series: newSeries,
      from: newFrom,
      to: newTo,
      title: title,
      categories: data(categories),
      showLegend: showLegend,
    );
  }
}
