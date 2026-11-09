import '../../sheet/cell_address.dart';
import '../../sheet/cell_value.dart';
import '../../sheet/chart.dart';
import '../../sheet/workbook.dart';
import 'chart_references.dart';
import 'xlsx_sheet_reader.dart' show emuPerPixel;
import 'xlsx_xml.dart';

typedef _Data = ({int sheet, CellRange range, String formula});
typedef _Cell = ({int index, CellAddress address, CellValue value});

/// Writes the drawing and chart parts of the workbook's charts. Every series
/// carries the current values as its cache, so readers that do not
/// recalculate still draw the chart.
class XlsxChartWriter {
  XlsxChartWriter(
    this.workbook, {
    required this.sheetNames,
    required this.valueOf,
    String Function(int sheetIndex, CellAddress address)? displayOf,
  }) : displayOf = displayOf ?? ((sheet, cell) => _plain(valueOf(sheet, cell)));

  final Workbook workbook;

  /// The names the workbook part gives the sheets, which formulas must use.
  final List<String> sheetNames;
  final CellValue Function(int sheetIndex, CellAddress address) valueOf;
  final String Function(int sheetIndex, CellAddress address) displayOf;

  static const _axisIds = '<c:axId val="1"/><c:axId val="2"/>';

  /// The drawing part of a sheet: the chart at index `i` of [charts] points
  /// to the relationship `rId{i + 1}`.
  static String drawing(List<SheetChart> charts) {
    final buffer = StringBuffer(xmlDeclaration)
      ..write(
        '<xdr:wsDr xmlns:xdr="${XlsxNamespaces.spreadsheetDrawing}" '
        'xmlns:a="${XlsxNamespaces.drawing}">',
      );
    for (var i = 0; i < charts.length; i++) {
      buffer.write('<xdr:twoCellAnchor editAs="twoCell">');
      _marker(buffer, 'from', charts[i].from);
      _marker(buffer, 'to', charts[i].to);
      buffer.write(
        '<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr>'
        '<xdr:cNvPr id="${i + 2}" name="Chart ${i + 1}"/>'
        '<xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>'
        '<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm>'
        '<a:graphic><a:graphicData uri="${XlsxNamespaces.chart}">'
        '<c:chart xmlns:c="${XlsxNamespaces.chart}" '
        'xmlns:r="${XlsxNamespaces.relationships}" r:id="rId${i + 1}"/>'
        '</a:graphicData></a:graphic></xdr:graphicFrame>'
        '<xdr:clientData/></xdr:twoCellAnchor>',
      );
    }
    buffer.write('</xdr:wsDr>');
    return buffer.toString();
  }

  static void _marker(StringBuffer buffer, String tag, ChartPoint point) {
    int emu(double pixels) => pixels > 0 ? (pixels * emuPerPixel).round() : 0;
    final column = point.cell.column.clamp(0, CellAddress.maxColumns - 1);
    final row = point.cell.row.clamp(0, CellAddress.maxRows - 1);
    buffer.write(
      '<xdr:$tag><xdr:col>$column</xdr:col>'
      '<xdr:colOff>${emu(point.dx)}</xdr:colOff>'
      '<xdr:row>$row</xdr:row>'
      '<xdr:rowOff>${emu(point.dy)}</xdr:rowOff></xdr:$tag>',
    );
  }

