import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';
import 'package:voges_tables/workbook/selection.dart';
import 'package:voges_tables/workbook/workbook_controller.dart';

CellAddress at(String a1) => CellAddress.tryParse(a1)!;

WorkbookController controller() => WorkbookController(
  workbook: Workbook.blank('Sheet1'),
  locale: () => FormulaLocale.en,
);

Selection wholeRows(int first, int last) => Selection(
  CellAddress(0, first),
  CellAddress(CellAddress.maxColumns - 1, last),
);

Selection wholeColumns(int first, int last) => Selection(
  CellAddress(first, 0),
  CellAddress(last, CellAddress.maxRows - 1),
);

Map<String, String> inputs(WorkbookController c) => {
  for (final MapEntry(:key, :value) in c.sheet.cells.entries)
    key.a1: value.isFormula ? value.input : c.displayAt(key),
};

void main() {
  test('inserting rows moves cells and formulas, and undo puts them back', () {
    final c = controller();
    c.enter(at('A1'), '1');
    c.enter(at('A2'), '2');
    c.enter(at('A3'), '=SUM(A1:A2)');
    final before = inputs(c);
    c.select(wholeRows(1, 2));
    expect(c.wholeRowsSelected, isTrue);
    expect(c.insertRows(), isTrue);
    expect(inputs(c), {'A1': '1', 'A4': '2', 'A5': '=SUM(A1:A4)'});
    expect(c.valueAt(at('A5')), const NumberValue(3));
    c.undo();
    expect(inputs(c), before);
    expect(c.valueAt(at('A3')), const NumberValue(3));
    c.redo();
    expect(inputs(c), {'A1': '1', 'A4': '2', 'A5': '=SUM(A1:A4)'});
  });

  test(
    'undoing a deletion brings back the cells and the broken references',
    () {
      final c = controller();
      c.enter(at('B1'), '5');
      c.enter(at('B2'), '7');
      c.enter(at('B3'), '=B2*2');
      c.enter(at('C3'), '=SUM(B1:B2)');
      c.setRowHeight(1, 40);
      final before = inputs(c);
      c.select(wholeRows(1, 1));
      c.deleteRows();
      expect(inputs(c), {'B1': '5', 'B2': '=#REF!*2', 'C2': '=SUM(B1:B1)'});
      expect(c.valueAt(at('C2')), const NumberValue(5));
      expect(c.sheet.rowHeights, isEmpty);
      c.undo();
      expect(inputs(c), before);
      expect(c.valueAt(at('B3')), const NumberValue(14));
      expect(c.valueAt(at('C3')), const NumberValue(12));
      expect(c.sheet.rowHeights, {1: 40});
    },
  );

  test('columns move with their widths and references', () {
    final c = controller();
    c.enter(at('A1'), '3');
    c.enter(at('B1'), '=A1+1');
    c.setColumnWidth(1, 150);
    c.select(wholeColumns(0, 0));
    expect(c.insertColumns(), isTrue);
    expect(inputs(c), {'B1': '3', 'C1': '=B1+1'});
    expect(c.sheet.columnWidths, {2: 150});
    c.select(wholeColumns(1, 1));
    c.deleteColumns();
    expect(c.cellAt(at('B1')).input, '=#REF!+1');
    c.undo();
    c.undo();
    expect(inputs(c), {'A1': '3', 'B1': '=A1+1'});
    expect(c.sheet.columnWidths, {1: 150});
  });

  test('a cell edit after an insertion undoes in order', () {
    final c = controller();
    c.enter(at('A1'), '1');
    c.enter(at('B1'), '=A1*2');
    c.select(wholeRows(0, 0));
    c.insertRows();
    c.enter(at('A2'), '10');
    expect(c.valueAt(at('B2')), const NumberValue(20));
    c.undo();
    expect(c.valueAt(at('B2')), const NumberValue(2));
    c.undo();
    expect(c.valueAt(at('B1')), const NumberValue(2));
    expect(c.canUndo, isTrue);
  });

  test('other sheets follow the rows of the edited one', () {
    final c = controller();
    c.enter(at('A2'), '4');
    c.addSheet('Report');
    c.enter(at('A1'), '=Sheet1!A2*2');
    c.showSheet(0);
    c.select(wholeRows(0, 0));
    c.insertRows();
    expect(c.workbook.sheets[1].cellAt(at('A1')).input, '=Sheet1!A3*2');
    expect(c.valueAt(at('A1'), 1), const NumberValue(8));
    c.undo();
    expect(c.workbook.sheets[1].cellAt(at('A1')).input, '=Sheet1!A2*2');
  });

  test('inserting is refused when it would push data off the sheet', () {
    final c = controller();
    c.enter(const CellAddress(0, CellAddress.maxRows - 1), '1');
    c.select(wholeRows(0, 0));
    expect(c.insertRows(), isFalse);
    expect(c.canUndo, isTrue);
    c.undo();
    expect(c.canUndo, isFalse);
  });

  test('a paste of many cells calculates the dependents once', () {
    final c = controller();
    c.enter(at('B1'), '=SUM(A1:A1000)');
    c.select(const Selection(CellAddress(0, 0), CellAddress(0, 999)));
    c.pasteText(List.filled(1000, '1').join('\n'));
    expect(c.valueAt(at('B1')), const NumberValue(1000));
  });
}
