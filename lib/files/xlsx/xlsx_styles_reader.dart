import 'package:xml/xml.dart';

import '../../sheet/cell_style.dart';
import 'number_format_codes.dart';
import 'xlsx_colors.dart';
import 'xlsx_xml.dart';

class _Font {
  const _Font({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.size,
    this.color,
  });

  final bool bold, italic, underline, strike;
  final double? size;
  final int? color;
}

/// Maps `styles.xml` to one [CellStyle] per `cellXfs` entry, so a cell's
/// `s` attribute indexes the list directly.
///
/// The file's default font size and color become the app's defaults, so
/// unstyled cells stay [CellStyle.plain] whatever font the file uses.
List<CellStyle> readCellStyles(XmlDocument? document, {List<int>? theme}) {
  if (document == null) return const [CellStyle.plain];
  final root = document.rootElement;
  final colors = XlsxColors(
    theme: theme,
    indexed: XlsxColors.indexedFrom(root),
  );
  final customCodes = _numberFormats(root);
  final fonts = _list(root, 'fonts', 'font', (e) => _font(e, colors));
  final fills = _list(root, 'fills', 'fill', (e) => _fill(e, colors));
  final borders = _list(root, 'borders', 'border', _borders);
  final defaultFont = fonts.firstOrNull ?? const _Font();

  CellStyle style(XmlElement xf) {
    final font = _at(fonts, xf.getAttribute('fontId')) ?? defaultFont;
    final alignment = child(xf, 'alignment');
    final numberFormatId = int.tryParse(xf.getAttribute('numFmtId') ?? '') ?? 0;
    return CellStyle(
      bold: font.bold,
      italic: font.italic,
      underline: font.underline,
      strike: font.strike,
      fontSize: font.size == null || font.size == defaultFont.size
          ? CellStyle.plain.fontSize
          : font.size!,
      textColor: font.color == defaultFont.color ? null : font.color,
      fillColor: _at<int?>(fills, xf.getAttribute('fillId')),
      horizontal: _horizontal(alignment?.getAttribute('horizontal')),
      vertical: _vertical(alignment?.getAttribute('vertical')),
      wrap: alignment != null && onOffAttribute(alignment, 'wrapText'),
      format: numberFormatForId(numberFormatId, customCodes),
      borders: _at(borders, xf.getAttribute('borderId')) ?? CellBorders.none,
    );
  }

  final cellXfs = child(root, 'cellXfs');
  final styles = [
    if (cellXfs != null)
      for (final xf in children(cellXfs, 'xf')) style(xf),
  ];
  return styles.isEmpty ? const [CellStyle.plain] : styles;
}

Map<int, String> _numberFormats(XmlElement root) {
  final numFmts = child(root, 'numFmts');
  if (numFmts == null) return const {};
  return {
    for (final format in children(numFmts, 'numFmt'))
      ?int.tryParse(format.getAttribute('numFmtId') ?? ''):
          format.getAttribute('formatCode') ?? 'General',
  };
}

List<T> _list<T>(
  XmlElement root,
  String group,
  String item,
  T Function(XmlElement) map,
) {
  final parent = child(root, group);
  return parent == null ? const [] : children(parent, item).map(map).toList();
}

T? _at<T>(List<T> list, String? index) {
  final i = int.tryParse(index ?? '');
  return i != null && i >= 0 && i < list.length ? list[i] : null;
}

bool _flag(XmlElement font, String name) {
  final element = child(font, name);
  return element != null && onOff(element.getAttribute('val'));
}

_Font _font(XmlElement font, XlsxColors colors) {
  final underline = child(font, 'u');
  return _Font(
    bold: _flag(font, 'b'),
    italic: _flag(font, 'i'),
    strike: _flag(font, 'strike'),
    underline: underline != null && underline.getAttribute('val') != 'none',
    size: double.tryParse(child(font, 'sz')?.getAttribute('val') ?? ''),
    color: colors.resolve(child(font, 'color')),
  );
}

int? _fill(XmlElement fill, XlsxColors colors) {
  final pattern = child(fill, 'patternFill');
  if (pattern?.getAttribute('patternType') != 'solid') return null;
  return colors.resolve(child(pattern!, 'fgColor')) ??
      colors.resolve(child(pattern, 'bgColor'));
}

CellBorders _borders(XmlElement border) {
  bool side(String name, [String? alias]) {
    final element =
        child(border, name) ?? (alias == null ? null : child(border, alias));
    final style = element?.getAttribute('style');
    return style != null && style != 'none';
  }

  return CellBorders(
    top: side('top'),
    right: side('right', 'end'),
    bottom: side('bottom'),
    left: side('left', 'start'),
  );
}

HorizontalAlign _horizontal(String? value) => switch (value) {
  'left' || 'justify' || 'fill' => HorizontalAlign.left,
  'center' || 'centerContinuous' || 'distributed' => HorizontalAlign.center,
  'right' => HorizontalAlign.right,
  _ => HorizontalAlign.general,
};

VerticalAlign _vertical(String? value) => switch (value) {
  'top' => VerticalAlign.top,
  'center' || 'justify' || 'distributed' => VerticalAlign.middle,
  _ => VerticalAlign.bottom,
};
