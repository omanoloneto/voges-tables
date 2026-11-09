import '../../sheet/cell_address.dart';
import '../../sheet/cell_value.dart';
import '../arguments.dart';
import '../cell_source.dart';
import '../comparison.dart';
import '../criteria.dart';
import '../operand.dart';
import 'registry.dart';
import 'support.dart';

final Map<String, FunctionSpec> lookupFunctions = {
  'VLOOKUP': const FunctionSpec(_vlookup, minArguments: 3, maxArguments: 4),
  'HLOOKUP': const FunctionSpec(_hlookup, minArguments: 3, maxArguments: 4),
  'XLOOKUP': const FunctionSpec(_xlookup, minArguments: 3, maxArguments: 6),
  'MATCH': const FunctionSpec(_match, minArguments: 2, maxArguments: 3),
  'INDEX': const FunctionSpec(_index, minArguments: 2, maxArguments: 3),
  'CHOOSE': const FunctionSpec(_choose, minArguments: 2),
  'ROW': const FunctionSpec(_row, maxArguments: 1),
  'COLUMN': const FunctionSpec(_column, maxArguments: 1),
  'ROWS': const FunctionSpec(_rows, minArguments: 1, maxArguments: 1),
  'COLUMNS': const FunctionSpec(_columns, minArguments: 1, maxArguments: 1),
};

/// A line of cells to search: a column or row of a range.
typedef _Line = ({int length, CellValue Function(int index) at});

CellValue _lookupValue(Arguments args) {
  final value = args.scalar(0);
  if (value is ErrorValue) throw FormulaError(value.error);
  return value;
}

/// Exact match, with wildcards when [lookup] is text.
int? _findExact(_Line line, CellValue lookup, {bool wildcards = true}) {
  final pattern = lookup is TextValue && wildcards
      ? wildcardPattern(lookup.value)
      : null;
  for (var i = 0; i < line.length; i++) {
    final value = line.at(i);
    final hit = pattern != null
        ? value is TextValue && pattern.hasMatch(value.value)
        : sameValue(value, lookup);
    if (hit) return i;
  }
  return null;
}

/// The last position not past [lookup] in a sorted line, as Excel's
/// approximate match; [descending] for MATCH type -1.
int? _findSorted(_Line line, CellValue lookup, {bool descending = false}) {
  int? found;
  for (var i = 0; i < line.length; i++) {
    final value = line.at(i);
    if (!sameType(value, lookup)) continue;
    final order = compareValues(value, lookup);
    if (descending ? order < 0 : order > 0) break;
    found = i;
  }
  return found;
}

_Line _columnLine(RangeView range, int column) =>
    (length: range.usedRows, at: (i) => range.at(i, column));

_Line _rowLine(RangeView range, int row) =>
    (length: range.usedColumns, at: (i) => range.at(row, i));

Operand _vlookup(Arguments args) => _tableLookup(args, vertical: true);

Operand _hlookup(Arguments args) => _tableLookup(args, vertical: false);

Operand _tableLookup(Arguments args, {required bool vertical}) {
  final lookup = _lookupValue(args);
  final table = args.range(1);
  final offset = args.integer(2);
  if (offset < 1) throw valueError;
  if (offset > (vertical ? table.columns : table.rows)) throw refError;
  final approximate = args.boolean(3, orElse: true);
  final line = vertical ? _columnLine(table, 0) : _rowLine(table, 0);
  final found = approximate
      ? _findSorted(line, lookup)
      : _findExact(line, lookup);
  if (found == null) throw naError;
  return Scalar(
    vertical ? table.at(found, offset - 1) : table.at(offset - 1, found),
  );
}

Operand _match(Arguments args) {
  final lookup = _lookupValue(args);
  final range = args.range(1);
  if (range.rows > 1 && range.columns > 1) throw naError;
  final line = range.columns == 1 ? _columnLine(range, 0) : _rowLine(range, 0);
  final type = args.number(2, orElse: 1);
  final found = type == 0
      ? _findExact(line, lookup)
      : _findSorted(line, lookup, descending: type < 0);
  if (found == null) throw naError;
  return number(found + 1.0);
}

