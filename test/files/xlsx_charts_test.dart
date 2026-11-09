import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/files/spreadsheet_format.dart';
import 'package:voges_tables/files/xlsx/chart_references.dart';
import 'package:voges_tables/files/xlsx/xlsx_reader.dart';
import 'package:voges_tables/files/xlsx/xlsx_writer.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/chart.dart';
import 'package:voges_tables/sheet/workbook.dart';
import 'package:xml/xml.dart';

import 'xlsx_fixtures.dart';

CellAddress at(String a1) => CellAddress.tryParse(a1)!;

CellRange range(String a1) {
  final corners = a1.split(':');
  return CellRange(at(corners.first), at(corners.last));
}

ChartData sales(String a1) => ChartData('Vendas 2026', range(a1));

Map<String, String> unzip(Uint8List bytes) => {
  for (final file in ZipDecoder().decodeBytes(bytes).files)
    if (file.isFile) file.name: utf8.decode(file.content),
};

/// A chart as plain values, to compare with `equals`.
Map<String, Object?> describe(SheetChart chart) => {
  'kind': chart.kind,
  'from': chart.from,
  'to': chart.to,
  'title': chart.title,
  'categories': chart.categories,
  'legend': chart.showLegend,
  'series': [
    for (final s in chart.series) [s.values, s.name, s.title],
  ],
};

List<Map<String, Object?>> describeAll(List<SheetChart> charts) => [
  for (final chart in charts) describe(chart),
];

Workbook chartWorkbook() {
  final data = Sheet('Vendas 2026');
  void put(String a1, CellValue value) =>
      data.setCell(at(a1), Cell(constant: value));
  put('A1', const TextValue('Mês'));
  put('B1', const TextValue('Loja A'));
  put('C1', const TextValue('Loja B'));
  put('A2', const TextValue('Jan'));
  put('A3', const TextValue('Fev & <Mar>'));
  put('A4', const NumberValue(2026));
  put('B2', const NumberValue(10));
  put('B3', const NumberValue(20.5));
  put('B4', const NumberValue(30));
  put('C2', const NumberValue(5));
  put('C3', const TextValue('n/a'));
  data
    ..setCell(at('C4'), const Cell(input: '=C2*4'))
    ..charts = [
      SheetChart(
        kind: ChartKind.line,
        series: [ChartSeries(values: sales('B2:B4'))],
        from: ChartPoint(at('E2'), dx: 4, dy: 2),
        to: ChartPoint(at('J12')),
        title: 'Linha\nsegunda linha',
        categories: sales('A2:A4'),
      ),
    ];
  final charts = Sheet('Gráficos')
    ..charts = [
      SheetChart(
        kind: ChartKind.column,
        series: [
          ChartSeries(values: sales('B2:B4'), name: sales('B1')),
          ChartSeries(values: sales('C2:C4'), title: 'Meta'),
        ],
        from: ChartPoint(at('A1')),
        to: ChartPoint(at('H15'), dx: 30, dy: 12),
        title: 'Vendas por mês',
        categories: sales('A2:A4'),
      ),
      SheetChart(
        kind: ChartKind.bar,
        series: [ChartSeries(values: sales('B2:C2'))],
        from: ChartPoint(at('J1'), dx: 1, dy: 1),
        to: ChartPoint(at('P15')),
        categories: sales('B1:C1'),
        showLegend: false,
      ),
      SheetChart(
        kind: ChartKind.area,
        series: [
          ChartSeries(values: sales('B2:B4'), name: sales('B1')),
          ChartSeries(values: sales('C2:C4'), name: sales('C1')),
        ],
        from: ChartPoint(at('A20')),
        to: ChartPoint(at('H35')),
      ),
      SheetChart(
        kind: ChartKind.pie,
        series: [ChartSeries(values: sales('B2:B4'), title: 'Fatias')],
        from: ChartPoint(at('J20')),
        to: ChartPoint(at('P35')),
        title: 'Pizza',
        categories: sales('A2:A4'),
      ),
      SheetChart(
        kind: ChartKind.scatter,
        series: [ChartSeries(values: sales('C2:C4'), name: sales('C1'))],
        from: ChartPoint(at('A40')),
        to: ChartPoint(at('H55'), dx: 7, dy: 3),
        title: 'Dispersão',
        categories: sales('B2:B4'),
      ),
    ];
  return Workbook([data, charts, Sheet('Vazia')]);
}

