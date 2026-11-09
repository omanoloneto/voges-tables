import '../../sheet/cell_value.dart';
import '../arguments.dart';
import '../coercion.dart';
import '../operand.dart';
import 'registry.dart';
import 'support.dart';

final Map<String, FunctionSpec> logicalFunctions = {
  'IF': const FunctionSpec(_if, minArguments: 1, maxArguments: 3),
  'IFS': const FunctionSpec(_ifs, minArguments: 2),
  'IFERROR': const FunctionSpec(_ifError, minArguments: 2, maxArguments: 2),
  'AND': const FunctionSpec(_and, minArguments: 1),
  'OR': const FunctionSpec(_or, minArguments: 1),
  'XOR': const FunctionSpec(_xor, minArguments: 1),
  'NOT': const FunctionSpec(_not, minArguments: 1, maxArguments: 1),
  'TRUE': const FunctionSpec(_true, maxArguments: 0),
  'FALSE': const FunctionSpec(_false, maxArguments: 0),
};

Operand _if(Arguments args) {
  if (args.boolean(0)) return args.has(1) ? args[1] : number(0);
  return args.has(2) ? args[2] : boolean(false);
}

Operand _ifs(Arguments args) {
  for (var i = 0; i + 1 < args.length; i += 2) {
    if (args.boolean(i)) return args[i + 1];
  }
  throw naError;
}

Operand _ifError(Arguments args) =>
    args.scalar(0) is ErrorValue ? args[1] : args[0];

/// The logical values of every argument; text and empty cells are skipped.
List<bool> _logicals(Arguments args) {
  final values = <bool>[];
  for (var i = 0; i < args.length; i++) {
    if (!args.isRange(i)) {
      if (args.scalar(i) is! EmptyValue) values.add(args.boolean(i));
      continue;
    }
    for (final value in flatten(args, i)) {
      switch (value) {
        case BoolValue(:final value):
          values.add(value);
        case NumberValue(:final value):
          values.add(value != 0);
        case ErrorValue(:final error):
          throw FormulaError(error);
        default:
          break;
      }
    }
  }
  if (values.isEmpty) throw valueError;
  return values;
}

Operand _and(Arguments args) => boolean(_logicals(args).every((x) => x));

Operand _or(Arguments args) => boolean(_logicals(args).any((x) => x));

Operand _xor(Arguments args) =>
    boolean(_logicals(args).where((x) => x).length.isOdd);

Operand _not(Arguments args) => boolean(!toBool(args.scalar(0), args.locale));

Operand _true(Arguments args) => boolean(true);

Operand _false(Arguments args) => boolean(false);
