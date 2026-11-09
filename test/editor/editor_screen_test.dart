import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/app.dart';
import 'package:voges_tables/editor/find_bar.dart';
import 'package:voges_tables/files/spreadsheet_files.dart';
import 'package:voges_tables/files/system_open.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/grid/chart_frame.dart';
import 'package:voges_tables/grid/spreadsheet_grid.dart';
import 'package:voges_tables/l10n/app_language.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/chart.dart';
import 'package:voges_tables/sheet/workbook.dart';
import 'package:voges_tables/workbook/selection.dart';
import 'package:voges_tables/workbook/workbook_controller.dart';

CellAddress at(String a1) => CellAddress.tryParse(a1)!;

Future<WorkbookController> pumpEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = WorkbookController(
    workbook: Workbook.blank('Planilha1'),
    locale: () => FormulaLocale.pt,
  );
  final files = SpreadsheetFiles();
  await tester.pumpWidget(
    VogesTablesApp(
      controller: controller,
      files: files,
      systemOpen: SystemOpen(files),
      language: AppLanguage(const Locale('pt')),
      launchArguments: const [],
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// A point of the grid, counting from its top left corner.
Offset onGrid(WidgetTester tester, double x, double y) =>
    tester.getTopLeft(find.byType(SpreadsheetGrid)) + Offset(x, y);

void main() {
  testWidgets('a right click on a row header inserts rows there', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    c.enter(at('A1'), '1');
    c.enter(at('A2'), '2');
    await tester.pump();
    await tester.tapAt(
      onGrid(tester, 10, 24 + 24 + 12),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(c.wholeRowsSelected, isTrue);
    await tester.tap(find.text('Inserir linhas'));
    await tester.pumpAndSettle();
    expect(c.displayAt(at('A1')), '1');
    expect(c.displayAt(at('A2')), '');
    expect(c.displayAt(at('A3')), '2');
  });

  testWidgets('the ribbon merges and unmerges the selection', (tester) async {
    final c = await pumpEditor(tester);
    c.enter(at('A1'), 'Título');
    c.select(Selection(at('A1'), at('C1')));
    await tester.pump();
    await tester.tap(find.byTooltip('Mesclar e centralizar'));
    await tester.pumpAndSettle();
    expect(c.sheet.merges.single.a1, 'A1:C1');
    await tester.tap(find.byTooltip('Desfazer mesclagem'));
    await tester.pumpAndSettle();
    expect(c.sheet.merges, isEmpty);
  });

  testWidgets('Ctrl+F finds the next match and Esc closes', (tester) async {
    final c = await pumpEditor(tester);
    c.enter(at('B3'), 'alvo');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(FindBar),
        matching: find.byType(TextField),
      ),
      'alvo',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(c.selection.active, at('B3'));
    expect(find.text('1 de 1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsNothing);
  });

  testWidgets('a chart is inserted from the ribbon and deleted with Delete', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    c.enter(at('A1'), 'Mês');
    c.enter(at('B1'), 'Total');
    c.enter(at('A2'), 'Jan');
    c.enter(at('B2'), '5');
    c.enter(at('A3'), 'Fev');
    c.enter(at('B3'), '8');
    c.select(Selection.single(at('A1')));
    await tester.pump();
    await tester.tap(find.text('Inserir gráfico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Colunas'));
    await tester.pumpAndSettle();
    expect(c.sheet.charts, hasLength(1));
    expect(find.byType(ChartFrame), findsOneWidget);
    expect(find.byTooltip('Excluir gráfico'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(c.sheet.charts, isEmpty);
    expect(find.byType(ChartFrame), findsNothing);
  });

  testWidgets('dragging a chart moves it', (tester) async {
    final c = await pumpEditor(tester);
    c.enter(at('A1'), '3');
    c.enter(at('A2'), '4');
    c.select(Selection.single(at('A1')));
    c.insertChart(ChartKind.line);
    await tester.pumpAndSettle();
    final before = c.sheet.charts.single.from;
    await tester.drag(find.byType(ChartFrame), const Offset(88, 48));
    await tester.pumpAndSettle();
    final after = c.sheet.charts.single.from;
    expect(after.cell.column, before.cell.column + 1);
    expect(after.cell.row, before.cell.row + 2);
  });
}
