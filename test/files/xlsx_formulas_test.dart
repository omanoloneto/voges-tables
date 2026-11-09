import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/files/xlsx/xlsx_formulas.dart';

void main() {
  group('shiftFormula', () {
    test('moves relative references and keeps absolute ones', () {
      expect(shiftFormula(r'A1+$B$1+C$1+$D1', 2, 3), r'C4+$B$1+E$1+$D4');
    });

    test('moves ranges, whole columns and whole rows', () {
      expect(shiftFormula('SUM(A1:B2)', 1, 1), 'SUM(B2:C3)');
      expect(shiftFormula(r'SUM(A:A,$B:C)', 1, 0), r'SUM(B:B,$B:D)');
      expect(shiftFormula(r'SUM(1:1,$2:3)', 0, 2), r'SUM(3:3,$2:5)');
    });

    test('leaves strings, quoted sheet names and functions alone', () {
      expect(
        shiftFormula('"A1"&\'A1\'!A1&LOG10(A1)&Sheet2!B2', 1, 1),
        '"A1"&\'A1\'!B2&LOG10(B2)&Sheet2!C3',
      );
      expect(shiftFormula('"say ""A1"""&A1', 0, 1), '"say ""A1"""&A2');
      expect(shiftFormula('Table1[Col A1]+A1', 0, 1), 'Table1[Col A1]+A2');
    });

    test('does not mistake names or numbers for references', () {
      expect(
        shiftFormula('TRUE+1.5+ROUND(A1,2)', 0, 1),
        'TRUE+1.5+ROUND(A2,2)',
      );
      expect(shiftFormula('ABCD1+A1', 0, 1), 'ABCD1+A2');
    });

    test('references pushed off the sheet become #REF!', () {
      expect(shiftFormula('A1', -1, 0), '#REF!');
      expect(shiftFormula('XFD1048576', 0, 1), '#REF!');
    });
  });

  group('future functions', () {
    test('strips the prefixes on read', () {
      expect(
        formulaFromXlsx('_xlfn.XLOOKUP(A1,_xlfn._xlws.SORT(B:B),C:C)'),
        'XLOOKUP(A1,SORT(B:B),C:C)',
      );
      expect(formulaFromXlsx('"_xlfn.IFS("'), '"_xlfn.IFS("');
    });

    test('adds them back on write', () {
      expect(
        formulaToXlsx('IFS(A1>1,1,TRUE,0)+SUM(stdev.s(B1:B3))'),
        '_xlfn.IFS(A1>1,1,TRUE,0)+SUM(_xlfn.STDEV.S(B1:B3))',
      );
      expect(formulaToXlsx('FILTER(A:A,B:B)'), '_xlfn._xlws.FILTER(A:A,B:B)');
      expect(
        formulaToXlsx('"IFS(" & CONCATENATE(A1)'),
        '"IFS(" & CONCATENATE(A1)',
      );
      expect(formulaToXlsx('T.DIST.RT(1,2)'), '_xlfn.T.DIST.RT(1,2)');
    });
  });
}
