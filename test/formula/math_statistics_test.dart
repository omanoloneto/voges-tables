import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/sheet/cell_value.dart';

import 'package:voges_tables/formula/locale.dart';

import 'helpers.dart';

const ptLocale = FormulaLocale.pt;

const data = <String, Object>{
  'A1': 1,
  'A2': 2,
  'A3': 3,
  'A4': 'text',
  'A5': true,
  'B1': 4,
  'B2': 4,
  'B3': 9,
};

void main() {
  group('math', () {
    test('SUM ignores text and booleans in cells but not typed ones', () {
      expect(evaluate('=SUM(A1:A5)', data), n(6));
      expect(evaluate('=SUM(A1:A3,10,"5",TRUE)', data), n(22));
      expect(evaluate('=SUM("x")', data), e(CellError.value));
      expect(evaluate('=SUM(A:A)', data), n(6));
      expect(evaluate('=SUM(A1,#N/A)', data), e(CellError.na));
    });
    test('PRODUCT', () {
      expect(evaluate('=PRODUCT(A1:A3,2)', data), n(12));
      expect(evaluate('=PRODUCT(A4)', data), n(0));
    });
    test('ROUND, ROUNDUP, ROUNDDOWN', () {
      expect(evaluate('=ROUND(2.675,2)'), n(2.68));
      expect(evaluate('=ROUND(-2.5,0)'), n(-3));
      expect(evaluate('=ROUND(1234.5,-2)'), n(1200));
      expect(evaluate('=ROUNDUP(3.21,1)'), n(3.3));
      expect(evaluate('=ROUNDUP(-3.21,1)'), n(-3.3));
      expect(evaluate('=ROUNDDOWN(3.29,1)'), n(3.2));
    });
    test('INT, TRUNC, ABS', () {
      expect(evaluate('=INT(-2.5)'), n(-3));
      expect(evaluate('=TRUNC(-2.57)'), n(-2));
      expect(evaluate('=TRUNC(2.578,2)'), n(2.57));
      expect(evaluate('=ABS(-4)'), n(4));
    });
    test('MOD takes the sign of the divisor', () {
      expect(evaluate('=MOD(7,3)'), n(1));
      expect(evaluate('=MOD(-3,2)'), n(1));
      expect(evaluate('=MOD(3,-2)'), n(-1));
      expect(evaluate('=MOD(1,0)'), e(CellError.div0));
    });
    test('POWER, SQRT, PI', () {
      expect(evaluate('=POWER(2,10)'), n(1024));
      expect(evaluate('=SQRT(16)'), n(4));
      expect(evaluate('=SQRT(-1)'), e(CellError.num));
      expect(evaluate('=PI()'), n(3.141592653589793));
    });
    test('RAND and RANDBETWEEN stay in range', () {
      final rand = evaluate('=RAND()') as NumberValue;
      expect(rand.value, inInclusiveRange(0, 1));
      final between = evaluate('=RANDBETWEEN(3,5)') as NumberValue;
      expect([3.0, 4.0, 5.0], contains(between.value));
      expect(evaluate('=RANDBETWEEN(5,3)'), e(CellError.num));
    });
  });

  group('statistics', () {
    test('AVERAGE, MIN, MAX', () {
      expect(evaluate('=AVERAGE(A1:A5)', data), n(2));
      expect(evaluate('=AVERAGE(A4)', data), e(CellError.div0));
      expect(evaluate('=MIN(A1:B3)', data), n(1));
      expect(evaluate('=MAX(A1:B3)', data), n(9));
      expect(evaluate('=MAX(A4)', data), n(0));
    });
    test('COUNT, COUNTA, COUNTBLANK', () {
      expect(evaluate('=COUNT(A1:A6)', data), n(3));
      expect(evaluate('=COUNT(1,"2","x",TRUE)', data), n(3));
      expect(evaluate('=COUNTA(A1:A6)', data), n(5));
      expect(evaluate('=COUNTBLANK(A1:A10)', data), n(5));
      expect(evaluate('=COUNTBLANK(C:C)', data), n(1048576));
    });
    test('MEDIAN, MODE', () {
      expect(evaluate('=MEDIAN(A1:B3)', data), n(3.5));
      expect(evaluate('=MEDIAN(1,2,3)'), n(2));
      expect(evaluate('=MODE(A1:B3)', data), n(4));
      expect(evaluate('=MODE.SNGL(1,2,2,3,3)'), n(2));
      expect(evaluate('=MODE(1,2)'), e(CellError.na));
    });
    test('STDEV and VAR are sample statistics', () {
      expect(evaluate('=VAR(2,4,4,4,5,5,7,9)'), n(32 / 7));
      final stdev = evaluate('=STDEV.S(2,4,4,4,5,5,7,9)') as NumberValue;
      expect(stdev.value, closeTo(2.13809, 1e-5));
      expect(evaluate('=STDEV(1)'), e(CellError.div0));
      expect(evaluate('=VAR.S(1,3)'), n(2));
    });
    test('LARGE and SMALL', () {
      expect(evaluate('=LARGE(B1:B3,1)', data), n(9));
      expect(evaluate('=LARGE(B1:B3,2)', data), n(4));
      expect(evaluate('=SMALL(A1:A5,2)', data), n(2));
      expect(evaluate('=SMALL(A1:A5,4)', data), e(CellError.num));
    });
    test('RANK in both orders', () {
      expect(evaluate('=RANK(9,B1:B3)', data), n(1));
      expect(evaluate('=RANK(4,B1:B3)', data), n(2));
      expect(evaluate('=RANK.EQ(9,B1:B3,1)', data), n(3));
      expect(evaluate('=RANK(5,B1:B3)', data), e(CellError.na));
    });
  });

  group('criteria', () {
    const sales = <String, Object>{
      'A1': 'apple',
      'A2': 'banana',
      'A3': 'Apple pie',
      'A4': 'cherry',
      'A5': '',
      'B1': 10,
      'B2': 20,
      'B3': 30,
      'B4': 40,
      'B5': 50,
      'C1': 'x',
      'C2': 'y',
      'C3': 'x',
      'C4': 'x',
      'C5': 'y',
    };
    test('COUNTIF with numbers, operators and wildcards', () {
      expect(evaluate('=COUNTIF(B1:B5,">25")', sales), n(3));
      expect(evaluate('=COUNTIF(B1:B5,20)', sales), n(1));
      expect(evaluate('=COUNTIF(B1:B5,"<=20")', sales), n(2));
      expect(evaluate('=COUNTIF(A1:A5,"apple")', sales), n(1));
      expect(evaluate('=COUNTIF(A1:A5,"APPLE*")', sales), n(2));
      expect(evaluate('=COUNTIF(A1:A5,"?????")', sales), n(1));
      expect(evaluate('=COUNTIF(A1:A5,"<>apple")', sales), n(4));
      expect(evaluate('=COUNTIF(A1:A6,"")', sales), n(2));
      expect(evaluate('=COUNTIF(A1:A6,"<>")', sales), n(4));
      expect(evaluate('=COUNTIF(A:A,"*e*")', sales), n(3));
      expect(evaluate('=COUNTIF(B:B,">"&B2)', sales), n(3));
    });
    test('COUNTIF with an escaped wildcard', () {
      expect(evaluate('=COUNTIF(A1:A2,"~*")', {'A1': '*', 'A2': 'a'}), n(1));
    });
    test('SUMIF and AVERAGEIF', () {
      expect(evaluate('=SUMIF(A1:A5,"a*",B1:B5)', sales), n(40));
      expect(evaluate('=SUMIF(B1:B5,">20")', sales), n(120));
      expect(evaluate('=SUMIF(A:A,"cherry",B:B)', sales), n(40));
      expect(evaluate('=AVERAGEIF(C1:C5,"x",B1:B5)', sales), n(80 / 3));
      expect(evaluate('=AVERAGEIF(C1:C5,"z",B1:B5)', sales), e(CellError.div0));
    });
    test('COUNTIFS and SUMIFS', () {
      expect(evaluate('=COUNTIFS(C1:C5,"x",B1:B5,">15")', sales), n(2));
      expect(evaluate('=SUMIFS(B1:B5,C1:C5,"y",B1:B5,"<50")', sales), n(20));
      expect(evaluate('=SUMIFS(B:B,C:C,"x")', sales), n(80));
      expect(
        evaluate('=COUNTIFS(B1:B5,">0",C1:C4,"x")', sales),
        e(CellError.value),
      );
    });
    test('criteria in pt use the pt decimal and words', () {
      final values = {'A1': 1.5, 'A2': 2.5, 'A3': true};
      expect(evaluate('=COUNTIF(A1:A3,">2,0")', values, ptLocale), n(1));
      expect(evaluate('=COUNTIF(A1:A3,"VERDADEIRO")', values, ptLocale), n(1));
    });
  });
}
