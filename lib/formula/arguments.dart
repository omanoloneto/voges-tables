import 'dart:math' as math;

import '../sheet/cell_value.dart';
import 'ast.dart';
import 'cell_source.dart';
import 'coercion.dart';
import 'evaluator.dart';
import 'locale.dart';
import 'operand.dart';

/// A function's arguments, evaluated only when asked for, so IF and IFERROR
/// skip what they do not need.
class Arguments {
  Arguments(this._evaluator, this._expressions, this.position)
    : _cache = List<Operand?>.filled(_expressions.length, null);

  final Evaluator _evaluator;
  final List<Expr> _expressions;
  final List<Operand?> _cache;
  final Position position;

  int get length => _expressions.length;
  FormulaLocale get locale => _evaluator.locale;
  math.Random get random => _evaluator.random;
  DateTime now() => _evaluator.clock();

  /// Whether argument [index] was written at all (`F(1,)` has two).
  bool has(int index) => index < length;

  /// The argument as written; errors come back as [Scalar] values.
  Operand operator [](int index) {
    if (index >= length) return const Scalar(EmptyValue());
    return _cache[index] ??= _evaluate(index);
  }

  Operand _evaluate(int index) {
    try {
      return _evaluator.evaluate(_expressions[index], position);
    } on FormulaError catch (e) {
      return Scalar(ErrorValue(e.error));
    }
  }

  /// One value, errors included; never throws.
  CellValue scalar(int index) {
    try {
      return _evaluator.scalarOf(this[index], position);
    } on FormulaError catch (e) {
      return ErrorValue(e.error);
    }
  }

  double number(int index, {double? orElse}) {
    if (!has(index) && orElse != null) return orElse;
    return toNumber(scalar(index), locale);
  }

  /// A whole number, truncated as Excel does for counts and positions.
  int integer(int index, {int? orElse}) {
    if (!has(index) && orElse != null) return orElse;
    final value = number(index);
    if (value.abs() > 1e15) throw numError;
    return value.truncate();
  }

  String text(int index, {String? orElse}) {
    if (!has(index) && orElse != null) return orElse;
    return toText(scalar(index), locale);
  }

  bool boolean(int index, {bool? orElse}) {
    if (!has(index) && orElse != null) return orElse;
    return toBool(scalar(index), locale);
  }

  bool isRange(int index) => this[index] is RangeRef;

  /// The argument as cells, or `#VALUE!` when it is not a reference.
  RangeView range(int index) {
    final operand = this[index];
    if (operand is RangeRef) return view(operand);
    final value = (operand as Scalar).value;
    if (value is ErrorValue) throw FormulaError(value.error);
    throw valueError;
  }

  RangeView view(RangeRef ref) =>
      RangeView(_evaluator.source, ref.sheet, ref.range);
}
