import '../../sheet/cell_address.dart';

/// Applies [transform] to the parts of a formula that are code: string
/// literals, quoted sheet names and bracketed parts (external workbooks,
/// structured references) pass through untouched.
String _mapCode(String formula, String Function(String code) transform) {
  final out = StringBuffer();
  var codeStart = 0;
  var i = 0;
  void flush(int end) {
    if (end > codeStart) {
      out.write(transform(formula.substring(codeStart, end)));
    }
  }

  while (i < formula.length) {
    final char = formula[i];
    final int end;
    if (char == '"' || char == "'") {
      end = _quotedEnd(formula, i, char);
    } else if (char == '[') {
      end = _bracketEnd(formula, i);
    } else {
      i++;
      continue;
    }
    flush(i);
    out.write(formula.substring(i, end));
    i = codeStart = end;
  }
  flush(formula.length);
  return out.toString();
}

int _quotedEnd(String formula, int start, String quote) {
  var i = start + 1;
  while (i < formula.length) {
    if (formula[i] == quote) {
      if (i + 1 < formula.length && formula[i + 1] == quote) {
        i += 2;
        continue;
      }
      return i + 1;
    }
    i++;
  }
  return formula.length;
}

int _bracketEnd(String formula, int start) {
  var depth = 0;
  for (var i = start; i < formula.length; i++) {
    if (formula[i] == '[') depth++;
    if (formula[i] == ']' && --depth == 0) return i + 1;
  }
  return formula.length;
}

final _reference = RegExp(
  r'(?<![A-Za-z0-9_.])(?:'
  r'(\$?)([A-Za-z]{1,3})(\$?)([0-9]{1,7})(?![A-Za-z0-9_.(!])'
  r'|(\$?)([A-Za-z]{1,3}):(\$?)([A-Za-z]{1,3})(?![A-Za-z0-9_.(!])'
  r'|(\$?)([0-9]{1,7}):(\$?)([0-9]{1,7})(?![0-9.])'
  r')',
);

/// Moves the relative references of a shared formula from its master cell
/// to another cell; references pushed off the sheet become `#REF!`.
String shiftFormula(String formula, int columns, int rows) {
  if (columns == 0 && rows == 0) return formula;
  return _mapCode(
    formula,
    (code) => code.replaceAllMapped(_reference, (match) {
      if (match.group(2) != null) {
        final column = _shiftColumn(match.group(1)!, match.group(2)!, columns);
        final row = _shiftRow(match.group(3)!, match.group(4)!, rows);
        if (column == null || row == null) {
          return _isColumn(match.group(2)!) && _isRow(match.group(4)!)
              ? '#REF!'
              : match.group(0)!;
        }
        return '$column$row';
      }
      if (match.group(6) != null) {
        if (!_isColumn(match.group(6)!) || !_isColumn(match.group(8)!)) {
          return match.group(0)!;
        }
        final first = _shiftColumn(match.group(5)!, match.group(6)!, columns);
        final last = _shiftColumn(match.group(7)!, match.group(8)!, columns);
        return first == null || last == null ? '#REF!' : '$first:$last';
      }
      if (!_isRow(match.group(10)!) || !_isRow(match.group(12)!)) {
        return match.group(0)!;
      }
      final first = _shiftRow(match.group(9)!, match.group(10)!, rows);
      final last = _shiftRow(match.group(11)!, match.group(12)!, rows);
      return first == null || last == null ? '#REF!' : '$first:$last';
    }),
  );
}

bool _isColumn(String letters) {
  final index = CellAddress.columnIndex(letters);
  return index >= 0 && index < CellAddress.maxColumns;
}

bool _isRow(String digits) {
  final row = int.parse(digits);
  return row >= 1 && row <= CellAddress.maxRows;
}

String? _shiftColumn(String absolute, String letters, int columns) {
  if (!_isColumn(letters)) return null;
  if (absolute.isNotEmpty) return '\$${letters.toUpperCase()}';
  final index = CellAddress.columnIndex(letters) + columns;
  if (index < 0 || index >= CellAddress.maxColumns) return null;
  return CellAddress.columnName(index);
}

String? _shiftRow(String absolute, String digits, int rows) {
  if (!_isRow(digits)) return null;
  if (absolute.isNotEmpty) return '\$$digits';
  final row = int.parse(digits) + rows;
  if (row < 1 || row > CellAddress.maxRows) return null;
  return '$row';
}

