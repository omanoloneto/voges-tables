import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/files/spreadsheet_file_exception.dart';
import 'package:voges_tables/files/spreadsheet_format.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';

import 'xlsx_fixtures.dart';

Cell asText(String raw) => Cell(constant: TextValue(raw));

String display(Workbook workbook, int sheet, CellAddress address) =>
    switch (workbook.sheets[sheet].cellAt(address).constant) {
      TextValue(:final value) => value,
      NumberValue(:final value) => '$value',
      _ => '',
    };

void main() {
  group('fromPath', () {
    test('knows the formats it opens and saves', () {
      expect(
        SpreadsheetFormat.fromPath('/a/Plan.XLSX'),
        SpreadsheetFormat.xlsx,
      );
      expect(SpreadsheetFormat.fromPath('macros.xlsm'), SpreadsheetFormat.xlsm);
      expect(SpreadsheetFormat.fromPath('dados.csv'), SpreadsheetFormat.csv);
      expect(SpreadsheetFormat.fromPath('dados.tsv'), SpreadsheetFormat.tsv);
      expect(SpreadsheetFormat.fromPath('unicode.txt'), SpreadsheetFormat.txt);
      expect(SpreadsheetFormat.openExtensions, [
        'xlsx',
        'xlsm',
        'csv',
        'tsv',
        'txt',
      ]);
      expect(SpreadsheetFormat.saveExtensions, ['xlsx', 'csv', 'tsv']);
    });

    test('names the formats that are not supported yet', () {
      SpreadsheetProblem problem(String path) {
        try {
          SpreadsheetFormat.fromPath(path);
        } on SpreadsheetFileException catch (e) {
          return e.problem;
        }
        fail('$path should not open');
      }

      expect(problem('old.xls'), SpreadsheetProblem.legacyExcel);
      expect(problem('big.xlsb'), SpreadsheetProblem.binaryExcel);
      expect(problem('calc.ods'), SpreadsheetProblem.openDocument);
      expect(problem('notes.pdf'), SpreadsheetProblem.unsupportedFormat);
      expect(problem('no-extension'), SpreadsheetProblem.unsupportedFormat);
    });
  });

  group('readSpreadsheet', () {
    test('reads CSV and TSV into one sheet', () {
      final csv = readSpreadsheet(
        Uint8List.fromList(utf8.encode('a;b\n1;2')),
        SpreadsheetFormat.csv,
        sheetName: 'dados',
        parse: asText,
      );
      expect(csv.sheets.single.name, 'dados');
      expect(csv.sheets.single.cells.length, 4);
      final tsv = readSpreadsheet(
        Uint8List.fromList(utf8.encode('a;b\tc')),
        SpreadsheetFormat.tsv,
        sheetName: 't',
        parse: asText,
      );
      expect(
        tsv.sheets.single.cellAt(const CellAddress(0, 0)).constant,
        const TextValue('a;b'),
      );
    });

    test('reads Excel "Unicode Text" (.txt, UTF-16, tabs)', () {
      final units = 'Nome\tValor\r\nJoão\t1,5\r\n'.codeUnits;
      final bytes = Uint8List.fromList([
        0xFF,
        0xFE,
        for (final unit in units) ...[unit & 0xFF, unit >> 8],
      ]);
      final sheet = readSpreadsheet(
        bytes,
        SpreadsheetFormat.txt,
        sheetName: 'texto',
        parse: asText,
      ).sheets.single;
      expect(
        sheet.cellAt(const CellAddress(0, 1)).constant,
        const TextValue('João'),
      );
      expect(
        sheet.cellAt(const CellAddress(1, 1)).constant,
        const TextValue('1,5'),
      );
    });

    test('reads a workbook saved under a .csv name as a workbook', () {
      final workbook = readSpreadsheet(
        excelWorkbook(),
        SpreadsheetFormat.csv,
        sheetName: 'ignored',
        parse: asText,
      );
      expect(workbook.sheets.length, 2);
    });
  });

  group('writeSpreadsheet', () {
    final workbook = Workbook([
      Sheet('One')..setCell(const CellAddress(0, 0), asText('first')),
      Sheet('Two')
        ..setCell(const CellAddress(0, 0), asText('x'))
        ..setCell(const CellAddress(1, 0), asText('y,z')),
    ]);

    Uint8List write(SpreadsheetFormat format, {String csvDelimiter = ','}) =>
        writeSpreadsheet(
          workbook,
          format,
          sheetIndex: 1,
          valueOf: (_, _) => const EmptyValue(),
          displayOf: (sheet, address) => display(workbook, sheet, address),
          csvDelimiter: csvDelimiter,
        );

    String withBom(Uint8List bytes) {
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      return utf8.decode(bytes.sublist(3));
    }

    test('text formats save the chosen sheet with a BOM', () {
      expect(withBom(write(SpreadsheetFormat.csv)), 'x,"y,z"\r\n');
      expect(
        withBom(write(SpreadsheetFormat.csv, csvDelimiter: ';')),
        'x;y,z\r\n',
      );
      expect(withBom(write(SpreadsheetFormat.tsv)), 'x\ty,z\r\n');
    });

    test('xlsx saves every sheet', () {
      final read = readSpreadsheet(
        write(SpreadsheetFormat.xlsx),
        SpreadsheetFormat.xlsx,
        sheetName: '',
        parse: asText,
      );
      expect(read.sheets.map((s) => s.name), ['One', 'Two']);
    });

    test('refuses to save as xlsm', () {
      expect(
        () => write(SpreadsheetFormat.xlsm),
        throwsA(isA<SpreadsheetFileException>()),
      );
    });
  });
}
