import 'package:flutter_test/flutter_test.dart';
import 'package:voges_tables/formula/function_names.dart';
import 'package:voges_tables/formula/functions/registry.dart';
import 'package:voges_tables/formula/locale.dart';
import 'package:voges_tables/formula/translate.dart';

void main() {
  const pt = FormulaLocale.pt;
  const es = FormulaLocale.es;
  const en = FormulaLocale.en;

  test('pt formulas become canonical', () {
    expect(toCanonical('=SOMA(A1;2,5)', pt), '=SUM(A1,2.5)');
    expect(
      toCanonical('=SE(A1>0;"sim; ok";FALSO)', pt),
      '=IF(A1>0,"sim; ok",FALSE)',
    );
    expect(
      toCanonical('=CONT.NÚM(A:A)+MÉDIA(B1:B3)', pt),
      '=COUNT(A:A)+AVERAGE(B1:B3)',
    );
    expect(
      toCanonical('=É.NÃO.DISP(PROCV(1;A1:B2;2;0))', pt),
      '=ISNA(VLOOKUP(1,A1:B2,2,0))',
    );
  });

  test('pt names typed without accents or in lower case', () {
    expect(
      toCanonical('=media(a1;maximo(b1;1,5e3))', pt),
      '=AVERAGE(A1,MAX(B1,1.5e3))',
    );
    expect(toCanonical('=ecel.vazia(A1)', pt), '=ISBLANK(A1)');
    expect(toCanonical('=verdadeiro', pt), '=TRUE');
  });

  test('English names still work in pt and unknown names stay as typed', () {
    expect(toCanonical('=SUM(1;2)', pt), '=SUM(1,2)');
    expect(toCanonical('=Minha(1;2)', pt), '=Minha(1,2)');
  });

  test('es formulas become canonical', () {
    expect(toCanonical('=SUMA(A1;2,5)', es), '=SUM(A1,2.5)');
    expect(
      toCanonical('=SI(Y(A1;VERDADERO);BUSCARV(1;A:B;2;FALSO);0)', es),
      '=IF(AND(A1,TRUE),VLOOKUP(1,A:B,2,FALSE),0)',
    );
    expect(toCanonical('=AÑO(HOY())+ano(1)', es), '=YEAR(TODAY())+YEAR(1)');
  });

  test('strings and sheet names are never translated', () {
    expect(
      toDisplay('=SUM(\'Plan, 1\'!A1,"1.5, SUM(")', pt),
      '=SOMA(\'Plan, 1\'!A1;"1.5, SUM(")',
    );
    expect(toDisplay('=IF!A1', pt), '=IF!A1');
    expect(toDisplay('=E:E', pt), '=E:E');
  });

  test('canonical formulas are shown in each locale', () {
    expect(toDisplay('=SUM(A1,2.5)', pt), '=SOMA(A1;2,5)');
    expect(toDisplay('=SUM(A1,2.5)', es), '=SUMA(A1;2,5)');
    expect(toDisplay('=SUM(A1,2.5)', en), '=SUM(A1,2.5)');
    expect(toDisplay('=IF(TRUE,#N/A,1E-3)', pt), '=SE(VERDADEIRO;#N/A;1E-3)');
  });

  test('round trips', () {
    const formulas = [
      r'=SUM($A$1:B5,Sheet2!C3,0.5)',
      '=IF(AND(A1>=1.25,NOT(B2)),"a,b;c",FALSE)',
      "=VLOOKUP(A1,'My sheet'!A:C,3,FALSE)&TEXT(NOW(),\"dd/mm/yyyy\")",
      '=STDEV.S(1:3)+COUNTIFS(A:A,">5",B:B,"<>x")-2^-1%',
      '=XLOOKUP(1,A1:A3,B1:B3,#N/A,0,-1)',
    ];
    for (final locale in FormulaLocale.values) {
      for (final formula in formulas) {
        expect(
          toCanonical(toDisplay(formula, locale), locale),
          formula,
          reason: '$locale $formula',
        );
      }
    }
  });

  test('text that is not a formula is left alone', () {
    expect(toCanonical('SOMA(1;2)', pt), 'SOMA(1;2)');
  });

  test('every function has a name in each locale and back', () {
    expect(functionRegistry.keys.toSet(), canonicalFunctionNames);
    for (final name in canonicalFunctionNames) {
      for (final locale in FormulaLocale.values) {
        final localized = localizedFunctionName(name, locale);
        expect(
          canonicalFunctionName(localized, locale),
          name,
          reason: '$locale $localized',
        );
      }
    }
  });
}
