import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/files/xlsx/xlsx_reader.dart';
import 'package:voges_tables/files/xlsx/xlsx_writer.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';

import 'xlsx_fixtures.dart';

CellRange range(String a1) {
  final [first, last] = a1.split(':');
  return CellRange(CellAddress.tryParse(first)!, CellAddress.tryParse(last)!);
}

String sheetXml(Uint8List bytes, [int sheet = 1]) => utf8.decode(
  ZipDecoder()
      .decodeBytes(bytes)
      .findFile('xl/worksheets/sheet$sheet.xml')!
      .content,
);

CellValue noValue(int sheet, CellAddress address) => const EmptyValue();

void main() {
  test('reads the merges Excel writes', () {
    final sheet = readXlsx(excelWorkbook()).sheets.first;
    expect(sheet.merges, [range('A10:B10')]);
    expect(sheet.mergeAt(CellAddress.tryParse('B10')!), range('A10:B10'));
    expect(readXlsx(libreOfficeWorkbook()).sheets.single.merges, isEmpty);
  });

  test('drops single cells and overlaps and clamps to the sheet', () {
    final sheet = readXlsx(workbookWithSheet(mergesSheet)).sheets.single;
    expect(sheet.merges, [
      range('A1:B2'),
      range('C3:D4'),
      range('XFC1:XFD2'),
      range('A1048575:B1048576'),
      range('G7:H8'),
    ]);
    expect(sheet.cellAt(const CellAddress(0, 0)).constant, NumberValue(1));
  });

  test('keeps the cells when the end of the sheet is damaged', () {
    final sheet = readXlsx(
      workbookWithSheet(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData><row r="1"><c r="A1"><v>7</v></c></row></sheetData>'
        '<mergeCells count="1"><mergeCell ref="A1:B1"/></mergeCells>'
        '<pageMargins left="0.7" <drawing/>',
      ),
    ).sheets.single;
    expect(sheet.cellAt(const CellAddress(0, 0)).constant, NumberValue(7));
    expect(sheet.merges, [range('A1:B1')]);
  });

  test('a self-closing sheetData still reads what follows', () {
    final sheet = readXlsx(
      workbookWithSheet(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData/><mergeCells><mergeCell ref="C1:C9"/></mergeCells></worksheet>',
      ),
    ).sheets.single;
    expect(sheet.merges, [range('C1:C9')]);
  });

  group('write', () {
    late Workbook workbook;

    setUp(() {
      final sheet = Sheet('Merges')
        ..setCell(
          const CellAddress(0, 0),
          const Cell(constant: TextValue('Title')),
        )
        ..merges = [
          range('A1:D1'),
          range('B3:C10'),
          range('XFC1048575:XFD1048576'),
        ];
      workbook = Workbook([sheet, Sheet('Plain')]);
    });

    test('round trips the merges', () {
      final read = readXlsx(writeXlsx(workbook, valueOf: noValue));
      expect(read.sheets.first.merges, workbook.sheets.first.merges);
      expect(read.sheets.last.merges, isEmpty);
    });

    test('puts mergeCells after sheetData and before pageMargins', () {
      final xml = sheetXml(writeXlsx(workbook, valueOf: noValue));
      expect(
        xml,
        contains(
          '</sheetData><mergeCells count="3"><mergeCell ref="A1:D1"/>'
          '<mergeCell ref="B3:C10"/><mergeCell ref="XFC1048575:XFD1048576"/>'
          '</mergeCells><pageMargins ',
        ),
      );
      expect(
        sheetXml(writeXlsx(workbook, valueOf: noValue), 2),
        isNot(contains('mergeCells')),
      );
    });

    test('leaves out merges of one cell', () {
      workbook.sheets.first.merges = [
        CellRange.single(const CellAddress(1, 1)),
      ];
      final xml = sheetXml(writeXlsx(workbook, valueOf: noValue));
      expect(xml, isNot(contains('mergeCells')));
    });
  });
}