Operand _xlookup(Arguments args) {
  final lookup = _lookupValue(args);
  final keys = args.range(1);
  final results = args.range(2);
  if (keys.rows > 1 && keys.columns > 1) throw valueError;
  final vertical = keys.columns == 1 && keys.rows > 1;
  if ((vertical ? results.rows : results.columns) !=
      (vertical ? keys.rows : keys.columns)) {
    throw valueError;
  }
  final line = vertical ? _columnLine(keys, 0) : _rowLine(keys, 0);
  final mode = args.integer(4, orElse: 0);
  final reverse = args.integer(5, orElse: 1) < 0;
  final found = _xmatch(line, lookup, mode, reverse);
  if (found == null) {
    if (args.has(3)) return args[3];
    throw naError;
  }
  final first = results.range.first;
  final last = results.range.last;
  return RangeRef(
    results.sheet,
    vertical
        ? CellRange(
            CellAddress(first.column, first.row + found),
            CellAddress(last.column, first.row + found),
          )
        : CellRange(
            CellAddress(first.column + found, first.row),
            CellAddress(first.column + found, last.row),
          ),
  );
}

/// XLOOKUP's match modes: 0 exact, -1 exact or next smaller, 1 exact or next
/// larger, 2 wildcards.
int? _xmatch(_Line line, CellValue lookup, int mode, bool reverse) {
  final pattern = mode == 2 && lookup is TextValue
      ? wildcardPattern(lookup.value)
      : null;
  int? best;
  CellValue? bestValue;
  for (var step = 0; step < line.length; step++) {
    final i = reverse ? line.length - 1 - step : step;
    final value = line.at(i);
    if (pattern != null) {
      if (value is TextValue && pattern.hasMatch(value.value)) return i;
      continue;
    }
    if (!sameType(value, lookup) || value is EmptyValue) continue;
    final order = compareValues(value, lookup);
    if (order == 0) return i;
    final candidate = (mode == -1 && order < 0) || (mode == 1 && order > 0);
    if (!candidate) continue;
    final closer =
        bestValue == null ||
        (mode == -1
            ? compareValues(value, bestValue) > 0
            : compareValues(value, bestValue) < 0);
    if (closer) {
      best = i;
      bestValue = value;
    }
  }
  return best;
}

Operand _index(Arguments args) {
  final range = args.range(0);
  var row = args.integer(1);
  var column = args.integer(2, orElse: 0);
  if (!args.has(2) && range.rows == 1 && range.columns > 1) {
    column = row;
    row = 0;
  }
  if (row < 0 || column < 0 || row > range.rows || column > range.columns) {
    throw refError;
  }
  final first = range.range.first;
  final last = range.range.last;
  return RangeRef(
    range.sheet,
    CellRange(
      CellAddress(
        column == 0 ? first.column : first.column + column - 1,
        row == 0 ? first.row : first.row + row - 1,
      ),
      CellAddress(
        column == 0 ? last.column : first.column + column - 1,
        row == 0 ? last.row : first.row + row - 1,
      ),
    ),
  );
}

Operand _choose(Arguments args) {
  final index = args.integer(0);
  if (index < 1 || index >= args.length) throw valueError;
  return args[index];
}

Operand _row(Arguments args) {
  if (!args.has(0)) return number(args.position.cell.row + 1.0);
  return number(args.range(0).range.first.row + 1.0);
}

Operand _column(Arguments args) {
  if (!args.has(0)) return number(args.position.cell.column + 1.0);
  return number(args.range(0).range.first.column + 1.0);
}

Operand _rows(Arguments args) =>
    number(args.isRange(0) ? args.range(0).rows.toDouble() : 1);

Operand _columns(Arguments args) =>
    number(args.isRange(0) ? args.range(0).columns.toDouble() : 1);
