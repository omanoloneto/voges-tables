import 'package:xml/xml.dart';

import '../../sheet/cell_address.dart';
import '../../sheet/chart.dart';
import '../../sheet/workbook.dart';
import 'chart_references.dart';
import 'xlsx_package.dart';
import 'xlsx_sheet_reader.dart' show emuPerPixel;
import 'xlsx_xml.dart';

/// Reads the charts of the drawing that the worksheet at [sheetPath] links
/// as [drawingId]. Charts of other kinds, and parts that are missing or
/// broken, are left out: they never fail the file.
List<SheetChart> readSheetCharts(
  XlsxPackage package, {
  required String sheetPath,
  required String drawingId,
  required Sheet sheet,
}) {
  try {
    final drawingPath = _target(package, sheetPath, drawingId, 'drawing');
    final drawing = drawingPath == null
        ? null
        : package.xml(drawingPath)?.rootElement;
    if (drawingPath == null || drawing == null) return const [];
    final charts = <SheetChart>[];
    for (final anchor in _anchors(drawing)) {
      try {
        final chart = _readAnchor(package, drawingPath, anchor, sheet);
        if (chart != null) charts.add(chart);
      } on Object {
        continue;
      }
    }
    return charts;
  } on Object {
    return const [];
  }
}

String? _target(XlsxPackage package, String source, String id, String type) {
  for (final relationship in package.relationships(source)) {
    if (relationship.id == id && relationship.hasType(type)) {
      return XlsxPackage.resolve(source, relationship.target);
    }
  }
  return null;
}

bool _isAnchor(XmlElement element) =>
    element.name.local == 'twoCellAnchor' ||
    element.name.local == 'oneCellAnchor';

/// The anchors of a drawing; of `mc:AlternateContent`, the first branch
/// that holds any.
Iterable<XmlElement> _anchors(XmlElement drawing) sync* {
  for (final element in drawing.childElements) {
    if (_isAnchor(element)) {
      yield element;
    } else if (element.name.local == 'AlternateContent') {
      for (final branch in element.childElements) {
        final anchors = branch.childElements.where(_isAnchor).toList();
        if (anchors.isEmpty) continue;
        yield* anchors;
        break;
      }
    }
  }
}

SheetChart? _readAnchor(
  XlsxPackage package,
  String drawingPath,
  XmlElement anchor,
  Sheet sheet,
) {
  final from = _marker(child(anchor, 'from'));
  if (from == null) return null;
  final ChartPoint? to;
  if (anchor.name.local == 'twoCellAnchor') {
    to = _marker(child(anchor, 'to'));
  } else {
    final extent = child(anchor, 'ext');
    double? pixels(String name) {
      final emu = int.tryParse(extent?.getAttribute(name) ?? '');
      return emu == null || emu < 0 ? null : emu / emuPerPixel;
    }

    final width = pixels('cx'), height = pixels('cy');
    to = width == null || height == null
        ? null
        : _pointAfter(from, width, height, sheet);
  }
  if (to == null) return null;
  final id = _chartId(anchor);
  if (id == null) return null;
  final chartPath = _target(package, drawingPath, id, 'chart');
  if (chartPath == null) return null;
  final space = package.xml(chartPath)?.rootElement;
  if (space == null) return null;
  return _readChart(space, from, to, sheet.name);
}

ChartPoint? _marker(XmlElement? marker) {
  if (marker == null) return null;
  int? number(String name) {
    final element = child(marker, name);
    return element == null ? null : int.tryParse(element.innerText.trim());
  }

  final column = number('col'), row = number('row');
  if (column == null || row == null) return null;
  final cell = CellAddress(column, row);
  if (!cell.isValid) return null;
  double offset(String name) {
    final emu = number(name) ?? 0;
    return emu > 0 ? emu / emuPerPixel : 0;
  }

  return ChartPoint(cell, dx: offset('colOff'), dy: offset('rowOff'));
}

/// Where a frame of [width] by [height] pixels that starts at [from] ends,
/// measured with the sheet's column widths and row heights.
ChartPoint _pointAfter(
  ChartPoint from,
  double width,
  double height,
  Sheet sheet,
) {
  var column = from.cell.column, x = from.dx + width;
  while (column < CellAddress.maxColumns - 1 &&
      x >= sheet.columnWidth(column)) {
    x -= sheet.columnWidth(column);
    column++;
  }
  var row = from.cell.row, y = from.dy + height;
  while (row < CellAddress.maxRows - 1 && y >= sheet.rowHeight(row)) {
    y -= sheet.rowHeight(row);
    row++;
  }
  return ChartPoint(CellAddress(column, row), dx: x, dy: y);
}

