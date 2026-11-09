import '../sheet/cell_value.dart';
import 'translate.dart';

enum TokenType {
  number,
  text,
  error,
  identifier,
  quotedName,
  operator,
  openParen,
  closeParen,
  comma,
  colon,
  bang,
  end,
  invalid,
}

class Token {
  const Token(this.type, this.value, this.start, this.end);

  final TokenType type;

  /// The token's meaning: unquoted text, the error code, the operator...
  final String value;

  /// Where the token sits in the source, end excluded.
  final int start;
  final int end;

  bool isOperator(String symbol) =>
      type == TokenType.operator && value == symbol;
}

/// Splits a canonical formula (with or without the leading `=`) into tokens.
/// Spaces are dropped; the list always ends with a [TokenType.end] token.
List<Token> tokenize(String source) {
  final tokens = <Token>[];
  var i = source.startsWith('=') ? 1 : 0;
  final length = source.length;
  while (i < length) {
    final char = source[i];
    final start = i;
    if (char == ' ' || char == '\n' || char == '\t' || char == '\r') {
      i++;
      continue;
    }
    if (char == '"' || char == "'") {
      i = quotedEnd(source, start);
      final closed = i - start >= 2 && source[i - 1] == char;
      if (!closed) {
        tokens.add(Token(TokenType.invalid, char, start, i));
        continue;
      }
      final inner = source
          .substring(start + 1, i - 1)
          .replaceAll('$char$char', char);
      tokens.add(
        Token(
          char == '"' ? TokenType.text : TokenType.quotedName,
          inner,
          start,
          i,
        ),
      );
      continue;
    }
    if (char == '#') {
      final error = _errorAt(source, start);
      if (error == null) {
        tokens.add(Token(TokenType.invalid, char, start, start + 1));
        i++;
      } else {
        i = start + error.code.length;
        tokens.add(Token(TokenType.error, error.code, start, i));
      }
      continue;
    }
    if (isDigit(char) ||
        (char == '.' && i + 1 < length && isDigit(source[i + 1]))) {
      i = _numberEnd(source, start);
      tokens.add(Token(TokenType.number, source.substring(start, i), start, i));
      continue;
    }
    if (isIdentifierStart(char)) {
      i++;
      while (i < length && isIdentifierPart(source[i])) {
        i++;
      }
      tokens.add(
        Token(TokenType.identifier, source.substring(start, i), start, i),
      );
      continue;
    }
    final two = i + 1 < length ? source.substring(i, i + 2) : '';
    if (two == '<=' || two == '>=' || two == '<>') {
      tokens.add(Token(TokenType.operator, two, start, i + 2));
      i += 2;
      continue;
    }
    final type = switch (char) {
      '+' ||
      '-' ||
      '*' ||
      '/' ||
      '^' ||
      '&' ||
      '%' ||
      '=' ||
      '<' ||
      '>' => TokenType.operator,
      '(' => TokenType.openParen,
      ')' => TokenType.closeParen,
      ',' => TokenType.comma,
      ':' => TokenType.colon,
      '!' => TokenType.bang,
      _ => TokenType.invalid,
    };
    tokens.add(Token(type, char, start, i + 1));
    i++;
  }
  tokens.add(Token(TokenType.end, '', length, length));
  return tokens;
}

CellError? _errorAt(String source, int start) {
  final rest = source.substring(start).toUpperCase();
  CellError? best;
  for (final error in CellError.values) {
    if (rest.startsWith(error.code) &&
        (best == null || error.code.length > best.code.length)) {
      best = error;
    }
  }
  return best;
}

int _numberEnd(String source, int start) {
  var i = start;
  while (i < source.length && isDigit(source[i])) {
    i++;
  }
  if (i < source.length && source[i] == '.') {
    i++;
    while (i < source.length && isDigit(source[i])) {
      i++;
    }
  }
  if (i < source.length && (source[i] == 'e' || source[i] == 'E')) {
    var j = i + 1;
    if (j < source.length && (source[j] == '+' || source[j] == '-')) j++;
    if (j < source.length && isDigit(source[j])) {
      while (j < source.length && isDigit(source[j])) {
        j++;
      }
      i = j;
    }
  }
  return i;
}
