import '../sheet/cell_value.dart';
import 'comparison.dart';
import 'locale.dart';
import 'recognize.dart';

/// A COUNTIF/SUMIF condition such as `5`, `">5"`, `"<>x"` or `"ab*"`.
class Criterion {
  Criterion._(this._operator, this._operand, this._pattern);

  factory Criterion.parse(CellValue criteria, FormulaLocale locale) {
    if (criteria is EmptyValue) {
      return Criterion._('=', const NumberValue(0), null);
    }
    if (criteria is! TextValue) return Criterion._('=', criteria, null);
    final text = criteria.value;
    final operator = _operators.firstWhere(text.startsWith, orElse: () => '');
    final rest = text.substring(operator.length);
    final op = operator.isEmpty ? '=' : operator;
    final operand = _parseOperand(rest, locale);
    final pattern = operand is TextValue && (op == '=' || op == '<>')
        ? wildcardPattern(operand.value)
        : null;
    return Criterion._(op, operand, pattern);
  }

  static const _operators = ['<=', '>=', '<>', '=', '<', '>'];

  final String _operator;
  final CellValue _operand;
  final RegExp? _pattern;

  bool matches(CellValue value) {
    final operand = _operand;
    if (operand is TextValue && operand.value.isEmpty) {
      final blank =
          value is EmptyValue || (value is TextValue && value.value.isEmpty);
      return switch (_operator) {
        '=' => blank,
        '<>' => !blank,
        _ => false,
      };
    }
    final equal = _equals(value);
    if (_operator == '=') return equal;
    if (_operator == '<>') return !equal;
    if (!sameType(value, operand)) return false;
    final order = compareValues(value, operand);
    return switch (_operator) {
      '<' => order < 0,
      '>' => order > 0,
      '<=' => order <= 0,
      _ => order >= 0,
    };
  }

  bool _equals(CellValue value) {
    final pattern = _pattern;
    if (pattern != null) {
      return value is TextValue && pattern.hasMatch(value.value);
    }
    if (_operand is ErrorValue) return value == _operand;
    return sameValue(value, _operand);
  }

  static CellValue _parseOperand(String text, FormulaLocale locale) {
    if (text.isEmpty) return const TextValue('');
    final constant = recognizeConstant(text, locale)?.value;
    if (constant is BoolValue || constant is ErrorValue) return constant!;
    final number = textToNumber(text, locale);
    if (number != null) return NumberValue(number);
    final upper = text.toUpperCase();
    if (upper == 'TRUE' || upper == 'FALSE') return BoolValue(upper == 'TRUE');
    return TextValue(text);
  }
}

/// A whole-text, case-insensitive pattern where `*` is any run, `?` any
/// character and `~` escapes them.
RegExp wildcardPattern(String text, {bool anchored = true}) {
  final buffer = StringBuffer(anchored ? '^' : '');
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '~' && i + 1 < text.length) {
      buffer.write(RegExp.escape(text[++i]));
    } else if (char == '*') {
      buffer.write('.*');
    } else if (char == '?') {
      buffer.write('.');
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  if (anchored) buffer.write(r'$');
  return RegExp(buffer.toString(), caseSensitive: false, dotAll: true);
}
