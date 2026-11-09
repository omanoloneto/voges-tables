import 'locale.dart';

/// Canonical (English), Brazilian Portuguese and Spanish Excel names.
const _table = <(String, String, String)>[
  ('SUM', 'SOMA', 'SUMA'),
  ('AVERAGE', 'MÉDIA', 'PROMEDIO'),
  ('MIN', 'MÍNIMO', 'MIN'),
  ('MAX', 'MÁXIMO', 'MAX'),
  ('COUNT', 'CONT.NÚM', 'CONTAR'),
  ('COUNTA', 'CONT.VALORES', 'CONTARA'),
  ('COUNTBLANK', 'CONTAR.VAZIO', 'CONTAR.BLANCO'),
  ('COUNTIF', 'CONT.SE', 'CONTAR.SI'),
  ('SUMIF', 'SOMASE', 'SUMAR.SI'),
  ('AVERAGEIF', 'MÉDIASE', 'PROMEDIO.SI'),
  ('COUNTIFS', 'CONT.SES', 'CONTAR.SI.CONJUNTO'),
  ('SUMIFS', 'SOMASES', 'SUMAR.SI.CONJUNTO'),
  ('IF', 'SE', 'SI'),
  ('IFS', 'SES', 'SI.CONJUNTO'),
  ('IFERROR', 'SEERRO', 'SI.ERROR'),
  ('AND', 'E', 'Y'),
  ('OR', 'OU', 'O'),
  ('NOT', 'NÃO', 'NO'),
  ('XOR', 'OUEXCL', 'XO'),
  ('TRUE', 'VERDADEIRO', 'VERDADERO'),
  ('FALSE', 'FALSO', 'FALSO'),
  ('ROUND', 'ARRED', 'REDONDEAR'),
  ('ROUNDUP', 'ARREDONDAR.PARA.CIMA', 'REDONDEAR.MAS'),
  ('ROUNDDOWN', 'ARREDONDAR.PARA.BAIXO', 'REDONDEAR.MENOS'),
  ('INT', 'INT', 'ENTERO'),
  ('TRUNC', 'TRUNCAR', 'TRUNCAR'),
  ('ABS', 'ABS', 'ABS'),
  ('MOD', 'MOD', 'RESIDUO'),
  ('POWER', 'POTÊNCIA', 'POTENCIA'),
  ('SQRT', 'RAIZ', 'RAIZ'),
  ('PI', 'PI', 'PI'),
  ('PRODUCT', 'MULT', 'PRODUCTO'),
  ('RAND', 'ALEATÓRIO', 'ALEATORIO'),
  ('RANDBETWEEN', 'ALEATÓRIOENTRE', 'ALEATORIO.ENTRE'),
  ('MEDIAN', 'MED', 'MEDIANA'),
  ('MODE', 'MODO', 'MODA'),
  ('MODE.SNGL', 'MODO.ÚNICO', 'MODA.UNO'),
  ('STDEV', 'DESVPAD', 'DESVEST'),
  ('STDEV.S', 'DESVPAD.A', 'DESVEST.M'),
  ('VAR', 'VAR', 'VAR'),
  ('VAR.S', 'VAR.A', 'VAR.S'),
  ('LARGE', 'MAIOR', 'K.ESIMO.MAYOR'),
  ('SMALL', 'MENOR', 'K.ESIMO.MENOR'),
  ('RANK', 'ORDEM', 'JERARQUIA'),
  ('RANK.EQ', 'ORDEM.EQ', 'JERARQUIA.EQV'),
  ('VLOOKUP', 'PROCV', 'BUSCARV'),
  ('HLOOKUP', 'PROCH', 'BUSCARH'),
  ('XLOOKUP', 'PROCX', 'BUSCARX'),
  ('MATCH', 'CORRESP', 'COINCIDIR'),
  ('INDEX', 'ÍNDICE', 'INDICE'),
  ('CHOOSE', 'ESCOLHER', 'ELEGIR'),
  ('LEN', 'NÚM.CARACT', 'LARGO'),
  ('LEFT', 'ESQUERDA', 'IZQUIERDA'),
  ('RIGHT', 'DIREITA', 'DERECHA'),
  ('MID', 'EXT.TEXTO', 'EXTRAE'),
  ('UPPER', 'MAIÚSCULA', 'MAYUSC'),
  ('LOWER', 'MINÚSCULA', 'MINUSC'),
  ('PROPER', 'PRI.MAIÚSCULA', 'NOMPROPIO'),
  ('TRIM', 'ARRUMAR', 'ESPACIOS'),
  ('CONCATENATE', 'CONCATENAR', 'CONCATENAR'),
  ('CONCAT', 'CONCAT', 'CONCAT'),
  ('TEXTJOIN', 'UNIRTEXTO', 'UNIRCADENAS'),
  ('TEXT', 'TEXTO', 'TEXTO'),
  ('VALUE', 'VALOR', 'VALOR'),
  ('FIND', 'PROCURAR', 'ENCONTRAR'),
  ('SEARCH', 'LOCALIZAR', 'HALLAR'),
  ('SUBSTITUTE', 'SUBSTITUIR', 'SUSTITUIR'),
  ('REPT', 'REPT', 'REPETIR'),
  ('EXACT', 'EXATO', 'IGUAL'),
  ('TODAY', 'HOJE', 'HOY'),
  ('NOW', 'AGORA', 'AHORA'),
  ('DATE', 'DATA', 'FECHA'),
  ('YEAR', 'ANO', 'AÑO'),
  ('MONTH', 'MÊS', 'MES'),
  ('DAY', 'DIA', 'DIA'),
  ('WEEKDAY', 'DIA.DA.SEMANA', 'DIASEM'),
  ('DATEDIF', 'DATADIF', 'SIFECHA'),
  ('DAYS', 'DIAS', 'DIAS'),
  ('EDATE', 'DATAM', 'FECHA.MES'),
  ('EOMONTH', 'FIMMÊS', 'FIN.MES'),
  ('HOUR', 'HORA', 'HORA'),
  ('MINUTE', 'MINUTO', 'MINUTO'),
  ('SECOND', 'SEGUNDO', 'SEGUNDO'),
  ('TIME', 'TEMPO', 'NSHORA'),
  ('ISBLANK', 'ÉCÉL.VAZIA', 'ESBLANCO'),
  ('ISNUMBER', 'ÉNÚM', 'ESNUMERO'),
  ('ISTEXT', 'ÉTEXTO', 'ESTEXTO'),
  ('ISERROR', 'ÉERROS', 'ESERROR'),
  ('ISNA', 'É.NÃO.DISP', 'ESNOD'),
  ('NA', 'NÃO.DISP', 'NOD'),
  ('ROW', 'LIN', 'FILA'),
  ('COLUMN', 'COL', 'COLUMNA'),
  ('ROWS', 'LINS', 'FILAS'),
  ('COLUMNS', 'COLS', 'COLUMNAS'),
];

