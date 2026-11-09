import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/formula.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/structure.dart';
import 'package:voges_tables/sheet/workbook.dart';

import 'helpers.dart';

StructureEdit rows(int at, int count, {int sheet = 0}) =>
    StructureEdit(sheet: sheet, axis: SheetAxis.rows, at: at, count: count);

StructureEdit columns(int at, int count) =>
    StructureEdit(sheet: 0, axis: SheetAxis.columns, at: at, count: count);

String adjust(String formula, StructureEdit edit, {bool sameSheet = true}) =>
    adjustReferences(
      formula,
      edit,
      targets: (sheet) => sheet == null ? sameSheet : sheet == 'Data',
    );

void main() {
  group('adjustReferences', () {
    test('inserted rows push the references below them', () {
      final edit = rows(2, 2);
      expect(adjust('=A1+A3+\$B\$5', edit), '=A1+A5+\$B\$7');
      expect(adjust('=SUM(A1:A10)', edit), '=SUM(A1:A12)');
      expect(adjust('=SUM(A3:A10)', edit), '=SUM(A5:A12)');
      expect(adjust('=SUM(A1:A2)', edit), '=SUM(A1:A2)');
      expect(adjust('=SUM(3:5)', edit), '=SUM(5:7)');
      expect(adjust('=SUM(A:B)', edit), '=SUM(A:B)');
    });

    test('deleted rows shrink ranges and break single references', () {
      final edit = rows(4, -2);
      expect(adjust('=A5', edit), '=#REF!');
      expect(adjust('=A7*2', edit), '=A5*2');
      expect(adjust('=SUM(A1:A10)', edit), '=SUM(A1:A8)');
      expect(adjust('=SUM(A5:A6)', edit), '=SUM(#REF!)');
      expect(adjust('=SUM(A6:A9)', edit), '=SUM(A5:A7)');
      expect(adjust('=SUM(A1:A5)', edit), '=SUM(A1:A4)');
    });

    test('columns move only the column part', () {
      final edit = columns(1, 1);
      expect(adjust('=A1+B1+C\$1', edit), '=A1+C1+D\$1');
      expect(adjust('=SUM(A:C)', edit), '=SUM(A:D)');
      expect(adjust('=SUM(1:1)', edit), '=SUM(1:1)');
    });

    test('only references to the edited sheet change', () {
      final edit = rows(0, 1);
      expect(
        adjust('=Data!A1+Other!A1', edit, sameSheet: false),
        '=Data!A2+Other!A1',
      );
      expect(adjust("='Data'!A1:A3", edit, sameSheet: false), "='Data'!A2:A4");
      expect(adjust('=A1', edit, sameSheet: false), '=A1');
    });

    test('text and function names are left alone', () {
      final edit = rows(0, 3);
      expect(adjust('=LOG10(A1)&"A1"', edit), '=LOG10(A4)&"A1"');
    });
  });

  group('Calculator.changeStructure', () {
    test('inserting rows keeps every value without calculating them again', () {
      final calc = calculatorOf({
        'A1': 2,
        'A2': 3,
        'B1': '=A1*10',
        'B2': '=A2*10',
        'C1': '=SUM(B1:B2)',
      });
      final result = calc.changeStructure(rows(0, 1))!;
      expect(calc.lastEvaluationCount, 0);
      expect(calc.valueAt(0, at('C2')), n(50));
      expect(calc.workbook.sheets[0].cellAt(at('C2')).input, '=SUM(B2:B3)');
      expect(result.rewritten[cellKey(0, at('C2'))], '=SUM(B1:B2)');
      calc.setCell(0, at('A2'), cellOf(5));
      expect(calc.valueAt(0, at('B2')), n(50));
      expect(calc.valueAt(0, at('C2')), n(80));
    });

    test('a range that grows or shrinks is calculated again', () {
      final calc = calculatorOf({
        'A1': 1,
        'A2': 2,
        'A3': 4,
        'B1': '=SUM(A1:A3)',
        'C1': '=ROWS(A1:A3)',
      });
      calc.changeStructure(rows(1, -1));
      expect(calc.valueAt(0, at('B1')), n(5));
      expect(calc.workbook.sheets[0].cellAt(at('B1')).input, '=SUM(A1:A2)');
      expect(calc.valueAt(0, at('C1')), n(2));
    });

    test('formulas reading deleted cells show #REF!', () {
      final calc = calculatorOf({'A1': 1, 'A2': 2, 'B3': '=A2*2'});
      final result = calc.changeStructure(rows(1, -1))!;
      expect(calc.valueAt(0, at('B2')), e(CellError.ref));
      expect(result.removed[at('A2')]?.constant, n(2));
    });

    test('ROW and COLUMN follow the cell they move to', () {
      final calc = calculatorOf({'A1': '=ROW()', 'B1': '=COLUMN(C1)'});
      calc.changeStructure(rows(0, 2));
      calc.changeStructure(columns(0, 1));
      expect(calc.valueAt(0, at('B3')), n(3));
      expect(calc.valueAt(0, at('C3')), n(4));
    });

    test('whole columns are calculated again when rows move', () {
      final calc = calculatorOf({'A1': 5, 'A2': 7, 'C1': '=INDEX(A:A,2)'});
      calc.changeStructure(rows(0, 1));
      expect(calc.valueAt(0, at('C2')), n(5));
    });

    test('other sheets follow the edited one', () {
      final workbook = workbookOf(
        [
          {'A1': 1, 'A2': 2},
          {'A1': '=Data!A2*3'},
        ],
        names: ['Data', 'Report'],
      );
      final calc = Calculator(workbook);
      calc.changeStructure(rows(0, 4));
      expect(workbook.sheets[1].cellAt(at('A1')).input, '=Data!A6*3');
      expect(calc.valueAt(1, at('A1')), n(6));
      calc.setCell(0, at('A6'), cellOf(10));
      expect(calc.valueAt(1, at('A1')), n(30));
    });

    test('inserting refuses to push filled cells off the sheet', () {
      final calc = calculatorOf({'A1048576': 1});
      expect(calc.changeStructure(rows(0, 1)), isNull);
      expect(calc.workbook.sheets[0].cellAt(at('A1048576')).constant, n(1));
    });

    test('deleting rows keeps the last used cell right', () {
      final workbook = Workbook.blank('S');
      final calc = Calculator(workbook);
      calc.setCell(0, at('C12'), cellOf(1));
      calc.changeStructure(rows(5, -5));
      expect(workbook.sheets[0].usedRange?.last, at('C7'));
      calc.changeStructure(columns(0, -3));
      expect(workbook.sheets[0].usedRange, isNull);
    });

    test('a large sheet moves fast and evaluates nothing', () {
      final workbook = Workbook.blank('S');
      final sheet = workbook.sheets[0];
      for (var row = 0; row < 20000; row++) {
        sheet.setCell(CellAddress(0, row), cellOf(row));
        sheet.setCell(CellAddress(1, row), cellOf('=A${row + 1}*2'));
        sheet.setCell(
          CellAddress(2, row),
          cellOf(row == 0 ? '=B1' : '=C$row+B${row + 1}'),
        );
      }
      final calc = Calculator(workbook);
      final watch = Stopwatch()..start();
      calc.changeStructure(rows(0, 1));
      watch.stop();
      expect(calc.lastEvaluationCount, 0);
      expect(calc.valueAt(0, at('C20001')), n(19999 * 20000.0));
      expect(watch.elapsedMilliseconds, lessThan(1500));
    });
  });
}
