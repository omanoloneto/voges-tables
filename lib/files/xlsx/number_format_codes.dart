import '../../sheet/cell_style.dart';

/// The format codes Excel implies for the built-in `numFmtId`s it does not
/// write out. Ids 5–8 and 41–44 depend on the locale; only their shape
/// (currency or not, decimals) matters here.
const builtInFormatCodes = <int, String>{
  0: 'General',
  1: '0',
  2: '0.00',
  3: '#,##0',
  4: '#,##0.00',
  5: r'"$"#,##0_);\("$"#,##0\)',
  6: r'"$"#,##0_);[Red]\("$"#,##0\)',
  7: r'"$"#,##0.00_);\("$"#,##0.00\)',
  8: r'"$"#,##0.00_);[Red]\("$"#,##0.00\)',
  9: '0%',
  10: '0.00%',
  11: '0.00E+00',
  12: '# ?/?',
  13: '# ??/??',
  14: 'mm-dd-yy',
  15: 'd-mmm-yy',
  16: 'd-mmm',
  17: 'mmm-yy',
  18: 'h:mm AM/PM',
  19: 'h:mm:ss AM/PM',
  20: 'h:mm',
  21: 'h:mm:ss',
  22: 'm/d/yy h:mm',
  37: '#,##0 ;(#,##0)',
  38: '#,##0 ;[Red](#,##0)',
  39: '#,##0.00;(#,##0.00)',
  40: '#,##0.00;[Red](#,##0.00)',
  41: r'_(* #,##0_);_(* \(#,##0\);_(* "-"_);_(@_)',
  42: r'_("$"* #,##0_);_("$"* \(#,##0\);_("$"* "-"_);_(@_)',
  43: r'_(* #,##0.00_);_(* \(#,##0.00\);_(* "-"??_);_(@_)',
  44: r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
  45: 'mm:ss',
  46: '[h]:mm:ss',
  47: 'mmss.0',
  48: '##0.0E+0',
  49: '@',
};

/// East Asian built-in date ids (27–36, 50–58) that are never written out.
bool _isEastAsianDateId(int id) =>
    (id >= 27 && id <= 36) || (id >= 50 && id <= 58);

NumberFormat numberFormatForId(int id, Map<int, String> customCodes) {
  final code = customCodes[id] ?? builtInFormatCodes[id];
  if (code != null) return numberFormatFromCode(code);
  if (_isEastAsianDateId(id)) return const NumberFormat(NumberKind.date);
  return NumberFormat.general;
}

const _currencySymbols = {r'$', '€', '£', '¥', '₩', '₹', '₽', '₺', '₱', '¢'};

/// Classifies a format code by its first section, the one used for positive
/// numbers. Percent, date and time kinds carry no thousands flag in `.xlsx`,
/// so they keep the defaults of [NumberFormat], as the interface builds them.
NumberFormat numberFormatFromCode(String code) {
  final section = _firstSection(code);
  if (section.trim().toLowerCase() == 'general' || section.trim().isEmpty) {
    return NumberFormat.general;
  }
  final scan = _scan(section);
  if (scan.hasDate && scan.hasTime) {
    return const NumberFormat(NumberKind.dateTime);
  }
  if (scan.hasDate) return const NumberFormat(NumberKind.date);
  if (scan.hasTime) return const NumberFormat(NumberKind.time);
  if (!scan.hasDigits) {
    return scan.isText
        ? const NumberFormat(NumberKind.text)
        : NumberFormat.general;
  }
  if (scan.isPercent) {
    return NumberFormat(NumberKind.percent, decimals: scan.decimals);
  }
  return NumberFormat(
    scan.isCurrency ? NumberKind.currency : NumberKind.number,
    decimals: scan.decimals,
    thousands: scan.thousands,
  );
}

String _firstSection(String code) {
  var quoted = false;
  for (var i = 0; i < code.length; i++) {
    final char = code[i];
    if (char == '\\') {
      i++;
    } else if (char == '"') {
      quoted = !quoted;
    } else if (char == ';' && !quoted) {
      return code.substring(0, i);
    }
  }
  return code;
}

class _CodeScan {
  bool hasDate = false;
  bool hasTime = false;
  bool hasDigits = false;
  bool isPercent = false;
  bool isCurrency = false;
  bool isText = false;
  bool thousands = false;
  bool afterPoint = false;
  int decimals = 0;
  String? previousToken;
}

