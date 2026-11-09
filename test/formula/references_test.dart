import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/references.dart';

void main() {
  test('relative parts move, absolute parts stay', () {
    expect(shiftReferences(r'=A1+$B$2+C$3+$D4', 1, 2), r'=B3+$B$2+D$3+$D6');
  });

  test('ranges, whole columns and whole rows', () {
    expect(shiftReferences('=SUM(A1:B5)', 2, 1), '=SUM(C2:D6)');
    expect(shiftReferences(r'=SUM(A:A,$B:C)', 1, 5), r'=SUM(B:B,$B:D)');
    expect(shiftReferences(r'=SUM(1:1,$2:3)', 4, 2), r'=SUM(3:3,$2:5)');
  });

  test('sheet references move too', () {
    expect(
      shiftReferences("=Sheet2!A1+'My sheet'!B2:C3", 0, 1),
      "=Sheet2!A2+'My sheet'!B3:C4",
    );
  });

  test('strings, function names and numbers stay', () {
    expect(
      shiftReferences('=LOG10(A1)&"A1"&B2*3', 1, 1),
      '=LOG10(B2)&"A1"&C3*3',
    );
    expect(shiftReferences('=IF(TRUE,1.5,A1)', 1, 0), '=IF(TRUE,1.5,B1)');
  });

  test('references pushed off the sheet become #REF!', () {
    expect(shiftReferences('=A1+B2', -1, 0), '=#REF!+A2');
    expect(shiftReferences('=SUM(A1:B2)', 0, -1), '=SUM(#REF!)');
    expect(shiftReferences('=Sheet2!A1', 0, -1), '=#REF!');
    expect(shiftReferences('=XFD1', 1, 0), '=#REF!');
    expect(shiftReferences('=A1048576', 0, 1), '=#REF!');
  });

  test('not a formula is returned as is', () {
    expect(shiftReferences('A1', 1, 1), 'A1');
  });
}
