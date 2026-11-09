import '../sheet/cell_address.dart';
import 'lexer.dart';

/// Moves the relative parts of every reference in a canonical formula by
/// [columns] and [rows], as copying a cell or dragging the fill handle does.
/// `$` parts stay; `A:A` only moves sideways and `1:1` only up and down. A
/// reference pushed off the sheet becomes `#REF!`.
String shiftReferences(String canonicalFormula, int columns, int rows) {
  if (!canonicalFormula.startsWith('=')) return canonicalFormula;
  final tokens = tokenize(canonicalFormula);
  final out = StringBuffer();
  var copied = 0;
  var i = 0;
  while (i < tokens.length) {
    final token = tokens[i];
    final next = i + 1 < tokens.length ? tokens[i + 1] : token;
    var start = i;
    if ((token.type == TokenType.identifier ||
            token.type == TokenType.quotedName) &&
        next.type == TokenType.bang) {
      start = i + 2;
    } else if (token.type == TokenType.identifier &&
        next.type == TokenType.openParen) {
      i++;
      continue;
    }
    final reference = _readReference(tokens, start);
    if (reference == null) {
      i++;
      continue;
    }
    final (end, parts) = reference;
    final shifted = [for (final part in parts) part.shift(columns, rows)];
    final valid = shifted.every((part) => part != null);
    out.write(canonicalFormula.substring(copied, token.start));
    out.write(
      valid
          ? canonicalFormula.substring(token.start, tokens[start].start) +
                shifted.map((part) => part!.text).join(':')
          : '#REF!',
    );
    copied = tokens[end].end;
    i = end + 1;
  }
  out.write(canonicalFormula.substring(copied));
  return out.toString();
}

/// The reference starting at token [index]: the index of its last token and
/// its one or two endpoints.
(int, List<_Part>)? _readReference(List<Token> tokens, int index) {
  if (index >= tokens.length) return null;
  final first = _Part.parse(tokens[index]);
  if (first == null) return null;
  if (index + 2 < tokens.length && tokens[index + 1].type == TokenType.colon) {
    final second = _Part.parse(tokens[index + 2]);
    if (second != null && second.sameKind(first)) {
      return (index + 2, [first, second]);
    }
  }
  if (first.column == null || first.row == null) return null;
  if (index + 1 < tokens.length &&
      tokens[index + 1].type == TokenType.openParen) {
    return null;
  }
  return (index, [first]);
}

final _cellPattern = RegExp(r'^(\$?)([A-Za-z]{1,3})(?:(\$?)([0-9]+))?$');
final _rowPattern = RegExp(r'^(\$?)([0-9]+)$');

class _Part {
  const _Part(this.column, this.absoluteColumn, this.row, this.absoluteRow);

  final int? column;
  final bool absoluteColumn;
  final int? row;
  final bool absoluteRow;

  static _Part? parse(Token token) {
    if (token.type != TokenType.identifier && token.type != TokenType.number) {
      return null;
    }
    final rowOnly = _rowPattern.firstMatch(token.value);
    if (rowOnly != null) {
      return _Part(
        null,
        false,
        int.parse(rowOnly.group(2)!) - 1,
        rowOnly.group(1)!.isNotEmpty,
      );
    }
    if (token.type != TokenType.identifier) return null;
    final match = _cellPattern.firstMatch(token.value);
    if (match == null) return null;
    final column = CellAddress.columnIndex(match.group(2)!);
    if (column < 0 || column >= CellAddress.maxColumns) return null;
    final rowText = match.group(4);
    return _Part(
      column,
      match.group(1)!.isNotEmpty,
      rowText == null ? null : int.parse(rowText) - 1,
      (match.group(3) ?? '').isNotEmpty,
    );
  }

  bool sameKind(_Part other) =>
      (column == null) == (other.column == null) &&
      (row == null) == (other.row == null);

  _Part? shift(int columns, int rows) {
    final newColumn = column == null || absoluteColumn
        ? column
        : column! + columns;
    final newRow = row == null || absoluteRow ? row : row! + rows;
    if (newColumn != null &&
        (newColumn < 0 || newColumn >= CellAddress.maxColumns)) {
      return null;
    }
    if (newRow != null && (newRow < 0 || newRow >= CellAddress.maxRows)) {
      return null;
    }
    return _Part(newColumn, absoluteColumn, newRow, absoluteRow);
  }

  String get text {
    final buffer = StringBuffer();
    if (column != null) {
      if (absoluteColumn) buffer.write(r'$');
      buffer.write(CellAddress.columnName(column!));
    }
    if (row != null) {
      if (absoluteRow) buffer.write(r'$');
      buffer.write(row! + 1);
    }
    return buffer.toString();
  }
}
