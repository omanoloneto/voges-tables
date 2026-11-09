import '../../sheet/cell_value.dart';
import '../arguments.dart';
import '../operand.dart';
import 'registry.dart';
import 'support.dart';

final Map<String, FunctionSpec> infoFunctions = {
  'ISBLANK': _is((value) => value is EmptyValue),
  'ISNUMBER': _is((value) => value is NumberValue),
  'ISTEXT': _is((value) => value is TextValue),
  'ISERROR': _is((value) => value is ErrorValue),
  'ISNA': _is((value) => value is ErrorValue && value.error == CellError.na),
  'NA': const FunctionSpec(_na, maxArguments: 0),
};

FunctionSpec _is(bool Function(CellValue value) test) => FunctionSpec(
  (args) => boolean(test(args.scalar(0))),
  minArguments: 1,
  maxArguments: 1,
);

Operand _na(Arguments args) => const Scalar(ErrorValue(CellError.na));
