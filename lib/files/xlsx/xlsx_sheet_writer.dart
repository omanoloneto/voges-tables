import '../../sheet/cell_address.dart';
import '../../sheet/cell_value.dart';
import '../../sheet/workbook.dart';
import 'xlsx_formulas.dart';
import 'xlsx_sheet_reader.dart' show pixelsPerPoint, pixelsPerWidthUnit;
import 'xlsx_shared_strings.dart';
import 'xlsx_styles_writer.dart';
import 'xlsx_xml.dart';

/// Writes one worksheet part. Shared strings and styles go to the tables
/// shared by the whole workbook.
class XlsxSheetWriter {
  XlsxSheetWriter({required this.styles, required this.strings});

  final XlsxStyleTable styles;
  final SharedStringTable strings;

  String write(
    Sheet sheet, {
    required CellValue Function(CellAddress address) valueOf,
    bool selected = false,
  }) {
    final addresses = sheet.cells.keys.toList()..sort();
    final buffer = StringBuffer(xmlDeclaration)
      ..write(
        '<worksheet xmlns="${XlsxNamespaces.main}" '
        'xmlns:r="${XlsxNamespaces.relationships}">',
      )
      ..write('<dimension ref="${_dimension(addresses)}"/>');
    _writeView(buffer, sheet, selected);
    buffer.write(
      '<sheetFormatPr '
      'defaultColWidth="${_number(Sheet.defaultColumnWidth / pixelsPerWidthUnit)}" '
      'defaultRowHeight="${_number(Sheet.defaultRowHeight / pixelsPerPoint)}" '
      'customHeight="1"/>',
    );
    _writeColumns(buffer, sheet);
    _writeRows(buffer, sheet, addresses, valueOf);
    buffer.write(
      '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" '
      'header="0.3" footer="0.3"/></worksheet>',
    );
    return buffer.toString();
  }

  static String _dimension(List<CellAddress> addresses) {
    if (addresses.isEmpty) return 'A1';
    var minColumn = addresses.first.column, maxColumn = minColumn;
    for (final address in addresses) {
      if (address.column < minColumn) minColumn = address.column;
      if (address.column > maxColumn) maxColumn = address.column;
    }
    return CellRange(
      CellAddress(minColumn, addresses.first.row),
      CellAddress(maxColumn, addresses.last.row),
    ).a1;
  }

  static void _writeView(StringBuffer buffer, Sheet sheet, bool selected) {
    buffer.write(
      '<sheetViews><sheetView${selected ? ' tabSelected="1"' : ''} '
      'workbookViewId="0"',
    );
    final columns = sheet.frozenColumns.clamp(0, CellAddress.maxColumns - 1);
    final rows = sheet.frozenRows.clamp(0, CellAddress.maxRows - 1);
    if (columns == 0 && rows == 0) {
      buffer.write('/></sheetViews>');
      return;
    }
    final pane = rows == 0
        ? 'topRight'
        : columns == 0
        ? 'bottomLeft'
        : 'bottomRight';
    buffer
      ..write('><pane')
      ..write(columns > 0 ? ' xSplit="$columns"' : '')
      ..write(rows > 0 ? ' ySplit="$rows"' : '')
      ..write(
        ' topLeftCell="${CellAddress(columns, rows).a1}" '
        'activePane="$pane" state="frozen"/>'
        '<selection pane="$pane"/></sheetView></sheetViews>',
      );
  }

  /// Neighbouring columns of the same width share one `<col>`.
  static void _writeColumns(StringBuffer buffer, Sheet sheet) {
    final columns =
        sheet.columnWidths.keys
            .where((column) => column >= 0 && column < CellAddress.maxColumns)
            .toList()
          ..sort();
    if (columns.isEmpty) return;
    buffer.write('<cols>');
    var start = 0;
    for (var i = 1; i <= columns.length; i++) {
      final width = sheet.columnWidths[columns[start]]!;
      final continues =
          i < columns.length &&
          columns[i] == columns[i - 1] + 1 &&
          sheet.columnWidths[columns[i]] == width;
      if (continues) continue;
      buffer.write(
        '<col min="${columns[start] + 1}" max="${columns[i - 1] + 1}" '
        'width="${_number(width / pixelsPerWidthUnit)}" customWidth="1"/>',
      );
      start = i;
    }
    buffer.write('</cols>');
  }

  void _writeRows(
    StringBuffer buffer,
    Sheet sheet,
    List<CellAddress> addresses,
    CellValue Function(CellAddress) valueOf,
  ) {
    final heights =
        sheet.rowHeights.keys
            .where((row) => row >= 0 && row < CellAddress.maxRows)
            .toList()
          ..sort();
    buffer.write('<sheetData>');
    var cell = 0, height = 0;
    while (cell < addresses.length || height < heights.length) {
      final cellRow = cell < addresses.length ? addresses[cell].row : null;
      final heightRow = height < heights.length ? heights[height] : null;
      final row = cellRow == null
          ? heightRow!
          : heightRow == null || cellRow < heightRow
          ? cellRow
          : heightRow;
      buffer.write('<row r="${row + 1}"');
      if (heightRow == row) {
        final points = sheet.rowHeights[row]! / pixelsPerPoint;
        buffer.write(' ht="${_number(points)}" customHeight="1"');
        height++;
      }
      buffer.write('>');
      while (cell < addresses.length && addresses[cell].row == row) {
        final address = addresses[cell++];
        _writeCell(buffer, address, sheet.cells[address]!, valueOf);
      }
      buffer.write('</row>');
    }
    buffer.write('</sheetData>');
  }

  void _writeCell(
    StringBuffer buffer,
    CellAddress address,
    Cell cell,
    CellValue Function(CellAddress) valueOf,
  ) {
    final style = styles.indexOf(cell.style);
    buffer.write('<c r="${address.a1}"${style == 0 ? '' : ' s="$style"'}');
    if (cell.isFormula) {
      final formula = escapeText(formulaToXlsx(cell.input.substring(1)));
      final (type, value) = _cached(valueOf(address));
      buffer
        ..write(type == null ? '>' : ' t="$type">')
        ..write('<f>$formula</f>')
        ..write(value == null ? '' : '<v>$value</v>')
        ..write('</c>');
      return;
    }
    final (type, value) = switch (cell.constant) {
      TextValue(:final value) => ('s', '${strings.indexOf(value)}'),
      final other => _cached(other),
    };
    if (value == null) {
      buffer.write('/>');
      return;
    }
    buffer.write('${type == null ? '' : ' t="$type"'}><v>$value</v></c>');
  }

  /// The `t` attribute and `<v>` text of a value, both escaped.
  static (String?, String?) _cached(CellValue value) => switch (value) {
    EmptyValue() => (null, null),
    NumberValue(:final value) when !value.isFinite => ('e', '#NUM!'),
    NumberValue(:final value) => (null, _number(value)),
    TextValue(:final value) => ('str', escapeText(value)),
    BoolValue(:final value) => ('b', value ? '1' : '0'),
    ErrorValue(error: CellError.circular) => (null, null),
    ErrorValue(:final error) => ('e', error.code),
  };

  /// The shortest text that reads back as the same double.
  static String _number(double value) {
    if (value == value.truncateToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}
