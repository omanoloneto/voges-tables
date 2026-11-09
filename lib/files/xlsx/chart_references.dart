import '../../sheet/cell_address.dart';
import '../../sheet/chart.dart';
import 'sheet_names.dart';

/// `Sales!$B$2:$B$5`, or `'Sales 2026'!$B$2` when the name needs quotes, as
/// a chart series formula keeps it.
String chartReference(String sheetName, CellRange range) {
  String absolute(CellAddress cell) =>
      '\$${CellAddress.columnName(cell.column)}\$${cell.row + 1}';
  final cells = range.isSingle
      ? absolute(range.first)
      : '${absolute(range.first)}:${absolute(range.last)}';
  return '${quoteSheetName(sheetName)}!$cells';
}

final _plainName = RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$');

/// Names Excel would read as a cell (`AB12`, `R1C1`, `C`) or a boolean.
final _readsAsSomethingElse = RegExp(
  r'^([A-Za-z]{1,3}[0-9]+|[Rr][0-9]*([Cc][0-9]*)?|[Cc][0-9]*|true|false)$',
  caseSensitive: false,
);

String quoteSheetName(String name) {
  if (_plainName.hasMatch(name) && !_readsAsSomethingElse.hasMatch(name)) {
    return name;
  }
  return "'${name.replaceAll("'", "''")}'";
}

final _unquotedSheet = RegExp(r"^[^\s'!(),;]+$");

/// Reads a chart formula such as `'Sales 2026'!$B$2:$B$5`; a formula with
/// no sheet is on [defaultSheet]. Null for anything that is not one block of
/// cells on one sheet of this workbook: several areas, names, whole columns
/// or other workbooks.
ChartData? parseChartReference(String formula, {required String defaultSheet}) {
  var text = formula.trim();
  if (text.startsWith('=')) text = text.substring(1).trim();
  String sheet;
  String cells;
  if (text.startsWith("'")) {
    final name = StringBuffer();
    var i = 1;
    for (; i < text.length; i++) {
      if (text[i] != "'") {
        name.write(text[i]);
      } else if (i + 1 < text.length && text[i + 1] == "'") {
        name.write("'");
        i++;
      } else {
        break;
      }
    }
    if (i + 1 >= text.length || text[i + 1] != '!') return null;
    sheet = name.toString();
    cells = text.substring(i + 2);
  } else {
    final bang = text.indexOf('!');
    if (bang < 0) {
      sheet = defaultSheet;
      cells = text;
    } else {
      sheet = text.substring(0, bang);
      if (!_unquotedSheet.hasMatch(sheet)) return null;
      cells = text.substring(bang + 1);
    }
  }
  if (sheet != defaultSheet && !isValidSheetName(sheet)) return null;
  final corners = cells.split(':');
  if (corners.length > 2) return null;
  final first = CellAddress.tryParse(corners.first);
  final last = corners.length == 2 ? CellAddress.tryParse(corners[1]) : first;
  if (first == null || last == null) return null;
  return ChartData(sheet, CellRange(first, last));
}