final _futurePrefix = RegExp(
  r'_xlfn\.|_xlws\.|_xludf\.|_xlpm\.',
  caseSensitive: false,
);

/// Excel stores functions newer than 2007 with `_xlfn.` and friends; the
/// app keeps the plain names.
String formulaFromXlsx(String formula) => formula.contains('_xl')
    ? _mapCode(formula, (code) => code.replaceAll(_futurePrefix, ''))
    : formula;

/// Puts the `_xlfn.` prefixes back, or Excel shows `#NAME?`.
String formulaToXlsx(String formula) => _mapCode(
  formula,
  (code) => code.replaceAllMapped(_futureFunction, (m) {
    final name = m.group(1)!.toUpperCase();
    return _worksheetFunctions.contains(name)
        ? '_xlfn._xlws.$name'
        : '_xlfn.$name';
  }),
);

const _worksheetFunctions = {'FILTER', 'SORT'};

const _futureFunctions = [
  'ACOT', 'ACOTH', 'AGGREGATE', 'ARABIC', 'BASE', 'BITAND', 'BITLSHIFT', //
  'BITOR', 'BITRSHIFT', 'BITXOR', 'CEILING.MATH', 'CEILING.PRECISE',
  'CHISQ.DIST', 'CHISQ.DIST.RT', 'CHISQ.INV', 'CHISQ.INV.RT', 'CHISQ.TEST',
  'CHOOSECOLS', 'CHOOSEROWS', 'COMBINA', 'CONCAT', 'CONFIDENCE.NORM',
  'CONFIDENCE.T', 'COT', 'COTH', 'COVARIANCE.P', 'COVARIANCE.S', 'CSC',
  'CSCH', 'DAYS', 'DECIMAL', 'DROP', 'ERF.PRECISE', 'ERFC.PRECISE',
  'EXPAND', 'EXPON.DIST', 'F.DIST', 'F.DIST.RT', 'F.INV', 'F.INV.RT',
  'F.TEST', 'FILTER', 'FLOOR.MATH', 'FLOOR.PRECISE', 'FORMULATEXT',
  'GAMMA', 'GAMMA.DIST', 'GAMMA.INV', 'GAMMALN.PRECISE', 'GAUSS', 'HSTACK',
  'IFNA', 'IFS', 'ISFORMULA', 'ISOWEEKNUM', 'LAMBDA', 'LET', 'LOGNORM.DIST',
  'LOGNORM.INV', 'MAXIFS', 'MINIFS', 'MODE.MULT', 'MODE.SNGL', 'MUNIT',
  'NETWORKDAYS.INTL', 'NORM.DIST', 'NORM.INV', 'NORM.S.DIST', 'NORM.S.INV',
  'NUMBERVALUE', 'PDURATION', 'PERCENTILE.EXC', 'PERCENTILE.INC',
  'PERCENTRANK.EXC', 'PERCENTRANK.INC', 'PERMUTATIONA', 'PHI',
  'POISSON.DIST', 'QUARTILE.EXC', 'QUARTILE.INC', 'RANDARRAY', 'RANK.AVG',
  'RANK.EQ', 'RRI', 'SEC', 'SECH', 'SEQUENCE', 'SHEET', 'SHEETS', 'SORT',
  'SORTBY', 'STDEV.P', 'STDEV.S', 'SWITCH', 'T.DIST', 'T.DIST.2T',
  'T.DIST.RT', 'T.INV', 'T.INV.2T', 'T.TEST', 'TAKE', 'TEXTAFTER',
  'TEXTBEFORE', 'TEXTJOIN', 'TEXTSPLIT', 'TOCOL', 'TOROW', 'UNICHAR',
  'UNICODE', 'UNIQUE', 'VAR.P', 'VAR.S', 'VSTACK', 'WEIBULL.DIST',
  'WORKDAY.INTL', 'WRAPCOLS', 'WRAPROWS', 'XLOOKUP', 'XMATCH', 'XOR',
];

final _futureFunction = RegExp(
  '(?<![A-Za-z0-9_.])(${_futureFunctions.map(RegExp.escape).join('|')})'
  r'(?=\s*\()',
  caseSensitive: false,
);
