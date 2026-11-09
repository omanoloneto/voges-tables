import '../../sheet/cell_address.dart';
import '../../sheet/workbook.dart';

const csvDelimiters = [',', ';', '\t'];

/// Reads CSV text (RFC 4180: quoted fields may hold delimiters, quotes as
/// `""` and line breaks) into a sheet. Each non-empty field becomes the cell
/// [parse] makes of it, as if the user had typed it.
///
/// The [delimiter] is detected among `,` `;` and tab when not given.
Sheet readCsv(
  String text, {
  required String sheetName,
  required Cell Function(String raw) parse,
  String? delimiter,
}) {
  final source = text.startsWith('\uFEFF') ? text.substring(1) : text;
  final sheet = Sheet(sheetName);
  final separator = delimiter ?? detectCsvDelimiter(source);
  var row = 0;
  for (final record in _records(source, separator)) {
    if (row >= CellAddress.maxRows) break;
    for (var column = 0; column < record.length; column++) {
      if (column >= CellAddress.maxColumns) break;
      final raw = record[column];
      if (raw.isEmpty) continue;
      sheet.setCell(CellAddress(column, row), parse(raw));
    }
    row++;
  }
  return sheet;
}

/// Picks the delimiter that splits the first lines into the same number of
/// fields; a tie goes to tab, then `;` (Brazilian Excel), as commas also
/// show up in decimals.
String detectCsvDelimiter(String text) {
  const sample = 20;
  String? best;
  var bestScore = 0;
  for (final candidate in const ['\t', ';', ',']) {
    final counts = _records(
      text,
      candidate,
    ).take(sample).map((record) => record.length - 1).toList();
    if (counts.isEmpty || counts.first == 0) continue;
    final consistent = counts.every((count) => count == counts.first);
    final score = consistent ? counts.first * 1000 : counts.first;
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best ?? ',';
}

Iterable<List<String>> _records(String text, String delimiter) sync* {
  final delimiterUnit = delimiter.codeUnitAt(0);
  const quote = 0x22, cr = 0x0D, lf = 0x0A;
  var fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var fieldStarted = false;
  var i = 0;
  while (i < text.length) {
    final unit = text.codeUnitAt(i);
    if (quoted) {
      if (unit == quote) {
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == quote) {
          field.writeCharCode(quote);
          i += 2;
          continue;
        }
        quoted = false;
      } else {
        field.writeCharCode(unit);
      }
      i++;
      continue;
    }
    if (unit == quote && !fieldStarted) {
      quoted = true;
      fieldStarted = true;
    } else if (unit == delimiterUnit) {
      fields.add(field.toString());
      field.clear();
      fieldStarted = false;
    } else if (unit == cr || unit == lf) {
      if (unit == cr && i + 1 < text.length && text.codeUnitAt(i + 1) == lf) {
        i++;
      }
      fields.add(field.toString());
      field.clear();
      fieldStarted = false;
      yield fields;
      fields = <String>[];
    } else {
      field.writeCharCode(unit);
      fieldStarted = true;
    }
    i++;
  }
  if (fieldStarted || fields.isNotEmpty) {
    fields.add(field.toString());
    yield fields;
  }
}
