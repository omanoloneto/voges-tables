import '../../sheet/cell_value.dart';
import '../arguments.dart';
import '../coercion.dart';
import '../criteria.dart';
import '../operand.dart';
import '../recognize.dart';
import '../text_format.dart';
import 'registry.dart';
import 'support.dart';

final Map<String, FunctionSpec> textFunctions = {
  'LEN': const FunctionSpec(_len, minArguments: 1, maxArguments: 1),
  'LEFT': const FunctionSpec(_left, minArguments: 1, maxArguments: 2),
  'RIGHT': const FunctionSpec(_right, minArguments: 1, maxArguments: 2),
  'MID': const FunctionSpec(_mid, minArguments: 3, maxArguments: 3),
  'UPPER': const FunctionSpec(_upper, minArguments: 1, maxArguments: 1),
  'LOWER': const FunctionSpec(_lower, minArguments: 1, maxArguments: 1),
  'PROPER': const FunctionSpec(_proper, minArguments: 1, maxArguments: 1),
  'TRIM': const FunctionSpec(_trim, minArguments: 1, maxArguments: 1),
  'CONCATENATE': const FunctionSpec(_concatenate, minArguments: 1),
  'CONCAT': const FunctionSpec(_concat, minArguments: 1),
  'TEXTJOIN': const FunctionSpec(_textJoin, minArguments: 3),
  'TEXT': const FunctionSpec(_text, minArguments: 2, maxArguments: 2),
  'VALUE': const FunctionSpec(_value, minArguments: 1, maxArguments: 1),
  'FIND': const FunctionSpec(_find, minArguments: 2, maxArguments: 3),
  'SEARCH': const FunctionSpec(_search, minArguments: 2, maxArguments: 3),
  'SUBSTITUTE': const FunctionSpec(
    _substitute,
    minArguments: 3,
    maxArguments: 4,
  ),
  'REPT': const FunctionSpec(_rept, minArguments: 2, maxArguments: 2),
  'EXACT': const FunctionSpec(_exact, minArguments: 2, maxArguments: 2),
};

const _maxTextLength = 32767;

Scalar _checked(String value) {
  if (value.length > _maxTextLength) throw valueError;
  return text(value);
}

Operand _len(Arguments args) => number(args.text(0).length.toDouble());

int _count(Arguments args, int index) {
  final count = args.integer(index, orElse: 1);
  if (count < 0) throw valueError;
  return count;
}

Operand _left(Arguments args) {
  final value = args.text(0);
  final count = _count(args, 1);
  return text(value.substring(0, count.clamp(0, value.length)));
}

Operand _right(Arguments args) {
  final value = args.text(0);
  final count = _count(args, 1);
  return text(value.substring(value.length - count.clamp(0, value.length)));
}

Operand _mid(Arguments args) {
  final value = args.text(0);
  final start = args.integer(1);
  final count = args.integer(2);
  if (start < 1 || count < 0) throw valueError;
  if (start > value.length) return text('');
  final end = (start - 1 + count).clamp(0, value.length);
  return text(value.substring(start - 1, end));
}

Operand _upper(Arguments args) => text(args.text(0).toUpperCase());

Operand _lower(Arguments args) => text(args.text(0).toLowerCase());

Operand _proper(Arguments args) {
  final buffer = StringBuffer();
  var previousLetter = false;
  for (final char in args.text(0).split('')) {
    final letter = char.toUpperCase() != char.toLowerCase();
    buffer.write(
      letter && !previousLetter ? char.toUpperCase() : char.toLowerCase(),
    );
    previousLetter = letter;
  }
  return text(buffer.toString());
}

Operand _trim(Arguments args) =>
    text(args.text(0).trim().replaceAll(RegExp(' {2,}'), ' '));

Operand _concatenate(Arguments args) {
  final buffer = StringBuffer();
  for (var i = 0; i < args.length; i++) {
    buffer.write(args.text(i));
  }
  return _checked(buffer.toString());
}

Operand _concat(Arguments args) {
  final buffer = StringBuffer();
  for (var i = 0; i < args.length; i++) {
    for (final value in flatten(args, i)) {
      buffer.write(toText(value, args.locale));
    }
  }
  return _checked(buffer.toString());
}

Operand _textJoin(Arguments args) {
  final delimiter = args.text(0);
  final ignoreEmpty = args.boolean(1);
  final parts = <String>[];
  for (var i = 2; i < args.length; i++) {
    for (final value in flatten(args, i)) {
      final part = toText(value, args.locale);
      if (!ignoreEmpty || part.isNotEmpty) parts.add(part);
    }
  }
  return _checked(parts.join(delimiter));
}

Operand _text(Arguments args) {
  final value = args.scalar(0);
  if (value is ErrorValue) throw FormulaError(value.error);
  return text(formatWithCode(value, args.text(1), args.locale));
}

Operand _value(Arguments args) {
  final value = args.scalar(0);
  return switch (value) {
    NumberValue() => Scalar(value),
    EmptyValue() => number(0),
    TextValue(:final value) => number(
      textToNumber(value, args.locale) ?? (throw valueError),
    ),
    ErrorValue(:final error) => throw FormulaError(error),
    BoolValue() => throw valueError,
  };
}

int _start(Arguments args, String within) {
  final start = args.integer(2, orElse: 1);
  if (start < 1 || start > within.length + 1) throw valueError;
  return start - 1;
}

Operand _find(Arguments args) {
  final needle = args.text(0);
  final within = args.text(1);
  final index = within.indexOf(needle, _start(args, within));
  if (index < 0) throw valueError;
  return number(index + 1.0);
}

Operand _search(Arguments args) {
  final pattern = wildcardPattern(args.text(0), anchored: false);
  final within = args.text(1);
  final match = pattern.allMatches(within, _start(args, within)).firstOrNull;
  if (match == null) throw valueError;
  return number(match.start + 1.0);
}

Operand _substitute(Arguments args) {
  final value = args.text(0);
  final old = args.text(1);
  final replacement = args.text(2);
  if (old.isEmpty) return text(value);
  if (!args.has(3)) return _checked(value.replaceAll(old, replacement));
  final instance = args.integer(3);
  if (instance < 1) throw valueError;
  var index = -1;
  var from = 0;
  for (var n = 0; n < instance; n++) {
    index = value.indexOf(old, from);
    if (index < 0) return text(value);
    from = index + old.length;
  }
  return _checked(value.replaceRange(index, index + old.length, replacement));
}

Operand _rept(Arguments args) {
  final value = args.text(0);
  final times = args.integer(1);
  if (times < 0 || value.length * times > _maxTextLength) throw valueError;
  return text(value * times);
}

Operand _exact(Arguments args) => boolean(args.text(0) == args.text(1));
