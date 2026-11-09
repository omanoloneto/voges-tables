import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';

/// A parsed formula.
sealed class Expr {
  const Expr();

  /// This node and every node below it.
  Iterable<Expr> get nodes sync* {
    yield this;
    switch (this) {
      case UnaryExpr(:final operand):
        yield* operand.nodes;
      case BinaryExpr(:final left, :final right):
        yield* left.nodes;
        yield* right.nodes;
      case CallExpr(:final arguments):
        for (final argument in arguments) {
          yield* argument.nodes;
        }
      default:
        break;
    }
  }
}

class NumberExpr extends Expr {
  const NumberExpr(this.value);
  final double value;
}

class TextExpr extends Expr {
  const TextExpr(this.value);
  final String value;
}

class BoolExpr extends Expr {
  const BoolExpr(this.value);
  final bool value;
}

class ErrorExpr extends Expr {
  const ErrorExpr(this.error);
  final CellError error;
}

/// An argument left empty, as in `IF(A1,,2)`.
class MissingExpr extends Expr {
  const MissingExpr();
}

/// A cell or range, on the formula's own sheet when [sheet] is null. Whole
/// columns and rows span every row or column of the sheet.
class ReferenceExpr extends Expr {
  const ReferenceExpr(
    this.sheet,
    this.range, {
    this.wholeColumns = false,
    this.wholeRows = false,
  });
  final String? sheet;
  final CellRange range;

  /// Written as `A:C`, without rows, or as `1:3`, without columns: moving
  /// rows leaves `A:C` as it is, and moving columns leaves `1:3`.
  final bool wholeColumns;
  final bool wholeRows;
}

/// An identifier that is neither a function nor a reference.
class NameExpr extends Expr {
  const NameExpr(this.name);
  final String name;
}

enum UnaryOperator { negate, plus, percent }

class UnaryExpr extends Expr {
  const UnaryExpr(this.operator, this.operand);
  final UnaryOperator operator;
  final Expr operand;
}

enum BinaryOperator {
  add,
  subtract,
  multiply,
  divide,
  power,
  concat,
  equal,
  notEqual,
  less,
  greater,
  lessOrEqual,
  greaterOrEqual,
}

class BinaryExpr extends Expr {
  const BinaryExpr(this.operator, this.left, this.right);
  final BinaryOperator operator;
  final Expr left;
  final Expr right;
}

/// A function call; [name] is upper case, without the `_xlfn.` prefix.
class CallExpr extends Expr {
  const CallExpr(this.name, this.arguments);
  final String name;
  final List<Expr> arguments;
}
