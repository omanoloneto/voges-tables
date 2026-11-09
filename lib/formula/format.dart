import '../sheet/cell_style.dart';
import '../sheet/cell_value.dart';
import 'dates.dart';
import 'locale.dart';
import 'numbers.dart';

/// The text drawn in a cell for [value] shown with [format].
String formatValue(
  CellValue value,
  NumberFormat format,
  FormulaLocale locale,
) => switch (value) {
  EmptyValue() => '',
  TextValue(:final value) => value,
  BoolValue(:final value) => locale.booleanWord(value),
  ErrorValue(:final error) => error.code,
  NumberValue(:final value) => _number(value, format, locale),
};

String _number(double value, NumberFormat format, FormulaLocale locale) {
  final decimals = format.decimals.clamp(0, 30);
  switch (format.kind) {
    case NumberKind.general || NumberKind.text:
      return generalNumber(value, locale);
    case NumberKind.number:
      return fixedNumber(value, decimals, locale, thousands: format.thousands);
    case NumberKind.currency:
      return _currency(value, decimals, format.thousands, locale);
    case NumberKind.percent:
      return '${fixedNumber(value * 100, decimals, locale, thousands: format.thousands)}%';
    case NumberKind.date:
      return _validDate(value) ? formatDate(value, locale) : _overflow;
    case NumberKind.time:
      return value >= 0 ? formatTime(value) : _overflow;
    case NumberKind.dateTime:
      return _validDate(value)
          ? '${formatDate(value, locale)} ${formatTime(value)}'
          : _overflow;
  }
}

const _overflow = '#####';

bool _validDate(double value) => value >= 0 && value < maxDateSerial + 1;

String _currency(
  double value,
  int decimals,
  bool thousands,
  FormulaLocale locale,
) {
  final amount = fixedNumber(
    value.abs(),
    decimals,
    locale,
    thousands: thousands,
  );
  final negative = value < 0 && roundHalfAwayFromZero(value, decimals) != 0;
  final sign = negative ? '-' : '';
  return switch (locale) {
    FormulaLocale.en => '$sign${locale.currencySymbol}$amount',
    FormulaLocale.pt => '$sign${locale.currencySymbol} $amount',
    FormulaLocale.es => '$sign$amount ${locale.currencySymbol}',
  };
}

/// `05/11/2026` in pt and es, `11/5/2026` in en.
String formatDate(double serial, FormulaLocale locale) {
  final date = serialToYmd(serial.floor());
  if (!locale.dayFirst) return '${date.month}/${date.day}/${date.year}';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// `13:45`, or `13:45:30` when there are seconds.
String formatTime(double serial) {
  final time = serialToTime(serial);
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  if (time.second == 0) return '$hour:$minute';
  return '$hour:$minute:${time.second.toString().padLeft(2, '0')}';
}
