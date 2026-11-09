import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/sheet/cell_address.dart';

void main() {
  test('column names round trip', () {
    for (var c = 0; c < CellAddress.maxColumns; c++) {
      expect(CellAddress.columnIndex(CellAddress.columnName(c)), c);
    }
    expect(CellAddress.columnName(0), 'A');
    expect(CellAddress.columnName(25), 'Z');
    expect(CellAddress.columnName(26), 'AA');
    expect(CellAddress.columnName(701), 'ZZ');
    expect(CellAddress.columnName(702), 'AAA');
    expect(CellAddress.columnName(16383), 'XFD');
  });
}