  /// The chart part of [chart], in the element order of the DrawingML chart
  /// schema; null when none of its series reads a sheet of the workbook.
  String? chart(SheetChart chart) {
    final series = <(ChartSeries, _Data)>[
      for (final s in chart.series)
        if (_resolve(s.values) case final values?) (s, values),
    ];
    if (series.isEmpty) return null;
    final kind = chart.kind;
    final categories = switch (chart.categories) {
      final data? => _categories(data, scatter: kind == ChartKind.scatter),
      null => '',
    };
    final buffer = StringBuffer(xmlDeclaration)
      ..write(
        '<c:chartSpace xmlns:c="${XlsxNamespaces.chart}" '
        'xmlns:a="${XlsxNamespaces.drawing}" '
        'xmlns:r="${XlsxNamespaces.relationships}">'
        '<c:roundedCorners val="0"/><c:chart>',
      );
    final title = chart.title;
    if (title != null && title.trim().isNotEmpty) {
      _title(buffer, title);
      buffer.write('<c:autoTitleDeleted val="0"/>');
    } else {
      buffer.write('<c:autoTitleDeleted val="1"/>');
    }
    buffer
      ..write('<c:plotArea><c:layout/>')
      ..write(switch (kind) {
        ChartKind.column =>
          '<c:barChart><c:barDir val="col"/><c:grouping val="clustered"/>'
              '<c:varyColors val="0"/>',
        ChartKind.bar =>
          '<c:barChart><c:barDir val="bar"/><c:grouping val="clustered"/>'
              '<c:varyColors val="0"/>',
        ChartKind.line =>
          '<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>',
        ChartKind.area =>
          '<c:areaChart><c:grouping val="standard"/><c:varyColors val="0"/>',
        ChartKind.pie => '<c:pieChart><c:varyColors val="1"/>',
        ChartKind.scatter =>
          '<c:scatterChart><c:scatterStyle val="lineMarker"/>'
              '<c:varyColors val="0"/>',
      });
    for (var i = 0; i < series.length; i++) {
      final (s, values) = series[i];
      _series(buffer, kind, i, s, values, categories);
    }
    buffer
      ..write(switch (kind) {
        ChartKind.column ||
        ChartKind.bar => '<c:gapWidth val="150"/>$_axisIds</c:barChart>',
        ChartKind.line => '<c:marker val="1"/>$_axisIds</c:lineChart>',
        ChartKind.area => '$_axisIds</c:areaChart>',
        ChartKind.pie => '<c:firstSliceAng val="0"/></c:pieChart>',
        ChartKind.scatter => '$_axisIds</c:scatterChart>',
      })
      ..write(_axes(kind))
      ..write('</c:plotArea>');
    if (chart.showLegend) {
      buffer.write(
        '<c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend>',
      );
    }
    buffer.write(
      '<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/>'
      '</c:chart></c:chartSpace>',
    );
    return buffer.toString();
  }

  _Data? _resolve(ChartData data) {
    final index = workbook.indexOf(data.sheet);
    if (index < 0) return null;
    return (
      sheet: index,
      range: data.range,
      formula: chartReference(sheetNames[index], data.range),
    );
  }

  static void _title(StringBuffer buffer, String title) {
    buffer.write('<c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/>');
    for (final line in title.split(RegExp(r'\r?\n'))) {
      buffer.write('<a:p><a:pPr><a:defRPr/></a:pPr>');
      if (line.isNotEmpty) {
        buffer.write('<a:r><a:t>${escapeXml(line)}</a:t></a:r>');
      }
      buffer.write('</a:p>');
    }
    buffer.write('</c:rich></c:tx><c:overlay val="0"/></c:title>');
  }

  /// The `c:cat` (or `c:xVal`) every series repeats; empty when the cells
  /// are on no sheet of the workbook.
  String _categories(ChartData data, {required bool scatter}) {
    final categories = _resolve(data);
    if (categories == null) return '';
    final cells = _cells(categories);
    final numeric = cells.every(
      (cell) => cell.value is EmptyValue || _isNumber(cell.value),
    );
    final buffer = StringBuffer(scatter ? '<c:xVal>' : '<c:cat>');
    if (numeric) {
      _numbers(buffer, categories, cells);
    } else {
      _texts(buffer, categories, cells);
    }
    buffer.write(scatter ? '</c:xVal>' : '</c:cat>');
    return buffer.toString();
  }

  void _series(
    StringBuffer buffer,
    ChartKind kind,
    int index,
    ChartSeries series,
    _Data values,
    String categories,
  ) {
    buffer.write('<c:ser><c:idx val="$index"/><c:order val="$index"/>');
    final name = series.name == null ? null : _resolve(series.name!);
    if (name != null) {
      buffer.write('<c:tx>');
      _texts(buffer, name, _cells(name));
      buffer.write('</c:tx>');
    } else if (series.title case final title? when title.isNotEmpty) {
      buffer.write('<c:tx><c:v>${escapeText(title)}</c:v></c:tx>');
    }
    final scatter = kind == ChartKind.scatter;
    switch (kind) {
      case ChartKind.column || ChartKind.bar:
        buffer.write('<c:invertIfNegative val="0"/>');
      case ChartKind.scatter:
        buffer.write('<c:spPr><a:ln w="19050"><a:noFill/></a:ln></c:spPr>');
      default:
        break;
    }
    buffer
      ..write(categories)
      ..write(scatter ? '<c:yVal>' : '<c:val>');
    _numbers(buffer, values, _cells(values));
    buffer.write(scatter ? '</c:yVal>' : '</c:val>');
    if (kind == ChartKind.line || scatter) buffer.write('<c:smooth val="0"/>');
    buffer.write('</c:ser>');
  }

