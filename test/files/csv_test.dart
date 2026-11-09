import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/files/csv/csv_encoding.dart';
import 'package:voges_tables/files/csv/csv_reader.dart';
import 'package:voges_tables/files/csv/csv_writer.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';

Cell asText(String raw) => Cell(constant: TextValue(raw));

/// The rows of [sheet] as text, empty cells as ''.
List<List<String>> rows(Sheet sheet) {
  final range = sheet.usedRange;
  if (range == null) return const [];
  return [
    for (var row = 0; row <= range.last.row; row++)
      [
        for (var column = 0; column <= range.last.column; column++)
          switch (sheet.cellAt(CellAddress(column, row)).constant) {
            TextValue(:final value) => value,
            _ => '',
          },
      ],
  ];
}

Sheet read(String text, {String? delimiter}) =>
    readCsv(text, sheetName: 'CSV', parse: asText, delimiter: delimiter);

void main() {
  group('readCsv', () {
    test('reads plain fields and names the sheet', () {
      final sheet = read('a,b,c\n1,2,3\n');
      expect(sheet.name, 'CSV');
      expect(rows(sheet), [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });

    test('handles quotes, doubled quotes and line breaks inside quotes', () {
      final sheet = read(
        'name,note\r\n"Silva, Ana","said ""hi""\r\nand left"\r\n"",x\r\n',
      );
      expect(rows(sheet), [
        ['name', 'note'],
        ['Silva, Ana', 'said "hi"\r\nand left'],
        ['', 'x'],
      ]);
    });

    test('keeps a quote inside an unquoted field', () {
      expect(rows(read('5" disk,ok')), [
        ['5" disk', 'ok'],
      ]);
    });

    test('accepts CR, LF and CRLF line ends and a last line without one', () {
      expect(rows(read('a\rb\nc\r\nd')), [
        ['a'],
        ['b'],
        ['c'],
        ['d'],
      ]);
    });

    test('keeps blank lines as empty rows and skips empty fields', () {
      final sheet = read('a,,c\n\nd\n');
      expect(sheet.cells.keys.map((a) => a.a1).toSet(), {'A1', 'C1', 'A3'});
    });

    test('detects the semicolon of Brazilian Excel', () {
      final sheet = read(
        'Nome;Valor;Data\nCafé;1,5;01/02/2026\nPão;2,25;03/02/2026\n',
      );
      expect(rows(sheet)[1], ['Café', '1,5', '01/02/2026']);
      expect(detectCsvDelimiter('a;1,5;2,3\nb;4,5;6,7'), ';');
    });

    test('detects tabs and commas', () {
      expect(detectCsvDelimiter('a\tb\n1\t2'), '\t');
      expect(detectCsvDelimiter('a,b\n"x;y",2'), ',');
      expect(detectCsvDelimiter('single column\nvalue'), ',');
    });

    test('an explicit delimiter wins', () {
      expect(rows(read('a,b\tc', delimiter: '\t')), [
        ['a,b', 'c'],
      ]);
    });

    test('strips the BOM', () {
      expect(rows(read('\uFEFFa,b')), [
        ['a', 'b'],
      ]);
    });

    test('passes each non-empty field to parse', () {
      final seen = <String>[];
      readCsv(
        '1,=A1*2,,x',
        sheetName: 'P',
        parse: (raw) {
          seen.add(raw);
          return raw.startsWith('=')
              ? Cell(input: raw)
              : Cell(constant: NumberValue(double.tryParse(raw) ?? 0));
        },
      );
      expect(seen, ['1', '=A1*2', 'x']);
    });
  });

  group('writeCsv', () {
    Sheet sheetOf(Map<String, String> values) {
      final sheet = Sheet('S');
      values.forEach(
        (a1, value) => sheet.setCell(
          CellAddress.tryParse(a1)!,
          Cell(constant: TextValue(value)),
        ),
      );
      return sheet;
    }

    String display(Sheet sheet, CellAddress address) =>
        (sheet.cellAt(address).constant as TextValue).value;

    test('writes the used range with CRLF and quotes when needed', () {
      final sheet = sheetOf({
        'A1': 'plain',
        'B1': 'a,b',
        'C1': 'say "hi"',
        'A2': 'two\nlines',
        'C3': 'end',
      });
      expect(
        writeCsv(sheet, displayOf: (a) => display(sheet, a)),
        'plain,"a,b","say ""hi"""\r\n"two\nlines",,\r\n,,end\r\n',
      );
    });

    test('quotes for the chosen delimiter only', () {
      final sheet = sheetOf({'A1': '1,5', 'B1': 'a;b'});
      expect(
        writeCsv(sheet, displayOf: (a) => display(sheet, a), delimiter: ';'),
        '1,5;"a;b"\r\n',
      );
    });

    test('an empty sheet is an empty file', () {
      expect(writeCsv(Sheet('E'), displayOf: (_) => 'x'), '');
    });

    test('reads back what it writes', () {
      final sheet = sheetOf({
        'A1': 'Nome',
        'B1': 'Obs',
        'A2': 'Ana, "a"',
        'B2': 'line\r\nbreak',
      });
      final text = writeCsv(sheet, displayOf: (a) => display(sheet, a));
      expect(rows(read(text)), rows(sheet));
    });
  });

  group('encoding', () {
    test('encodes UTF-8 with a BOM', () {
      expect(encodeCsv('é'), [0xEF, 0xBB, 0xBF, 0xC3, 0xA9]);
    });

    test('decodes UTF-8 with and without BOM', () {
      expect(decodeCsv(encodeCsv('Ação,€')), 'Ação,€');
      expect(decodeCsv(Uint8List.fromList(utf8.encode('Ação'))), 'Ação');
    });

    test('falls back to Windows-1252 for Latin-1 bytes', () {
      final bytes = Uint8List.fromList([
        0x41, 0xE7, 0xE3, 0x6F, 0x3B, 0x80, 0x93, 0x94, 0xC9, //
      ]);
      expect(decodeCsv(bytes), 'Ação;€“”É');
    });

    test('decodes UTF-16 with BOM, as Excel "Unicode text"', () {
      final little = Uint8List.fromList([
        0xFF,
        0xFE,
        0x41,
        0,
        0xE9,
        0,
        0x09,
        0,
      ]);
      final big = Uint8List.fromList([0xFE, 0xFF, 0, 0x41, 0, 0xE9]);
      expect(decodeCsv(little), 'Aé\t');
      expect(decodeCsv(big), 'Aé');
    });
  });
}
