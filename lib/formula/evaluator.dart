import 'dart:math' as math;

import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';
import 'arguments.dart';
import 'ast.dart';
import 'cell_source.dart';
import 'coercion.dart';
import 'comparison.dart';
import 'functions/registry.dart';
import 'locale.dart';
import 'operand.dart';

/// Where a formula is being evaluated.
class Position {
  const Position(this.sheet, this.cell);
  final int sheet;
  final CellAddress cell;
}

/// Evaluates parsed formulas against a [CellSource].
class Evaluator {
  Evaluator(
    this.source, {
    this.locale = FormulaLocale.en,
    DateTime Function()? clock,
    math.Random? random,
  }) : clock = clock ?? DateTime.now,
       random = random ?? math.Random();

  final CellSource source;
  final FormulaLocale locale;
  final DateTime Function() clock;
  final math.Random random;

  /// The value a cell shows for [expr]; never throws.
  CellValue evaluateFormula(Expr expr, int sheet, CellAddress cell) {
    final position = Position(sheet, cell);
    try {
      final value = scalarOf(evaluate(expr, position), position);
      return value is EmptyValue ? const NumberValue(0) : value;
    } on FormulaError catch (e) {
      return ErrorValue(e.error);
    } catch (_) {
      return const ErrorValue(CellError.value);
    }
  }

  Operand evaluate(Expr expr, Position position) => switch (expr) {
    NumberExpr(:final value) => Scalar(NumberValue(value)),
    TextExpr(:final value) => Scalar(TextValue(value)),
    BoolExpr(:final value) => Scalar(BoolValue(value)),
    ErrorExpr(:final error) => Scalar(ErrorValue(error)),
    MissingExpr() => const Scalar(EmptyValue()),
    NameExpr() => const Scalar(ErrorValue(CellError.name)),
    ReferenceExpr() => _reference(expr, position),
    UnaryExpr() => _unary(expr, position),
    BinaryExpr() => _binary(expr, position),
    CallExpr() => _call(expr, position),
  };

  /// One value from [operand]; a range gives the cell in the formula's row
  /// or column (implicit intersection) or `#VALUE!`.
  CellValue scalarOf(Operand operand, Position position) {
    if (operand is Scalar) return operand.value;
    final ref = operand as RangeRef;
    final range = ref.range;
    if (range.isSingle) return source.valueAt(ref.sheet, range.first);
    final cell = position.cell;
    if (range.columns == 1 &&
        cell.row >= range.first.row &&
        cell.row <= range.last.row) {
      return source.valueAt(
        ref.sheet,
        CellAddress(range.first.column, cell.row),
      );
    }
    if (range.rows == 1 &&
        cell.column >= range.first.column &&
        cell.column <= range.last.column) {
      return source.valueAt(
        ref.sheet,
        CellAddress(cell.column, range.first.row),
      );
    }
    throw valueError;
  }

  Operand _reference(ReferenceExpr expr, Position position) {
    final name = expr.sheet;
    final sheet = name == null ? position.sheet : source.sheetIndex(name);
    if (sheet < 0) return const Scalar(ErrorValue(CellError.ref));
    return RangeRef(sheet, expr.range);
  }

  Operand _unary(UnaryExpr expr, Position position) {
    final value = scalarOf(evaluate(expr.operand, position), position);
    final number = toNumber(value, locale);
    return numberResult(switch (expr.operator) {
      UnaryOperator.negate => -number,
      UnaryOperator.plus => number,
      UnaryOperator.percent => number / 100,
    });
  }

  Operand _binary(BinaryExpr expr, Position position) {
    final left = _settled(expr.left, position);
    final right = _settled(expr.right, position);
    switch (expr.operator) {
      case BinaryOperator.concat:
        return Scalar(TextValue(toText(left, locale) + toText(right, locale)));
      case BinaryOperator.equal ||
          BinaryOperator.notEqual ||
          BinaryOperator.less ||
          BinaryOperator.greater ||
          BinaryOperator.lessOrEqual ||
          BinaryOperator.greaterOrEqual:
        if (left is ErrorValue) throw FormulaError(left.error);
        if (right is ErrorValue) throw FormulaError(right.error);
        final order = compareValues(left, right);
        return Scalar(
          BoolValue(switch (expr.operator) {
            BinaryOperator.equal => order == 0,
            BinaryOperator.notEqual => order != 0,
            BinaryOperator.less => order < 0,
            BinaryOperator.greater => order > 0,
            BinaryOperator.lessOrEqual => order <= 0,
            _ => order >= 0,
          }),
        );
      default:
        final a = toNumber(left, locale);
        final b = toNumber(right, locale);
        return numberResult(arithmetic(expr.operator, a, b));
    }
  }

  /// The value of [expr] with errors kept as values, so `#N/A+1/0` reports
  /// the left error as Excel does.
  CellValue _settled(Expr expr, Position position) {
    try {
      return scalarOf(evaluate(expr, position), position);
    } on FormulaError catch (e) {
      return ErrorValue(e.error);
    }
  }

  Operand _call(CallExpr expr, Position position) {
    final spec = functionRegistry[expr.name];
    if (spec == null) throw const FormulaError(CellError.name);
    final count = expr.arguments.length;
    if (count < spec.minArguments || count > spec.maxArguments) {
      throw valueError;
    }
    return spec.body(Arguments(this, expr.arguments, position));
  }
}

double arithmetic(BinaryOperator operator, double a, double b) {
  switch (operator) {
    case BinaryOperator.add:
      return a + b;
    case BinaryOperator.subtract:
      return a - b;
    case BinaryOperator.multiply:
      return a * b;
    case BinaryOperator.divide:
      if (b == 0) throw div0Error;
      return a / b;
    default:
      return power(a, b);
  }
}

double power(double base, double exponent) {
  if (base == 0 && exponent == 0) throw numError;
  if (base == 0 && exponent < 0) throw div0Error;
  final result = math.pow(base, exponent).toDouble();
  if (result.isNaN) throw numError;
  return result;
}
