/// What a cell shows after its input is evaluated.
sealed class CellValue {
  const CellValue();
}

class EmptyValue extends CellValue {
  const EmptyValue();
  @override
  bool operator ==(Object other) => other is EmptyValue;
  @override
  int get hashCode => 0;
}

class NumberValue extends CellValue {
  const NumberValue(this.value);
  final double value;
  @override
  bool operator ==(Object other) =>
      other is NumberValue && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'NumberValue($value)';
}

class TextValue extends CellValue {
  const TextValue(this.value);
  final String value;
  @override
  bool operator ==(Object other) => other is TextValue && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'TextValue($value)';
}

class BoolValue extends CellValue {
  const BoolValue(this.value);
  final bool value;
  @override
  bool operator ==(Object other) => other is BoolValue && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'BoolValue($value)';
}

/// The Excel error codes the app produces and reads.
enum CellError {
  div0('#DIV/0!'),
  value('#VALUE!'),
  ref('#REF!'),
  name('#NAME?'),
  num('#NUM!'),
  na('#N/A'),
  nullError('#NULL!'),
  circular('#CIRC!');

  const CellError(this.code);
  final String code;

  static CellError? fromCode(String code) {
    for (final error in values) {
      if (error.code == code) return error;
    }
    return null;
  }
}

class ErrorValue extends CellValue {
  const ErrorValue(this.error);
  final CellError error;
  @override
  bool operator ==(Object other) => other is ErrorValue && other.error == error;
  @override
  int get hashCode => error.hashCode;
  @override
  String toString() => 'ErrorValue(${error.code})';
}
