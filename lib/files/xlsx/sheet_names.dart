/// Excel's rules for a sheet name: 1–31 characters, none of `[]:*?/\`, no
/// apostrophe at either end, and not the reserved `History`.
const maxSheetNameLength = 31;

final _forbidden = RegExp(r'[\[\]:*?/\\]');

bool isValidSheetName(String name) =>
    name.isNotEmpty &&
    name.length <= maxSheetNameLength &&
    !_forbidden.hasMatch(name) &&
    !name.startsWith("'") &&
    !name.endsWith("'") &&
    name.toLowerCase() != 'history';

/// Fixes names Excel would refuse and makes them unique ignoring case, so a
/// workbook always saves; valid, distinct names are kept as they are.
List<String> safeSheetNames(List<String> names) {
  final taken = <String>{};
  final result = <String>[];
  for (var i = 0; i < names.length; i++) {
    var base = names[i]
        .replaceAll(_forbidden, '_')
        .replaceAll(RegExp(r"^'+|'+$"), '');
    if (base.trim().isEmpty || base.toLowerCase() == 'history') {
      base = 'Sheet${i + 1}';
    }
    if (base.length > maxSheetNameLength) {
      base = base.substring(0, maxSheetNameLength);
    }
    var name = base;
    for (var n = 2; taken.contains(name.toLowerCase()); n++) {
      final suffix = ' ($n)';
      final room = maxSheetNameLength - suffix.length;
      name = '${base.length > room ? base.substring(0, room) : base}$suffix';
    }
    taken.add(name.toLowerCase());
    result.add(name);
  }
  return result;
}
