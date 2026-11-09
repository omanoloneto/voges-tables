import '../sheet/cell_style.dart';
import '../sheet/cell_value.dart';
import '../sheet/workbook.dart';
import 'dates.dart';
import 'format.dart';
import 'locale.dart';
import 'numbers.dart';
import 'recognize.dart';
import 'translate.dart';

/// What typing a text into a cell produces.
class ParsedInput {
  const ParsedInput({
    this.input = '',
    this.constant = const EmptyValue(),
    this.format,
  });

  /// The canonical formula, or empty for a constant.
  final String input;
  final CellValue constant;

  /// The format the typed text suggests, such as percent for `10%`.
  final NumberFormat? format;

  bool get isFormula => input.isNotEmpty;

  /// [previous] with the new content; the suggested format only replaces a
  /// General one, as in Excel.
  Cell applyTo(Cell previous) {
    final suggested = format;
    final keep =
        suggested == null || previous.style.format.kind != NumberKind.general;
    return Cell(
      input: input,
      constant: constant,
      style: keep ? previous.style : previous.style.copyWith(format: suggested),
    );
  }
}

ParsedInput parseInput(String text, FormulaLocale locale) {
  if (text.isEmpty) return const ParsedInput();
  if (text.startsWith("'")) {
    return ParsedInput(constant: TextValue(text.substring(1)));
  }
  if (text.startsWith('=') && text.length > 1) {
    return ParsedInput(input: toCanonical(text, locale));
  }
  final recognized = recognizeConstant(text, locale);
  if (recognized == null) return ParsedInput(constant: TextValue(text));
  return ParsedInput(constant: recognized.value, format: recognized.format);
}

/// The text the editor shows for [cell], ready to be typed back.
String editText(Cell cell, FormulaLocale locale) {
  if (cell.isFormula) return toDisplay(cell.input, locale);
  return switch (cell.constant) {
    EmptyValue() => '',
    TextValue(:final value) => _textToEdit(value, locale),
    BoolValue(:final value) => locale.booleanWord(value),
    ErrorValue(:final error) => error.code,
    NumberValue(:final value) => _numberToEdit(
      value,
      cell.style.format.kind,
      locale,
    ),
  };
}

String _textToEdit(String text, FormulaLocale locale) {
  final parsed = parseInput(text, locale);
  final same = !parsed.isFormula && parsed.constant == TextValue(text);
  return same ? text : "'$text";
}

String _numberToEdit(double value, NumberKind kind, FormulaLocale locale) {
  final isDate = value >= 0 && value < maxDateSerial + 1;
  final hasTime = value != value.floorToDouble();
  switch (kind) {
    case NumberKind.date || NumberKind.dateTime when isDate:
      final date = formatDate(value, locale);
      return hasTime ? '$date ${formatTime(value)}' : date;
    case NumberKind.time when isDate:
      return value < 1
          ? formatTime(value)
          : '${formatDate(value, locale)} ${formatTime(value)}';
    case NumberKind.percent:
      return '${numberToText(value * 100, locale)}%';
    default:
      return numberToText(value, locale);
  }
}
