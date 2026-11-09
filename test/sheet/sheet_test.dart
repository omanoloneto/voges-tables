import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/structure.dart';
import 'package:voges_tables/sheet/workbook.dart';

const one = Cell(constant: NumberValue(1));

void main() {
  test('the used range follows cells coming and going', () {
    final sheet = Sheet('S');
    expect(sheet.usedRange, isNull);
    sheet.setCell(const CellAddress(2, 9), one);
    sheet.setCell(const CellAddress(4, 1), one);
    expect(sheet.usedRange?.last, const CellAddress(4, 9));
    sheet.setCell(const CellAddress(4, 1), const Cell());
    expect(sheet.usedRange?.last, const CellAddress(2, 9));
    sheet.setCell(const CellAddress(2, 9), const Cell());
    expect(sheet.usedRange, isNull);
  });

  test('sizes and frozen panes move with rows and columns', () {
    final sheet = Sheet('S')
      ..rowHeights = {1: 30, 5: 40}
      ..columnWidths = {0: 100, 3: 50}
      ..frozenRows = 2
      ..frozenColumns = 1;
    sheet.moveLayout(
      const StructureEdit(sheet: 0, axis: SheetAxis.rows, at: 1, count: 2),
    );
    expect(sheet.rowHeights, {3: 30, 7: 40});
    expect(sheet.frozenRows, 4);
    sheet.moveLayout(
      const StructureEdit(sheet: 0, axis: SheetAxis.columns, at: 0, count: -1),
    );
    expect(sheet.columnWidths, {2: 50});
    expect(sheet.frozenColumns, 0);
  });
}