CellValue chartValues(Workbook workbook, int sheet, CellAddress address) {
  final cell = workbook.sheets[sheet].cellAt(address);
  if (cell.isFormula) return const NumberValue(20);
  return cell.constant;
}

String chartDisplay(Workbook workbook, int sheet, CellAddress address) =>
    switch (chartValues(workbook, sheet, address)) {
      TextValue(:final value) => value,
      NumberValue(:final value) => 'n${value.toStringAsFixed(1)}',
      _ => '',
    };

Uint8List writeCharts(Workbook workbook) => writeXlsx(
  workbook,
  valueOf: (sheet, address) => chartValues(workbook, sheet, address),
  displayOf: (sheet, address) => chartDisplay(workbook, sheet, address),
);

/// The order of the children of each element, from the OOXML schemas
/// (CT_ChartSpace, CT_Chart, CT_BarChart, CT_Worksheet...).
const _schemaOrder = <String, List<String>>{
  'chartSpace': [
    'date1904', 'lang', 'roundedCorners', 'AlternateContent', 'clrMapOvr', //
    'pivotSource', 'protection', 'chart', 'spPr', 'txPr', 'externalData',
    'printSettings', 'userShapes', 'extLst',
  ],
  'chart': [
    'title', 'autoTitleDeleted', 'pivotFmts', 'view3D', 'floor', //
    'sideWall', 'backWall', 'plotArea', 'legend', 'plotVisOnly',
    'dispBlanksAs', 'showDLblsOverMax', 'extLst',
  ],
  'title': ['tx', 'layout', 'overlay', 'spPr', 'txPr', 'extLst'],
  'title.tx': ['strRef', 'rich'],
  'rich': ['bodyPr', 'lstStyle', 'p'],
  'p': ['pPr', 'r', 'br', 'fld', 'endParaRPr'],
  'r': ['rPr', 't'],
  'plotArea': [
    'layout', 'areaChart', 'barChart', 'lineChart', 'pieChart', //
    'scatterChart', 'catAx', 'valAx', 'dTable', 'spPr', 'extLst',
  ],
  'barChart': [
    'barDir', 'grouping', 'varyColors', 'ser', 'dLbls', 'gapWidth', //
    'overlap', 'serLines', 'axId', 'extLst',
  ],
  'lineChart': [
    'grouping', 'varyColors', 'ser', 'dLbls', 'dropLines', 'hiLowLines', //
    'upDownBars', 'marker', 'smooth', 'axId', 'extLst',
  ],
  'areaChart': [
    'grouping',
    'varyColors',
    'ser',
    'dLbls',
    'dropLines',
    'axId',
    'extLst',
  ],
  'pieChart': ['varyColors', 'ser', 'dLbls', 'firstSliceAng', 'extLst'],
  'scatterChart': [
    'scatterStyle',
    'varyColors',
    'ser',
    'dLbls',
    'axId',
    'extLst',
  ],
  'barChart.ser': [
    'idx', 'order', 'tx', 'spPr', 'invertIfNegative', 'pictureOptions', //
    'dPt', 'dLbls', 'trendline', 'errBars', 'cat', 'val', 'shape', 'extLst',
  ],
  'lineChart.ser': [
    'idx', 'order', 'tx', 'spPr', 'marker', 'dPt', 'dLbls', 'trendline', //
    'errBars', 'cat', 'val', 'smooth', 'extLst',
  ],
  'areaChart.ser': [
    'idx', 'order', 'tx', 'spPr', 'pictureOptions', 'dPt', 'dLbls', //
    'trendline', 'errBars', 'cat', 'val', 'extLst',
  ],
  'pieChart.ser': [
    'idx', 'order', 'tx', 'spPr', 'explosion', 'dPt', 'dLbls', 'cat', //
    'val', 'extLst',
  ],
  'scatterChart.ser': [
    'idx', 'order', 'tx', 'spPr', 'marker', 'dPt', 'dLbls', 'trendline', //
    'errBars', 'xVal', 'yVal', 'smooth', 'extLst',
  ],
  'ser.tx': ['strRef', 'v'],
  'cat': ['multiLvlStrRef', 'numRef', 'numLit', 'strRef', 'strLit'],
  'val': ['numRef', 'numLit'],
  'xVal': ['multiLvlStrRef', 'numRef', 'numLit', 'strRef', 'strLit'],
  'yVal': ['numRef', 'numLit'],
  'strRef': ['f', 'strCache', 'extLst'],
  'numRef': ['f', 'numCache', 'extLst'],
  'strCache': ['ptCount', 'pt', 'extLst'],
  'numCache': ['formatCode', 'ptCount', 'pt', 'extLst'],
  'pt': ['v'],
  'catAx': [
    'axId', 'scaling', 'delete', 'axPos', 'majorGridlines', //
    'minorGridlines', 'title', 'numFmt', 'majorTickMark', 'minorTickMark',
    'tickLblPos', 'spPr', 'txPr', 'crossAx', 'crosses', 'crossesAt', 'auto',
    'lblAlgn', 'lblOffset', 'tickLblSkip', 'tickMarkSkip', 'noMultiLvlLbl',
    'extLst',
  ],
  'valAx': [
    'axId', 'scaling', 'delete', 'axPos', 'majorGridlines', //
    'minorGridlines', 'title', 'numFmt', 'majorTickMark', 'minorTickMark',
    'tickLblPos', 'spPr', 'txPr', 'crossAx', 'crosses', 'crossesAt',
    'crossBetween', 'majorUnit', 'minorUnit', 'dispUnits', 'extLst',
  ],
  'scaling': ['logBase', 'orientation', 'max', 'min', 'extLst'],
  'legend': [
    'legendPos', 'legendEntry', 'layout', 'overlay', 'spPr', 'txPr', //
    'extLst',
  ],
  'worksheet': [
    'sheetPr', 'dimension', 'sheetViews', 'sheetFormatPr', 'cols', //
    'sheetData', 'sheetCalcPr', 'sheetProtection', 'protectedRanges',
    'scenarios', 'autoFilter', 'sortState', 'dataConsolidate',
    'customSheetViews', 'mergeCells', 'phoneticPr', 'conditionalFormatting',
    'dataValidations', 'hyperlinks', 'printOptions', 'pageMargins',
    'pageSetup', 'headerFooter', 'rowBreaks', 'colBreaks',
    'customProperties', 'cellWatches', 'ignoredErrors', 'smartTags',
    'drawing', 'legacyDrawing', 'tableParts', 'extLst',
  ],
  'mergeCells': ['mergeCell'],
  'wsDr': ['twoCellAnchor', 'oneCellAnchor', 'absoluteAnchor'],
  'twoCellAnchor': ['from', 'to', 'graphicFrame', 'clientData'],
  'from': ['col', 'colOff', 'row', 'rowOff'],
  'to': ['col', 'colOff', 'row', 'rowOff'],
  'graphicFrame': ['nvGraphicFramePr', 'xfrm', 'graphic'],
  'nvGraphicFramePr': ['cNvPr', 'cNvGraphicFramePr'],
  'xfrm': ['off', 'ext'],
  'graphic': ['graphicData'],
  'graphicData': ['chart'],
};

