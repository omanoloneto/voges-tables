/// Excel's 1900 date system: serial 1 is 1 Jan 1900 and serial 60 is the
/// 29 Feb 1900 that never existed, kept so serials match Excel files.
library;

final _beforeMarch1900 = DateTime.utc(1899, 12, 31);
final _fromMarch1900 = DateTime.utc(1899, 12, 30);

/// The last date Excel accepts, 31 Dec 9999.
const maxDateSerial = 2958465;

/// Serial of the date and time in [date]'s own fields (its time zone is not
/// converted).
double dateToSerial(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  var days = day.difference(_fromMarch1900).inDays;
  if (days < 61) days -= 1;
  final seconds =
      date.hour * 3600 +
      date.minute * 60 +
      date.second +
      date.millisecond / 1000;
  return days + seconds / 86400;
}

/// The UTC date and time of [serial]. The fake 29 Feb 1900 (60) comes back as
/// 1 Mar 1900; use [serialToYmd] to show it.
DateTime serialToDate(double serial) {
  final days = serial.floor();
  final base = days < 61 ? _beforeMarch1900 : _fromMarch1900;
  final millis = ((serial - days) * 86400000).round();
  return DateTime.utc(base.year, base.month, base.day + days, 0, 0, 0, millis);
}

/// Year, month and day of a whole serial, Excel style: 0 is 0 Jan 1900 and
/// 60 is 29 Feb 1900.
({int year, int month, int day}) serialToYmd(int serial) {
  if (serial == 0) return (year: 1900, month: 1, day: 0);
  if (serial == 60) return (year: 1900, month: 2, day: 29);
  final base = serial < 60 ? _beforeMarch1900 : _fromMarch1900;
  final date = DateTime.utc(base.year, base.month, base.day + serial);
  return (year: date.year, month: date.month, day: date.day);
}

/// Serial of a date given as Excel's DATE does: months and days out of range
/// roll over, so `ymdToSerial(1900, 2, 29)` is 60.
int ymdToSerial(int year, int month, int day) {
  final first = DateTime.utc(year, month, 1);
  return dateToSerial(first).floor() + day - 1;
}

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Hours, minutes and seconds of the fraction of [serial], rounded to the
/// nearest second.
({int hour, int minute, int second}) serialToTime(double serial) {
  var seconds = ((serial - serial.floor()) * 86400).round();
  if (seconds >= 86400) seconds = 0;
  return (
    hour: seconds ~/ 3600,
    minute: seconds % 3600 ~/ 60,
    second: seconds % 60,
  );
}
