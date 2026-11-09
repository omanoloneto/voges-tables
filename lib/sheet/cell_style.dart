enum HorizontalAlign { general, left, center, right }

enum VerticalAlign { top, middle, bottom }

/// How a number is shown. `decimals` applies to every kind except
/// [NumberKind.general] and [NumberKind.text].
enum NumberKind {
  general,
  number,
  currency,
  percent,
  date,
  time,
  dateTime,
  text,
}

class NumberFormat {
  const NumberFormat(this.kind, {this.decimals = 2, this.thousands = true});

  static const general = NumberFormat(NumberKind.general, decimals: 0);

  final NumberKind kind;
  final int decimals;
  final bool thousands;

  NumberFormat copyWith({NumberKind? kind, int? decimals, bool? thousands}) =>
      NumberFormat(
        kind ?? this.kind,
        decimals: decimals ?? this.decimals,
        thousands: thousands ?? this.thousands,
      );

  @override
  bool operator ==(Object other) =>
      other is NumberFormat &&
      other.kind == kind &&
      other.decimals == decimals &&
      other.thousands == thousands;

  @override
  int get hashCode => Object.hash(kind, decimals, thousands);
}

/// Thin borders on each side of the cell.
class CellBorders {
  const CellBorders({
    this.top = false,
    this.right = false,
    this.bottom = false,
    this.left = false,
  });

  static const none = CellBorders();
  static const all = CellBorders(
    top: true,
    right: true,
    bottom: true,
    left: true,
  );

  final bool top, right, bottom, left;

  bool get isEmpty => !top && !right && !bottom && !left;

  @override
  bool operator ==(Object other) =>
      other is CellBorders &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

/// The look of one cell. Colors are ARGB; null means the default.
class CellStyle {
  const CellStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize = 11,
    this.textColor,
    this.fillColor,
    this.horizontal = HorizontalAlign.general,
    this.vertical = VerticalAlign.bottom,
    this.wrap = false,
    this.format = NumberFormat.general,
    this.borders = CellBorders.none,
  });

  static const plain = CellStyle();

  final bool bold, italic, underline, strike;
  final double fontSize;
  final int? textColor;
  final int? fillColor;
  final HorizontalAlign horizontal;
  final VerticalAlign vertical;
  final bool wrap;
  final NumberFormat format;
  final CellBorders borders;

  bool get isPlain => this == plain;

  CellStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    double? fontSize,
    int? Function()? textColor,
    int? Function()? fillColor,
    HorizontalAlign? horizontal,
    VerticalAlign? vertical,
    bool? wrap,
    NumberFormat? format,
    CellBorders? borders,
  }) => CellStyle(
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    strike: strike ?? this.strike,
    fontSize: fontSize ?? this.fontSize,
    textColor: textColor != null ? textColor() : this.textColor,
    fillColor: fillColor != null ? fillColor() : this.fillColor,
    horizontal: horizontal ?? this.horizontal,
    vertical: vertical ?? this.vertical,
    wrap: wrap ?? this.wrap,
    format: format ?? this.format,
    borders: borders ?? this.borders,
  );

  @override
  bool operator ==(Object other) =>
      other is CellStyle &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike &&
      other.fontSize == fontSize &&
      other.textColor == textColor &&
      other.fillColor == fillColor &&
      other.horizontal == horizontal &&
      other.vertical == vertical &&
      other.wrap == wrap &&
      other.format == format &&
      other.borders == borders;

  @override
  int get hashCode => Object.hash(
    bold,
    italic,
    underline,
    strike,
    fontSize,
    textColor,
    fillColor,
    horizontal,
    vertical,
    wrap,
    format,
    borders,
  );
}