  /// The cells of [data] that can hold something, as `idx` in the range.
  /// Only the used part of the sheet is visited, so `A:A`-sized ranges cost
  /// no more than the cells there.
  List<_Cell> _cells(_Data data) {
    final used = workbook.sheets[data.sheet].usedRange;
    if (used == null) return const [];
    final range = data.range;
    final lastColumn = range.last.column < used.last.column
        ? range.last.column
        : used.last.column;
    final lastRow = range.last.row < used.last.row
        ? range.last.row
        : used.last.row;
    return [
      for (var row = range.first.row; row <= lastRow; row++)
        for (var column = range.first.column; column <= lastColumn; column++)
          (
            index:
                (row - range.first.row) * range.columns +
                column -
                range.first.column,
            address: CellAddress(column, row),
            value: valueOf(data.sheet, CellAddress(column, row)),
          ),
    ];
  }

  static void _numbers(StringBuffer buffer, _Data data, List<_Cell> cells) {
    buffer.write(
      '<c:numRef><c:f>${escapeText(data.formula)}</c:f><c:numCache>'
      '<c:formatCode>General</c:formatCode>'
      '<c:ptCount val="${data.range.columns * data.range.rows}"/>',
    );
    for (final cell in cells) {
      if (cell.value case NumberValue(:final value) when value.isFinite) {
        buffer.write(
          '<c:pt idx="${cell.index}"><c:v>${xlsxNumber(value)}</c:v></c:pt>',
        );
      }
    }
    buffer.write('</c:numCache></c:numRef>');
  }

  void _texts(StringBuffer buffer, _Data data, List<_Cell> cells) {
    buffer.write(
      '<c:strRef><c:f>${escapeText(data.formula)}</c:f><c:strCache>'
      '<c:ptCount val="${data.range.columns * data.range.rows}"/>',
    );
    for (final cell in cells) {
      if (cell.value is EmptyValue) continue;
      final text = displayOf(data.sheet, cell.address);
      buffer.write(
        '<c:pt idx="${cell.index}"><c:v>${escapeText(text)}</c:v></c:pt>',
      );
    }
    buffer.write('</c:strCache></c:strRef>');
  }

  static String _axes(ChartKind kind) {
    switch (kind) {
      case ChartKind.pie:
        return '';
      case ChartKind.scatter:
        return _valueAxis(1, 2, 'b', gridlines: false, between: 'midCat') +
            _valueAxis(2, 1, 'l', gridlines: true, between: 'midCat');
      default:
        final horizontal = kind == ChartKind.bar;
        final values = _valueAxis(
          2,
          1,
          horizontal ? 'b' : 'l',
          gridlines: true,
          between: kind == ChartKind.area ? 'midCat' : 'between',
        );
        return '<c:catAx><c:axId val="1"/>'
            '<c:scaling><c:orientation val="minMax"/></c:scaling>'
            '<c:delete val="0"/><c:axPos val="${horizontal ? 'l' : 'b'}"/>'
            '<c:numFmt formatCode="General" sourceLinked="1"/>'
            '<c:majorTickMark val="out"/><c:minorTickMark val="none"/>'
            '<c:tickLblPos val="nextTo"/><c:crossAx val="2"/>'
            '<c:crosses val="autoZero"/><c:auto val="1"/>'
            '<c:lblAlgn val="ctr"/><c:lblOffset val="100"/>'
            '<c:noMultiLvlLbl val="0"/></c:catAx>$values';
    }
  }

  static String _valueAxis(
    int id,
    int crossing,
    String position, {
    required bool gridlines,
    required String between,
  }) =>
      '<c:valAx><c:axId val="$id"/>'
      '<c:scaling><c:orientation val="minMax"/></c:scaling>'
      '<c:delete val="0"/><c:axPos val="$position"/>'
      '${gridlines ? '<c:majorGridlines/>' : ''}'
      '<c:numFmt formatCode="General" sourceLinked="1"/>'
      '<c:majorTickMark val="out"/><c:minorTickMark val="none"/>'
      '<c:tickLblPos val="nextTo"/><c:crossAx val="$crossing"/>'
      '<c:crosses val="autoZero"/><c:crossBetween val="$between"/></c:valAx>';

  static bool _isNumber(CellValue value) =>
      value is NumberValue && value.value.isFinite;

  static String _plain(CellValue value) => switch (value) {
    EmptyValue() => '',
    NumberValue(:final value) => xlsxNumber(value),
    TextValue(:final value) => value,
    BoolValue(:final value) => value ? 'TRUE' : 'FALSE',
    ErrorValue(:final error) => error.code,
  };
}
