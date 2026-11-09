import '../arguments.dart';
import '../operand.dart';
import 'date_time.dart';
import 'info.dart';
import 'logical.dart';
import 'lookup.dart';
import 'math.dart';
import 'statistics.dart';
import 'text.dart';

typedef FunctionBody = Operand Function(Arguments args);

class FunctionSpec {
  const FunctionSpec(
    this.body, {
    this.minArguments = 0,
    this.maxArguments = 255,
    this.volatile = false,
  });

  final FunctionBody body;
  final int minArguments;
  final int maxArguments;

  /// Recalculated on every change, like RAND and NOW.
  final bool volatile;
}

/// Every function by canonical name.
final Map<String, FunctionSpec> functionRegistry = {
  ...mathFunctions,
  ...statisticsFunctions,
  ...logicalFunctions,
  ...lookupFunctions,
  ...textFunctions,
  ...dateTimeFunctions,
  ...infoFunctions,
};
