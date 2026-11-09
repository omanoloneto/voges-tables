import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/sheet/cell_value.dart';

import 'helpers.dart';

void main() {
  group('text', () {
    test('LEN, LEFT, RIGHT, MID', () {
      expect(evaluate('=LEN("hello")'), n(5));
      expect(evaluate('=LEN(12.5)'), n(4));
      expect(evaluate('=LEFT("hello",2)'), t('he'));
      expect(evaluate('=LEFT("hello")'), t('h'));
      expect(evaluate('=RIGHT("hello",3)'), t('llo'));
      expect(evaluate('=RIGHT("hi",9)'), t('hi'));
      expect(evaluate('=MID("hello",2,3)'), t('ell'));
      expect(evaluate('=MID("hello",9,3)'), t(''));
      expect(evaluate('=MID("hello",0,3)'), e(CellError.value));
      expect(evaluate('=LEFT("hello",-1)'), e(CellError.value));
    });
    test('UPPER, LOWER, PROPER, TRIM', () {
      expect(evaluate('=UPPER("ação")'), t('AÇÃO'));
      expect(evaluate('=LOWER("ABC")'), t('abc'));
      expect(
        evaluate('=PROPER("joão da SILVA-souza")'),
        t('João Da Silva-Souza'),
      );
      expect(evaluate('=TRIM("  a   b  ")'), t('a b'));
    });
    test('CONCATENATE, CONCAT, TEXTJOIN', () {
      final cells = {'A1': 'a', 'A2': 2, 'A4': 'd'};
      expect(evaluate('=CONCATENATE("x",1,TRUE)'), t('x1TRUE'));
      expect(evaluate('=CONCAT(A1:A4,"!")', cells), t('a2d!'));
      expect(evaluate('=TEXTJOIN(", ",TRUE,A1:A4)', cells), t('a, 2, d'));
      expect(evaluate('=TEXTJOIN("-",FALSE,"a","","b")'), t('a--b'));
    });
    test('TEXT with number and date codes', () {
      expect(evaluate('=TEXT(1234.567,"0.00")'), t('1234.57'));
      expect(evaluate('=TEXT(1234.567,"#,##0.00")'), t('1,234.57'));
      expect(evaluate('=TEXT(0.256,"0.0%")'), t('25.6%'));
      expect(evaluate('=TEXT(5,"000")'), t('005'));
      expect(evaluate('=TEXT(-5,"0;(0)")'), t('(5)'));
      expect(evaluate(r'=TEXT(5.5,"$#,##0.00")'), t(r'$5.50'));
      expect(evaluate('=TEXT(12345,"0.00E+00")'), t('1.23E+04'));
      expect(evaluate('=TEXT(46331,"dd/mm/yyyy")'), t('05/11/2026'));
      expect(evaluate('=TEXT(46331,"mmmm d, yyyy")'), t('November 5, 2026'));
      expect(evaluate('=TEXT(46331,"ddd")'), t('Thu'));
      expect(evaluate('=TEXT(0.75,"hh:mm")'), t('18:00'));
      expect(evaluate('=TEXT(0.75,"h:mm AM/PM")'), t('6:00 PM'));
      expect(evaluate('=TEXT("abc","@!")'), t('abc!'));
    });
    test('TEXT uses pt separators and aaaa years', () {
      const pt = FormulaLocale.pt;
      expect(evaluate('=TEXT(1234.5,"#.##0,00")', {}, pt), t('1.234,50'));
      expect(evaluate('=TEXT(46331,"dd/mm/aaaa")', {}, pt), t('05/11/2026'));
      expect(
        evaluate('=TEXT(46331,"dddd, d ""de"" mmmm")', {}, pt),
        t('quinta-feira, 5 de novembro'),
      );
    });
    test('VALUE', () {
      expect(evaluate('=VALUE("12.5")'), n(12.5));
      expect(evaluate('=VALUE("10%")'), n(0.1));
      expect(evaluate('=VALUE("abc")'), e(CellError.value));
      expect(evaluate('=VALUE("1.234,5")', {}, FormulaLocale.pt), n(1234.5));
    });
    test('FIND is case-sensitive, SEARCH is not and takes wildcards', () {
      expect(evaluate('=FIND("l","hello")'), n(3));
      expect(evaluate('=FIND("l","hello",4)'), n(4));
      expect(evaluate('=FIND("L","hello")'), e(CellError.value));
      expect(evaluate('=SEARCH("L","hello")'), n(3));
      expect(evaluate('=SEARCH("e?l","hello")'), n(2));
      expect(evaluate('=SEARCH("z","hello")'), e(CellError.value));
    });
    test('SUBSTITUTE, REPT, EXACT', () {
      expect(evaluate('=SUBSTITUTE("a-b-c","-","+")'), t('a+b+c'));
      expect(evaluate('=SUBSTITUTE("a-b-c","-","+",2)'), t('a-b+c'));
      expect(evaluate('=SUBSTITUTE("a-b","x","+")'), t('a-b'));
      expect(evaluate('=REPT("ab",3)'), t('ababab'));
      expect(evaluate('=REPT("ab",-1)'), e(CellError.value));
      expect(evaluate('=EXACT("a","A")'), b(false));
      expect(evaluate('=EXACT("a","a")'), b(true));
    });
  });

  group('dates', () {
    test('TODAY and NOW use the clock', () {
      expect(evaluate('=TODAY()'), n(46335));
      final now = evaluate('=NOW()') as NumberValue;
      expect(
        now.value,
        closeTo(46335 + (14 * 3600 + 30 * 60 + 15) / 86400, 1e-9),
      );
    });
    test('DATE rolls over and keeps the fake leap day', () {
      expect(evaluate('=DATE(2026,11,5)'), n(46331));
      expect(evaluate('=DATE(2026,13,1)'), n(46388));
      expect(evaluate('=DATE(2026,3,0)'), n(46081));
      expect(evaluate('=DATE(1900,2,29)'), n(60));
      expect(evaluate('=DATE(1900,3,1)'), n(61));
      expect(evaluate('=DATE(126,1,1)'), n(46023));
      expect(evaluate('=DATE(1900,0,1)'), e(CellError.num));
    });
    test('YEAR, MONTH, DAY, also from typed dates', () {
      expect(evaluate('=YEAR(46331)'), n(2026));
      expect(evaluate('=MONTH(46331)'), n(11));
      expect(evaluate('=DAY(46331)'), n(5));
      expect(evaluate('=DAY(60)'), n(29));
      expect(evaluate('=MONTH("11/5/2026")'), n(11));
      expect(evaluate('=MONTH("05/11/2026")', {}, FormulaLocale.pt), n(11));
      expect(evaluate('=YEAR(-1)'), e(CellError.num));
    });
    test('WEEKDAY in its return types', () {
      expect(evaluate('=WEEKDAY(46331)'), n(5));
      expect(evaluate('=WEEKDAY(46331,2)'), n(4));
      expect(evaluate('=WEEKDAY(46331,3)'), n(3));
      expect(evaluate('=WEEKDAY(46331,16)'), n(6));
      expect(evaluate('=WEEKDAY(1)'), n(1));
      expect(evaluate('=WEEKDAY(46331,9)'), e(CellError.num));
    });
    test('DATEDIF in every unit', () {
      const start = 'DATE(2020,1,31)';
      const end = 'DATE(2026,3,15)';
      expect(evaluate('=DATEDIF($start,$end,"Y")'), n(6));
      expect(evaluate('=DATEDIF($start,$end,"M")'), n(73));
      expect(evaluate('=DATEDIF($start,$end,"D")'), n(2235));
      expect(evaluate('=DATEDIF($start,$end,"YM")'), n(1));
      expect(evaluate('=DATEDIF($start,$end,"MD")'), n(12));
      expect(evaluate('=DATEDIF($start,$end,"YD")'), n(43));
      expect(evaluate('=DATEDIF($end,$start,"D")'), e(CellError.num));
    });
    test('DAYS, EDATE, EOMONTH', () {
      expect(evaluate('=DAYS(DATE(2026,3,1),DATE(2026,2,1))'), n(28));
      expect(evaluate('=EDATE(DATE(2026,1,31),1)'), n(46081));
      expect(evaluate('=EDATE(DATE(2026,3,31),-1)'), n(46081));
      expect(evaluate('=EOMONTH(DATE(2024,1,15),1)'), n(45351));
      expect(evaluate('=EOMONTH(DATE(2026,1,15),0)'), n(46053));
    });
    test('HOUR, MINUTE, SECOND, TIME', () {
      expect(evaluate('=HOUR(0.75)'), n(18));
      expect(evaluate('=MINUTE("13:45")'), n(45));
      expect(evaluate('=SECOND(TIME(1,2,3))'), n(3));
      expect(evaluate('=TIME(12,0,0)'), n(0.5));
      expect(evaluate('=TIME(25,0,0)'), n(1 / 24));
      expect(evaluate('=TIME(-1,0,0)'), e(CellError.num));
    });
  });
}
