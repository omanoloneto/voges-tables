import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/formula.dart';
import 'package:voges_tables/sheet/cell_address.dart';

void main() {
  test('a cell key gives back its sheet and address', () {
    for (final (sheet, column, row) in [
      (0, 0, 0),
      (3, 16383, 1048575),
      (250, 7, 99999),
      (1, 16000, 0),
    ]) {
      final key = cellKey(sheet, CellAddress(column, row));
      expect(key.sheet, sheet);
      expect(key.address, CellAddress(column, row));
    }
    expect(
      cellKey(0, const CellAddress(1, 2)),
      isNot(cellKey(0, const CellAddress(2, 1))),
    );
  });
}
