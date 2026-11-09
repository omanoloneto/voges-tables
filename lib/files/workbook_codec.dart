import 'package:flutter/foundation.dart';

import '../formula/input.dart';
import '../formula/locale.dart';
import '../sheet/workbook.dart';
import '../workbook/workbook_controller.dart';
import 'spreadsheet_file_exception.dart';
import 'spreadsheet_files.dart';
import 'spreadsheet_format.dart';

export 'spreadsheet_file_exception.dart'
    show SpreadsheetFileException, SpreadsheetProblem;

/// Reads an opened file; text files are typed in cell by cell, as if the
/// user had typed each value in the interface language.
Future<Workbook> decodeWorkbook(
  OpenedFile file, {
  required FormulaLocale locale,
  required String sheetName,
}) async {
  final format = SpreadsheetFormat.fromPath(file.name);
  return readSpreadsheet(
    file.bytes,
    format,
    sheetName: sheetName,
    parse: (raw) => parseInput(raw, locale).applyTo(const Cell()),
  );
}

/// CSV of the Portuguese and Spanish Excel uses `;`, because `,` is the
/// decimal separator there.
Uint8List encodeWorkbook(
  WorkbookController controller,
  SaveFormat format, {
  required FormulaLocale locale,
}) => writeSpreadsheet(
  controller.workbook,
  format == SaveFormat.xlsx ? SpreadsheetFormat.xlsx : SpreadsheetFormat.csv,
  sheetIndex: controller.activeSheet,
  valueOf: (sheet, address) => controller.valueAt(address, sheet),
  displayOf: (sheet, address) => controller.displayAt(address, sheet),
  currencySymbol: switch (locale) {
    FormulaLocale.pt => r'R$',
    FormulaLocale.es => '€',
    _ => r'$',
  },
  csvDelimiter: locale == FormulaLocale.en ? ',' : ';',
);

/// Problems that mean "another kind of file", not a broken one.
bool isUnsupported(SpreadsheetFileException error) => switch (error.problem) {
  SpreadsheetProblem.legacyExcel ||
  SpreadsheetProblem.binaryExcel ||
  SpreadsheetProblem.openDocument ||
  SpreadsheetProblem.unsupportedFormat ||
  SpreadsheetProblem.encrypted => true,
  _ => false,
};
