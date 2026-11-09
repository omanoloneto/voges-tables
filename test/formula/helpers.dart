import 'package:voges_tables/formula/calculator.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';

CellAddress at(String a1) => CellAddress.tryParse(a1)!;

/// Text starting with `=` is a canonical formula; numbers, booleans and
/// other strings are constants.
Cell cellOf(Object content) => switch (content) {
  final String text when text.startsWith('=') => Cell(input: text),
  final String text => Cell(constant: TextValue(text)),
  final num number => Cell(constant: NumberValue(number.toDouble())),
  final bool value => Cell(constant: BoolValue(value)),
  final CellValue value => Cell(constant: value),
  _ => throw ArgumentError(content),
};

Workbook workbookOf(List<Map<String, Object>> sheets, {List<String>? names}) {
  final workbook = Workbook([
    for (var i = 0; i < sheets.length; i++) Sheet(names?[i] ?? 'Sheet${i + 1}'),
  ]);
  for (var i = 0; i < sheets.length; i++) {
    sheets[i].forEach((a1, content) {
      workbook.sheets[i].setCell(at(a1), cellOf(content));
    });
  }
  return workbook;
}

Calculator calculatorOf(
  Map<String, Object> cells, {
  FormulaLocale locale = FormulaLocale.en,
  DateTime Function()? clock,
}) => Calculator(workbookOf([cells]), locale: locale, clock: clock);

/// Evaluates [formula] in cell `Z100` of a sheet holding [cells].
CellValue evaluate(
  String formula, [
  Map<String, Object> cells = const {},
  FormulaLocale locale = FormulaLocale.en,
]) {
  final calculator = calculatorOf(
    {...cells, 'Z100': formula},
    locale: locale,
    clock: () => DateTime(2026, 11, 9, 14, 30, 15),
  );
  return calculator.valueAt(0, at('Z100'));
}

CellValue n(num value) => NumberValue(value.toDouble());
CellValue t(String value) => TextValue(value);
CellValue b(bool value) => BoolValue(value);
CellValue e(CellError error) => ErrorValue(error);
