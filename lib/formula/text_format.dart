import 'dart:math' as math;

import '../sheet/cell_value.dart';
import 'coercion.dart';
import 'dates.dart';
import 'locale.dart';
import 'numbers.dart';
import 'operand.dart';
import 'recognize.dart';

/// TEXT's format codes: `0.00`, `#,##0`, `0%`, `0.00E+00`, literals, up to
/// four `;` sections, and dates/times such as `dd/mm/yyyy hh:mm`. In pt and es
/// the code uses that locale's separators and `a` for years (`dd/mm/aaaa`).
String formatWithCode(CellValue value, String code, FormulaLocale locale) {
  final sections = _split(code);
  final number = switch (value) {
    NumberValue(:final value) => value,
    EmptyValue() => 0.0,
    TextValue(:final value) => textToNumber(value, locale),
    _ => null,
  };
  if (number == null) {
    final text = toText(value, locale);
    final section = sections.length >= 4
        ? sections[3]
        : sections.firstWhere((s) => s.contains('@'), orElse: () => '');
    return section.isEmpty ? text : _withText(section, text);
  }
  var section = sections.first;
  var signed = true;
  if (number < 0 && sections.length >= 2) {
    section = sections[1];
    signed = false;
  } else if (number == 0 && sections.length >= 3) {
    section = sections[2];
  }
  if (const {
    'general',
    'geral',
    'estándar',
    'standard',
  }.contains(section.trim().toLowerCase())) {
    return generalNumber(number, locale);
  }
  if (_isDateCode(section, locale)) {
    if (number < 0 || number > maxDateSerial + 1) throw valueError;
    return _formatDate(number, section, locale);
  }
  return _formatNumber(signed ? number : number.abs(), section, locale);
}

