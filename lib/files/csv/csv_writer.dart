import '../../sheet/cell_address.dart';
import '../../sheet/workbook.dart';

/// Writes the used range of [sheet] as CSV with CRLF line ends, each cell as
/// [displayOf] shows it. Fields are quoted only when they need to be.
String writeCsv(
  Sheet sheet, {
  required String Function(CellAddress address) displayOf,
  String delimiter = ',',
}) {
  final range = sheet.usedRange;
  if (range == null) return '';
  final buffer = StringBuffer();
  for (var row = 0; row <= range.last.row; row++) {
    for (var column = 0; column <= range.last.column; column++) {
      if (column > 0) buffer.write(delimiter);
      final address = CellAddress(column, row);
      if (sheet.cells.containsKey(address)) {
        buffer.write(_field(displayOf(address), delimiter));
      }
    }
    buffer.write('\r\n');
  }
  return buffer.toString();
}

String _field(String value, String delimiter) {
  final needsQuotes =
      value.contains(delimiter) ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  return needsQuotes ? '"${value.replaceAll('"', '""')}"' : value;
}
