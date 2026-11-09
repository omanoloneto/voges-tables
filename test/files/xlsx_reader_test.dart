import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/files/spreadsheet_file_exception.dart';
import 'package:voges_tables/files/xlsx/xlsx_reader.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_style.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';

import 'xlsx_fixtures.dart';

Cell cellAt(Sheet sheet, String a1) => sheet.cellAt(CellAddress.tryParse(a1)!);

Matcher throwsProblem(SpreadsheetProblem problem) => throwsA(
  isA<SpreadsheetFileException>().having((e) => e.problem, 'problem', problem),
);

void main() {
  group('Excel workbook', () {
    late Workbook workbook;
    late Sheet sheet;

    setUpAll(() {
      workbook = readXlsx(excelWorkbook());
      sheet = workbook.sheets.first;
    });

    test('lists worksheets in workbook order and skips chart sheets', () {
      expect(workbook.sheets.map((s) => s.name), ['Resumo & Totais', 'Dados']);
      expect(cellAt(workbook.sheets[1], 'B1').constant, const NumberValue(2.5));
    });

    test('reads every constant type', () {
      expect(cellAt(sheet, 'A1').constant, const TextValue('Produto'));
      expect(cellAt(sheet, 'A1').input, isEmpty);
      expect(cellAt(sheet, 'B1').constant, const NumberValue(1234.5));
      expect(cellAt(sheet, 'C1').constant, const BoolValue(true));
      expect(cellAt(sheet, 'D1').constant, const ErrorValue(CellError.div0));
      expect(cellAt(sheet, 'E1').constant, const TextValue('Inline rich'));
      expect(cellAt(sheet, 'A6').constant, const TextValue('formula-less str'));
      expect(cellAt(sheet, 'B6').constant, const NumberValue(45293.5));
      expect(cellAt(sheet, 'C6').constant, const TextValue('#SPILL!'));
    });

    test('flattens rich text without phonetic guides and keeps spaces', () {
      expect(cellAt(sheet, 'G1').constant, const TextValue('Rich text'));
      expect(
        cellAt(sheet, 'H1').constant,
        const TextValue('  line one\r\nline two '),
      );
    });

    test('expands shared formulas by shifting relative references', () {
      expect(
        cellAt(sheet, 'A2').input,
        "=B2*\$C\$1+SUM(B\$2:B2)+'Other Sheet'!A2",
      );
      expect(
        cellAt(sheet, 'A3').input,
        "=B3*\$C\$1+SUM(B\$2:B3)+'Other Sheet'!A3",
      );
      expect(
        cellAt(sheet, 'A4').input,
        "=B4*\$C\$1+SUM(B\$2:B4)+'Other Sheet'!A4",
      );
      expect(cellAt(sheet, 'A3').constant, const EmptyValue());
    });

    test('keeps the array formula on its master and the other values', () {
      expect(cellAt(sheet, 'F1').input, '=SUM(B1:B3*C1:C3)');
      expect(cellAt(sheet, 'F2').constant, const NumberValue(2));
      expect(cellAt(sheet, 'F2').input, isEmpty);
    });

    test('drops the _xlfn prefix of newer functions', () {
      expect(cellAt(sheet, 'G2').input, '=IFS(B2>1,"big",TRUE,"small")');
    });

    test('places cells without a reference after the previous one', () {
      expect(cellAt(sheet, 'B4').constant, const NumberValue(11));
      expect(cellAt(sheet, 'C4').constant, const TextValue('Produto'));
    });

    test('maps built-in and custom number formats', () {
      NumberFormat format(String a1) => cellAt(sheet, a1).style.format;
      expect(format('A1'), NumberFormat.general);
      expect(format('B1'), const NumberFormat(NumberKind.currency));
      expect(format('B2'), const NumberFormat(NumberKind.dateTime));
      expect(format('C2'), const NumberFormat(NumberKind.percent, decimals: 0));
      expect(format('D2'), const NumberFormat(NumberKind.percent));
      expect(format('E2'), const NumberFormat(NumberKind.currency));
      expect(
        format('C3'),
        const NumberFormat(NumberKind.number, decimals: 3, thousands: false),
      );
      expect(format('D3'), const NumberFormat(NumberKind.number, decimals: 0));
      expect(format('E3'), const NumberFormat(NumberKind.time));
      expect(format('G3'), const NumberFormat(NumberKind.text));
      expect(format('H3'), const NumberFormat(NumberKind.date));
      expect(
        workbook.sheets[1].cellAt(const CellAddress(0, 1)).style.format,
        const NumberFormat(NumberKind.date),
      );
    });

    test('maps fonts, fills, alignment and borders', () {
      expect(
        cellAt(sheet, 'G1').style,
        const CellStyle(
          bold: true,
          fillColor: 0xFFFFFF00,
          horizontal: HorizontalAlign.center,
          vertical: VerticalAlign.middle,
          wrap: true,
          borders: CellBorders.all,
        ),
      );
      expect(
        cellAt(sheet, 'G2').style,
        const CellStyle(
          italic: true,
          underline: true,
          strike: true,
          fontSize: 14,
          textColor: 0xFFFF0000,
          horizontal: HorizontalAlign.right,
          vertical: VerticalAlign.top,
          borders: CellBorders(bottom: true),
        ),
      );
    });

    test('resolves theme colors from the theme part, with tint', () {
      final style = cellAt(sheet, 'B3').style;
      expect(style.bold, isFalse);
      expect(style.textColor, 0xFF123456);
      expect(style.fillColor, 0xFF808080);
    });

    test('keeps empty cells that carry a style only', () {
      expect(sheet.cells.containsKey(CellAddress.tryParse('H5')), isTrue);
      expect(cellAt(sheet, 'H5').style.bold, isTrue);
      expect(sheet.cells.containsKey(CellAddress.tryParse('G5')), isFalse);
      expect(cellAt(sheet, 'G3').style.format.kind, NumberKind.text);
    });

    test('reads custom widths, heights and the frozen pane', () {
      expect(sheet.columnWidths, {0: 145.0, 2: 64.0, 3: 64.0, 4: 64.0});
      expect(sheet.rowHeights, {0: 40.0, 4: 30.0});
      expect(sheet.frozenColumns, 1);
      expect(sheet.frozenRows, 2);
    });
  });

  group('LibreOffice workbook', () {
    late Sheet sheet;

    setUpAll(() => sheet = readXlsx(libreOfficeWorkbook()).sheets.single);

    test('treats the default font as plain', () {
      expect(cellAt(sheet, 'A2').style, CellStyle.plain);
      expect(cellAt(sheet, 'A1').style, const CellStyle(bold: true));
    });

    test('reads inline strings, true booleans and formulas', () {
      expect(sheet.name, 'Planilha1');
      expect(cellAt(sheet, 'A2').constant, const TextValue('Café'));
      expect(cellAt(sheet, 'C2').constant, const BoolValue(true));
      expect(cellAt(sheet, 'D2').input, '=B2*2');
      expect(
        cellAt(sheet, 'B2').style.format,
        const NumberFormat(NumberKind.currency),
      );
      expect(sheet.cells.containsKey(CellAddress.tryParse('A3')), isFalse);
    });

    test('ignores default widths and heights', () {
      expect(sheet.columnWidths, {0: 179.0});
      expect(sheet.rowHeights, {2: 54.0});
      expect(sheet.frozenRows, 1);
      expect(sheet.frozenColumns, 0);
    });
  });

  group('other producers', () {
    test('reads prefixed elements', () {
      final sheet = readXlsx(prefixedWorkbook()).sheets.single;
      expect(sheet.name, 'Sheet A');
      expect(cellAt(sheet, 'A1').constant, const TextValue('hello'));
      expect(cellAt(sheet, 'B1').constant, const NumberValue(0));
      expect(cellAt(sheet, 'C1').input, '=A1&"!"');
    });

    test('moves 1904 dates to the 1900 system', () {
      final sheet = readXlsx(prefixedWorkbook(date1904: true)).sheets.single;
      expect(cellAt(sheet, 'B1').constant, const NumberValue(1462));
    });
  });

  group('files it cannot read', () {
    Uint8List compound(List<int> body) => Uint8List.fromList([
      0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, //
      ...List.filled(64, 0),
      ...body,
    ]);

    test('random bytes', () {
      expect(
        () => readXlsx(Uint8List.fromList('a,b,c'.codeUnits)),
        throwsProblem(SpreadsheetProblem.notSpreadsheet),
      );
    });

    test('legacy .xls', () {
      expect(
        () => readXlsx(compound('Workbook'.codeUnits)),
        throwsProblem(SpreadsheetProblem.legacyExcel),
      );
    });

    test('password-protected workbook', () {
      final name = [
        for (final unit in 'EncryptedPackage'.codeUnits) ...[unit, 0],
      ];
      expect(
        () => readXlsx(compound(name)),
        throwsProblem(SpreadsheetProblem.encrypted),
      );
    });

    test('.xlsb', () {
      final bytes = zipParts({
        '_rels/.rels':
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.bin"/>'
            '</Relationships>',
        'xl/workbook.bin': 'binary',
      });
      expect(
        () => readXlsx(bytes),
        throwsProblem(SpreadsheetProblem.binaryExcel),
      );
    });

    test('.ods', () {
      final bytes = zipParts({
        'mimetype': 'application/vnd.oasis.opendocument.spreadsheet',
        'content.xml': '<office:document-content/>',
      });
      expect(
        () => readXlsx(bytes),
        throwsProblem(SpreadsheetProblem.openDocument),
      );
    });

    test('a zip without a workbook', () {
      expect(
        () => readXlsx(zipParts({'readme.txt': 'hello'})),
        throwsProblem(SpreadsheetProblem.notSpreadsheet),
      );
    });

    test('a damaged sheet', () {
      Uint8List withSheet(String xml) => zipParts({
        'xl/workbook.xml':
            '<workbook xmlns:r="r"><sheets><sheet name="A" r:id="rId1"/></sheets></workbook>',
        'xl/_rels/workbook.xml.rels':
            '<Relationships><Relationship Id="rId1" Type="x/worksheet" Target="s.xml"/></Relationships>',
        'xl/s.xml': xml,
      });
      expect(
        () => readXlsx(withSheet('<worksheet><sheetData><row><c r="A1" <v>')),
        throwsProblem(SpreadsheetProblem.notSpreadsheet),
      );
      final truncated = readXlsx(
        withSheet(
          '<worksheet><sheetData><row><c r="B2"><v>7</v></c><c r="C2"><v>',
        ),
      );
      expect(
        cellAt(truncated.sheets.single, 'B2').constant,
        const NumberValue(7),
      );
    });
  });
}
