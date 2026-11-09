import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/ast.dart';
import 'package:voges_tables/formula/parser.dart';
import 'package:voges_tables/sheet/cell_address.dart';
import 'package:voges_tables/sheet/cell_value.dart';

import 'package:voges_tables/formula/locale.dart';

import 'helpers.dart';

const ptLocale = FormulaLocale.pt;

void main() {
  group('precedence', () {
    test('multiplication before addition', () {
      expect(evaluate('=1+2*3'), n(7));
      expect(evaluate('=(1+2)*3'), n(9));
    });
    test('negation binds tighter than power', () {
      expect(evaluate('=-2^2'), n(4));
      expect(evaluate('=0-2^2'), n(-4));
    });
    test('power is left associative', () => expect(evaluate('=2^3^2'), n(64)));
    test('percent binds tighter than power', () {
      expect(evaluate('=50%'), n(0.5));
      expect(evaluate('=200%^2'), n(4));
      expect(evaluate('=10+5%'), n(10.05));
    });
    test('concatenation is below arithmetic', () {
      expect(evaluate('="a"&1+2'), t('a3'));
    });
    test('comparison is the lowest', () {
      expect(evaluate('=1+1=2'), b(true));
      expect(evaluate('="a"&"b"="AB"'), b(true));
      expect(evaluate('=1<>1'), b(false));
      expect(evaluate('=2>=3'), b(false));
      expect(evaluate('=2<=3'), b(true));
    });
    test('subtraction and division are left associative', () {
      expect(evaluate('=10-3-2'), n(5));
      expect(evaluate('=12/3/2'), n(2));
    });
    test('unary plus and double negation', () {
      expect(evaluate('=+5'), n(5));
      expect(evaluate('=--5'), n(5));
      expect(evaluate('=2*-3'), n(-6));
    });
  });

  group('literals and references', () {
    test('numbers, strings with doubled quotes, booleans and errors', () {
      expect(evaluate('=1.5e2'), n(150));
      expect(evaluate('=.5'), n(0.5));
      expect(evaluate('="say ""hi"""'), t('say "hi"'));
      expect(evaluate('=true'), b(true));
      expect(evaluate('=#N/A'), e(CellError.na));
      expect(evaluate('=#div/0!'), e(CellError.div0));
    });

    test('absolute references, whole columns and rows', () {
      final abs = parseFormula(r'=$B$2') as ReferenceExpr;
      expect(abs.range, CellRange.single(const CellAddress(1, 1)));
      final columns = parseFormula('=A:B') as ReferenceExpr;
      expect(columns.range.first, const CellAddress(0, 0));
      expect(columns.range.last, const CellAddress(1, CellAddress.maxRows - 1));
      final rows = parseFormula(r'=2:$3') as ReferenceExpr;
      expect(rows.range.first, const CellAddress(0, 1));
      expect(rows.range.last, const CellAddress(CellAddress.maxColumns - 1, 2));
    });

    test('sheet references, quoted or not', () {
      final plain = parseFormula('=Sheet2!A1') as ReferenceExpr;
      expect(plain.sheet, 'Sheet2');
      final quoted = parseFormula("='My ''big'' sheet'!A1:B2") as ReferenceExpr;
      expect(quoted.sheet, "My 'big' sheet");
      expect(quoted.range.a1, 'A1:B2');
    });

    test('function calls with missing arguments', () {
      final call = parseFormula('=IF(A1,,2)') as CallExpr;
      expect(call.name, 'IF');
      expect(call.arguments[1], isA<MissingExpr>());
      expect((parseFormula('=_xlfn.STDEV.S(1,2)') as CallExpr).name, 'STDEV.S');
    });

    test('a reference pointing to an empty cell shows 0', () {
      expect(evaluate('=A1'), n(0));
    });

    test('implicit intersection with the formula row', () {
      expect(evaluate('=A99:A101', {'A100': 7}), n(7));
      expect(evaluate('=A1:A3', {'A1': 1}), e(CellError.value));
    });
  });

  group('errors', () {
    test('syntax errors never throw', () {
      expect(evaluate('=1+'), e(CellError.value));
      expect(evaluate('=(1'), e(CellError.value));
      expect(evaluate('=SUM(1'), e(CellError.value));
      expect(evaluate('=1 2'), e(CellError.value));
      expect(evaluate('="abc'), e(CellError.name));
      expect(evaluate('=1@2'), e(CellError.name));
    });
    test('unknown names and functions are #NAME?', () {
      expect(evaluate('=foo'), e(CellError.name));
      expect(evaluate('=NOPE(1)'), e(CellError.name));
    });
    test('wrong argument count is #VALUE!', () {
      expect(evaluate('=ABS(1,2)'), e(CellError.value));
    });
    test('missing sheet is #REF!', () {
      expect(evaluate('=Nope!A1'), e(CellError.ref));
    });
    test('arithmetic errors', () {
      expect(evaluate('=1/0'), e(CellError.div0));
      expect(evaluate('=0^0'), e(CellError.num));
      expect(evaluate('=(-8)^0.5'), e(CellError.num));
      expect(evaluate('="a"+1'), e(CellError.value));
    });
    test('errors propagate from the left first', () {
      expect(evaluate('=#N/A+1/0'), e(CellError.na));
      expect(evaluate('=1/0&#N/A'), e(CellError.div0));
    });
    test('deep nesting is an error, not a crash', () {
      final deep = '=${'(' * 500}1${')' * 500}';
      expect(evaluate(deep), e(CellError.value));
    });
  });

  group('coercion', () {
    test('text that looks like a number takes part in arithmetic', () {
      expect(evaluate('="2"+3'), n(5));
      expect(evaluate('=" 4 "*2'), n(8));
      expect(evaluate('="10%"*1'), n(0.1));
      expect(evaluate('=TRUE+TRUE'), n(2));
      expect(evaluate('=A1+1'), n(1));
    });
    test('text uses the locale decimal in pt', () {
      expect(evaluate('="1,5"*2', {}, ptLocale), n(3));
      expect(evaluate('=1.5&""', {}, ptLocale), t('1,5'));
      expect(evaluate('=TRUE&""', {}, ptLocale), t('VERDADEIRO'));
    });
    test('comparisons across types follow Excel', () {
      expect(evaluate('=1<"a"'), b(true));
      expect(evaluate('="z"<TRUE'), b(true));
      expect(evaluate('="ABC"="abc"'), b(true));
      expect(evaluate('=A1=0'), b(true));
      expect(evaluate('=A1=""'), b(true));
      expect(evaluate('=0.1+0.2=0.3'), b(true));
    });
  });
}
