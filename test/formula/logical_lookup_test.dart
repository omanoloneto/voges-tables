import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/sheet/cell_value.dart';

import 'helpers.dart';

const table = <String, Object>{
  'A1': 'id',
  'B1': 'name',
  'C1': 'price',
  'A2': 10,
  'B2': 'pen',
  'C2': 1.5,
  'A3': 20,
  'B3': 'book',
  'C3': 12,
  'A4': 30,
  'B4': 'bag',
  'C4': 40,
};

void main() {
  group('logical', () {
    test('IF picks a branch and skips the other', () {
      expect(evaluate('=IF(1>0,"yes","no")'), t('yes'));
      expect(evaluate('=IF(0,"yes","no")'), t('no'));
      expect(evaluate('=IF(FALSE,1/0,2)'), n(2));
      expect(evaluate('=IF(FALSE,1)'), b(false));
      expect(evaluate('=IF(TRUE,,1)'), n(0));
      expect(evaluate('=IF("x",1,2)'), e(CellError.value));
      expect(evaluate('=IF(#N/A,1,2)'), e(CellError.na));
    });
    test('IFS', () {
      expect(evaluate('=IFS(1>2,"a",2>1,"b")'), t('b'));
      expect(evaluate('=IFS(FALSE,1)'), e(CellError.na));
    });
    test('IFERROR', () {
      expect(evaluate('=IFERROR(1/0,"oops")'), t('oops'));
      expect(evaluate('=IFERROR(5,"oops")'), n(5));
      expect(evaluate('=IFERROR(NOPE(),0)'), n(0));
    });
    test('AND, OR, XOR, NOT', () {
      expect(evaluate('=AND(TRUE,1,A1:A2)', {'A1': true, 'A2': 'x'}), b(true));
      expect(evaluate('=AND(TRUE,0)'), b(false));
      expect(evaluate('=OR(FALSE,0,1)'), b(true));
      expect(evaluate('=XOR(TRUE,TRUE,TRUE)'), b(true));
      expect(evaluate('=XOR(TRUE,TRUE)'), b(false));
      expect(evaluate('=NOT(1)'), b(false));
      expect(evaluate('=AND(A1:A2)'), e(CellError.value));
      expect(evaluate('=TRUE()'), b(true));
      expect(evaluate('=FALSE()'), b(false));
    });
  });

  group('information', () {
    test('IS functions never propagate errors', () {
      expect(evaluate('=ISBLANK(A1)'), b(true));
      expect(evaluate('=ISBLANK("")'), b(false));
      expect(evaluate('=ISNUMBER(A1)', {'A1': 5}), b(true));
      expect(evaluate('=ISNUMBER("5")'), b(false));
      expect(evaluate('=ISTEXT("5")'), b(true));
      expect(evaluate('=ISERROR(1/0)'), b(true));
      expect(evaluate('=ISERROR(1)'), b(false));
      expect(evaluate('=ISNA(NA())'), b(true));
      expect(evaluate('=ISNA(1/0)'), b(false));
      expect(evaluate('=NA()'), e(CellError.na));
    });
  });

  group('lookup', () {
    test('VLOOKUP exact and approximate', () {
      expect(evaluate('=VLOOKUP(20,A2:C4,2,FALSE)', table), t('book'));
      expect(evaluate('=VLOOKUP(25,A2:C4,3)', table), n(12));
      expect(evaluate('=VLOOKUP(5,A2:C4,3)', table), e(CellError.na));
      expect(evaluate('=VLOOKUP(99,A2:C4,2,FALSE)', table), e(CellError.na));
      expect(evaluate('=VLOOKUP(10,A2:C4,4,FALSE)', table), e(CellError.ref));
      expect(evaluate('=VLOOKUP(10,A2:C4,0,FALSE)', table), e(CellError.value));
      expect(evaluate('=VLOOKUP(30,A:C,3,FALSE)', table), n(40));
    });
    test('VLOOKUP finds text ignoring case, with wildcards', () {
      final names = {'A1': 'Ana', 'B1': 1, 'A2': 'Bruno', 'B2': 2};
      expect(evaluate('=VLOOKUP("bruno",A1:B2,2,FALSE)', names), n(2));
      expect(evaluate('=VLOOKUP("B*",A1:B2,2,FALSE)', names), n(2));
      expect(
        evaluate('=VLOOKUP("5",A1:B1,2,FALSE)', {'A1': 5, 'B1': 1}),
        e(CellError.na),
      );
    });
    test('HLOOKUP', () {
      expect(evaluate('=HLOOKUP("price",A1:C4,3,FALSE)', table), n(12));
      expect(evaluate('=HLOOKUP("name",A1:C4,4,FALSE)', table), t('bag'));
    });
    test('MATCH in every mode', () {
      expect(evaluate('=MATCH(20,A2:A4,0)', table), n(2));
      expect(evaluate('=MATCH(25,A2:A4)', table), n(2));
      expect(evaluate('=MATCH("price",A1:C1,0)', table), n(3));
      expect(evaluate('=MATCH("b*",B2:B4,0)', table), n(2));
      final descending = {'A1': 30, 'A2': 20, 'A3': 10};
      expect(evaluate('=MATCH(25,A1:A3,-1)', descending), n(1));
      expect(evaluate('=MATCH(1,A2:A4,0)', table), e(CellError.na));
    });
    test('XLOOKUP', () {
      expect(evaluate('=XLOOKUP("bag",B2:B4,C2:C4)', table), n(40));
      expect(evaluate('=XLOOKUP("none",B2:B4,C2:C4,"-")', table), t('-'));
      expect(evaluate('=XLOOKUP("none",B2:B4,C2:C4)', table), e(CellError.na));
      expect(evaluate('=XLOOKUP(25,A2:A4,B2:B4,,-1)', table), t('book'));
      expect(evaluate('=XLOOKUP(25,A2:A4,B2:B4,,1)', table), t('bag'));
      expect(evaluate('=XLOOKUP("b*",B2:B4,A2:A4,,2,-1)', table), n(30));
      expect(evaluate('=XLOOKUP("price",A1:C1,A3:C3)', table), n(12));
    });
    test('INDEX by row, column and inside a range', () {
      expect(evaluate('=INDEX(A2:C4,2,3)', table), n(12));
      expect(evaluate('=INDEX(B2:B4,3)', table), t('bag'));
      expect(evaluate('=INDEX(A1:C1,2)', table), t('name'));
      expect(evaluate('=SUM(INDEX(A2:C4,0,3))', table), n(53.5));
      expect(evaluate('=INDEX(A2:C4,5,1)', table), e(CellError.ref));
      expect(evaluate('=INDEX(A2:C4,MATCH("book",B2:B4,0),3)', table), n(12));
    });
    test('CHOOSE', () {
      expect(evaluate('=CHOOSE(2,"a","b","c")'), t('b'));
      expect(evaluate('=CHOOSE(4,"a","b","c")'), e(CellError.value));
      expect(evaluate('=SUM(CHOOSE(1,A2:A4,C2:C4))', table), n(60));
    });
    test('ROW, COLUMN, ROWS, COLUMNS', () {
      expect(evaluate('=ROW()'), n(100));
      expect(evaluate('=COLUMN()'), n(26));
      expect(evaluate('=ROW(C7)'), n(7));
      expect(evaluate('=COLUMN(C7:E9)'), n(3));
      expect(evaluate('=ROWS(C7:E9)'), n(3));
      expect(evaluate('=COLUMNS(C7:E9)'), n(3));
      expect(evaluate('=ROWS(A:A)'), n(1048576));
    });
  });
}
