import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';
import 'ast.dart';
import 'function_names.dart';
import 'lexer.dart';

/// Parses a canonical formula, with or without the leading `=`. Never throws:
/// a formula that cannot be read becomes an [ErrorExpr].
Expr parseFormula(String formula) {
  try {
    return _Parser(tokenize(formula)).parse();
  } on _SyntaxError catch (e) {
    return ErrorExpr(e.error);
  }
}

class _SyntaxError implements Exception {
  const _SyntaxError(this.error);
  final CellError error;
}

const _valueError = _SyntaxError(CellError.value);
const _nameError = _SyntaxError(CellError.name);

const _maxDepth = 200;

// Excel's precedence: comparisons < & < + - < * / < ^ < % < unary minus.
const _binaryPowers = {
  '=': (1, BinaryOperator.equal),
  '<>': (1, BinaryOperator.notEqual),
  '<': (1, BinaryOperator.less),
  '>': (1, BinaryOperator.greater),
  '<=': (1, BinaryOperator.lessOrEqual),
  '>=': (1, BinaryOperator.greaterOrEqual),
  '&': (2, BinaryOperator.concat),
  '+': (3, BinaryOperator.add),
  '-': (3, BinaryOperator.subtract),
  '*': (4, BinaryOperator.multiply),
  '/': (4, BinaryOperator.divide),
  '^': (5, BinaryOperator.power),
};
const _percentPower = 6;
const _unaryPower = 7;

final _cellPart = RegExp(r'^\$?([A-Za-z]{1,3})(?:\$?([0-9]+))?$');
final _rowPart = RegExp(r'^\$?([0-9]+)$');

class _Parser {
  _Parser(this._tokens);

  final List<Token> _tokens;
  var _position = 0;
  var _depth = 0;

  Token get _peek => _tokens[_position];
  Token _next() => _tokens[_position++];
  Token _peekAt(int offset) =>
      _tokens[(_position + offset).clamp(0, _tokens.length - 1)];

  Expr parse() {
    if (_tokens.any((token) => token.type == TokenType.invalid)) {
      throw _nameError;
    }
    if (_peek.type == TokenType.end) throw _valueError;
    final expr = _expression(0);
    if (_peek.type != TokenType.end) throw _valueError;
    return expr;
  }

  Expr _expression(int minPower) {
    if (++_depth > _maxDepth) throw _valueError;
    var left = _prefix();
    while (true) {
      final token = _peek;
      if (token.type != TokenType.operator) break;
      if (token.value == '%') {
        if (_percentPower < minPower) break;
        _next();
        left = UnaryExpr(UnaryOperator.percent, left);
        continue;
      }
      final binary = _binaryPowers[token.value];
      if (binary == null || binary.$1 < minPower) break;
      _next();
      left = BinaryExpr(binary.$2, left, _expression(binary.$1 + 1));
    }
    _depth--;
    return left;
  }

  Expr _prefix() {
    final token = _peek;
    if (token.isOperator('-') || token.isOperator('+')) {
      _next();
      final operand = _expression(_unaryPower);
      return UnaryExpr(
        token.value == '-' ? UnaryOperator.negate : UnaryOperator.plus,
        operand,
      );
    }
    return _primary();
  }

  Expr _primary() {
    final token = _next();
    switch (token.type) {
      case TokenType.number:
        if (_peek.type == TokenType.colon) {
          return _reference(null, token) ?? (throw _valueError);
        }
        return NumberExpr(double.parse(token.value));
      case TokenType.text:
        return TextExpr(token.value);
      case TokenType.error:
        return ErrorExpr(CellError.fromCode(token.value)!);
      case TokenType.openParen:
        final inner = _expression(0);
        if (_next().type != TokenType.closeParen) throw _valueError;
        return inner;
      case TokenType.quotedName:
        return _qualified(token.value);
      case TokenType.identifier:
        return _identifier(token);
      default:
        throw _valueError;
    }
  }

  Expr _identifier(Token token) {
    if (_peek.type == TokenType.openParen) return _call(token.value);
    if (_peek.type == TokenType.bang) return _qualified(token.value);
    final upper = token.value.toUpperCase();
    if (upper == 'TRUE') return const BoolExpr(true);
    if (upper == 'FALSE') return const BoolExpr(false);
    return _reference(null, token) ?? NameExpr(token.value);
  }

  Expr _qualified(String sheet) {
    if (_next().type != TokenType.bang) throw _valueError;
    final first = _next();
    if (first.type == TokenType.error && first.value == CellError.ref.code) {
      return const ErrorExpr(CellError.ref);
    }
    return _reference(sheet, first) ?? (throw _nameError);
  }

  Expr _call(String name) {
    _next();
    final arguments = <Expr>[];
    if (_peek.type == TokenType.closeParen) {
      _next();
    } else {
      while (true) {
        final type = _peek.type;
        arguments.add(
          type == TokenType.comma || type == TokenType.closeParen
              ? const MissingExpr()
              : _expression(0),
        );
        final separator = _next();
        if (separator.type == TokenType.closeParen) break;
        if (separator.type != TokenType.comma) throw _valueError;
      }
    }
    return CallExpr(stripFunctionPrefix(name.toUpperCase()), arguments);
  }

  /// A cell, a range of cells, whole columns (`A:C`) or whole rows (`1:3`)
  /// starting at [first]; null when [first] is not one.
  ReferenceExpr? _reference(String? sheet, Token first) {
    final start = _endpoint(first);
    if (start == null) return null;
    final hasRange =
        _peek.type == TokenType.colon &&
        (_peekAt(1).type == TokenType.identifier ||
            _peekAt(1).type == TokenType.number);
    if (!hasRange) {
      if (start.column == null || start.row == null) return null;
      return ReferenceExpr(
        sheet,
        CellRange.single(CellAddress(start.column!, start.row!)),
      );
    }
    _next();
    final end = _endpoint(_next()) ?? (throw _valueError);
    final cells = start.column != null && start.row != null;
    final columns = start.row == null && start.column != null;
    if (cells && end.column != null && end.row != null) {
      return ReferenceExpr(
        sheet,
        CellRange(
          CellAddress(start.column!, start.row!),
          CellAddress(end.column!, end.row!),
        ),
      );
    }
    if (columns && end.row == null && end.column != null) {
      return ReferenceExpr(
        sheet,
        CellRange(
          CellAddress(start.column!, 0),
          CellAddress(end.column!, CellAddress.maxRows - 1),
        ),
      );
    }
    if (start.column == null && end.column == null) {
      return ReferenceExpr(
        sheet,
        CellRange(
          CellAddress(0, start.row!),
          CellAddress(CellAddress.maxColumns - 1, end.row!),
        ),
      );
    }
    throw _valueError;
  }

  ({int? column, int? row})? _endpoint(Token token) {
    if (token.type != TokenType.identifier && token.type != TokenType.number) {
      return null;
    }
    final rowOnly = _rowPart.firstMatch(token.value);
    if (rowOnly != null) {
      final row = int.parse(rowOnly.group(1)!) - 1;
      if (row < 0 || row >= CellAddress.maxRows) return null;
      return (column: null, row: row);
    }
    if (token.type != TokenType.identifier) return null;
    final match = _cellPart.firstMatch(token.value);
    if (match == null) return null;
    final column = CellAddress.columnIndex(match.group(1)!);
    if (column < 0 || column >= CellAddress.maxColumns) return null;
    final rowText = match.group(2);
    if (rowText == null) return (column: column, row: null);
    final row = int.parse(rowText) - 1;
    if (row < 0 || row >= CellAddress.maxRows) return null;
    return (column: column, row: row);
  }
}
