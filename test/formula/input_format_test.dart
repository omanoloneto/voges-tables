import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/dates.dart';
import 'package:voges_tables/formula/format.dart';
import 'package:voges_tables/formula/input.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/sheet/cell_style.dart';
import 'package:voges_tables/sheet/cell_value.dart';
import 'package:voges_tables/sheet/workbook.dart';

import 'helpers.dart';

void main() {
  const pt = FormulaLocale.pt;
  const es = FormulaLocale.es;
  const en = FormulaLocale.en;

  group('dates', () {
    test('serials match Excel, fake leap day included', () {
      expect(dateToSerial(DateTime(1900, 1, 1)), 1);
      expect(dateToSerial(DateTime(1900, 2, 28)), 59);
      expect(dateToSerial(DateTime(1900, 3, 1)), 61);
      expect(dateToSerial(DateTime(2026, 11, 5)), 46331);
      expect(dateToSerial(DateTime(2026, 11, 5, 18)), 46331.75);
      expect(serialToYmd(60), (year: 1900, month: 2, day: 29));
      expect(serialToYmd(59), (year: 1900, month: 2, day: 28));
      expect(serialToDate(46331.5), DateTime.utc(2026, 11, 5, 12));
      expect(serialToDate(1), DateTime.utc(1900, 1, 1));
      expect(serialToTime(0.5 + 1 / 86400), (hour: 12, minute: 0, second: 1));
    });
  });

  group('parseInput', () {
    ParsedInput parse(String text, [FormulaLocale locale = en]) =>
        parseInput(text, locale);

    test('empty, text, forced text and a lone =', () {
      expect(parse('').constant, const EmptyValue());
      expect(parse('hello').constant, t('hello'));
      expect(parse("'123").constant, t('123'));
      expect(parse('=').constant, t('='));
    });
    test('formulas are stored canonical', () {
      final parsed = parse('=SOMA(A1;2,5)', pt);
      expect(parsed.isFormula, isTrue);
      expect(parsed.input, '=SUM(A1,2.5)');
    });
    test('numbers per locale', () {
      expect(parse('1234.5').constant, n(1234.5));
      expect(parse('1234.5').format, isNull);
      expect(parse('1,234.5').constant, n(1234.5));
      expect(parse('1,234.5').format?.kind, NumberKind.number);
      expect(parse('1.234,5', pt).constant, n(1234.5));
      expect(parse('2,5', es).constant, n(2.5));
      expect(parse('-3', pt).constant, n(-3));
      expect(parse('1,5E+3', pt).constant, n(1500));
      expect(parse('1.5', pt).constant, t('1.5'));
      expect(parse(' 42 ').constant, n(42));
    });
    test('percent and currency', () {
      expect(parse('10%').constant, n(0.1));
      expect(
        parse('10%').format,
        const NumberFormat(NumberKind.percent, decimals: 0),
      );
      expect(parse('12,5%', pt).format?.decimals, 2);
      expect(parse(r'R$ 5,50', pt).constant, n(5.5));
      expect(parse(r'R$ 5,50', pt).format?.kind, NumberKind.currency);
      expect(parse(r'-R$ 1.000', pt).constant, n(-1000));
      expect(parse(r'$5.50').constant, n(5.5));
      expect(parse('5,50 €', es).constant, n(5.5));
      expect(parse(r'$5.50', pt).constant, t(r'$5.50'));
    });
    test('dates and times', () {
      expect(parse('05/11/2026', pt).constant, n(46331));
      expect(parse('05/11/2026', pt).format?.kind, NumberKind.date);
      expect(parse('5/11/2026', es).constant, n(46331));
      expect(parse('11/5/2026').constant, n(46331));
      expect(parse('2026-11-05').constant, n(46331));
      expect(parse('5/11/26', pt).constant, n(46331));
      expect(parse('31/02/2026', pt).constant, t('31/02/2026'));
      expect(parse('13:45').constant, n((13 * 60 + 45) / 1440));
      expect(parse('13:45').format?.kind, NumberKind.time);
      expect(parse('1:30 PM').constant, n((13 * 60 + 30) / 1440));
      expect(parse('05/11/2026 18:00', pt).constant, n(46331.75));
      expect(parse('05/11/2026 18:00', pt).format?.kind, NumberKind.dateTime);
    });
    test('booleans and errors', () {
      expect(parse('TRUE').constant, b(true));
      expect(parse('verdadeiro', pt).constant, b(true));
      expect(parse('FALSO', es).constant, b(false));
      expect(parse('TRUE', pt).constant, t('TRUE'));
      expect(parse('#N/A').constant, e(CellError.na));
    });
    test('the suggested format only replaces General', () {
      final general = parse('10%').applyTo(const Cell());
      expect(general.style.format.kind, NumberKind.percent);
      const dated = Cell(
        style: CellStyle(format: NumberFormat(NumberKind.date)),
      );
      expect(parse('10%').applyTo(dated).style.format.kind, NumberKind.date);
    });
  });

  group('editText', () {
    Cell cell(CellValue value, [NumberKind kind = NumberKind.general]) => Cell(
      constant: value,
      style: CellStyle(format: NumberFormat(kind)),
    );

    test('formulas are localized', () {
      expect(editText(const Cell(input: '=SUM(A1,2.5)'), pt), '=SOMA(A1;2,5)');
    });
    test('constants are written as they would be typed', () {
      expect(editText(cell(n(1234.5)), pt), '1234,5');
      expect(editText(cell(n(1234.5)), en), '1234.5');
      expect(editText(cell(n(0.1), NumberKind.percent), pt), '10%');
      expect(editText(cell(n(0.125), NumberKind.percent), pt), '12,5%');
      expect(editText(cell(n(5.5), NumberKind.currency), pt), '5,5');
      expect(editText(cell(n(46331), NumberKind.date), pt), '05/11/2026');
      expect(editText(cell(n(46331), NumberKind.date), en), '11/5/2026');
      expect(
        editText(cell(n(46331.75), NumberKind.dateTime), pt),
        '05/11/2026 18:00',
      );
      expect(editText(cell(n(0.5), NumberKind.time), pt), '12:00');
      expect(editText(cell(b(true)), pt), 'VERDADEIRO');
      expect(editText(cell(t('123')), pt), "'123");
      expect(editText(cell(t('=x')), pt), "'=x");
      expect(editText(cell(t('hello')), pt), 'hello');
      expect(editText(cell(e(CellError.div0)), pt), '#DIV/0!');
      expect(editText(const Cell(), pt), '');
    });
    test('edit text parses back to the same constant', () {
      final values = [
        n(1234.5),
        n(-0.001),
        n(1e20),
        t('05/11/2026'),
        t("'x"),
        b(false),
      ];
      for (final locale in FormulaLocale.values) {
        for (final value in values) {
          final text = editText(cell(value), locale);
          expect(
            parseInput(text, locale).constant,
            value,
            reason: '$locale $text',
          );
        }
      }
    });
  });

  group('formatValue', () {
    String show(
      CellValue value,
      NumberFormat format, [
      FormulaLocale locale = en,
    ]) => formatValue(value, format, locale);
    const general = NumberFormat.general;

    test('general keeps about ten significant digits', () {
      expect(show(n(0), general), '0');
      expect(show(n(1 / 3), general), '0.333333333');
      expect(show(n(0.1 + 0.2), general), '0.3');
      expect(show(n(123456.789), general), '123456.789');
      expect(show(n(12345678901), general), '12345678901');
      expect(show(n(123456789012), general), '1.23457E+11');
      expect(show(n(0.00001234), general), '1.234E-05');
      expect(show(n(0.0001), general), '0.0001');
      expect(show(n(-2.5), general, pt), '-2,5');
    });
    test('numbers with decimals and thousands', () {
      const format = NumberFormat(NumberKind.number);
      expect(show(n(1234567.891), format), '1,234,567.89');
      expect(show(n(1234567.891), format, pt), '1.234.567,89');
      expect(show(n(2.675), format), '2.68');
      expect(show(n(-0.001), format), '0.00');
      expect(
        show(
          n(1234.5),
          const NumberFormat(NumberKind.number, decimals: 0, thousands: false),
        ),
        '1235',
      );
    });
    test('currency per locale', () {
      const format = NumberFormat(NumberKind.currency);
      expect(show(n(1234.5), format, pt), r'R$ 1.234,50');
      expect(show(n(1234.5), format, en), r'$1,234.50');
      expect(show(n(1234.5), format, es), '1.234,50 €');
      expect(show(n(-5), format, pt), r'-R$ 5,00');
    });
    test('percent, dates and times', () {
      expect(
        show(n(0.125), const NumberFormat(NumberKind.percent, decimals: 1), pt),
        '12,5%',
      );
      expect(
        show(n(46331), const NumberFormat(NumberKind.date), pt),
        '05/11/2026',
      );
      expect(
        show(n(46331), const NumberFormat(NumberKind.date), es),
        '05/11/2026',
      );
      expect(
        show(n(46331), const NumberFormat(NumberKind.date), en),
        '11/5/2026',
      );
      expect(
        show(n(60), const NumberFormat(NumberKind.date), pt),
        '29/02/1900',
      );
      expect(
        show(n(0.5729166666666666), const NumberFormat(NumberKind.time)),
        '13:45',
      );
      expect(
        show(n(46331.75), const NumberFormat(NumberKind.dateTime), pt),
        '05/11/2026 18:00',
      );
      expect(show(n(-1), const NumberFormat(NumberKind.date)), '#####');
    });
    test('booleans, text, errors and empty', () {
      expect(show(b(true), general, pt), 'VERDADEIRO');
      expect(show(b(false), general, es), 'FALSO');
      expect(show(b(true), general), 'TRUE');
      expect(show(t('abc'), general), 'abc');
      expect(show(e(CellError.na), general, pt), '#N/A');
      expect(show(const EmptyValue(), general), '');
    });
  });
}
