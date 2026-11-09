import '../../sheet/cell_style.dart';
import 'number_format_codes.dart';
import 'xlsx_colors.dart';
import 'xlsx_xml.dart';

/// Collects the styles used while the sheets are written and deduplicates
/// fonts, fills, borders, number formats and `cellXfs`. Entry 0 of each list
/// is the default, as Excel requires.
class XlsxStyleTable {
  XlsxStyleTable({this.currencySymbol = r'R$'});

  final String currencySymbol;

  static const defaultFontName = 'Calibri';
  static const _firstCustomFormatId = 164;

  final _styles = <CellStyle, int>{CellStyle.plain: 0};
  final _fonts = <String, int>{};
  final _fills = <int?, int>{null: 0};
  final _borders = <CellBorders, int>{CellBorders.none: 0};
  final _customFormats = <String, int>{};
  final _xfs = <String>[];

  /// The `s` attribute for a cell with [style].
  int indexOf(CellStyle style) {
    final known = _styles[style];
    if (known != null) return known;
    if (_xfs.isEmpty) _xfs.add(_xf(CellStyle.plain));
    final index = _xfs.length;
    _xfs.add(_xf(style));
    _styles[style] = index;
    return index;
  }

  String _xf(CellStyle style) {
    final fontId = _fonts.putIfAbsent(_font(style), () => _fonts.length);
    final fillId = style.fillColor == null
        ? 0
        : _fills.putIfAbsent(style.fillColor, () => _fills.length + 1);
    final borderId = _borders.putIfAbsent(style.borders, () => _borders.length);
    final numFmtId = _numberFormatId(style.format);
    final alignment = _alignment(style);
    final attributes =
        'numFmtId="$numFmtId" fontId="$fontId" fillId="$fillId" '
        'borderId="$borderId" xfId="0"'
        '${numFmtId != 0 ? ' applyNumberFormat="1"' : ''}'
        '${fontId != 0 ? ' applyFont="1"' : ''}'
        '${fillId != 0 ? ' applyFill="1"' : ''}'
        '${borderId != 0 ? ' applyBorder="1"' : ''}';
    return alignment == null
        ? '<xf $attributes/>'
        : '<xf $attributes applyAlignment="1">$alignment</xf>';
  }

  int _numberFormatId(NumberFormat format) {
    final code = formatCodeFor(format, currencySymbol: currencySymbol);
    return builtInIdFor(code) ??
        _customFormats.putIfAbsent(
          code,
          () => _firstCustomFormatId + _customFormats.length,
        );
  }

  static String _font(CellStyle style) {
    final buffer = StringBuffer('<font>');
    if (style.bold) buffer.write('<b/>');
    if (style.italic) buffer.write('<i/>');
    if (style.strike) buffer.write('<strike/>');
    if (style.underline) buffer.write('<u/>');
    buffer.write('<sz val="${_number(style.fontSize)}"/>');
    final color = style.textColor;
    if (color != null) {
      buffer.write('<color rgb="${XlsxColors.toHex(color)}"/>');
    }
    buffer.write('<name val="$defaultFontName"/><family val="2"/></font>');
    return buffer.toString();
  }

  static String? _alignment(CellStyle style) {
    final horizontal = switch (style.horizontal) {
      HorizontalAlign.general => null,
      HorizontalAlign.left => 'left',
      HorizontalAlign.center => 'center',
      HorizontalAlign.right => 'right',
    };
    final vertical = switch (style.vertical) {
      VerticalAlign.top => 'top',
      VerticalAlign.middle => 'center',
      VerticalAlign.bottom => null,
    };
    if (horizontal == null && vertical == null && !style.wrap) return null;
    return '<alignment'
        '${horizontal == null ? '' : ' horizontal="$horizontal"'}'
        '${vertical == null ? '' : ' vertical="$vertical"'}'
        '${style.wrap ? ' wrapText="1"' : ''}/>';
  }

  static String _border(CellBorders borders) {
    String side(String name, bool on) =>
        on ? '<$name style="thin"><color auto="1"/></$name>' : '<$name/>';
    return '<border>${side('left', borders.left)}${side('right', borders.right)}'
        '${side('top', borders.top)}${side('bottom', borders.bottom)}'
        '<diagonal/></border>';
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  /// The whole `xl/styles.xml`.
  String toXml() {
    if (_xfs.isEmpty) _xfs.add(_xf(CellStyle.plain));
    final buffer = StringBuffer(xmlDeclaration)
      ..write('<styleSheet xmlns="${XlsxNamespaces.main}">');
    if (_customFormats.isNotEmpty) {
      buffer.write('<numFmts count="${_customFormats.length}">');
      _customFormats.forEach((code, id) {
        buffer.write(
          '<numFmt numFmtId="$id" formatCode="${escapeAttribute(code)}"/>',
        );
      });
      buffer.write('</numFmts>');
    }
    buffer
      ..write('<fonts count="${_fonts.length}">')
      ..writeAll(_fonts.keys)
      ..write('</fonts>')
      ..write('<fills count="${_fills.length + 1}">')
      ..write('<fill><patternFill patternType="none"/></fill>')
      ..write('<fill><patternFill patternType="gray125"/></fill>');
    for (final color in _fills.keys.whereType<int>()) {
      buffer.write(
        '<fill><patternFill patternType="solid">'
        '<fgColor rgb="${XlsxColors.toHex(color)}"/><bgColor indexed="64"/>'
        '</patternFill></fill>',
      );
    }
    buffer
      ..write('</fills><borders count="${_borders.length}">')
      ..writeAll(_borders.keys.map(_border))
      ..write('</borders>')
      ..write(
        '<cellStyleXfs count="1">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
        '</cellStyleXfs>',
      )
      ..write('<cellXfs count="${_xfs.length}">')
      ..writeAll(_xfs)
      ..write('</cellXfs>')
      ..write(
        '<cellStyles count="1">'
        '<cellStyle name="Normal" xfId="0" builtinId="0"/>'
        '</cellStyles>'
        '<dxfs count="0"/>'
        '<tableStyles count="0" defaultTableStyle="TableStyleMedium2" '
        'defaultPivotStyle="PivotStyleLight16"/>'
        '</styleSheet>',
      );
    return buffer.toString();
  }
}
