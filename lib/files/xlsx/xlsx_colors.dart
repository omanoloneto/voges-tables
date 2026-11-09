import 'package:xml/xml.dart';

import 'xlsx_xml.dart';

/// Turns `<color>` elements (rgb, theme + tint, indexed) into ARGB.
class XlsxColors {
  XlsxColors({List<int>? theme, List<int>? indexed})
    : theme = theme ?? officeTheme,
      indexed = indexed ?? officeIndexed;

  /// Theme colors in `theme="n"` order: lt1, dk1, lt2, dk2, accent1–6,
  /// hlink, folHlink (the file lists dk before lt).
  final List<int> theme;
  final List<int> indexed;

  static const officeTheme = [
    0xFFFFFFFF,
    0xFF000000,
    0xFFE7E6E6,
    0xFF44546A,
    0xFF4472C4,
    0xFFED7D31,
    0xFFA5A5A5,
    0xFFFFC000,
    0xFF5B9BD5,
    0xFF70AD47,
    0xFF0563C1,
    0xFF954F72,
  ];

  static const officeIndexed = [
    0xFF000000, 0xFFFFFFFF, 0xFFFF0000, 0xFF00FF00, //
    0xFF0000FF, 0xFFFFFF00, 0xFFFF00FF, 0xFF00FFFF,
    0xFF000000, 0xFFFFFFFF, 0xFFFF0000, 0xFF00FF00,
    0xFF0000FF, 0xFFFFFF00, 0xFFFF00FF, 0xFF00FFFF,
    0xFF800000, 0xFF008000, 0xFF000080, 0xFF808000,
    0xFF800080, 0xFF008080, 0xFFC0C0C0, 0xFF808080,
    0xFF9999FF, 0xFF993366, 0xFFFFFFCC, 0xFFCCFFFF,
    0xFF660066, 0xFFFF8080, 0xFF0066CC, 0xFFCCCCFF,
    0xFF000080, 0xFFFF00FF, 0xFFFFFF00, 0xFF00FFFF,
    0xFF800080, 0xFF800000, 0xFF008080, 0xFF0000FF,
    0xFF00CCFF, 0xFFCCFFFF, 0xFFCCFFCC, 0xFFFFFF99,
    0xFF99CCFF, 0xFFFF99CC, 0xFFCC99FF, 0xFFFFCC99,
    0xFF3366FF, 0xFF33CCCC, 0xFF99CC00, 0xFFFFCC00,
    0xFFFF9900, 0xFFFF6600, 0xFF666699, 0xFF969696,
    0xFF003366, 0xFF339966, 0xFF003300, 0xFF333300,
    0xFF993300, 0xFF993366, 0xFF333399, 0xFF333333,
  ];

  /// Reads `a:clrScheme` from a theme part; null when it has none.
  static List<int>? themeFrom(XmlDocument? document) {
    if (document == null) return null;
    final scheme = document.rootElement.descendantElements
        .where((element) => element.name.local == 'clrScheme')
        .firstOrNull;
    if (scheme == null) return null;
    final colors = <int>[];
    for (final slot in scheme.childElements) {
      final color = slot.childElements.firstOrNull;
      final hex = color?.name.local == 'sysClr'
          ? color?.getAttribute('lastClr')
          : color?.getAttribute('val');
      colors.add(parseHex(hex) ?? 0xFF000000);
    }
    if (colors.length < 4) return null;
    return [colors[1], colors[0], colors[3], colors[2], ...colors.skip(4)];
  }

  /// A custom `<colors><indexedColors>` palette, when the styles have one.
  static List<int>? indexedFrom(XmlElement? styleSheet) {
    final palette = styleSheet == null ? null : child(styleSheet, 'colors');
    final indexed = palette == null ? null : child(palette, 'indexedColors');
    if (indexed == null) return null;
    return [
      for (final entry in children(indexed, 'rgbColor'))
        parseHex(entry.getAttribute('rgb')) ?? 0xFF000000,
    ];
  }

  /// Null for automatic colors and anything that cannot be resolved.
  int? resolve(XmlElement? color) {
    if (color == null || onOffAttribute(color, 'auto')) return null;
    final rgb = parseHex(color.getAttribute('rgb'));
    if (rgb != null) return rgb;
    final themeIndex = int.tryParse(color.getAttribute('theme') ?? '');
    if (themeIndex != null) {
      if (themeIndex < 0 || themeIndex >= theme.length) return null;
      final tint = double.tryParse(color.getAttribute('tint') ?? '') ?? 0;
      return applyTint(theme[themeIndex], tint);
    }
    final index = int.tryParse(color.getAttribute('indexed') ?? '');
    if (index != null && index >= 0 && index < indexed.length) {
      return indexed[index];
    }
    return null;
  }

  /// Accepts `RRGGBB` and `AARRGGBB`; the alpha is ignored because many
  /// writers leave it at 00 for opaque colors.
  static int? parseHex(String? hex) {
    if (hex == null) return null;
    final digits = hex.length == 8 ? hex.substring(2) : hex;
    if (digits.length != 6) return null;
    final value = int.tryParse(digits, radix: 16);
    return value == null ? null : 0xFF000000 | value;
  }

  static String toHex(int argb) =>
      (argb | 0xFF000000).toRadixString(16).toUpperCase().padLeft(8, '0');

  /// Excel's tint: shifts the HSL lightness towards black (< 0) or white.
  static int applyTint(int argb, double tint) {
    if (tint == 0) return argb;
    final r = ((argb >> 16) & 0xFF) / 255;
    final g = ((argb >> 8) & 0xFF) / 255;
    final b = (argb & 0xFF) / 255;
    final max = [r, g, b].reduce((a, b) => a > b ? a : b);
    final min = [r, g, b].reduce((a, b) => a < b ? a : b);
    var lightness = (max + min) / 2;
    final delta = max - min;
    var hue = 0.0, saturation = 0.0;
    if (delta != 0) {
      saturation = lightness > 0.5
          ? delta / (2 - max - min)
          : delta / (max + min);
      if (max == r) {
        hue = ((g - b) / delta) % 6;
      } else if (max == g) {
        hue = (b - r) / delta + 2;
      } else {
        hue = (r - g) / delta + 4;
      }
      hue /= 6;
    }
    lightness = tint < 0
        ? lightness * (1 + tint)
        : lightness * (1 - tint) + tint;
    return 0xFF000000 | _hslToRgb(hue, saturation, lightness.clamp(0.0, 1.0));
  }

  static int _hslToRgb(double hue, double saturation, double lightness) {
    if (saturation == 0) {
      final grey = (lightness * 255).round();
      return grey << 16 | grey << 8 | grey;
    }
    final q = lightness < 0.5
        ? lightness * (1 + saturation)
        : lightness + saturation - lightness * saturation;
    final p = 2 * lightness - q;
    int channel(double t) {
      var x = t;
      if (x < 0) x += 1;
      if (x > 1) x -= 1;
      final double value;
      if (x < 1 / 6) {
        value = p + (q - p) * 6 * x;
      } else if (x < 1 / 2) {
        value = q;
      } else if (x < 2 / 3) {
        value = p + (q - p) * (2 / 3 - x) * 6;
      } else {
        value = p;
      }
      return (value * 255).round().clamp(0, 255);
    }

    return channel(hue + 1 / 3) << 16 |
        channel(hue) << 8 |
        channel(hue - 1 / 3);
  }
}
