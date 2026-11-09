import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/files/xlsx/sheet_names.dart';
import 'package:voges_tables/files/xlsx/xlsx_reader.dart';
import 'package:voges_tables/files/xlsx/xlsx_writer.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_style.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';
import 'package:xml/xml.dart';

CellAddress at(String a1) => CellAddress.tryParse(a1)!;

Map<String, String> unzip(Uint8List bytes) => {
  for (final file in ZipDecoder().decodeBytes(bytes).files)
    if (file.isFile) file.name: utf8.decode(file.content),
};

CellValue noValue(int sheet, CellAddress address) => const EmptyValue();

Workbook sampleWorkbook() {
  final summary = Sheet('Resumo & "Q1" <2026>')
    ..frozenRows = 1
    ..frozenColumns = 2
    ..columnWidths.addAll({0: 140, 1: 88 + 7, 2: 95, 3: 95, 7: 40})
    ..rowHeights.addAll({0: 40, 9: 32});
  summary
    ..setCell(at('A1'), const Cell(constant: TextValue('Produto')))
    ..setCell(at('B1'), const Cell(constant: NumberValue(1234.5)))
    ..setCell(at('C1'), const Cell(constant: NumberValue(-0.000001)))
    ..setCell(at('D1'), const Cell(constant: BoolValue(false)))
    ..setCell(at('E1'), const Cell(constant: ErrorValue(CellError.na)))
    ..setCell(at('F1'), const Cell(constant: NumberValue(1e21)))
    ..setCell(
      at('A2'),
      const Cell(
        constant: TextValue('  spaced\r\nline <&> "q" _x0041_ \u0001 😀'),
      ),
    )
    ..setCell(at('B2'), const Cell(input: '=SUM(B1:C1)*2'))
    ..setCell(at('C2'), const Cell(input: '=IF(B2>1,"big","small")'))
    ..setCell(at('D2'), const Cell(input: '=B1>0'))
    ..setCell(at('E2'), const Cell(input: '=1/0'))
    ..setCell(at('F2'), const Cell(input: '=XLOOKUP(A1,A:A,B:B)'))
    ..setCell(at('G2'), const Cell(input: '=G2'))
    ..setCell(
      at('A3'),
      const Cell(
        constant: NumberValue(45658),
        style: CellStyle(format: NumberFormat(NumberKind.date)),
      ),
    )
    ..setCell(
      at('B3'),
      const Cell(
        constant: NumberValue(0.5),
        style: CellStyle(format: NumberFormat(NumberKind.time)),
      ),
    )
    ..setCell(
      at('C3'),
      const Cell(
        constant: NumberValue(45658.5),
        style: CellStyle(format: NumberFormat(NumberKind.dateTime)),
      ),
    )
    ..setCell(
      at('D3'),
      const Cell(
        constant: NumberValue(0.123),
        style: CellStyle(format: NumberFormat(NumberKind.percent, decimals: 1)),
      ),
    )
    ..setCell(
      at('E3'),
      const Cell(
        constant: NumberValue(99.9),
        style: CellStyle(format: NumberFormat(NumberKind.currency)),
      ),
    )
    ..setCell(
      at('F3'),
      const Cell(
        constant: NumberValue(3),
        style: CellStyle(
          format: NumberFormat(
            NumberKind.number,
            decimals: 3,
            thousands: false,
          ),
        ),
      ),
    )
    ..setCell(
      at('G3'),
      const Cell(
        constant: TextValue('007'),
        style: CellStyle(format: NumberFormat(NumberKind.text)),
      ),
    )
    ..setCell(
      at('A4'),
      const Cell(
        constant: TextValue('Styled'),
        style: CellStyle(
          bold: true,
          italic: true,
          underline: true,
          strike: true,
          fontSize: 14.5,
          textColor: 0xFF336699,
          fillColor: 0xFFFFEE00,
          horizontal: HorizontalAlign.center,
          vertical: VerticalAlign.middle,
          wrap: true,
          borders: CellBorders(top: true, left: true),
        ),
      ),
    )
    ..setCell(
      at('B4'),
      const Cell(
        style: CellStyle(
          fillColor: 0xFF000000,
          horizontal: HorizontalAlign.right,
          vertical: VerticalAlign.top,
          borders: CellBorders.all,
        ),
      ),
    )
    ..setCell(
      at('C4'),
      const Cell(
        constant: TextValue('Produto'),
        style: CellStyle(
          textColor: 0xFF000000,
          horizontal: HorizontalAlign.left,
        ),
      ),
    )
    ..setCell(at('Z100'), const Cell(constant: NumberValue(1)));
  final data = Sheet('Dados')
    ..setCell(at('A1'), const Cell(input: "='Resumo & \"Q1\" <2026>'!B1"));
  return Workbook([summary, data, Sheet('Vazia')]);
}