List<String> _split(String code) {
  final sections = <String>[];
  final current = StringBuffer();
  for (var i = 0; i < code.length; i++) {
    final char = code[i];
    if (char == '"') {
      final end = code.indexOf('"', i + 1);
      final stop = end < 0 ? code.length : end + 1;
      current.write(code.substring(i, stop));
      i = stop - 1;
    } else if (char == r'\' && i + 1 < code.length) {
      current.write(code.substring(i, i + 2));
      i++;
    } else if (char == ';') {
      sections.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  sections.add(current.toString());
  return sections;
}

/// Walks [section], handing literal text to [literal] and every other
/// character (with its index) to [code].
void _scan(
  String section,
  void Function(String text) literal,
  void Function(int index) code,
) {
  for (var i = 0; i < section.length; i++) {
    final char = section[i];
    if (char == '"') {
      final end = section.indexOf('"', i + 1);
      final stop = end < 0 ? section.length : end;
      literal(section.substring(i + 1, stop));
      i = stop;
    } else if (char == r'\' && i + 1 < section.length) {
      literal(section[++i]);
    } else if (char == '[') {
      final end = section.indexOf(']', i);
      i = end < 0 ? section.length : end;
    } else if (char == '_' && i + 1 < section.length) {
      literal(' ');
      i++;
    } else if (char == '*' && i + 1 < section.length) {
      i++;
    } else {
      code(i);
    }
  }
}

String _withText(String section, String text) {
  final out = StringBuffer();
  _scan(
    section,
    out.write,
    (i) => out.write(section[i] == '@' ? text : section[i]),
  );
  return out.toString();
}

String _formatNumber(double value, String section, FormulaLocale locale) {
  final dec = locale.decimalSeparator, th = locale.thousandsSeparator;
  final prefix = StringBuffer(),
      suffix = StringBuffer(),
      digits = StringBuffer();
  var state = 0;
  var percent = false;
  int? exponentDigits;
  var exponentPlus = false;
  final skip = <int>{};
  void literal(String text) => (state == 0 ? prefix : suffix).write(text);
  _scan(
    section,
    (text) {
      if (state == 1) state = 2;
      literal(text);
    },
    (i) {
      if (skip.contains(i)) return;
      final char = section[i];
      final placeholder = char == '0' || char == '#' || char == '?';
      if (placeholder ||
          (state == 1 && (char == dec || char == th)) ||
          (state == 0 &&
              char == dec &&
              i + 1 < section.length &&
              '0#?'.contains(section[i + 1]))) {
        if (state == 2) return;
        state = 1;
        digits.write(char);
      } else if (state == 1 &&
          (char == 'E' || char == 'e') &&
          i + 1 < section.length &&
          (section[i + 1] == '+' || section[i + 1] == '-')) {
        exponentPlus = section[i + 1] == '+';
        var j = i + 2;
        while (j < section.length && section[j] == '0') {
          skip.add(j);
          j++;
        }
        skip.add(i + 1);
        exponentDigits = j - i - 2;
      } else {
        if (char == '%') percent = true;
        if (state == 1) state = 2;
        literal(char);
      }
    },
  );
  final pattern = digits.toString();
  if (pattern.isEmpty) {
    final sign = value < 0 ? '-' : '';
    return '$sign$prefix$suffix';
  }
  final point = pattern.indexOf(dec);
  var integerPattern = point < 0 ? pattern : pattern.substring(0, point);
  final fractionPattern = point < 0 ? '' : pattern.substring(point + 1);
  var scale = 1.0;
  while (integerPattern.endsWith(th)) {
    integerPattern = integerPattern.substring(0, integerPattern.length - 1);
    scale *= 1000;
  }
  final grouped = integerPattern.contains(th);
  final minInteger = '0'.allMatches(integerPattern).length;
  final decimals = RegExp('[0#?]').allMatches(fractionPattern).length;
  final minDecimals = '0'.allMatches(fractionPattern).length;
  var amount = value.abs() * (percent ? 100 : 1) / scale;

  var exponentText = '';
  if (exponentDigits != null) {
    var exponent = amount == 0 ? 0 : (math.log(amount) / math.ln10).floor();
    var mantissa = amount / math.pow(10, exponent);
    if (roundHalfAwayFromZero(mantissa, decimals) >= 10) {
      exponent++;
      mantissa /= 10;
    }
    amount = mantissa;
    final sign = exponent < 0 ? '-' : (exponentPlus ? '+' : '');
    exponentText =
        'E$sign${exponent.abs().toString().padLeft(exponentDigits!, '0')}';
  }

  final fixed = roundHalfAwayFromZero(
    amount,
    decimals,
  ).toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  var integer = dot < 0 ? fixed : fixed.substring(0, dot);
  var fraction = dot < 0 ? '' : fixed.substring(dot + 1);
  if (integer == '0' && minInteger == 0) integer = '';
  integer = integer.padLeft(minInteger, '0');
  if (grouped) integer = groupThousands(integer, th);
  while (fraction.length > minDecimals && fraction.endsWith('0')) {
    fraction = fraction.substring(0, fraction.length - 1);
  }
  final body = fraction.isEmpty ? integer : '$integer$dec$fraction';
  final negative = value < 0 && RegExp('[1-9]').hasMatch(body);
  return '${negative ? '-' : ''}$prefix$body$exponentText$suffix';
}

bool _isDateCode(String section, FormulaLocale locale) {
  var found = false;
  final letters = locale == FormulaLocale.en ? 'dmyhs' : 'dmyhsa';
  _scan(section, (_) {}, (i) {
    if (letters.contains(section[i].toLowerCase())) found = true;
  });
  return found;
}

String _formatDate(double serial, String section, FormulaLocale locale) {
  final tokens = <(String, int)>[];
  final upper = section.toUpperCase();
  var skipUntil = -1;
  _scan(section, (text) => tokens.add(('"$text', 0)), (i) {
    if (i < skipUntil) return;
    if (upper.startsWith('AM/PM', i)) {
      tokens.add(('ampm', 5));
      skipUntil = i + 5;
      return;
    }
    if (upper.startsWith('A/P', i)) {
      tokens.add(('ap', 3));
      skipUntil = i + 3;
      return;
    }
    var letter = section[i].toLowerCase();
    if (letter == 'a' && locale != FormulaLocale.en) letter = 'y';
    if ('dmyhs'.contains(letter)) {
      final last = tokens.isEmpty ? null : tokens.last;
      if (last != null && last.$1 == letter) {
        tokens[tokens.length - 1] = (letter, last.$2 + 1);
      } else {
        tokens.add((letter, 1));
      }
    } else {
      tokens.add(('"${section[i]}', 0));
    }
  });
  final twelveHour = tokens.any((t) => t.$1 == 'ampm' || t.$1 == 'ap');
  final ymd = serialToYmd(serial.floor());
  final time = serialToTime(serial);
  final names = _names[locale]!;
  final out = StringBuffer();
  for (var t = 0; t < tokens.length; t++) {
    final (kind, count) = tokens[t];
    String two(int n) => count >= 2 ? n.toString().padLeft(2, '0') : '$n';
    switch (kind) {
      case 'y':
        out.write(
          count <= 2
              ? (ymd.year % 100).toString().padLeft(2, '0')
              : ymd.year.toString(),
        );
      case 'm' when _isMinute(tokens, t):
        out.write(two(time.minute));
      case 'm':
        out.write(switch (count) {
          1 || 2 => two(ymd.month),
          3 => names.shortMonths[ymd.month - 1],
          4 => names.months[ymd.month - 1],
          _ => names.months[ymd.month - 1][0],
        });
      case 'd':
        final weekday = (serial.floor() + 6) % 7;
        out.write(switch (count) {
          1 || 2 => two(ymd.day),
          3 => names.shortDays[weekday],
          _ => names.days[weekday],
        });
      case 'h':
        final hour = twelveHour ? (time.hour + 11) % 12 + 1 : time.hour;
        out.write(two(hour));
      case 's':
        out.write(two(time.second));
      case 'ampm':
        out.write(time.hour < 12 ? 'AM' : 'PM');
      case 'ap':
        out.write(time.hour < 12 ? 'A' : 'P');
      default:
        out.write(kind.substring(1));
    }
  }
  return out.toString();
}

/// `m` means minutes right after hours or right before seconds.
bool _isMinute(List<(String, int)> tokens, int index) {
  for (var i = index - 1; i >= 0; i--) {
    final kind = tokens[i].$1;
    if (kind.startsWith('"')) continue;
    if (kind == 'h') return true;
    break;
  }
  for (var i = index + 1; i < tokens.length; i++) {
    final kind = tokens[i].$1;
    if (kind.startsWith('"')) continue;
    return kind == 's';
  }
  return false;
}

typedef _Names = ({
  List<String> months,
  List<String> shortMonths,
  List<String> days,
  List<String> shortDays,
});

const Map<FormulaLocale, _Names> _names = {
  FormulaLocale.en: (
    months: [
      'January', 'February', 'March', 'April', 'May', 'June', 'July', //
      'August', 'September', 'October', 'November', 'December',
    ],
    shortMonths: [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ],
    days: [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', //
      'Saturday',
    ],
    shortDays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
  ),
  FormulaLocale.pt: (
    months: [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', //
      'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ],
    shortMonths: [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun', //
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ],
    days: [
      'domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', //
      'quinta-feira', 'sexta-feira', 'sábado',
    ],
    shortDays: ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'],
  ),
  FormulaLocale.es: (
    months: [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', //
      'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ],
    shortMonths: [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
      'jul', 'ago', 'sept', 'oct', 'nov', 'dic',
    ],
    days: [
      'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', //
      'sábado',
    ],
    shortDays: ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'],
  ),
};
