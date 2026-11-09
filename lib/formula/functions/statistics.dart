import 'dart:math' as math;

import '../../sheet/cell_value.dart';
import '../arguments.dart';
import '../cell_source.dart';
import '../coercion.dart';
import '../comparison.dart';
import '../criteria.dart';
import '../operand.dart';
import 'registry.dart';
import 'support.dart';

final Map<String, FunctionSpec> statisticsFunctions = {
  'AVERAGE': const FunctionSpec(_average, minArguments: 1),
  'MIN': const FunctionSpec(_min),
  'MAX': const FunctionSpec(_max),
  'COUNT': const FunctionSpec(_count),
  'COUNTA': const FunctionSpec(_countA),
  'COUNTBLANK': const FunctionSpec(
    _countBlank,
    minArguments: 1,
    maxArguments: 1,
  ),
  'MEDIAN': const FunctionSpec(_median, minArguments: 1),
  'MODE': const FunctionSpec(_mode, minArguments: 1),
  'MODE.SNGL': const FunctionSpec(_mode, minArguments: 1),
  'STDEV': const FunctionSpec(_stdev, minArguments: 1),
  'STDEV.S': const FunctionSpec(_stdev, minArguments: 1),
  'VAR': const FunctionSpec(_variance, minArguments: 1),
  'VAR.S': const FunctionSpec(_variance, minArguments: 1),
  'LARGE': const FunctionSpec(_large, minArguments: 2, maxArguments: 2),
  'SMALL': const FunctionSpec(_small, minArguments: 2, maxArguments: 2),
  'RANK': const FunctionSpec(_rank, minArguments: 2, maxArguments: 3),
  'RANK.EQ': const FunctionSpec(_rank, minArguments: 2, maxArguments: 3),
  'COUNTIF': const FunctionSpec(_countIf, minArguments: 2, maxArguments: 2),
  'COUNTIFS': const FunctionSpec(_countIfs, minArguments: 2),
  'SUMIF': const FunctionSpec(_sumIf, minArguments: 2, maxArguments: 3),
  'SUMIFS': const FunctionSpec(_sumIfs, minArguments: 3),
  'AVERAGEIF': const FunctionSpec(_averageIf, minArguments: 2, maxArguments: 3),
};

Operand _average(Arguments args) {
  final numbers = collectNumbers(args);
  if (numbers.isEmpty) throw div0Error;
  return number(_sumOf(numbers) / numbers.length);
}

Operand _min(Arguments args) {
  final numbers = collectNumbers(args);
  return number(numbers.isEmpty ? 0 : numbers.reduce(math.min));
}

Operand _max(Arguments args) {
  final numbers = collectNumbers(args);
  return number(numbers.isEmpty ? 0 : numbers.reduce(math.max));
}

Operand _count(Arguments args) {
  var count = 0;
  for (var i = 0; i < args.length; i++) {
    if (args.isRange(i)) {
      count += flatten(args, i).whereType<NumberValue>().length;
      continue;
    }
    final value = args.scalar(i);
    final counts = switch (value) {
      NumberValue() || BoolValue() => true,
      TextValue() => _isNumeric(value, args),
      _ => false,
    };
    if (counts) count++;
  }
  return number(count.toDouble());
}

bool _isNumeric(CellValue value, Arguments args) {
  try {
    toNumber(value, args.locale);
    return true;
  } on FormulaError {
    return false;
  }
}

Operand _countA(Arguments args) {
  var count = 0;
  for (var i = 0; i < args.length; i++) {
    if (args.isRange(i)) {
      count += flatten(args, i).length;
    } else if (args.scalar(i) is! EmptyValue) {
      count++;
    }
  }
  return number(count.toDouble());
}

Operand _countBlank(Arguments args) {
  final range = args.range(0);
  final filled = range.values
      .where((value) => !(value is TextValue && value.value.isEmpty))
      .length;
  return number((range.area - filled).toDouble());
}

Operand _median(Arguments args) {
  final numbers = collectNumbers(args)..sort();
  if (numbers.isEmpty) throw numError;
  final middle = numbers.length ~/ 2;
  return number(
    numbers.length.isOdd
        ? numbers[middle]
        : (numbers[middle - 1] + numbers[middle]) / 2,
  );
}

Operand _mode(Arguments args) {
  final counts = <double, int>{};
  for (final value in collectNumbers(args)) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  double? best;
  var bestCount = 1;
  counts.forEach((value, count) {
    if (count > bestCount) {
      best = value;
      bestCount = count;
    }
  });
  if (best == null) throw naError;
  return number(best!);
}

Operand _stdev(Arguments args) =>
    number(math.sqrt(_sampleVariance(collectNumbers(args))));

Operand _variance(Arguments args) =>
    number(_sampleVariance(collectNumbers(args)));