CellValue sampleValues(int sheet, CellAddress address) {
  if (sheet != 0) return const NumberValue(1234.5);
  return switch (address.a1) {
    'B2' => const NumberValue(2469),
    'C2' => const TextValue('big'),
    'D2' => const BoolValue(true),
    'E2' => const ErrorValue(CellError.div0),
    'F2' => const NumberValue(double.nan),
    'G2' => const ErrorValue(CellError.circular),
    _ => const EmptyValue(),
  };
}

void main() {
  group('round trip', () {
    late Workbook original;
    late Workbook read;

    setUpAll(() {
      original = sampleWorkbook();
      read = readXlsx(writeXlsx(original, valueOf: sampleValues));
    });

    test('keeps the sheets and their names', () {
      expect(
        read.sheets.map((s) => s.name),
        original.sheets.map((s) => s.name),
      );
    });

    test('keeps every cell: input, constant and style', () {
      for (var i = 0; i < original.sheets.length; i++) {
        final before = original.sheets[i].cells;
        final after = read.sheets[i].cells;
        expect(after.keys.toSet(), before.keys.toSet(), reason: 'sheet $i');
        before.forEach((address, cell) {
          final copy = after[address]!;
          expect(copy.input, cell.input, reason: '$address input');
          expect(copy.constant, cell.constant, reason: '$address constant');
          expect(copy.style, cell.style, reason: '$address style');
        });
      }
    });

    test('keeps widths, heights and frozen panes', () {
      final before = original.sheets.first;
      final after = read.sheets.first;
      expect(after.columnWidths, before.columnWidths);
      expect(after.rowHeights, before.rowHeights);
      expect(after.frozenRows, 1);
      expect(after.frozenColumns, 2);
      expect(read.sheets[1].frozenRows, 0);
    });
  });

  group('package', () {
    late Map<String, String> parts;

    setUpAll(() {
      parts = unzip(writeXlsx(sampleWorkbook(), valueOf: sampleValues));
    });

    test('every XML part is well formed and declared', () {
      for (final entry in parts.entries) {
        expect(() => XmlDocument.parse(entry.value), returnsNormally);
      }
      final types = XmlDocument.parse(parts['[Content_Types].xml']!);
      final overrides = types
          .findAllElements('Override')
          .map((e) => e.getAttribute('PartName')!.substring(1))
          .toSet();
      expect(
        overrides,
        parts.keys
            .where((p) => p.endsWith('.xml') && p != '[Content_Types].xml')
            .toSet(),
      );
    });

    test('names the application and asks for a full recalculation', () {
      expect(parts['docProps/app.xml'], contains('<Application>Voges Tables'));
      expect(parts['xl/workbook.xml'], contains('fullCalcOnLoad="1"'));
      expect(
        parts['xl/workbook.xml'],
        contains('name="Resumo &amp; &quot;Q1&quot; &lt;2026&gt;"'),
      );
    });

    test('writes cached formula results with their types', () {
      final sheet = parts['xl/worksheets/sheet1.xml']!;
      expect(sheet, contains('<c r="B2"><f>SUM(B1:C1)*2</f><v>2469</v></c>'));
      expect(
        sheet,
        contains(
          '<c r="C2" t="str"><f>IF(B2&gt;1,"big","small")</f><v>big</v></c>',
        ),
      );
      expect(sheet, contains('<c r="D2" t="b"><f>B1&gt;0</f><v>1</v></c>'));
      expect(sheet, contains('<c r="E2" t="e"><f>1/0</f><v>#DIV/0!</v></c>'));
      expect(
        sheet,
        contains(
          '<c r="F2" t="e"><f>_xlfn.XLOOKUP(A1,A:A,B:B)</f><v>#NUM!</v></c>',
        ),
      );
      expect(sheet, contains('<c r="G2"><f>G2</f></c>'));
    });

    test('writes the dimension, frozen pane and grouped columns', () {
      final sheet = parts['xl/worksheets/sheet1.xml']!;
      expect(sheet, contains('<dimension ref="A1:Z100"/>'));
      expect(
        sheet,
        contains(
          '<pane xSplit="2" ySplit="1" topLeftCell="C2" '
          'activePane="bottomRight" state="frozen"/>',
        ),
      );
      expect(RegExp('<col ').allMatches(sheet).length, 3);
      expect(sheet, contains('<col min="2" max="4" '));
      expect(
        parts['xl/worksheets/sheet3.xml'],
        contains('<dimension ref="A1"/>'),
      );
    });

    test('deduplicates styles and shared strings', () {
      final styles = XmlDocument.parse(parts['xl/styles.xml']!);
      int count(String group) => int.parse(
        styles.findAllElements(group).single.getAttribute('count')!,
      );
      final xfs = styles.findAllElements('cellXfs').single.childElements;
      expect(count('cellXfs'), xfs.length);
      expect(xfs.first.getAttribute('numFmtId'), '0');
      expect(xfs.first.getAttribute('fontId'), '0');
      expect(count('fills'), 4);
      expect(count('borders'), 3);
      expect(
        parts['xl/styles.xml'],
        contains('formatCode="&quot;R\$&quot; #,##0.00"'),
      );
      expect(parts['xl/styles.xml'], contains('formatCode="dd/mm/yyyy hh:mm"'));
      final strings = XmlDocument.parse(parts['xl/sharedStrings.xml']!);
      expect(strings.rootElement.getAttribute('uniqueCount'), '4');
      expect(strings.rootElement.getAttribute('count'), '5');
    });

    test('uses the given currency symbol', () {
      final workbook = Workbook([
        Sheet('A')..setCell(
          at('A1'),
          const Cell(
            constant: NumberValue(1),
            style: CellStyle(format: NumberFormat(NumberKind.currency)),
          ),
        ),
      ]);
      final styles = unzip(
        writeXlsx(workbook, valueOf: noValue, currencySymbol: '€'),
      )['xl/styles.xml']!;
      expect(styles, contains('formatCode="&quot;€&quot; #,##0.00"'));
    });

    test('leaves the shared strings out when there are none', () {
      final parts = unzip(
        writeXlsx(Workbook.blank('Planilha1'), valueOf: noValue),
      );
      expect(parts.containsKey('xl/sharedStrings.xml'), isFalse);
      expect(parts['[Content_Types].xml'], isNot(contains('sharedStrings')));
      expect(
        readXlsx(
          writeXlsx(Workbook.blank('P'), valueOf: noValue),
        ).sheets.single.name,
        'P',
      );
    });
  });

  group('sheet names', () {
    test('validates Excel rules', () {
      expect(isValidSheetName('Resumo 2026'), isTrue);
      expect(isValidSheetName(''), isFalse);
      expect(isValidSheetName('a' * 32), isFalse);
      expect(isValidSheetName('a/b'), isFalse);
      expect(isValidSheetName('[x]'), isFalse);
      expect(isValidSheetName("'quoted"), isFalse);
      expect(isValidSheetName('History'), isFalse);
    });

    test('fixes names Excel would refuse and keeps them unique', () {
      expect(
        safeSheetNames(['a/b', 'A_B', '', 'History', 'x' * 40, 'x' * 40, 'Ok']),
        [
          'a_b',
          'A_B (2)',
          'Sheet3',
          'Sheet4',
          'x' * 31,
          '${'x' * 27} (2)',
          'Ok',
        ],
      );
    });

    test('the writer saves fixed names', () {
      final workbook = Workbook([Sheet('a:b'), Sheet('A:B')]);
      final read = readXlsx(writeXlsx(workbook, valueOf: noValue));
      expect(read.sheets.map((s) => s.name), ['a_b', 'A_B (2)']);
      expect(workbook.sheets.first.name, 'a:b');
    });
  });

  test('writes and reads 100 000 cells quickly', () {
    final sheet = Sheet('Big');
    const bold = CellStyle(bold: true);
    for (var row = 0; row < 10000; row++) {
      for (var column = 0; column < 10; column++) {
        final address = CellAddress(column, row);
        sheet.setCell(address, switch (column) {
          0 => Cell(constant: TextValue('Item $row')),
          1 => Cell(input: '=C${row + 1}*2'),
          2 => const Cell(constant: NumberValue(1.5), style: bold),
          _ => Cell(constant: NumberValue(row * column / 7)),
        });
      }
    }
    final watch = Stopwatch()..start();
    final bytes = writeXlsx(
      Workbook([sheet]),
      valueOf: (_, _) => const NumberValue(3),
    );
    final written = watch.elapsedMilliseconds;
    final read = readXlsx(bytes).sheets.single;
    final total = watch.elapsedMilliseconds;
    expect(read.cells.length, 100000);
    expect(read.cellAt(const CellAddress(1, 9999)).input, '=C10000*2');
    expect(read.cellAt(const CellAddress(2, 5)).style, bold);
    expect(
      total,
      lessThan(5000),
      reason: 'write ${written}ms, total ${total}ms',
    );
  });
}
