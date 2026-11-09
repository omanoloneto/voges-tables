import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_style.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/chart.dart';
import 'package:voges_tables/sheet/workbook.dart';
import 'package:voges_tables/workbook/find.dart';
import 'package:voges_tables/workbook/selection.dart';
import 'package:voges_tables/workbook/workbook_controller.dart';

CellAddress at(String a1) => CellAddress.tryParse(a1)!;

CellRange range(String a1) {
  final [first, last] = a1.split(':');
  return CellRange(at(first), at(last));
}

WorkbookController controller() => WorkbookController(
  workbook: Workbook.blank('Sheet1'),
  locale: () => FormulaLocale.pt,
)..localeChanged();

Selection select(String a1) {
  final r = range(a1);
  return Selection(r.first, r.last);
}

void main() {
  group('merged cells', () {
    test('merging keeps the top left content, centers it and undoes', () {
      final c = controller();
      c.enter(at('A1'), 'Título');
      c.enter(at('B1'), 'perdido');
      c.select(select('A1:C1'));
      expect(c.mergeWouldClear, isTrue);
      c.mergeSelection();
      expect(c.sheet.merges, [range('A1:C1')]);
      expect(c.cellAt(at('B1')).constant, const EmptyValue());
      expect(c.cellAt(at('A1')).style.horizontal, HorizontalAlign.center);
      c.undo();
      expect(c.sheet.merges, isEmpty);
      expect(c.displayAt(at('B1')), 'perdido');
      c.redo();
      expect(c.sheet.merges, [range('A1:C1')]);
    });

    test('clicking inside a merge selects all of it', () {
      final c = controller();
      c.select(select('B2:C3'));
      c.mergeSelection();
      c.select(Selection.single(at('C3')));
      expect(c.selection.range, range('B2:C3'));
      expect(c.selection.active, at('B2'));
      c.select(select('A1:B2'));
      expect(c.selection.range, range('A1:C3'));
    });

    test('merges follow inserted and deleted rows', () {
      final c = controller();
      c.select(select('A2:B3'));
      c.mergeSelection();
      c.select(
        const Selection(
          CellAddress(0, 0),
          CellAddress(CellAddress.maxColumns - 1, 0),
        ),
      );
      c.insertRows();
      expect(c.sheet.merges, [range('A3:B4')]);
      c.select(
        const Selection(
          CellAddress(0, 3),
          CellAddress(CellAddress.maxColumns - 1, 3),
        ),
      );
      c.deleteRows();
      expect(c.sheet.merges, isEmpty);
      c.undo();
      expect(c.sheet.merges, [range('A3:B4')]);
    });

    test('copy and paste carry the merges, cut moves them', () {
      final c = controller();
      c.enter(at('A1'), 'x');
      c.select(select('A1:B1'));
      c.mergeSelection();
      c.select(select('A1:B2'));
      c.copy();
      c.select(Selection.single(at('D5')));
      c.paste();
      expect(c.sheet.merges, [range('A1:B1'), range('D5:E5')]);
      expect(c.displayAt(at('D5')), 'x');
      c.undo();
      expect(c.sheet.merges, [range('A1:B1')]);
      c.select(select('A1:B2'));
      c.copy(cut: true);
      c.select(Selection.single(at('A4')));
      c.paste();
      expect(c.sheet.merges, [range('A4:B4')]);
    });

    test('unmerging splits the merges under the selection', () {
      final c = controller();
      c.select(select('A1:B1'));
      c.mergeSelection();
      c.select(select('D1:E1'));
      c.mergeSelection();
      c.select(Selection.single(at('A1')));
      c.unmergeSelection();
      expect(c.sheet.merges, [range('D1:E1')]);
    });
  });

  group('find and replace', () {
    WorkbookController filled() {
      final c = controller();
      c.enter(at('A1'), 'Maçã');
      c.enter(at('B2'), 'maçã verde');
      c.enter(at('A3'), '12,5');
      c.enter(at('C3'), '=A3*2');
      return c;
    }

    test('finds by rows and wraps around', () {
      final c = filled();
      final query = FindQuery('maçã');
      expect(c.findAll(query), [at('A1'), at('B2')]);
      expect(c.findNext(query), at('B2'));
      expect(c.findNext(query), at('A1'));
      expect(c.findNext(query, backwards: true), at('B2'));
    });

    test('options: case, whole cell, wildcards and formulas', () {
      final c = filled();
      expect(c.findAll(FindQuery('maçã', matchCase: true)), [at('B2')]);
      expect(c.findAll(FindQuery('maçã', wholeCell: true)), [at('A1')]);
      expect(c.findAll(FindQuery('m*e')), [at('B2')]);
      expect(c.findAll(FindQuery('25')), [at('C3')]);
      expect(c.findAll(FindQuery('a3', inFormulas: true)), [at('C3')]);
    });

    test('replace all is one change that undoes at once', () {
      final c = filled();
      final count = c.replaceAll(FindQuery('maçã'), 'pera');
      expect(count, 2);
      expect(c.displayAt(at('A1')), 'pera');
      expect(c.displayAt(at('B2')), 'pera verde');
      c.undo();
      expect(c.displayAt(at('A1')), 'Maçã');
      expect(c.displayAt(at('B2')), 'maçã verde');
    });

    test('replacing in a formula changes what was typed', () {
      final c = filled();
      c.select(Selection.single(at('C3')));
      c.replaceNext(FindQuery('~*2', inFormulas: true), '*4');
      expect(c.cellAt(at('C3')).input, '=A3*4');
      expect(c.valueAt(at('C3')), const NumberValue(50));
    });
  });

  group('charts', () {
    WorkbookController sales() {
      final c = controller();
      c.enter(at('A1'), 'Mês');
      c.enter(at('B1'), 'Vendas');
      c.enter(at('C1'), 'Custos');
      c.enter(at('A2'), 'Jan');
      c.enter(at('B2'), '10');
      c.enter(at('C2'), '4');
      c.enter(at('A3'), 'Fev');
      c.enter(at('B3'), '20');
      c.enter(at('C3'), '7');
      return c;
    }

    test('a chart from one cell takes the whole block, as Excel', () {
      final c = sales();
      c.select(Selection.single(at('B2')));
      final index = c.insertChart(ChartKind.column)!;
      final chart = c.sheet.charts[index];
      expect(chart.categories?.range, range('A2:A3'));
      expect(
        [for (final s in chart.series) s.values.range],
        [range('B2:B3'), range('C2:C3')],
      );
      expect(
        [for (final s in chart.series) s.name?.range],
        [range('B1:B1'), range('C1:C1')],
      );
      expect(chart.from.cell, at('E1'));
      expect(chart.showLegend, isTrue);
      c.undo();
      expect(c.sheet.charts, isEmpty);
    });

    test('a pie keeps only the first series', () {
      final c = sales();
      c.select(select('A1:C3'));
      final index = c.insertChart(ChartKind.pie)!;
      final chart = c.sheet.charts[index];
      expect(chart.series, hasLength(1));
    });

    test('no numbers, no chart', () {
      final c = controller();
      c.enter(at('A1'), 'texto');
      c.select(Selection.single(at('A1')));
      expect(c.insertChart(ChartKind.line), isNull);
    });

    test('charts follow inserted rows and columns', () {
      final c = sales();
      c.select(Selection.single(at('A1')));
      c.insertChart(ChartKind.line);
      c.select(
        const Selection(
          CellAddress(0, 0),
          CellAddress(CellAddress.maxColumns - 1, 0),
        ),
      );
      c.insertRows();
      final chart = c.sheet.charts.single;
      expect(chart.series.first.values.range, range('B3:B4'));
      expect(chart.from.cell, at('E2'));
      c.undo();
      expect(c.sheet.charts.single.series.first.values.range, range('B2:B3'));
    });

    test('moving and deleting a chart undo', () {
      final c = sales();
      c.select(Selection.single(at('A1')));
      c.insertChart(ChartKind.bar);
      final chart = c.sheet.charts.single;
      c.updateChart(0, chart.copyWith(title: () => 'Resultado'));
      expect(c.sheet.charts.single.title, 'Resultado');
      c.deleteChart(0);
      expect(c.sheet.charts, isEmpty);
      c.undo();
      c.undo();
      expect(c.sheet.charts.single.title, isNull);
    });
  });
}