/// Every canonical function name the engine knows.
final Set<String> canonicalFunctionNames = {for (final row in _table) row.$1};

final _toLocalized = {
  FormulaLocale.pt: {for (final row in _table) row.$1: row.$2},
  FormulaLocale.es: {for (final row in _table) row.$1: row.$3},
};

final _toCanonical = {
  FormulaLocale.pt: {for (final row in _table) foldName(row.$2): row.$1},
  FormulaLocale.es: {for (final row in _table) foldName(row.$3): row.$1},
};

const _accents = {
  'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', //
  'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E', //
  'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I', //
  'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O', //
  'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', //
  'Ç': 'C', 'Ñ': 'N',
};

/// Upper case without accents, so `média` and `MEDIA` find `MÉDIA`.
String foldName(String name) {
  final upper = name.toUpperCase();
  final buffer = StringBuffer();
  for (final char in upper.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// The canonical name for a name typed in [locale], or null when unknown.
///
/// English names are accepted in every locale. The `_xlfn.` prefix that
/// `.xlsx` files put on newer functions is dropped.
String? canonicalFunctionName(String typed, FormulaLocale locale) {
  final name = stripFunctionPrefix(typed.toUpperCase());
  final localized = _toCanonical[locale]?[foldName(name)];
  if (localized != null) return localized;
  return canonicalFunctionNames.contains(name) ? name : null;
}

/// The name shown in [locale] for a canonical function name.
String localizedFunctionName(String canonical, FormulaLocale locale) =>
    _toLocalized[locale]?[canonical] ?? canonical;

String stripFunctionPrefix(String upperName) {
  for (final prefix in const ['_XLFN.', '_XLWS.']) {
    if (upperName.startsWith(prefix)) {
      return upperName.substring(prefix.length);
    }
  }
  return upperName;
}
