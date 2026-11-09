import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';

/// What an expression evaluates to: one value or a reference to cells.
sealed class Operand {
  const Operand();
}

final class Scalar extends Operand {
  const Scalar(this.value);
  final CellValue value;
}

final class RangeRef extends Operand {
  const RangeRef(this.sheet, this.range);
  final int sheet;
  final CellRange range;
}

/// Thrown inside the evaluator to stop at an error; never leaves the engine.
class FormulaError implements Exception {
  const FormulaError(this.error);
  final CellError error;
}

const valueError = FormulaError(CellError.value);
const numError = FormulaError(CellError.num);
const refError = FormulaError(CellError.ref);
const naError = FormulaError(CellError.na);
const div0Error = FormulaError(CellError.div0);
