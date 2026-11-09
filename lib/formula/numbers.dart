import 'dart:math' as math;

import 'locale.dart';

/// Rounds half away from zero like Excel, ignoring binary noise such as
/// 2.675 being stored as 2.67499999.
double roundHalfAwayFromZero(double value, int digits) =>
    _roundWith(value, digits, (scaled) => scaled.roundToDouble());

double roundAwayFromZero(double value, int digits) =>
    _roundWith(value, digits, (scaled) => scaled.ceilToDouble());

double roundTowardZero(double value, int digits) =>
    _roundWith(value, digits, (scaled) => scaled.floorToDouble());

double _roundWith(double value, int digits, double Function(double) round) {
  if (!value.isFinite || value == 0) return value;
  final factor = math.pow(10, digits).toDouble();
  final scaled = value.abs() * factor;
  if (!scaled.isFinite || scaled > 1e15) return value;
  final clean = double.parse(scaled.toStringAsPrecision(15));
  final rounded = round(clean) / factor;
  return value < 0 ? -rounded : rounded;
}

/// A number as `&`, CONCAT or the cell editor write it: up to 15 significant
/// digits, no thousands separator.
String numberToText(double value, FormulaLocale locale) {
  if (value == 0) return '0';
  final (digits, exponent) = _decompose(value.abs(), 15);
  final body = exponent >= 15 || exponent < -9
      ? _scientific(digits, exponent)
      : _positional(digits, exponent);
  return _signed(value, body.replaceAll('.', locale.decimalSeparator));
}

/// Excel's General format in a default-width column: at most 11 characters,
/// scientific notation when the number does not fit.
String generalNumber(double value, FormulaLocale locale) {
  if (value == 0) return '0';
  final abs = value.abs();
  final (_, exponent) = _decompose(abs, 15);
  String? body;
  if (exponent < 11 && exponent > -5) {
    final integerDigits = exponent >= 0 ? exponent + 1 : 1;
    final decimals = math.max(0, math.min(10 - integerDigits, 14 - exponent));
    final fixed = _trimZeros(
      roundHalfAwayFromZero(abs, decimals).toStringAsFixed(decimals),
    );
    if (fixed.split('.').first.length <= 11) body = fixed;
  }
  if (body == null) {
    final (digits, sciExponent) = _decompose(abs, 6);
    body = _scientific(digits, sciExponent);
  }
  return _signed(value, body.replaceAll('.', locale.decimalSeparator));
}

/// [value] with a fixed number of decimals, optionally grouping thousands.
String fixedNumber(
  double value,
  int decimals,
  FormulaLocale locale, {
  bool thousands = false,
}) {
  final rounded = roundHalfAwayFromZero(value, decimals);
  if (rounded.abs() >= 1e21) return generalNumber(value, locale);
  final text = rounded.abs().toStringAsFixed(decimals);
  final dot = text.indexOf('.');
  var integer = dot < 0 ? text : text.substring(0, dot);
  final fraction = dot < 0 ? '' : text.substring(dot + 1);
  if (thousands) integer = groupThousands(integer, locale.thousandsSeparator);
  final body = fraction.isEmpty
      ? integer
      : '$integer${locale.decimalSeparator}$fraction';
  return _signed(rounded, body);
}

String groupThousands(String digits, String separator) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _signed(double value, String body) =>
    value < 0 && RegExp('[1-9]').hasMatch(body) ? '-$body' : body;

String _trimZeros(String fixed) {
  if (!fixed.contains('.')) return fixed;
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Significant digits (no trailing zeros) and decimal exponent of [abs].
(String, int) _decompose(double abs, int precision) {
  final text = abs.toStringAsExponential(precision - 1);
  final e = text.indexOf('e');
  var digits = text.substring(0, e).replaceAll('.', '');
  digits = digits.replaceFirst(RegExp(r'0+$'), '');
  return (digits.isEmpty ? '0' : digits, int.parse(text.substring(e + 1)));
}

String _positional(String digits, int exponent) {
  if (exponent < 0) return '0.${'0' * (-exponent - 1)}$digits';
  if (digits.length <= exponent + 1) return digits.padRight(exponent + 1, '0');
  return '${digits.substring(0, exponent + 1)}.${digits.substring(exponent + 1)}';
}

String _scientific(String digits, int exponent) {
  final mantissa = digits.length == 1
      ? digits
      : '${digits[0]}.${digits.substring(1)}';
  final sign = exponent < 0 ? '-' : '+';
  return '${mantissa}E$sign${exponent.abs().toString().padLeft(2, '0')}';
}
