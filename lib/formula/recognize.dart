import '../sheet/cell_style.dart';
import '../sheet/cell_value.dart';
import 'dates.dart';
import 'locale.dart';

/// A constant read from typed text, with the format it suggests.
class Recognized {
  const Recognized(this.value, [this.format]);
  final CellValue value;
  final NumberFormat? format;
}

/// Booleans, error codes, numbers, percentages, currency, dates and times
/// typed in [locale]; null for plain text.
Recognized? recognizeConstant(String text, FormulaLocale locale) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final upper = trimmed.toUpperCase();
  if (upper == locale.trueWord) return const Recognized(BoolValue(true));
  if (upper == locale.falseWord) return const Recognized(BoolValue(false));
  final error = CellError.fromCode(upper);
  if (error != null) return Recognized(ErrorValue(error));
  return recognizeNumeric(trimmed, locale);
}

/// The numeric readings of [recognizeConstant], also used to turn text into
/// numbers inside formulas.
Recognized? recognizeNumeric(String text, FormulaLocale locale) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return _number(trimmed, locale) ??
      _percent(trimmed, locale) ??
      _currency(trimmed, locale) ??
      _dateTime(trimmed, locale) ??
      _timeOnly(trimmed);
}

double? textToNumber(String text, FormulaLocale locale) {
  final value = recognizeNumeric(text, locale)?.value;
  return value is NumberValue ? value.value : null;
}

typedef _Plain = ({double value, int decimals, bool grouped});

final _plainPatterns = <(FormulaLocale, bool), RegExp>{};

_Plain? _parsePlain(String text, FormulaLocale locale, {bool exponent = true}) {
  final pattern = _plainPatterns.putIfAbsent((locale, exponent), () {
    final dec = RegExp.escape(locale.decimalSeparator);
    final th = RegExp.escape(locale.thousandsSeparator);
    final exp = exponent ? r'(?:[eE]([+-]?\d+))?' : '()';
    return RegExp('^([+-]?)(\\d{1,3}(?:$th\\d{3})+|\\d*)(?:$dec(\\d*))?$exp\$');
  });
  final match = pattern.firstMatch(text);
  if (match == null) return null;
  final integer = match.group(2)!;
  final fraction = match.group(3) ?? '';
  if (integer.isEmpty && fraction.isEmpty) return null;
  final grouped = integer.contains(locale.thousandsSeparator);
  final digits = integer.replaceAll(locale.thousandsSeparator, '');
  final power = match.group(4);
  final source =
      '${match.group(1)}${digits.isEmpty ? '0' : digits}.${fraction.isEmpty ? '0' : fraction}'
      '${power == null || power.isEmpty ? '' : 'e$power'}';
  final value = double.tryParse(source);
  if (value == null || !value.isFinite) return null;
  return (value: value, decimals: fraction.length, grouped: grouped);
}

Recognized? _number(String text, FormulaLocale locale) {
  final plain = _parsePlain(text, locale);
  if (plain == null) return null;
  final format = plain.grouped
      ? NumberFormat(NumberKind.number, decimals: plain.decimals > 0 ? 2 : 0)
      : null;
  return Recognized(NumberValue(plain.value), format);
}

Recognized? _percent(String text, FormulaLocale locale) {
  if (!text.endsWith('%')) return null;
  final plain = _parsePlain(
    text.substring(0, text.length - 1).trimRight(),
    locale,
    exponent: false,
  );
  if (plain == null) return null;
  return Recognized(
    NumberValue(plain.value / 100),
    NumberFormat(NumberKind.percent, decimals: plain.decimals > 0 ? 2 : 0),
  );
}

Recognized? _currency(String text, FormulaLocale locale) {
  final symbol = locale.currencySymbol.toUpperCase();
  var rest = text;
  var negative = false;
  if (rest.startsWith('-')) {
    negative = true;
    rest = rest.substring(1).trimLeft();
  }
  if (rest.toUpperCase().startsWith(symbol)) {
    rest = rest.substring(symbol.length).trim();
  } else if (rest.toUpperCase().endsWith(symbol)) {
    rest = rest.substring(0, rest.length - symbol.length).trim();
  } else {
    return null;
  }
  if (!negative && rest.startsWith('-')) {
    negative = true;
    rest = rest.substring(1);
  }
  if (rest.startsWith('+') || rest.startsWith('-')) return null;
  final plain = _parsePlain(rest, locale, exponent: false);
  if (plain == null) return null;
  return Recognized(
    NumberValue(negative ? -plain.value : plain.value),
    NumberFormat(NumberKind.currency, decimals: plain.decimals > 0 ? 2 : 0),
  );
}

final _datePattern = RegExp(r'^(\d{1,4})[/-](\d{1,2})(?:[/-](\d{1,4}))?$');
final _timePattern = RegExp(
  r'^(\d{1,2}):(\d{1,2})(?::(\d{1,2})(?:[.,](\d+))?)?(?:\s*([AaPp])\.?[Mm]?\.?)?$',
);

Recognized? _dateTime(String text, FormulaLocale locale) {
  final space = text.indexOf(' ');
  final datePart = space < 0 ? text : text.substring(0, space);
  final timePart = space < 0 ? null : text.substring(space + 1).trim();
  final date = _date(datePart, locale);
  if (date == null) return null;
  if (timePart == null) {
    return Recognized(
      NumberValue(date.toDouble()),
      const NumberFormat(NumberKind.date),
    );
  }
  final time = _time(timePart);
  if (time == null) return null;
  return Recognized(
    NumberValue(date + time),
    const NumberFormat(NumberKind.dateTime),
  );
}

int? _date(String text, FormulaLocale locale) {
  final match = _datePattern.firstMatch(text);
  if (match == null) return null;
  final a = match.group(1)!, b = match.group(2)!, c = match.group(3);
  int year, month, day;
  if (a.length == 4) {
    if (c == null) return null;
    (year, month, day) = (int.parse(a), int.parse(b), int.parse(c));
  } else {
    if (a.length > 2) return null;
    final first = int.parse(a), second = int.parse(b);
    (day, month) = locale.dayFirst ? (first, second) : (second, first);
    if (c == null) {
      year = DateTime.now().year;
    } else if (c.length == 2) {
      final short = int.parse(c);
      year = short < 30 ? 2000 + short : 1900 + short;
    } else if (c.length == 4) {
      year = int.parse(c);
    } else {
      return null;
    }
  }
  if (year < 1900 || year > 9999 || month < 1 || month > 12 || day < 1) {
    return null;
  }
  final leapDay1900 = year == 1900 && month == 2 && day == 29;
  if (!leapDay1900 && day > daysInMonth(year, month)) return null;
  return ymdToSerial(year, month, day);
}

Recognized? _timeOnly(String text) {
  final time = _time(text);
  if (time == null) return null;
  return Recognized(NumberValue(time), const NumberFormat(NumberKind.time));
}

double? _time(String text) {
  final match = _timePattern.firstMatch(text);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final second = int.parse(match.group(3) ?? '0');
  final fraction = match.group(4);
  final meridiem = match.group(5)?.toUpperCase();
  if (minute > 59 || second > 59) return null;
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (meridiem == 'P' ? 12 : 0);
  } else if (hour > 23) {
    return null;
  }
  final seconds =
      hour * 3600 +
      minute * 60 +
      second +
      (fraction == null ? 0 : double.parse('0.$fraction'));
  return seconds / 86400;
}
