import '../sheet/cell_value.dart';
import 'locale.dart';
import 'numbers.dart';
import 'operand.dart';
import 'recognize.dart';

/// Excel's implicit conversions. Each throws [FormulaError] for an error
/// value or a text that cannot be converted.
double toNumber(CellValue value, FormulaLocale locale) => switch (value) {
  NumberValue(:final value) => value,
  BoolValue(:final value) => value ? 1 : 0,
  EmptyValue() => 0,
  TextValue(:final value) => textToNumber(value, locale) ?? (throw valueError),
  ErrorValue(:final error) => throw FormulaError(error),
};

String toText(CellValue value, FormulaLocale locale) => switch (value) {
  NumberValue(:final value) => numberToText(value, locale),
  BoolValue(:final value) => locale.booleanWord(value),
  EmptyValue() => '',
  TextValue(:final value) => value,
  ErrorValue(:final error) => throw FormulaError(error),
};

bool toBool(CellValue value, FormulaLocale locale) => switch (value) {
  NumberValue(:final value) => value != 0,
  BoolValue(:final value) => value,
  EmptyValue() => false,
  TextValue(:final value) => _textToBool(value, locale) ?? (throw valueError),
  ErrorValue(:final error) => throw FormulaError(error),
};

bool? _textToBool(String text, FormulaLocale locale) {
  final upper = text.trim().toUpperCase();
  if (upper == 'TRUE' || upper == locale.trueWord) return true;
  if (upper == 'FALSE' || upper == locale.falseWord) return false;
  return null;
}

/// A finite result, or `#NUM!`; -0 becomes 0.
Scalar numberResult(double value) {
  if (!value.isFinite) throw numError;
  return Scalar(NumberValue(value == 0 ? 0 : value));
}
