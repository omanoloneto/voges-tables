import 'function_names.dart';
import 'locale.dart';

/// Turns a formula typed in [locale] into the canonical form kept in cells.
String toCanonical(String formula, FormulaLocale locale) =>
    _translate(formula, locale, FormulaLocale.en);

/// Turns a canonical formula into the text shown to edit it in [locale].
String toDisplay(String canonical, FormulaLocale locale) =>
    _translate(canonical, FormulaLocale.en, locale);

final _cellReference = RegExp(r'^\$?[A-Za-z]{1,3}\$?[0-9]+$');

String _translate(String text, FormulaLocale from, FormulaLocale to) {
  if (!text.startsWith('=')) return text;
  final out = StringBuffer('=');
  final length = text.length;
  var i = 1;
  while (i < length) {
    final char = text[i];
    if (char == '"' || char == "'") {
      final end = quotedEnd(text, i);
      out.write(text.substring(i, end));
      i = end;
    } else if (char == '#') {
      final end = _errorEnd(text, i);
      out.write(text.substring(i, end));
      i = end;
    } else if (isDigit(char) ||
        (char == from.decimalSeparator &&
            i + 1 < length &&
            isDigit(text[i + 1]))) {
      final end = _numberEnd(text, i, from.decimalSeparator);
      out.write(
        text
            .substring(i, end)
            .replaceAll(from.decimalSeparator, to.decimalSeparator),
      );
      i = end;
    } else if (isIdentifierStart(char)) {
      var end = i + 1;
      while (end < length && isIdentifierPart(text[end])) {
        end++;
      }
      final next = end < length ? text[end] : '';
      out.write(_identifier(text.substring(i, end), next, from, to));
      i = end;
    } else if (char == from.argumentSeparator) {
      out.write(to.argumentSeparator);
      i++;
    } else {
      out.write(char);
      i++;
    }
  }
  return out.toString();
}

String _identifier(
  String word,
  String next,
  FormulaLocale from,
  FormulaLocale to,
) {
  if (next == '(') {
    final canonical = canonicalFunctionName(word, from);
    return canonical == null ? word : localizedFunctionName(canonical, to);
  }
  if (next == '!') return word;
  final folded = foldName(word);
  if (folded == foldName(from.trueWord)) return to.trueWord;
  if (folded == foldName(from.falseWord)) return to.falseWord;
  if (_cellReference.hasMatch(word)) return word.toUpperCase();
  return word;
}

/// The index just past a `"..."` or `'...'` that starts at [start]; doubled
/// quotes stay inside.
int quotedEnd(String text, int start) {
  final quote = text[start];
  var i = start + 1;
  while (i < text.length) {
    if (text[i] == quote) {
      if (i + 1 < text.length && text[i + 1] == quote) {
        i += 2;
        continue;
      }
      return i + 1;
    }
    i++;
  }
  return text.length;
}

int _errorEnd(String text, int start) {
  var i = start + 1;
  while (i < text.length && RegExp(r'[A-Za-z0-9/]').hasMatch(text[i])) {
    i++;
  }
  if (i < text.length && (text[i] == '!' || text[i] == '?')) i++;
  return i;
}

int _numberEnd(String text, int start, String decimal) {
  var i = start;
  while (i < text.length && isDigit(text[i])) {
    i++;
  }
  if (i + 1 < text.length && text[i] == decimal && isDigit(text[i + 1])) {
    i++;
    while (i < text.length && isDigit(text[i])) {
      i++;
    }
  }
  if (i < text.length && (text[i] == 'e' || text[i] == 'E')) {
    var j = i + 1;
    if (j < text.length && (text[j] == '+' || text[j] == '-')) j++;
    if (j < text.length && isDigit(text[j])) {
      while (j < text.length && isDigit(text[j])) {
        j++;
      }
      i = j;
    }
  }
  return i;
}

bool isDigit(String char) {
  final unit = char.codeUnitAt(0);
  return unit >= 48 && unit <= 57;
}

bool isIdentifierStart(String char) {
  final unit = char.codeUnitAt(0);
  return (unit >= 65 && unit <= 90) ||
      (unit >= 97 && unit <= 122) ||
      unit == 95 ||
      unit == 36 ||
      unit == 92 ||
      (unit > 127 && char.toUpperCase() != char.toLowerCase());
}

bool isIdentifierPart(String char) =>
    isIdentifierStart(char) || isDigit(char) || char == '.';