/// The `r:id` of the `c:chart` in the anchor's graphic frame, looking into
/// `mc:AlternateContent` too.
String? _chartId(XmlElement anchor) {
  for (final element in anchor.descendantElements) {
    if (element.name.local == 'chart' &&
        element.parentElement?.name.local == 'graphicData') {
      return relationshipId(element);
    }
  }
  return null;
}

SheetChart? _readChart(
  XmlElement space,
  ChartPoint from,
  ChartPoint to,
  String sheetName,
) {
  final chart = child(space, 'chart');
  final plot = chart == null ? null : child(chart, 'plotArea');
  if (chart == null || plot == null) return null;
  ChartKind? kind;
  ChartData? categories;
  final series = <ChartSeries>[];
  for (final group in plot.childElements) {
    final groupKind = _kindOf(group);
    if (groupKind == null) continue;
    final scatter = groupKind == ChartKind.scatter;
    for (final element in children(group, 'ser')) {
      final values = _reference(
        child(element, scatter ? 'yVal' : 'val'),
        sheetName,
      );
      if (values == null) continue;
      kind ??= groupKind;
      categories ??= _reference(
        child(element, scatter ? 'xVal' : 'cat'),
        sheetName,
      );
      series.add(_series(element, values, sheetName));
    }
  }
  if (kind == null) return null;
  return SheetChart(
    kind: kind,
    series: series,
    from: from,
    to: to,
    title: _title(chart),
    categories: categories,
    showLegend: child(chart, 'legend') != null,
  );
}

ChartKind? _kindOf(XmlElement group) => switch (group.name.local) {
  'barChart' || 'bar3DChart' =>
    _value(child(group, 'barDir')) == 'bar' ? ChartKind.bar : ChartKind.column,
  'lineChart' || 'line3DChart' => ChartKind.line,
  'areaChart' => ChartKind.area,
  'pieChart' || 'pie3DChart' || 'doughnutChart' => ChartKind.pie,
  'scatterChart' => ChartKind.scatter,
  _ => null,
};

String? _value(XmlElement? element) => element?.getAttribute('val');

ChartSeries _series(XmlElement element, ChartData values, String sheetName) {
  final text = child(element, 'tx');
  final reference = text == null ? null : child(text, 'strRef');
  if (reference != null) {
    final name = _formula(reference, sheetName);
    return ChartSeries(
      values: values,
      name: name,
      title: name == null ? _cached(reference) : null,
    );
  }
  final literal = text == null ? null : child(text, 'v')?.innerText;
  return ChartSeries(
    values: values,
    title: literal == null || literal.isEmpty ? null : unescapeText(literal),
  );
}

/// The cells behind a series' data (`c:cat`, `c:val`...), whatever the
/// kind of reference.
ChartData? _reference(XmlElement? data, String sheetName) {
  if (data == null) return null;
  for (final reference in data.childElements) {
    switch (reference.name.local) {
      case 'numRef' || 'strRef' || 'multiLvlStrRef':
        return _formula(reference, sheetName);
    }
  }
  return null;
}

ChartData? _formula(XmlElement reference, String sheetName) {
  final formula = child(reference, 'f')?.innerText;
  return formula == null
      ? null
      : parseChartReference(formula, defaultSheet: sheetName);
}

String? _cached(XmlElement reference) {
  final cache = child(reference, 'strCache');
  final point = cache == null ? null : child(cache, 'pt');
  final value = point == null ? null : child(point, 'v')?.innerText;
  return value == null || value.isEmpty ? null : unescapeText(value);
}

/// The title's text, its runs joined and one line per paragraph.
String? _title(XmlElement chart) {
  final title = child(chart, 'title');
  final text = title == null ? null : child(title, 'tx');
  if (text == null) return null;
  final rich = child(text, 'rich');
  if (rich == null) {
    final reference = child(text, 'strRef');
    return reference == null ? null : _cached(reference);
  }
  final lines = [
    for (final paragraph in children(rich, 'p'))
      [
        for (final run in paragraph.childElements)
          switch (run.name.local) {
            'r' || 'fld' => child(run, 't')?.innerText ?? '',
            'br' => '\n',
            _ => '',
          },
      ].join(),
  ];
  final joined = lines.join('\n');
  return joined.trim().isEmpty ? null : joined;
}
