/// Why a file could not be opened, so the interface can say it plainly.
enum SpreadsheetProblem {
  /// Not a spreadsheet, or damaged beyond reading.
  notSpreadsheet,

  /// A password-protected workbook.
  encrypted,

  /// The old binary Excel format (`.xls`, Excel 97–2003).
  legacyExcel,

  /// The binary Excel workbook (`.xlsb`).
  binaryExcel,

  /// An OpenDocument spreadsheet (`.ods`).
  openDocument,

  /// Any other extension.
  unsupportedFormat,

  /// Expands to more data than is safe to hold in memory.
  tooLarge,
}

class SpreadsheetFileException extends FormatException {
  SpreadsheetFileException(this.problem, [String? detail])
    : super(detail ?? problem.name);

  final SpreadsheetProblem problem;

  @override
  String toString() => 'SpreadsheetFileException(${problem.name}): $message';
}
