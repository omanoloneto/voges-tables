import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/calculator.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';

import 'helpers.dart';

void main() {
  test('computes on creation and after edits', () {
    final calc = calculatorOf({'A1': 2, 'A2': 3, 'A3': '=A1*A2'});
    expect(calc.valueAt(0, at('A3')), n(6));
    calc.setCell(0, at('A1'), cellOf(10));
    expect(calc.valueAt(0, at('A3')), n(30));
    expect(calc.workbook.sheets[0].cellAt(at('A1')).constant, n(10));
  });

  test('constants and empty cells read back', () {
    final calc = calculatorOf({'A1': 'x'});
    expect(calc.valueAt(0, at('A1')), t('x'));
    expect(calc.valueAt(0, at('B9')), const EmptyValue());
    expect(calc.valueAt(5, at('A1')), const EmptyValue());
  });

  test('recalculates only what depends on the edited cell', () {
    final calc = calculatorOf({
      'A1': 1,
      'B1': '=A1+1',
      'C1': '=B1*2',
      'D1': '=SUM(A:A)',
      'X1': 5,
      'Y1': '=X1+1',
      'Y2': '=Y1+1',
    });
    calc.setCell(0, at('A1'), cellOf(2));
    expect(calc.lastEvaluationCount, 3);
    expect(calc.valueAt(0, at('C1')), n(6));
    expect(calc.valueAt(0, at('D1')), n(2));
    calc.setCell(0, at('A50'), cellOf(8));
    expect(calc.lastEvaluationCount, 1);
    expect(calc.valueAt(0, at('D1')), n(10));
    calc.setCell(0, at('Q7'), cellOf(1));
    expect(calc.lastEvaluationCount, 0);
  });

  test('replacing and clearing a formula updates its readers', () {
    final calc = calculatorOf({'A1': '=1+1', 'B1': '=A1*10'});
    calc.setCell(0, at('A1'), cellOf('=5'));
    expect(calc.valueAt(0, at('B1')), n(50));
    calc.setCell(0, at('A1'), const Cell());
    expect(calc.valueAt(0, at('B1')), n(0));
    expect(calc.workbook.sheets[0].cells.containsKey(at('A1')), isFalse);
  });

  test('a formula stops depending on cells it no longer reads', () {
    final calc = calculatorOf({'A1': 1, 'B1': '=A1'});
    calc.setCell(0, at('B1'), cellOf('=2'));
    calc.setCell(0, at('A1'), cellOf(9));
    expect(calc.lastEvaluationCount, 0);
  });

  group('circular references', () {
    test('self reference', () {
      final calc = calculatorOf({'A1': '=A1+1'});
      expect(calc.valueAt(0, at('A1')), e(CellError.circular));
    });

    test('a loop marks its members; cells after it still evaluate', () {
      final calc = calculatorOf({
        'A1': '=B1',
        'B1': '=C1',
        'C1': '=A1',
        'D1': '=IFERROR(A1,"broken")',
        'E1': 7,
      });
      for (final a1 in ['A1', 'B1', 'C1']) {
        expect(calc.valueAt(0, at(a1)), e(CellError.circular));
      }
      expect(calc.valueAt(0, at('D1')), t('broken'));
      calc.setCell(0, at('C1'), cellOf('=E1'));
      expect(calc.valueAt(0, at('A1')), n(7));
      expect(calc.valueAt(0, at('D1')), n(7));
    });

    test('a range that includes its own cell', () {
      final calc = calculatorOf({'A1': 1, 'A3': '=SUM(A1:A5)'});
      expect(calc.valueAt(0, at('A3')), e(CellError.circular));
    });
  });

  test('a chain of 20 000 cells does not overflow', () {
    final cells = <String, Object>{'A1': 1};
    for (var row = 2; row <= 20000; row++) {
      cells['A$row'] = '=A${row - 1}+1';
    }
    final calc = calculatorOf(cells);
    expect(calc.valueAt(0, at('A20000')), n(20000));
    calc.setCell(0, at('A1'), cellOf(101));
    expect(calc.valueAt(0, at('A20000')), n(20100));
    expect(calc.lastEvaluationCount, 19999);
    calc.setCell(0, at('A1'), cellOf('=A20000'));
    expect(calc.valueAt(0, at('A10')), e(CellError.circular));
  });

  test('big sheets recalculate only dependents', () {
    final workbook = Workbook([Sheet('Data')]);
    final sheet = workbook.sheets[0];
    for (var row = 0; row < 40000; row++) {
      sheet.setCell(CellAddress(0, row), cellOf(row));
    }
    for (var row = 0; row < 10000; row++) {
      sheet.setCell(CellAddress(1, row), cellOf('=A${row + 1}*2'));
    }
    sheet.setCell(const CellAddress(2, 0), cellOf('=SUM(A:A)'));
    final calc = Calculator(workbook);
    expect(calc.valueAt(0, const CellAddress(1, 9999)), n(19998));
    final watch = Stopwatch()..start();
    calc.setCell(0, const CellAddress(0, 5), cellOf(1000));
    watch.stop();
    expect(calc.lastEvaluationCount, 2);
    expect(calc.valueAt(0, const CellAddress(1, 5)), n(2000));
    expect(calc.valueAt(0, const CellAddress(2, 0)), n(799980000 + 995));
    expect(watch.elapsedMilliseconds, lessThan(500));
  });

  group('sheets', () {
    test('cross-sheet references and their updates', () {
      final workbook = workbookOf(
        [
          {'A1': '=Data!A1*2', 'A2': "='My data'!B2+1"},
          {'A1': 21},
          {'B2': 4},
        ],
        names: ['Main', 'Data', 'My data'],
      );
      final calc = Calculator(workbook);
      expect(calc.valueAt(0, at('A1')), n(42));
      expect(calc.valueAt(0, at('A2')), n(5));
      calc.setCell(1, at('A1'), cellOf(1));
      expect(calc.valueAt(0, at('A1')), n(2));
      expect(calc.lastEvaluationCount, 1);
    });

    test('renaming a sheet needs sheetsChanged', () {
      final workbook = workbookOf([
        {'A1': '=Other!A1'},
        {'A1': 3},
      ]);
      final calc = Calculator(workbook);
      expect(calc.valueAt(0, at('A1')), e(CellError.ref));
      workbook.sheets[1].name = 'Other';
      calc.sheetsChanged();
      expect(calc.valueAt(0, at('A1')), n(3));
      workbook.sheets.removeAt(1);
      calc.sheetsChanged();
      expect(calc.valueAt(0, at('A1')), e(CellError.ref));
    });
  });

  test('volatile functions refresh on every edit', () {
    var now = DateTime(2026, 11, 9);
    final calc = calculatorOf({'A1': '=TODAY()'}, clock: () => now);
    expect(calc.valueAt(0, at('A1')), n(46335));
    now = DateTime(2026, 11, 10);
    calc.setCell(0, at('B1'), cellOf(1));
    expect(calc.valueAt(0, at('A1')), n(46336));
  });

  test('the locale changes text results', () {
    final calc = calculatorOf({'A1': '=2.5&""'});
    expect(calc.valueAt(0, at('A1')), t('2.5'));
    calc.locale = FormulaLocale.pt;
    expect(calc.valueAt(0, at('A1')), t('2,5'));
  });

  test('recalculateAll picks up cells written straight to the workbook', () {
    final calc = calculatorOf({'A1': 1});
    calc.workbook.sheets[0].setCell(at('B1'), cellOf('=A1+1'));
    calc.recalculateAll();
    expect(calc.valueAt(0, at('B1')), n(2));
  });
}
