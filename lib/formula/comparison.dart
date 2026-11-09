import '../sheet/cell_value.dart';

/// Excel's ordering: numbers < text < booleans, text ignoring case. An empty
/// value takes the type of the other side. Errors must be handled before.
int compareValues(CellValue a, CellValue b) {
  if (a is EmptyValue) a = _emptyLike(b);
  if (b is EmptyValue) b = _emptyLike(a);
  final rankA = _rank(a), rankB = _rank(b);
  if (rankA != rankB) return rankA - rankB;
  return switch ((a, b)) {
    (NumberValue(value: final x), NumberValue(value: final y)) =>
      _compareNumbers(x, y),
    (TextValue(value: final x), TextValue(value: final y)) =>
      x.toLowerCase().compareTo(y.toLowerCase()).sign,
    (BoolValue(value: final x), BoolValue(value: final y)) =>
      x == y ? 0 : (x ? 1 : -1),
    _ => 0,
  };
}

/// Same type and equal, as lookups need (5 does not find "5").
bool sameValue(CellValue a, CellValue b) =>
    _rank(a) == _rank(b) && a is! EmptyValue && compareValues(a, b) == 0;

bool sameType(CellValue a, CellValue b) => _rank(a) == _rank(b);

int _compareNumbers(double x, double y) {
  if (x == y) return 0;
  // Excel compares with 15 significant digits, so 0.1 + 0.2 = 0.3.
  final scale = x.abs() > y.abs() ? x.abs() : y.abs();
  if ((x - y).abs() <= scale * 1e-15) return 0;
  return x < y ? -1 : 1;
}

CellValue _emptyLike(CellValue other) => switch (other) {
  TextValue() => const TextValue(''),
  BoolValue() => const BoolValue(false),
  _ => const NumberValue(0),
};

int _rank(CellValue value) => switch (value) {
  NumberValue() => 0,
  TextValue() => 1,
  BoolValue() => 2,
  EmptyValue() => 3,
  ErrorValue() => 4,
};
