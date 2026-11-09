import '../../sheet/cell_value.dart';
import '../arguments.dart';
import '../coercion.dart';
import '../operand.dart';

/// The numbers SUM sees in arguments [from] onwards: typed values are
/// converted, while cells only count when they hold numbers. Errors stop it.
List<double> collectNumbers(Arguments args, {int from = 0}) {
  final numbers = <double>[];
  for (var i = from; i < args.length; i++) {
    final operand = args[i];
    if (operand is RangeRef) {
      for (final value in args.view(operand).values) {
        if (value is NumberValue) numbers.add(value.value);
        if (value is ErrorValue) throw FormulaError(value.error);
      }
    } else {
      final value = args.scalar(i);
      if (value is EmptyValue) continue;
      numbers.add(toNumber(value, args.locale));
    }
  }
  return numbers;
}

/// Every value of the argument: the cells of a range or the single value.
Iterable<CellValue> flatten(Arguments args, int index) {
  final operand = args[index];
  if (operand is RangeRef) return args.view(operand).values;
  return [args.scalar(index)];
}

Scalar number(double value) => numberResult(value);
Scalar text(String value) => Scalar(TextValue(value));
Scalar boolean(bool value) => Scalar(BoolValue(value));
