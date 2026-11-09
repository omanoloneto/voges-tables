import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/files/xlsx/number_format_codes.dart';
import 'package:voges_tables/sheet/cell_style.dart';

void main() {
  group('numberFormatFromCode', () {
    const number = NumberKind.number;
    const currency = NumberKind.currency;
    final cases = <String, NumberFormat>{
      'General': NumberFormat.general,
      '0': const NumberFormat(number, decimals: 0, thousands: false),
      '0.00': const NumberFormat(number, thousands: false),
      '#,##0': const NumberFormat(number, decimals: 0),
      '#,##0.000;[Red]-#,##0.000': const NumberFormat(number, decimals: 3),
      '0.00E+00': const NumberFormat(number, thousands: false),
      '0%': const NumberFormat(NumberKind.percent, decimals: 0),
      '0.0%': const NumberFormat(NumberKind.percent, decimals: 1),
      r'"R$" #,##0.00': const NumberFormat(currency),
      r'"R$"\ #,##0.00': const NumberFormat(currency),
      r'[$R$-416] #,##0.00;[Red]-[$R$-416] #,##0.00': const NumberFormat(
        currency,
      ),
      r'#,##0.00 [$€-1]': const NumberFormat(currency),
      r'$#,##0': const NumberFormat(currency, decimals: 0),
      r'\$0.0': const NumberFormat(currency, decimals: 1, thousands: false),
      r'_-"€"* #,##0.00_-;\-"€"* #,##0.00_-': const NumberFormat(currency),
      r'[$-416]0.00': const NumberFormat(number, thousands: false),
      '0.00 "kg"': const NumberFormat(number, thousands: false),
      'dd/mm/yyyy': const NumberFormat(NumberKind.date),
      r'[$-416]d\ mmmm\ yyyy;@': const NumberFormat(NumberKind.date),
      'mmm-yy': const NumberFormat(NumberKind.date),
      'hh:mm': const NumberFormat(NumberKind.time),
      'mm:ss': const NumberFormat(NumberKind.time),
      '[h]:mm:ss': const NumberFormat(NumberKind.time),
      'h:mm AM/PM': const NumberFormat(NumberKind.time),
      'dd/mm/yyyy hh:mm': const NumberFormat(NumberKind.dateTime),
      'yyyy-mm-dd"T"hh:mm:ss': const NumberFormat(NumberKind.dateTime),
      '@': const NumberFormat(NumberKind.text),
      '"just text"': NumberFormat.general,
    };
    cases.forEach((code, expected) {
      test(code, () => expect(numberFormatFromCode(code), expected));
    });
  });

  test('built-in ids map like their codes', () {
    expect(
      numberFormatForId(14, const {}),
      const NumberFormat(NumberKind.date),
    );
    expect(
      numberFormatForId(22, const {}),
      const NumberFormat(NumberKind.dateTime),
    );
    expect(
      numberFormatForId(9, const {}),
      const NumberFormat(NumberKind.percent, decimals: 0),
    );
    expect(
      numberFormatForId(10, const {}),
      const NumberFormat(NumberKind.percent),
    );
    expect(
      numberFormatForId(44, const {}),
      const NumberFormat(NumberKind.currency),
    );
    expect(
      numberFormatForId(42, const {}),
      const NumberFormat(NumberKind.currency, decimals: 0),
    );
    expect(
      numberFormatForId(41, const {}),
      const NumberFormat(NumberKind.number, decimals: 0),
    );
    expect(
      numberFormatForId(31, const {}),
      const NumberFormat(NumberKind.date),
    );
    expect(numberFormatForId(999, const {}), NumberFormat.general);
    expect(
      numberFormatForId(164, const {164: '0.0'}),
      const NumberFormat(NumberKind.number, decimals: 1, thousands: false),
    );
  });

  group('formatCodeFor', () {
    test('writes the Brazilian style', () {
      expect(
        formatCodeFor(const NumberFormat(NumberKind.currency)),
        r'"R$" #,##0.00',
      );
      expect(
        formatCodeFor(
          const NumberFormat(NumberKind.currency, decimals: 0),
          currencySymbol: '€',
        ),
        '"€" #,##0',
      );
      expect(formatCodeFor(const NumberFormat(NumberKind.percent)), '0.00%');
      expect(
        formatCodeFor(const NumberFormat(NumberKind.percent, decimals: 0)),
        '0%',
      );
      expect(formatCodeFor(const NumberFormat(NumberKind.date)), 'dd/mm/yyyy');
      expect(formatCodeFor(const NumberFormat(NumberKind.time)), 'hh:mm');
      expect(
        formatCodeFor(const NumberFormat(NumberKind.dateTime)),
        'dd/mm/yyyy hh:mm',
      );
      expect(formatCodeFor(const NumberFormat(NumberKind.number)), '#,##0.00');
      expect(
        formatCodeFor(
          const NumberFormat(NumberKind.number, decimals: 1, thousands: false),
        ),
        '0.0',
      );
      expect(formatCodeFor(const NumberFormat(NumberKind.text)), '@');
      expect(formatCodeFor(NumberFormat.general), 'General');
    });

    test('every written code reads back as the same format', () {
      final formats = [
        NumberFormat.general,
        const NumberFormat(NumberKind.text),
        const NumberFormat(NumberKind.date),
        const NumberFormat(NumberKind.time),
        const NumberFormat(NumberKind.dateTime),
        for (final decimals in [0, 1, 2, 5])
          for (final thousands in [true, false]) ...[
            NumberFormat(
              NumberKind.number,
              decimals: decimals,
              thousands: thousands,
            ),
            NumberFormat(
              NumberKind.currency,
              decimals: decimals,
              thousands: thousands,
            ),
          ],
        for (final decimals in [0, 2, 3])
          NumberFormat(NumberKind.percent, decimals: decimals),
      ];
      for (final format in formats) {
        expect(numberFormatFromCode(formatCodeFor(format)), format);
      }
    });
  });
}
