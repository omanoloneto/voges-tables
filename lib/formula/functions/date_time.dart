import '../arguments.dart';
import '../dates.dart';
import '../operand.dart';
import 'registry.dart';
import 'support.dart';

final Map<String, FunctionSpec> dateTimeFunctions = {
  'TODAY': const FunctionSpec(_today, maxArguments: 0, volatile: true),
  'NOW': const FunctionSpec(_now, maxArguments: 0, volatile: true),
  'DATE': const FunctionSpec(_date, minArguments: 3, maxArguments: 3),
  'YEAR': const FunctionSpec(_year, minArguments: 1, maxArguments: 1),
  'MONTH': const FunctionSpec(_month, minArguments: 1, maxArguments: 1),
  'DAY': const FunctionSpec(_day, minArguments: 1, maxArguments: 1),
  'WEEKDAY': const FunctionSpec(_weekday, minArguments: 1, maxArguments: 2),
  'DATEDIF': const FunctionSpec(_dateDif, minArguments: 3, maxArguments: 3),
  'DAYS': const FunctionSpec(_days, minArguments: 2, maxArguments: 2),
  'EDATE': const FunctionSpec(_edate, minArguments: 2, maxArguments: 2),
  'EOMONTH': const FunctionSpec(_eomonth, minArguments: 2, maxArguments: 2),
  'HOUR': const FunctionSpec(_hour, minArguments: 1, maxArguments: 1),
  'MINUTE': const FunctionSpec(_minute, minArguments: 1, maxArguments: 1),
  'SECOND': const FunctionSpec(_second, minArguments: 1, maxArguments: 1),
  'TIME': const FunctionSpec(_time, minArguments: 3, maxArguments: 3),
};

Operand _today(Arguments args) =>
    number(dateToSerial(args.now()).floorToDouble());

Operand _now(Arguments args) => number(dateToSerial(args.now()));

/// A serial argument in Excel's valid range.
double _serial(Arguments args, int index) {
  final value = args.number(index);
  if (value < 0 || value >= maxDateSerial + 1) throw numError;
  return value;
}

({int year, int month, int day}) _ymd(Arguments args, int index) =>
    serialToYmd(_serial(args, index).floor());

Scalar _dateResult(int serial) {
  if (serial < 0 || serial > maxDateSerial) throw numError;
  return number(serial.toDouble());
}

Operand _date(Arguments args) {
  var year = args.integer(0);
  if (year < 0 || year > 9999) throw numError;
  if (year < 1900) year += 1900;
  return _dateResult(ymdToSerial(year, args.integer(1), args.integer(2)));
}

Operand _year(Arguments args) => number(_ymd(args, 0).year.toDouble());

Operand _month(Arguments args) => number(_ymd(args, 0).month.toDouble());

Operand _day(Arguments args) => number(_ymd(args, 0).day.toDouble());

Operand _weekday(Arguments args) {
  final serial = _serial(args, 0).floor();
  final type = args.integer(1, orElse: 1);
  // Excel counts serial 0 as a Saturday, so serial 1 (1 Jan 1900) is Sunday.
  final sunday0 = (serial + 6) % 7;
  final start = switch (type) {
    1 => 0,
    2 || 3 => 1,
    >= 11 && <= 17 => (type - 10) % 7,
    _ => throw numError,
  };
  final weekday = (sunday0 - start + 7) % 7;
  return number(type == 3 ? weekday.toDouble() : weekday + 1.0);
}

Operand _dateDif(Arguments args) {
  final start = _serial(args, 0).floor();
  final end = _serial(args, 1).floor();
  if (start > end) throw numError;
  final s = serialToYmd(start), e = serialToYmd(end);
  final months =
      (e.year - s.year) * 12 + e.month - s.month - (e.day < s.day ? 1 : 0);
  final result = switch (args.text(2).toUpperCase()) {
    'D' => end - start,
    'M' => months,
    'Y' => months ~/ 12,
    'YM' => months % 12,
    'MD' => _daysIgnoringMonths(s, e),
    'YD' => _daysIgnoringYears(s, e),
    _ => throw numError,
  };
  return number(result.toDouble());
}

int _daysIgnoringMonths(
  ({int year, int month, int day}) s,
  ({int year, int month, int day}) e,
) {
  if (e.day >= s.day) return e.day - s.day;
  final previous = DateTime.utc(e.year, e.month, 0);
  final from = DateTime.utc(previous.year, previous.month, s.day);
  return DateTime.utc(e.year, e.month, e.day).difference(from).inDays;
}

int _daysIgnoringYears(
  ({int year, int month, int day}) s,
  ({int year, int month, int day}) e,
) {
  var from = DateTime.utc(e.year, s.month, s.day);
  final to = DateTime.utc(e.year, e.month, e.day);
  if (from.isAfter(to)) from = DateTime.utc(e.year - 1, s.month, s.day);
  return to.difference(from).inDays;
}

Operand _days(Arguments args) =>
    number((_serial(args, 0).floor() - _serial(args, 1).floor()).toDouble());

Operand _edate(Arguments args) {
  final start = _ymd(args, 0);
  final target = DateTime.utc(start.year, start.month + args.integer(1), 1);
  final day = start.day.clamp(1, daysInMonth(target.year, target.month));
  return _dateResult(ymdToSerial(target.year, target.month, day));
}

Operand _eomonth(Arguments args) {
  final start = _ymd(args, 0);
  final target = DateTime.utc(start.year, start.month + args.integer(1), 1);
  return _dateResult(
    ymdToSerial(
      target.year,
      target.month,
      daysInMonth(target.year, target.month),
    ),
  );
}

Operand _hour(Arguments args) =>
    number(serialToTime(_serial(args, 0)).hour.toDouble());

Operand _minute(Arguments args) =>
    number(serialToTime(_serial(args, 0)).minute.toDouble());

Operand _second(Arguments args) =>
    number(serialToTime(_serial(args, 0)).second.toDouble());

Operand _time(Arguments args) {
  final seconds =
      args.integer(0) * 3600 + args.integer(1) * 60 + args.integer(2);
  if (seconds < 0) throw numError;
  return number((seconds % 86400) / 86400);
}