double _sampleVariance(List<double> numbers) {
  if (numbers.length < 2) throw div0Error;
  final mean = _sumOf(numbers) / numbers.length;
  final squares = numbers.fold(0.0, (sum, x) => sum + (x - mean) * (x - mean));
  return squares / (numbers.length - 1);
}

double _sumOf(List<double> numbers) => numbers.fold(0.0, (sum, x) => sum + x);

Operand _large(Arguments args) => _kth(args, descending: true);

Operand _small(Arguments args) => _kth(args, descending: false);

Operand _kth(Arguments args, {required bool descending}) {
  final numbers = _numbersOf(args, 0)..sort();
  final k = args.number(1).ceil();
  if (k < 1 || k > numbers.length) throw numError;
  return number(descending ? numbers[numbers.length - k] : numbers[k - 1]);
}

/// Numbers of a single argument; text and booleans in cells are skipped.
List<double> _numbersOf(Arguments args, int index) {
  if (!args.isRange(index)) return [args.number(index)];
  final numbers = <double>[];
  for (final value in flatten(args, index)) {
    if (value is NumberValue) numbers.add(value.value);
    if (value is ErrorValue) throw FormulaError(value.error);
  }
  return numbers;
}

Operand _rank(Arguments args) {
  final target = args.number(0);
  final numbers = args.range(1).values.whereType<NumberValue>();
  final ascending = args.number(2, orElse: 0) != 0;
  var found = false;
  var better = 0;
  for (final value in numbers) {
    final order = compareValues(value, NumberValue(target));
    if (order == 0) found = true;
    if (ascending ? order < 0 : order > 0) better++;
  }
  if (!found) throw naError;
  return number(better + 1.0);
}

typedef _Test = (RangeView, Criterion);

Operand _countIf(Arguments args) => number(
  _countMatches([
    (args.range(0), Criterion.parse(args.scalar(1), args.locale)),
  ]).toDouble(),
);

Operand _countIfs(Arguments args) {
  if (args.length.isOdd) throw valueError;
  return number(_countMatches(_tests(args, 0)).toDouble());
}

Operand _sumIf(Arguments args) {
  final range = args.range(0);
  final criterion = Criterion.parse(args.scalar(1), args.locale);
  final sumRange = args.has(2)
      ? args.range(2).resized(range.rows, range.columns)
      : range;
  return number(_sumMatches([(range, criterion)], sumRange).$1);
}

Operand _averageIf(Arguments args) {
  final range = args.range(0);
  final criterion = Criterion.parse(args.scalar(1), args.locale);
  final averageRange = args.has(2)
      ? args.range(2).resized(range.rows, range.columns)
      : range;
  final (sum, count) = _sumMatches([(range, criterion)], averageRange);
  if (count == 0) throw div0Error;
  return number(sum / count);
}

Operand _sumIfs(Arguments args) {
  if (args.length.isEven) throw valueError;
  return number(_sumMatches(_tests(args, 1), args.range(0)).$1);
}

List<_Test> _tests(Arguments args, int from) => [
  for (var i = from; i < args.length; i += 2)
    (args.range(i), Criterion.parse(args.scalar(i + 1), args.locale)),
];

/// Calls [onMatch] with each offset where every test holds, and returns how
/// many cells past the used area were skipped.
int _forEachMatch(
  List<_Test> tests,
  List<RangeView> alsoRead,
  void Function(int row, int column) onMatch,
) {
  final first = tests.first.$1;
  for (final (range, _) in tests) {
    if (range.rows != first.rows || range.columns != first.columns) {
      throw valueError;
    }
  }
  var rows = 0, columns = 0;
  for (final range in [for (final test in tests) test.$1, ...alsoRead]) {
    rows = math.max(rows, range.usedRows);
    columns = math.max(columns, range.usedColumns);
  }
  rows = math.min(rows, first.rows);
  columns = math.min(columns, first.columns);
  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      if (tests.every((test) => test.$2.matches(test.$1.at(row, column)))) {
        onMatch(row, column);
      }
    }
  }
  return first.area - rows * columns;
}

int _countMatches(List<_Test> tests) {
  var count = 0;
  final skipped = _forEachMatch(tests, const [], (_, _) => count++);
  final emptyMatches = tests.every(
    (test) => test.$2.matches(const EmptyValue()),
  );
  return count + (emptyMatches ? skipped : 0);
}

(double, int) _sumMatches(List<_Test> tests, RangeView values) {
  final first = tests.first.$1;
  if (values.rows != first.rows || values.columns != first.columns) {
    throw valueError;
  }
  var sum = 0.0;
  var count = 0;
  _forEachMatch(tests, [values], (row, column) {
    final value = values.at(row, column);
    if (value is ErrorValue) throw FormulaError(value.error);
    if (value is NumberValue) {
      sum += value.value;
      count++;
    }
  });
  return (sum, count);
}
