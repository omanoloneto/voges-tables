import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/files/spreadsheet_files.dart';
import 'package:voges_tables/files/workbook_codec.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_style.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';
import 'package:voges_tables/workbook/selection.dart';
import 'package:voges_tables/workbook/workbook_controller.dart';

CellAddress at(String a1) => CellAddress.tryParse(a1)!;

WorkbookController sheet({FormulaLocale locale = FormulaLocale.pt}) =>
    WorkbookController(
      workbook: Workbook.blank('Planilha1'),
      locale: () => locale,
    )..localeChanged();

void main() {
  test('typing numbers and a Portuguese formula calculates it', () {
    final c = sheet();
    c.enter(at('A1'), '10,5');
    c.enter(at('A2'), '20');
    c.enter(at('A3'), '=soma(a1;a2)*2');
    expect(c.valueAt(at('A3')), const NumberValue(61));
    expect(c.cellAt(at('A3')).input, '=SUM(A1,A2)*2');
    expect(c.editTextAt(at('A3')), '=SOMA(A1;A2)*2');
    expect(c.displayAt(at('A1')), '10,5');
    expect(c.dirty, isTrue);
  });

  test('a percentage or a date typed in a general cell gets that format', () {
    final c = sheet();
    c.enter(at('B1'), '15%');
    c.enter(at('B2'), '05/11/2026');
    expect(c.cellAt(at('B1')).style.format.kind, NumberKind.percent);
    expect(c.displayAt(at('B1')), '15%');
    expect(c.cellAt(at('B2')).style.format.kind, NumberKind.date);
    expect(c.displayAt(at('B2')), '05/11/2026');
  });

  test('undo and redo bring back cells and the values that depend on them', () {
    final c = sheet();
    c.enter(at('A1'), '2');
    c.enter(at('A2'), '=A1*10');
    c.enter(at('A1'), '3');
    expect(c.valueAt(at('A2')), const NumberValue(30));
    c.undo();
    expect(c.valueAt(at('A2')), const NumberValue(20));
    c.redo();
    expect(c.valueAt(at('A2')), const NumberValue(30));
  });

  test('copy shifts relative references, cut keeps them', () {
    final c = sheet();
    c.enter(at('A1'), '1');
    c.enter(at('B1'), '2');
    c.enter(at('A2'), r'=A1+$B$1');
    c.select(Selection.single(at('A2')));
    c.copy();
    c.select(Selection.single(at('C2')));
    c.paste();
    expect(c.cellAt(at('C2')).input, r'=C1+$B$1');
    c.select(Selection.single(at('A2')));
    c.copy(cut: true);
    c.select(Selection.single(at('D5')));
    c.paste();
    expect(c.cellAt(at('D5')).input, r'=A1+$B$1');
    expect(c.cellAt(at('A2')).isEmpty, isTrue);
  });

  test('pasting tab-separated text from another program', () {
    final c = sheet();
    c.select(Selection.single(at('B2')));
    c.pasteText('Nome\tNota\r\nAna\t9,5\r\n');
    expect(c.valueAt(at('C3')), const NumberValue(9.5));
    expect(c.valueAt(at('B3')), const TextValue('Ana'));
    expect(c.selection.range.a1, 'B2:C3');
  });

  test('the fill handle continues a number series and shifts formulas', () {
    final c = sheet();
    c.enter(at('A1'), '1');
    c.enter(at('A2'), '3');
    c.enter(at('B1'), '=A1*2');
    c.select(Selection(at('A1'), at('A2')));
    c.fillTo(CellRange(at('A1'), at('A5')));
    expect(
      [for (var r = 0; r < 5; r++) c.valueAt(CellAddress(0, r))],
      const [
        NumberValue(1),
        NumberValue(3),
        NumberValue(5),
        NumberValue(7),
        NumberValue(9),
      ],
    );
    c.select(Selection.single(at('B1')));
    c.fillTo(CellRange(at('B1'), at('B3')));
    expect(c.cellAt(at('B3')).input, '=A3*2');
    expect(c.valueAt(at('B3')), const NumberValue(10));
  });

  test('sorting the selection by the active column keeps rows together', () {
    final c = sheet();
    for (final (row, name, grade) in [
      (0, 'Caio', '7'),
      (1, 'Ana', '9'),
      (2, 'Bia', '8'),
    ]) {
      c.enter(CellAddress(0, row), name);
      c.enter(CellAddress(1, row), grade);
    }
    c.select(Selection(at('A3'), at('B1')));
    c.sortSelection(ascending: false);
    expect(
      [for (var r = 0; r < 3; r++) c.displayAt(CellAddress(0, r))],
      ['Ana', 'Bia', 'Caio'],
    );
    expect(c.displayAt(at('B1')), '9');
  });

  test('styles apply to every selected cell and undo in one step', () {
    final c = sheet();
    c.select(Selection(at('A1'), at('B2')));
    c.applyStyle((s) => s.copyWith(bold: true, fillColor: () => 0xFFFFFF00));
    expect(c.cellAt(at('B2')).style.bold, isTrue);
    c.undo();
    expect(c.cellAt(at('B2')).style.bold, isFalse);
  });

  test('sheet names follow the Excel rules', () {
    final c = sheet();
    c.addSheet('Planilha2');
    expect(c.renameSheet(1, 'Notas'), isTrue);
    expect(c.renameSheet(1, 'planilha1'), isFalse);
    expect(c.renameSheet(1, 'a/b'), isFalse);
    expect(c.workbook.sheets.map((s) => s.name), ['Planilha1', 'Notas']);
  });

  test(
    'saving as xlsx and opening again keeps values, formulas and formats',
    () async {
      final c = sheet();
      c.enter(at('A1'), '10,5');
      c.enter(at('A2'), '=A1*2');
      c.enter(at('B1'), '15%');
      c.select(Selection.single(at('A1')));
      c.applyStyle((s) => s.copyWith(bold: true));
      c.setColumnWidth(0, 140);
      final bytes = encodeWorkbook(
        c,
        SaveFormat.xlsx,
        locale: FormulaLocale.pt,
      );
      final reopened = await decodeWorkbook(
        OpenedFile(name: 'notas.xlsx', bytes: bytes),
        locale: FormulaLocale.pt,
        sheetName: 'Planilha1',
      );
      final d = sheet()..load(reopened);
      expect(d.valueAt(at('A2')), const NumberValue(21));
      expect(d.cellAt(at('A2')).input, '=A1*2');
      expect(d.cellAt(at('A1')).style.bold, isTrue);
      expect(d.displayAt(at('B1')), '15%');
      expect(d.sheet.columnWidth(0), closeTo(140, 7));
    },
  );

  test('CSV in Portuguese uses semicolons and reads back as numbers', () async {
    final c = sheet();
    c.enter(at('A1'), 'Nome');
    c.enter(at('B1'), '9,5');
    final bytes = encodeWorkbook(c, SaveFormat.csv, locale: FormulaLocale.pt);
    final text = String.fromCharCodes(bytes.skip(3));
    expect(text.trim(), 'Nome;9,5');
    final reopened = await decodeWorkbook(
      OpenedFile(name: 'notas.csv', bytes: bytes),
      locale: FormulaLocale.pt,
      sheetName: 'Planilha1',
    );
    final d = sheet()..load(reopened);
    expect(d.valueAt(at('B1')), const NumberValue(9.5));
  });
}
