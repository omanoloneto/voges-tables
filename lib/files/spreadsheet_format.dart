import 'dart:typed_data';

import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';
import '../sheet/workbook.dart';
import 'csv/csv_encoding.dart';
import 'csv/csv_reader.dart';
import 'csv/csv_writer.dart';
import 'spreadsheet_file_exception.dart';
import 'xlsx/xlsx_reader.dart';
import 'xlsx/xlsx_writer.dart';

/// The file formats Voges Tables opens and saves, by extension.
enum SpreadsheetFormat {
  xlsx('xlsx', canSave: true),

  /// Opens like `.xlsx`, without the macros; saving goes to `.xlsx`.
  xlsm('xlsm', canSave: false),
  csv('csv', canSave: true),
  tsv('tsv', canSave: true),

  /// Excel's "Text" and "Unicode Text"; the delimiter is detected.
  txt('txt', canSave: false);

  const SpreadsheetFormat(this.extension, {required this.canSave});

  final String extension;
  final bool canSave;

  bool get isText => this == csv || this == tsv || this == txt;

  static List<String> get openExtensions => [
    for (final format in values) format.extension,
  ];

  static List<String> get saveExtensions => [
    for (final format in values)
      if (format.canSave) format.extension,
  ];

  /// Throws [SpreadsheetFileException] for extensions it cannot open, with
  /// a problem that names the format when it is a known one.
  static SpreadsheetFormat fromPath(String path) {
    final dot = path.lastIndexOf('.');
    final extension = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    for (final format in values) {
      if (format.extension == extension) return format;
    }
    throw SpreadsheetFileException(switch (extension) {
      'xls' || 'xlt' => SpreadsheetProblem.legacyExcel,
      'xlsb' => SpreadsheetProblem.binaryExcel,
      'ods' || 'fods' || 'ots' => SpreadsheetProblem.openDocument,
      _ => SpreadsheetProblem.unsupportedFormat,
    }, extension);
  }
}

/// Opens a file of [format]. A text file becomes one sheet named
/// [sheetName] whose fields go through [parse]; a workbook saved under a
/// `.csv` name is still read as the workbook it is.
Workbook readSpreadsheet(
  Uint8List bytes,
  SpreadsheetFormat format, {
  required String sheetName,
  required Cell Function(String raw) parse,
}) {
  if (!format.isText || _looksBinary(bytes)) return readXlsx(bytes);
  final sheet = readCsv(
    decodeCsv(bytes),
    sheetName: sheetName,
    parse: parse,
    delimiter: format == SpreadsheetFormat.tsv ? '\t' : null,
  );
  return Workbook([sheet]);
}

/// Saves [workbook] as [format]. A text format holds a single sheet, the one
/// at [sheetIndex], written as [displayOf] shows its cells; `.csv` uses
/// [csvDelimiter] (`;` suits locales with a decimal comma).
Uint8List writeSpreadsheet(
  Workbook workbook,
  SpreadsheetFormat format, {
  required int sheetIndex,
  required CellValue Function(int sheetIndex, CellAddress address) valueOf,
  required String Function(int sheetIndex, CellAddress address) displayOf,
  String currencySymbol = r'R$',
  String csvDelimiter = ',',
}) {
  if (!format.canSave) {
    throw SpreadsheetFileException(
      SpreadsheetProblem.unsupportedFormat,
      format.extension,
    );
  }
  if (!format.isText) {
    return writeXlsx(
      workbook,
      valueOf: valueOf,
      currencySymbol: currencySymbol,
    );
  }
  final text = writeCsv(
    workbook.sheets[sheetIndex],
    displayOf: (address) => displayOf(sheetIndex, address),
    delimiter: format == SpreadsheetFormat.tsv ? '\t' : csvDelimiter,
  );
  return encodeCsv(text);
}

bool _looksBinary(Uint8List bytes) =>
    bytes.length >= 4 &&
    ((bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 3 && bytes[3] == 4) ||
        (bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11));