_CodeScan _scan(String section) {
  final scan = _CodeScan();
  final lower = section.toLowerCase();
  var i = 0;
  while (i < section.length) {
    final char = section[i];
    final low = lower[i];
    if (char == '"') {
      final end = section.indexOf('"', i + 1);
      final literal = end < 0
          ? section.substring(i + 1)
          : section.substring(i + 1, end);
      if (_hasCurrencySymbol(literal)) scan.isCurrency = true;
      i = end < 0 ? section.length : end + 1;
      continue;
    }
    if (char == '\\' || char == '_' || char == '*') {
      if (char == '\\' && i + 1 < section.length) {
        if (_currencySymbols.contains(section[i + 1])) scan.isCurrency = true;
      }
      i += 2;
      continue;
    }
    if (char == '[') {
      final end = section.indexOf(']', i);
      final inner = end < 0
          ? section.substring(i + 1)
          : section.substring(i + 1, end);
      _scanBracket(inner, scan);
      i = end < 0 ? section.length : end + 1;
      continue;
    }
    if (lower.startsWith('am/pm', i) || lower.startsWith('a/p', i)) {
      scan.hasTime = true;
      i += lower.startsWith('am/pm', i) ? 5 : 3;
      continue;
    }
    switch (low) {
      case 'y' || 'd':
        scan.hasDate = true;
        scan.previousToken = 'date';
      case 'h' || 's':
        scan.hasTime = true;
        scan.previousToken = 'time';
      case 'm':
        // Alone "m" is the month; next to hours or seconds it is minutes.
        if (scan.previousToken == 'time' || _secondsFollow(lower, i)) {
          scan.hasTime = true;
        } else {
          scan.hasDate = true;
        }
      case '0' || '#' || '?':
        scan.hasDigits = true;
        if (scan.afterPoint) scan.decimals++;
      case '.':
        if (scan.hasDigits || _digitFollows(section, i)) scan.afterPoint = true;
      case ',':
        if (scan.hasDigits && !scan.afterPoint && _digitFollows(section, i)) {
          scan.thousands = true;
        }
      case 'e' when i + 1 < section.length && '+-'.contains(section[i + 1]):
        scan.afterPoint = false;
      case '%':
        scan.isPercent = true;
      case '@':
        scan.isText = true;
      default:
        if (_currencySymbols.contains(char)) scan.isCurrency = true;
    }
    i++;
  }
  if (scan.hasDate || scan.hasTime) scan.hasDigits = false;
  return scan;
}

void _scanBracket(String inner, _CodeScan scan) {
  if (inner.startsWith(r'$')) {
    final symbol = inner.substring(1).split('-').first;
    if (symbol.isNotEmpty) scan.isCurrency = true;
    return;
  }
  final lower = inner.toLowerCase();
  if (RegExp(r'^(h+|m+|s+)$').hasMatch(lower)) {
    scan.hasTime = true;
    scan.previousToken = 'time';
  }
}

bool _hasCurrencySymbol(String literal) =>
    literal.split('').any(_currencySymbols.contains);

bool _digitFollows(String section, int index) =>
    index + 1 < section.length && '0#?'.contains(section[index + 1]);

/// `mm:ss` — minutes when seconds come right after.
bool _secondsFollow(String lower, int index) {
  var i = index;
  while (i < lower.length && lower[i] == 'm') {
    i++;
  }
  while (i < lower.length && ':. '.contains(lower[i])) {
    i++;
  }
  return i < lower.length && (lower[i] == 's' || lower.startsWith('[s', i));
}

/// The code Voges Tables writes for a format, in the Brazilian style.
String formatCodeFor(NumberFormat format, {String currencySymbol = r'R$'}) {
  final digits = _digitsCode(format);
  return switch (format.kind) {
    NumberKind.general => 'General',
    NumberKind.number => digits,
    NumberKind.currency => '"${currencySymbol.replaceAll('"', '')}" $digits',
    NumberKind.percent => '${_digitsCode(format.copyWith(thousands: false))}%',
    NumberKind.date => 'dd/mm/yyyy',
    NumberKind.time => 'hh:mm',
    NumberKind.dateTime => 'dd/mm/yyyy hh:mm',
    NumberKind.text => '@',
  };
}

String _digitsCode(NumberFormat format) {
  final integer = format.thousands ? '#,##0' : '0';
  final decimals = format.decimals.clamp(0, 30);
  return decimals > 0 ? '$integer.${'0' * decimals}' : integer;
}

/// The built-in id for [code] when Excel already knows it, else null.
int? builtInIdFor(String code) {
  const reusable = [0, 1, 2, 3, 4, 9, 10, 49];
  for (final id in reusable) {
    if (builtInFormatCodes[id] == code) return id;
  }
  return null;
}