const _required = <String, List<String>>{
  'chartSpace': ['chart'],
  'plotArea': ['layout'],
  'barChart': ['barDir', 'axId'],
  'lineChart': ['grouping', 'axId'],
  'areaChart': ['axId'],
  'scatterChart': ['scatterStyle', 'axId'],
  'ser': ['idx', 'order'],
  'catAx': ['axId', 'scaling', 'axPos', 'crossAx'],
  'valAx': ['axId', 'scaling', 'axPos', 'crossAx'],
  'strRef': ['f'],
  'numRef': ['f'],
  'twoCellAnchor': ['from', 'to', 'graphicFrame', 'clientData'],
  'from': ['col', 'colOff', 'row', 'rowOff'],
  'to': ['col', 'colOff', 'row', 'rowOff'],
  'graphicFrame': ['nvGraphicFramePr', 'xfrm', 'graphic'],
};

/// Every place where [root] breaks the schema's element order, misses a
/// required element or has one the schema does not allow there.
List<String> schemaProblems(XmlElement root) {
  final problems = <String>[];
  void visit(XmlElement element, String path) {
    final name = element.name.local;
    final parent = element.parentElement?.name.local;
    final key = switch (name) {
      'ser' => '$parent.ser',
      'tx' => parent == 'ser' ? 'ser.tx' : '$parent.tx',
      _ => name,
    };
    final order = _schemaOrder[key];
    final names = [for (final c in element.childElements) c.name.local];
    if (order != null) {
      var last = -1;
      for (final child in names) {
        final index = order.indexOf(child);
        if (index < 0) {
          problems.add('$path: unexpected $child');
        } else if (index < last) {
          problems.add('$path: $child is out of order in $names');
        } else {
          last = index;
        }
      }
    }
    for (final needed in _required[name] ?? const <String>[]) {
      if (!names.contains(needed)) problems.add('$path: no $needed');
    }
    for (final child in element.childElements) {
      visit(child, '$path/${child.name.local}');
    }
  }

  visit(root, root.name.local);
  return problems;
}

