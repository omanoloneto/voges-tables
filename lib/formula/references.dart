import '../sheet/cell_address.dart';
import '../sheet/structure.dart';
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

/// Rewrites the references of a canonical formula after rows or columns
/// were inserted or deleted, as Excel does: references after the edit move,
/// ranges across it grow or shrink and references to deleted cells become
/// `#REF!`. [targets] tells whether a reference with that sheet prefix (null
/// for none) points to the edited sheet. Returns [canonicalFormula] itself
/// when nothing changes.
String adjustReferences(
  String canonicalFormula,
  StructureEdit edit, {
  required bool Function(String? sheet) targets,
}) {
  if (!canonicalFormula.startsWith('=')) return canonicalFormula;
  final tokens = tokenize(canonicalFormula);
  final rows = edit.axis == SheetAxis.rows;
  StringBuffer? out;
  var copied = 0;
  var i = 0;
  while (i < tokens.length) {
    final token = tokens[i];
    final next = i + 1 < tokens.length ? tokens[i + 1] : token;
    var start = i;
    String? sheet;
    if ((token.type == TokenType.identifier ||
            token.type == TokenType.quotedName) &&
        next.type == TokenType.bang) {
      start = i + 2;
      sheet = token.value;
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
    i = end + 1;
    if (!targets(sheet)) continue;
    final moved = _moveParts(parts, edit, rows);
    if (identical(moved, parts)) continue;
    out ??= StringBuffer();
    out.write(canonicalFormula.substring(copied, token.start));
    if (moved == null) {
      out.write('#REF!');
    } else {
      out.write(canonicalFormula.substring(token.start, tokens[start].start));
      moved.first.writeTo(out);
      if (moved.length > 1) {
        out.write(':');
        moved.last.writeTo(out);
      }
    }
    copied = tokens[end].end;
  }
  if (out == null) return canonicalFormula;
  out.write(canonicalFormula.substring(copied));
  return out.toString();
}

/// [parts] itself when the edit does not touch them, null for `#REF!`.
List<_Part>? _moveParts(List<_Part> parts, StructureEdit edit, bool rows) {
  int? at(_Part part) => rows ? part.row : part.column;
  final first = at(parts.first);
  if (first == null) return parts;
  if (parts.length == 1) {
    if (first < edit.at) return parts;
    final moved = edit.moveIndex(first);
    return moved == null ? null : [parts.first.withIndex(moved, rows)];
  }
  final last = at(parts.last)!;
  final low = first < last ? first : last;
  final high = first < last ? last : first;
  if (high < edit.at) return parts;
  final span = edit.moveSpan(low, high);
  if (span == null) return null;
  final (newLow, newHigh) = span;
  if (newLow == low && newHigh == high) return parts;
  return first <= last
      ? [
          parts.first.withIndex(newLow, rows),
          parts.last.withIndex(newHigh, rows),
        ]
      : [
          parts.first.withIndex(newHigh, rows),
          parts.last.withIndex(newLow, rows),
        ];
}

/// How a sheet name is written before `!`: quoted when it is not a plain
/// name, with quotes inside doubled.
String sheetPrefix(String name) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$').hasMatch(name) &&
        CellAddress.tryParse(name) == null
    ? name
    : "'${name.replaceAll("'", "''")}'";

/// [canonicalFormula] with every `oldName!` prefix (in any case) written as
/// [newName]; the same string when there is none.
String renameSheetReferences(
  String canonicalFormula,
  String oldName,
  String newName,
) {
  if (!canonicalFormula.startsWith('=') || !canonicalFormula.contains('!')) {
    return canonicalFormula;
  }
  final wanted = oldName.toLowerCase();
  final tokens = tokenize(canonicalFormula);
  StringBuffer? out;
  var copied = 0;
  for (var i = 0; i + 1 < tokens.length; i++) {
    final token = tokens[i];
    if ((token.type != TokenType.identifier &&
            token.type != TokenType.quotedName) ||
        tokens[i + 1].type != TokenType.bang ||
        token.value.toLowerCase() != wanted) {
      continue;
    }
    out ??= StringBuffer();
    out
      ..write(canonicalFormula.substring(copied, token.start))
      ..write(sheetPrefix(newName));
    copied = token.end;
  }
  if (out == null) return canonicalFormula;
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

class _Part {
  const _Part(this.column, this.absoluteColumn, this.row, this.absoluteRow);

  final int? column;
  final bool absoluteColumn;
  final int? row;
  final bool absoluteRow;

  /// `A1`, `$A$1`, `A`, `$A`, `1` or `$1`, read without regular expressions:
  /// moving rows rewrites every formula below them, so this runs a lot.
  static _Part? parse(Token token) {
    final isIdentifier = token.type == TokenType.identifier;
    if (!isIdentifier && token.type != TokenType.number) return null;
    final text = token.value;
    final length = text.length;
    var i = 0;
    var dollar = false;
    if (i < length && text.codeUnitAt(i) == 36) {
      dollar = true;
      i++;
    }
    final lettersStart = i;
    var column = 0;
    while (i < length) {
      var unit = text.codeUnitAt(i);
      if (unit >= 97 && unit <= 122) unit -= 32;
      if (unit < 65 || unit > 90) break;
      column = column * 26 + unit - 64;
      i++;
    }
    final letters = i - lettersStart;
    if (letters == 0) {
      final row = _digits(text, i);
      return row == null ? null : _Part(null, false, row, dollar);
    }
    if (!isIdentifier || letters > 3) return null;
    column -= 1;
    if (column >= CellAddress.maxColumns) return null;
    if (i == length) return _Part(column, dollar, null, false);
    var absoluteRow = false;
    if (text.codeUnitAt(i) == 36) {
      absoluteRow = true;
      i++;
    }
    final row = _digits(text, i);
    return row == null ? null : _Part(column, dollar, row, absoluteRow);
  }

  /// The zero-based row written from [start] to the end, or null.
  static int? _digits(String text, int start) {
    final length = text.length;
    if (start >= length || length - start > 7) return null;
    var value = 0;
    for (var i = start; i < length; i++) {
      final digit = text.codeUnitAt(i) - 48;
      if (digit < 0 || digit > 9) return null;
      value = value * 10 + digit;
    }
    final row = value - 1;
    return row < 0 || row >= CellAddress.maxRows ? null : row;
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

  _Part withIndex(int index, bool rows) => rows
      ? _Part(column, absoluteColumn, index, absoluteRow)
      : _Part(index, absoluteColumn, row, absoluteRow);

  String get text {
    final buffer = StringBuffer();
    writeTo(buffer);
    return buffer.toString();
  }

  void writeTo(StringBuffer buffer) {
    if (column != null) {
      if (absoluteColumn) buffer.write(r'$');
      buffer.write(CellAddress.columnName(column!));
    }
    if (row != null) {
      if (absoluteRow) buffer.write(r'$');
      buffer.write(row! + 1);
    }
  }
}
