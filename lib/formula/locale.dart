/// How formulas and constants are typed and shown in each interface language.
///
/// Brazilian Portuguese and Spanish follow their Excel versions: `;` between
/// arguments, `,` as the decimal point and `.` between thousands.
enum FormulaLocale {
  en(
    argumentSeparator: ',',
    decimalSeparator: '.',
    thousandsSeparator: ',',
    trueWord: 'TRUE',
    falseWord: 'FALSE',
    dayFirst: false,
    currencySymbol: r'$',
    currencyBefore: true,
  ),
  pt(
    argumentSeparator: ';',
    decimalSeparator: ',',
    thousandsSeparator: '.',
    trueWord: 'VERDADEIRO',
    falseWord: 'FALSO',
    dayFirst: true,
    currencySymbol: r'R$',
    currencyBefore: true,
  ),
  es(
    argumentSeparator: ';',
    decimalSeparator: ',',
    thousandsSeparator: '.',
    trueWord: 'VERDADERO',
    falseWord: 'FALSO',
    dayFirst: true,
    currencySymbol: '€',
    currencyBefore: false,
  );

  const FormulaLocale({
    required this.argumentSeparator,
    required this.decimalSeparator,
    required this.thousandsSeparator,
    required this.trueWord,
    required this.falseWord,
    required this.dayFirst,
    required this.currencySymbol,
    required this.currencyBefore,
  });

  final String argumentSeparator;
  final String decimalSeparator;
  final String thousandsSeparator;
  final String trueWord;
  final String falseWord;

  /// Dates are typed and shown as dd/mm/yyyy instead of m/d/yyyy.
  final bool dayFirst;
  final String currencySymbol;
  final bool currencyBefore;

  String booleanWord(bool value) => value ? trueWord : falseWord;

  /// `pt`, `pt_BR`, `es-419`... fall back to English.
  static FormulaLocale fromLanguageCode(String code) {
    final language = code.toLowerCase().split(RegExp('[-_]')).first;
    return switch (language) {
      'pt' => pt,
      'es' => es,
      _ => en,
    };
  }
}
