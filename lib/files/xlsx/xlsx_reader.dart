import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../sheet/workbook.dart';
import '../spreadsheet_file_exception.dart';
import 'xlsx_colors.dart';
import 'xlsx_package.dart';
import 'xlsx_shared_strings.dart';
import 'xlsx_sheet_reader.dart';
import 'xlsx_styles_reader.dart';
import 'xlsx_xml.dart';

/// Reads every worksheet of an `.xlsx` (or `.xlsm`) in workbook order.
///
/// Throws [SpreadsheetFileException] for anything that is not a readable
/// OOXML workbook: `.xls`, `.xlsb`, `.ods`, encrypted or damaged files.
Workbook readXlsx(Uint8List bytes) {
  final package = XlsxPackage.decode(bytes);
  try {
    return _XlsxReader(package).read();
  } on SpreadsheetFileException {
    rethrow;
  } on Object catch (error) {
    throw SpreadsheetFileException(
      SpreadsheetProblem.notSpreadsheet,
      error.toString(),
    );
  }
}

class _XlsxReader {
  _XlsxReader(this.package);

  final XlsxPackage package;

  Workbook read() {
    final workbookPath = _workbookPath();
    if (workbookPath.endsWith('.bin')) {
      throw SpreadsheetFileException(SpreadsheetProblem.binaryExcel);
    }
    final workbook = package.xml(workbookPath)?.rootElement;
    if (workbook == null || workbook.name.local != 'workbook') {
      throw SpreadsheetFileException(SpreadsheetProblem.notSpreadsheet);
    }
    final relationships = {
      for (final relationship in package.relationships(workbookPath))
        relationship.id: relationship,
    };
    String? partOf(String type) {
      for (final relationship in relationships.values) {
        if (relationship.hasType(type)) {
          return XlsxPackage.resolve(workbookPath, relationship.target);
        }
      }
      return null;
    }

    final themePath = partOf('theme');
    final stylesPath = partOf('styles');
    final stringsPath = partOf('sharedStrings');
    final sheetReader = XlsxSheetReader(
      sharedStrings: readSharedStrings(
        stringsPath == null ? null : package.text(stringsPath),
      ),
      styles: readCellStyles(
        stylesPath == null ? null : package.xml(stylesPath),
        theme: XlsxColors.themeFrom(
          themePath == null ? null : package.xml(themePath),
        ),
      ),
      date1904: _uses1904(workbook),
    );

    final sheets = <Sheet>[];
    final list = child(workbook, 'sheets');
    for (final entry
        in list == null ? <XmlElement>[] : children(list, 'sheet')) {
      final relationship = relationships[relationshipId(entry)];
      if (relationship == null || !relationship.hasType('worksheet')) continue;
      final sheet = Sheet(
        entry.getAttribute('name') ?? 'Sheet${sheets.length + 1}',
      );
      final source = package.text(
        XlsxPackage.resolve(workbookPath, relationship.target),
      );
      if (source != null) sheetReader.read(source, sheet);
      sheets.add(sheet);
    }
    if (sheets.isEmpty) {
      throw SpreadsheetFileException(
        SpreadsheetProblem.notSpreadsheet,
        'The workbook has no worksheets',
      );
    }
    return Workbook(sheets);
  }

  String _workbookPath() {
    for (final relationship in package.relationships('')) {
      if (relationship.hasType('officeDocument')) {
        return XlsxPackage.resolve('', relationship.target);
      }
    }
    if (package.has('xl/workbook.bin')) {
      throw SpreadsheetFileException(SpreadsheetProblem.binaryExcel);
    }
    if (package.has('content.xml') && package.has('mimetype')) {
      throw SpreadsheetFileException(SpreadsheetProblem.openDocument);
    }
    return 'xl/workbook.xml';
  }

  static bool _uses1904(XmlElement workbook) {
    final properties = child(workbook, 'workbookPr');
    return properties != null && onOffAttribute(properties, 'date1904');
  }
}