void main() {
  group('references', () {
    test('quotes sheet names only when needed', () {
      expect(chartReference('Sales', range('B2:B5')), r'Sales!$B$2:$B$5');
      expect(chartReference('Q1_2026.v2', range('A1')), r'Q1_2026.v2!$A$1');
      expect(
        chartReference('Nome com espaço', range('A1:A3')),
        r"'Nome com espaço'!$A$1:$A$3",
      );
      expect(chartReference("It's", range('A1')), r"'It''s'!$A$1");
      for (final name in ['A1', 'xfd99', 'R1C1', 'R', 'C', 'RC2', 'TRUE']) {
        expect(quoteSheetName(name), "'$name'", reason: name);
      }
      expect(quoteSheetName('2026'), "'2026'");
      expect(quoteSheetName('Gráfico'), "'Gráfico'");
    });

    test('reads one block of cells on one sheet', () {
      ChartData? parse(String f) => parseChartReference(f, defaultSheet: 'P');
      expect(
        parse(r"='My sheet'!$B$2:$B$5"),
        ChartData('My sheet', range('B2:B5')),
      );
      expect(parse(r"'It''s'!$A$1"), ChartData("It's", range('A1')));
      expect(parse('Sheet1!a1:b2'), ChartData('Sheet1', range('A1:B2')));
      expect(parse(r'$C$3:$A$1'), ChartData('P', range('A1:C3')));
      for (final other in [
        r'(Sheet1!$A$1,Sheet1!$A$3)',
        r'Sheet1!$A:$A',
        r'[1]Sheet1!$A$1',
        r"'[Book.xlsx]Sheet1'!$A$1",
        r"'Unclosed!$A$1",
        r'Sales',
        r'Sheet1!$A$1:$B$2:$C$3',
        r'Sheet 1!$A$1',
        '',
      ]) {
        expect(parse(other), isNull, reason: other);
      }
    });
  });

  group('Excel charts', () {
    late Workbook workbook;
    late Sheet sheet;

    setUpAll(() {
      workbook = readXlsx(excelChartWorkbook());
      sheet = workbook.sheets.single;
    });

    test('loads the cells and merges next to the charts', () {
      expect(sheet.cellAt(at('A1')).constant, const TextValue('Mês'));
      expect(sheet.cellAt(at('C4')).input, '=C2+10');
      expect(sheet.merges, [range('A6:C6')]);
    });

    test('reads the column chart with its title, series and frame', () {
      expect(sheet.charts, hasLength(2));
      expect(describe(sheet.charts.first), {
        'kind': ChartKind.column,
        'from': ChartPoint(at('E2'), dx: 32, dy: 1),
        'to': ChartPoint(at('L17'), dy: 9),
        'title': 'Vendas por mês\n2026',
        'categories': sales('A2:A4'),
        'legend': true,
        'series': [
          [sales('B2:B4'), sales('B1'), null],
          [sales('C2:C4'), null, 'Meta'],
        ],
      });
    });

    test('turns a one-cell anchor into a frame over the cells', () {
      // B is 100 px, C 150 px, D 88 px; row 21 is 40 px, the others 24 px.
      expect(describe(sheet.charts.last), {
        'kind': ChartKind.pie,
        'from': ChartPoint(at('B21')),
        'to': ChartPoint(at('D24'), dx: 50, dy: 12),
        'title': null,
        'categories': sales('A2:A4'),
        'legend': false,
        'series': [
          [sales('C2:C4'), null, 'Loja A e Meta'],
        ],
      });
    });

    test('survives writing and reading again', () {
      final again = readXlsx(
        writeXlsx(
          workbook,
          valueOf: (sheet, address) =>
              workbook.sheets[sheet].cellAt(address).constant,
        ),
      );
      expect(
        describeAll(again.sheets.single.charts),
        describeAll(sheet.charts),
      );
      expect(again.sheets.single.merges, sheet.merges);
    });

    test('a broken drawing loses only the charts', () {
      final broken = readXlsx(
        excelChartWorkbook(drawing: '<xdr:wsDr><xdr:twoCellAnchor <x'),
      ).sheets.single;
      expect(broken.charts, isEmpty);
      expect(broken.cellAt(at('B4')).constant, const NumberValue(30));
      expect(broken.merges, [range('A6:C6')]);
    });

    test('a drawing that is missing or not linked loses nothing else', () {
      const sheetXml =
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheetData><row r="1"><c r="A1"><v>3</v></c></row></sheetData>'
          '<drawing r:id="rId1"/></worksheet>';
      final unlinked = readXlsx(workbookWithSheet(sheetXml)).sheets.single;
      expect(unlinked.charts, isEmpty);
      expect(unlinked.cellAt(at('A1')).constant, const NumberValue(3));
      final brokenLinks = readXlsx(
        workbookWithSheet(
          sheetXml,
          parts: {'xl/worksheets/_rels/sheet1.xml.rels': '<Relationships <'},
        ),
      ).sheets.single;
      expect(brokenLinks.charts, isEmpty);
      expect(brokenLinks.cellAt(at('A1')).constant, const NumberValue(3));
    });
  });

  group('round trip', () {
    late Workbook original;
    late Workbook read;

    setUpAll(() {
      original = chartWorkbook();
      read = readXlsx(writeCharts(original));
    });

    test('keeps every kind of chart', () {
      for (var i = 0; i < original.sheets.length; i++) {
        expect(
          describeAll(read.sheets[i].charts),
          describeAll(original.sheets[i].charts),
          reason: original.sheets[i].name,
        );
      }
      expect(
        read.sheets[1].charts.map((c) => c.kind),
        ChartKind.values.where((kind) => kind != ChartKind.line),
      );
    });

    test('references use the names the workbook saves', () {
      final workbook = Workbook([
        Sheet('a:b')..setCell(at('A1'), const Cell(constant: NumberValue(1))),
        Sheet('Plot')
          ..charts = [
            SheetChart(
              kind: ChartKind.column,
              series: [
                ChartSeries(values: ChartData('A:B', range('A1:A2'))),
                ChartSeries(values: ChartData('Gone', range('A1:A2'))),
              ],
              from: ChartPoint(at('A1')),
              to: ChartPoint(at('C5')),
              categories: ChartData('Gone', range('B1:B2')),
            ),
            SheetChart(
              kind: ChartKind.pie,
              series: [ChartSeries(values: ChartData('Gone', range('A1')))],
              from: ChartPoint(at('A1')),
              to: ChartPoint(at('C5')),
            ),
          ],
      ]);
      final parts = unzip(
        writeXlsx(workbook, valueOf: (_, _) => const NumberValue(1)),
      );
      expect(parts['xl/charts/chart1.xml'], contains(r'<c:f>a_b!$A$1:$A$2'));
      expect(parts.containsKey('xl/charts/chart2.xml'), isFalse);
      final chart = readXlsx(
        writeXlsx(workbook, valueOf: (_, _) => const NumberValue(1)),
      ).sheets[1].charts.single;
      expect(chart.series.single.values, ChartData('a_b', range('A1:A2')));
      expect(chart.categories, isNull);
    });
  });

  group('package', () {
    late Map<String, String> parts;

    setUpAll(() => parts = unzip(writeCharts(chartWorkbook())));

    test('declares the drawings and charts and links them', () {
      final types = XmlDocument.parse(parts['[Content_Types].xml']!);
      final overrides = {
        for (final o in types.findAllElements('Override'))
          o.getAttribute('PartName')!.substring(1): o.getAttribute(
            'ContentType',
          ),
      };
      expect(
        overrides.keys.toSet(),
        parts.keys
            .where((p) => p.endsWith('.xml') && p != '[Content_Types].xml')
            .toSet(),
      );
      expect(
        overrides['xl/drawings/drawing2.xml'],
        'application/vnd.openxmlformats-officedocument.drawing+xml',
      );
      expect(
        overrides['xl/charts/chart6.xml'],
        'application/vnd.openxmlformats-officedocument.drawingml.chart+xml',
      );
      expect(parts.containsKey('xl/charts/chart7.xml'), isFalse);
      expect(
        parts['xl/worksheets/_rels/sheet2.xml.rels'],
        contains(
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
          'officeDocument/2006/relationships/drawing" '
          'Target="../drawings/drawing2.xml"/>',
        ),
      );
      expect(parts.containsKey('xl/worksheets/_rels/sheet3.xml.rels'), isFalse);
      final drawingLinks = XmlDocument.parse(
        parts['xl/drawings/_rels/drawing2.xml.rels']!,
      ).findAllElements('Relationship');
      expect(drawingLinks.map((r) => r.getAttribute('Target')), [
        for (var i = 2; i <= 6; i++) '../charts/chart$i.xml',
      ]);
      expect(
        drawingLinks.map((r) => r.getAttribute('Type')!.split('/').last),
        everyElement('chart'),
      );
      expect(
        parts['xl/worksheets/sheet2.xml'],
        endsWith('<drawing r:id="rId1"/></worksheet>'),
      );
      expect(parts['xl/worksheets/sheet3.xml'], isNot(contains('<drawing')));
    });

    test('anchors each chart to its cells in EMU', () {
      final drawing = parts['xl/drawings/drawing2.xml']!;
      expect(
        RegExp('<xdr:twoCellAnchor editAs="twoCell">').allMatches(drawing),
        hasLength(5),
      );
      expect(
        drawing,
        contains(
          '<xdr:to><xdr:col>7</xdr:col><xdr:colOff>285750</xdr:colOff>'
          '<xdr:row>14</xdr:row><xdr:rowOff>114300</xdr:rowOff></xdr:to>',
        ),
      );
      expect(drawing, contains('r:id="rId5"/>'));
    });

    test('caches the values and the label text', () {
      final column = parts['xl/charts/chart2.xml']!;
      expect(
        column,
        contains(
          "<c:tx><c:strRef><c:f>'Vendas 2026'!\$B\$1</c:f><c:strCache>"
          '<c:ptCount val="1"/><c:pt idx="0"><c:v>Loja A</c:v></c:pt>'
          '</c:strCache></c:strRef></c:tx>',
        ),
      );
      expect(
        column,
        contains(
          "<c:cat><c:strRef><c:f>'Vendas 2026'!\$A\$2:\$A\$4</c:f><c:strCache>"
          '<c:ptCount val="3"/><c:pt idx="0"><c:v>Jan</c:v></c:pt>'
          '<c:pt idx="1"><c:v>Fev &amp; &lt;Mar&gt;</c:v></c:pt>'
          '<c:pt idx="2"><c:v>n2026.0</c:v></c:pt></c:strCache></c:strRef></c:cat>',
        ),
      );
      expect(
        column,
        contains(
          "<c:val><c:numRef><c:f>'Vendas 2026'!\$B\$2:\$B\$4</c:f><c:numCache>"
          '<c:formatCode>General</c:formatCode><c:ptCount val="3"/>'
          '<c:pt idx="0"><c:v>10</c:v></c:pt><c:pt idx="1"><c:v>20.5</c:v></c:pt>'
          '<c:pt idx="2"><c:v>30</c:v></c:pt></c:numCache></c:numRef></c:val>',
        ),
      );
      expect(column, contains('<c:tx><c:v>Meta</c:v></c:tx>'));
      expect(
        column,
        contains(
          '<c:ptCount val="3"/><c:pt idx="0"><c:v>5</c:v></c:pt>'
          '<c:pt idx="2"><c:v>20</c:v></c:pt></c:numCache>',
        ),
      );
      expect(column, contains('<c:barDir val="col"/>'));
      expect(
        column,
        contains('<a:p><a:pPr><a:defRPr/></a:pPr><a:r><a:t>Vendas por mês'),
      );
      final scatter = parts['xl/charts/chart6.xml']!;
      expect(
        scatter,
        contains("<c:xVal><c:numRef><c:f>'Vendas 2026'!\$B\$2:\$B\$4</c:f>"),
      );
      expect(scatter, contains('<c:yVal><c:numRef>'));
      expect(scatter, contains('<c:scatterStyle val="lineMarker"/>'));
      expect(RegExp('<c:valAx>').allMatches(scatter), hasLength(2));
      expect(scatter, isNot(contains('<c:catAx>')));
    });

    test('writes titles, legends and axes as each kind needs', () {
      final bar = parts['xl/charts/chart3.xml']!;
      expect(bar, contains('<c:barDir val="bar"/>'));
      expect(bar, contains('<c:autoTitleDeleted val="1"/>'));
      expect(bar, isNot(contains('<c:title>')));
      expect(bar, isNot(contains('<c:legend>')));
      expect(bar, contains('<c:catAx><c:axId val="1"/>'));
      final area = parts['xl/charts/chart4.xml']!;
      expect(area, contains('<c:areaChart>'));
      expect(area, isNot(contains('<c:cat>')));
      final pie = parts['xl/charts/chart5.xml']!;
      expect(pie, contains('<c:pieChart><c:varyColors val="1"/>'));
      expect(pie, isNot(contains('Ax>')));
      expect(pie, contains('<c:legend>'));
      final line = parts['xl/charts/chart1.xml']!;
      expect(line, contains('<c:lineChart>'));
      expect(
        line,
        contains(
          '<a:t>Linha</a:t></a:r></a:p><a:p><a:pPr><a:defRPr/></a:pPr>'
          '<a:r><a:t>segunda linha</a:t>',
        ),
      );
    });

    test('follows the element order of the schemas', () {
      for (final entry in parts.entries) {
        final path = entry.key;
        if (!path.startsWith('xl/charts/') &&
            !path.startsWith('xl/drawings/drawing') &&
            !path.startsWith('xl/worksheets/sheet')) {
          continue;
        }
        final root = XmlDocument.parse(entry.value).rootElement;
        expect(schemaProblems(root), isEmpty, reason: path);
      }
    });

    test('the order check accepts Excel and catches misplaced elements', () {
      final excel = unzip(excelChartWorkbook())['xl/charts/chart1.xml']!;
      expect(schemaProblems(XmlDocument.parse(excel).rootElement), isEmpty);
      final misplaced = excel
          .replaceFirst('<c:autoTitleDeleted val="0"/>', '')
          .replaceFirst(
            '<c:plotVisOnly',
            '<c:autoTitleDeleted val="0"/><c:plotVisOnly',
          );
      expect(schemaProblems(XmlDocument.parse(misplaced).rootElement), [
        contains('autoTitleDeleted is out of order'),
      ]);
    });

    test('every axis crosses the other one of its chart', () {
      for (var i = 1; i <= 6; i++) {
        final chart = XmlDocument.parse(parts['xl/charts/chart$i.xml']!);
        final plot = chart.findAllElements('c:plotArea').single;
        final group = plot.childElements.firstWhere(
          (e) => e.name.local.endsWith('Chart'),
        );
        final ids = [
          for (final id in group.findElements('c:axId')) id.getAttribute('val'),
        ];
        final axes = plot.childElements.where(
          (e) => e.name.local.endsWith('Ax'),
        );
        expect([
          for (final a in axes) a.getElement('c:axId')!.getAttribute('val'),
        ], ids);
        for (final axis in axes) {
          final crossing = axis.getElement('c:crossAx')!.getAttribute('val');
          expect(ids.where((id) => id != crossing), [
            axis.getElement('c:axId')!.getAttribute('val'),
          ]);
        }
      }
    });
  });

  test('a chart over a whole column caches only the used cells', () {
    final sheet = Sheet('Big');
    for (var row = 0; row < 1000; row++) {
      sheet.setCell(
        CellAddress(0, row),
        Cell(constant: NumberValue(row * 1.0)),
      );
    }
    sheet.charts = [
      SheetChart(
        kind: ChartKind.line,
        series: [ChartSeries(values: ChartData('Big', range('A1:A1048576')))],
        from: ChartPoint(at('C1')),
        to: ChartPoint(at('J20')),
      ),
    ];
    final workbook = Workbook([sheet]);
    final watch = Stopwatch()..start();
    final chart = unzip(
      writeXlsx(
        workbook,
        valueOf: (_, address) => sheet.cellAt(address).constant,
      ),
    )['xl/charts/chart1.xml']!;
    expect(watch.elapsedMilliseconds, lessThan(1000));
    expect(chart, contains('<c:ptCount val="1048576"/>'));
    expect(RegExp('<c:pt ').allMatches(chart), hasLength(1000));
  });

  test('the save facade passes the display text to the chart labels', () {
    final workbook = chartWorkbook();
    final bytes = writeSpreadsheet(
      workbook,
      SpreadsheetFormat.xlsx,
      sheetIndex: 0,
      valueOf: (sheet, address) => chartValues(workbook, sheet, address),
      displayOf: (sheet, address) => '«${address.a1}»',
    );
    expect(
      unzip(bytes)['xl/charts/chart2.xml'],
      contains('<c:pt idx="0"><c:v>«A2»</c:v></c:pt>'),
    );
  });
}
