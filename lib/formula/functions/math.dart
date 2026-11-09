import 'dart:math' as math;

import '../arguments.dart';
import '../evaluator.dart' as evaluator;
import '../numbers.dart';
import '../operand.dart';
import 'registry.dart';
import 'support.dart';

final Map<String, FunctionSpec> mathFunctions = {
  'SUM': const FunctionSpec(_sum),
  'PRODUCT': const FunctionSpec(_product),
  'ROUND': const FunctionSpec(_round, minArguments: 2, maxArguments: 2),
  'ROUNDUP': const FunctionSpec(_roundUp, minArguments: 2, maxArguments: 2),
  'ROUNDDOWN': const FunctionSpec(_roundDown, minArguments: 2, maxArguments: 2),
  'INT': const FunctionSpec(_int, minArguments: 1, maxArguments: 1),
  'TRUNC': const FunctionSpec(_trunc, minArguments: 1, maxArguments: 2),
  'ABS': const FunctionSpec(_abs, minArguments: 1, maxArguments: 1),
  'MOD': const FunctionSpec(_mod, minArguments: 2, maxArguments: 2),
  'POWER': const FunctionSpec(_power, minArguments: 2, maxArguments: 2),
  'SQRT': const FunctionSpec(_sqrt, minArguments: 1, maxArguments: 1),
  'PI': const FunctionSpec(_pi, maxArguments: 0),
  'RAND': const FunctionSpec(_rand, maxArguments: 0, volatile: true),
  'RANDBETWEEN': const FunctionSpec(
    _randBetween,
    minArguments: 2,
    maxArguments: 2,
    volatile: true,
  ),
};

Operand _sum(Arguments args) =>
    number(collectNumbers(args).fold(0.0, (sum, x) => sum + x));

Operand _product(Arguments args) {
  final numbers = collectNumbers(args);
  if (numbers.isEmpty) return number(0);
  return number(numbers.fold(1.0, (product, x) => product * x));
}

Operand _round(Arguments args) =>
    number(roundHalfAwayFromZero(args.number(0), args.integer(1)));

Operand _roundUp(Arguments args) =>
    number(roundAwayFromZero(args.number(0), args.integer(1)));

Operand _roundDown(Arguments args) =>
    number(roundTowardZero(args.number(0), args.integer(1)));

Operand _int(Arguments args) => number(args.number(0).floorToDouble());

Operand _trunc(Arguments args) =>
    number(roundTowardZero(args.number(0), args.integer(1, orElse: 0)));

Operand _abs(Arguments args) => number(args.number(0).abs());

Operand _mod(Arguments args) {
  final a = args.number(0), b = args.number(1);
  if (b == 0) throw div0Error;
  return number(a - b * (a / b).floorToDouble());
}

Operand _power(Arguments args) =>
    number(evaluator.power(args.number(0), args.number(1)));

Operand _sqrt(Arguments args) {
  final value = args.number(0);
  if (value < 0) throw numError;
  return number(math.sqrt(value));
}

Operand _pi(Arguments args) => number(math.pi);

Operand _rand(Arguments args) => number(args.random.nextDouble());

Operand _randBetween(Arguments args) {
  final low = args.number(0).ceil(), high = args.number(1).floor();
  if (low > high) throw numError;
  return number((low + args.random.nextInt(high - low + 1)).toDouble());
}
