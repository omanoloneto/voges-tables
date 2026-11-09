import 'package:xml/xml_events.dart';

import '../../sheet/cell_address.dart';
import '../../sheet/cell_style.dart';
import '../../sheet/cell_value.dart';
import '../../sheet/workbook.dart';
import 'xlsx_formulas.dart';
import 'xlsx_shared_strings.dart';
import 'xlsx_xml.dart';

/// Points to pixels, as the grid measures rows.
const pixelsPerPoint = 4 / 3;

/// Excel's stored column width already includes the 5 px cell padding, so
/// one unit is one maximum digit width of Calibri 11 (7 px).
const pixelsPerWidthUnit = 7.0;

/// Days between the 1904 and the 1900 date systems.
const _date1904Offset = 1462;

/// Streams one worksheet part into a [Sheet]; the XML is never held as a
/// tree, so large sheets stay cheap.
class XlsxSheetReader {
  XlsxSheetReader({
    required this.sharedStrings,
    required this.styles,
    this.date1904 = false,
  });

  final List<String> sharedStrings;
  final List<CellStyle> styles;
  final bool date1904;

  void read(String source, Sheet sheet) {
    _SheetParse(this, sheet).run(source);
  }
}

class _SharedFormula {
  const _SharedFormula(this.master, this.text);
  final CellAddress master;
  final String text;
}

class _SheetParse {
  _SheetParse(this.reader, this.sheet);

  final XlsxSheetReader reader;
  final Sheet sheet;

  final _sharedFormulas = <String, _SharedFormula>{};
  final _value = StringBuffer();
  final _formula = StringBuffer();
  final _inline = StringItemText();

  var _sheetViews = 0;
  var _defaultRowHeight = 15.0;
  var _row = -1;
  var _column = -1;

  CellAddress? _address;
  String? _type;
  var _style = 0;
  var _inValue = false;
  var _inFormula = false;
  var _inInline = false;
  var _hasFormula = false;
  String? _formulaType;
  String? _sharedIndex;

  void run(String source) {
    for (final event in parseEvents(source)) {
      switch (event) {
        case XmlStartElementEvent():
          _start(event);
        case XmlEndElementEvent():
          if (_end(event)) return;
        case XmlTextEvent(:final value):
          _text(value);
        case XmlCDATAEvent(:final value):
          _text(value);
        default:
          break;
      }
    }
  }

  void _start(XmlStartElementEvent event) {
    if (_inInline) {
      _inline.start(event);
      return;
    }
    final closed = event.isSelfClosing;
    switch (event.localName) {
      case 'c':
        _startCell(event);
        if (closed) _endCell();
      case 'v':
        _inValue = !closed;
      case 'f':
        _hasFormula = true;
        _formulaType = _attribute(event, 't');
        _sharedIndex = _attribute(event, 'si');
        _inFormula = !closed;
      case 'is':
        _inInline = !closed;
      case 'row':
        _startRow(event);
      case 'col':
        _readColumn(event);
      case 'sheetFormatPr':
        _defaultRowHeight =
            double.tryParse(_attribute(event, 'defaultRowHeight') ?? '') ??
            _defaultRowHeight;
      case 'sheetView':
        _sheetViews++;
      case 'pane' when _sheetViews == 1:
        _readPane(event);
    }
  }

  /// True once the cells are over: nothing after `sheetData` is needed.
  bool _end(XmlEndElementEvent event) {
    switch (event.localName) {
      case 'is':
        _inInline = false;
      case 'c':
        _endCell();
      case 'v':
        _inValue = false;
      case 'f':
        _inFormula = false;
      case 'sheetData':
        return true;
      default:
        if (_inInline) _inline.end(event);
    }
    return false;
  }

  void _text(String value) {
    if (_inValue) {
      _value.write(value);
    } else if (_inFormula) {
      _formula.write(value);
    } else if (_inInline) {
      _inline.text(value);
    }
  }

  static String? _attribute(XmlStartElementEvent event, String name) {
    for (final attribute in event.attributes) {
      if (attribute.name == name) return attribute.value;
    }
    return null;
  }

  void _startRow(XmlStartElementEvent event) {
    final number = int.tryParse(_attribute(event, 'r') ?? '');
    _row = number == null ? _row + 1 : number - 1;
    _column = -1;
    final height = double.tryParse(_attribute(event, 'ht') ?? '');
    if (height == null || _row < 0 || _row >= CellAddress.maxRows) return;
    final custom = onOff(_attribute(event, 'customHeight') ?? '0');
    if (custom || (height - _defaultRowHeight).abs() > 0.01) {
      sheet.rowHeights[_row] = (height * pixelsPerPoint).roundToDouble();
    }
  }

  void _readColumn(XmlStartElementEvent event) {
    final width = double.tryParse(_attribute(event, 'width') ?? '');
    if (width == null || !onOff(_attribute(event, 'customWidth') ?? '0')) {
      return;
    }
    final first = (int.tryParse(_attribute(event, 'min') ?? '') ?? 1) - 1;
    final last =
        (int.tryParse(_attribute(event, 'max') ?? '') ?? first + 1) - 1;
    final pixels = (width * pixelsPerWidthUnit).roundToDouble();
    final end = last < CellAddress.maxColumns
        ? last
        : CellAddress.maxColumns - 1;
    for (var column = first < 0 ? 0 : first; column <= end; column++) {
      sheet.columnWidths[column] = pixels;
    }
  }

  void _readPane(XmlStartElementEvent event) {
    final state = _attribute(event, 'state');
    if (state != 'frozen' && state != 'frozenSplit') return;
    int split(String name) =>
        (double.tryParse(_attribute(event, name) ?? '') ?? 0).floor();
    sheet.frozenColumns = split('xSplit').clamp(0, CellAddress.maxColumns);
    sheet.frozenRows = split('ySplit').clamp(0, CellAddress.maxRows);
  }

  void _startCell(XmlStartElementEvent event) {
    final reference = _attribute(event, 'r');
    final parsed = reference == null ? null : _parseReference(reference);
    if (parsed != null) {
      _row = parsed.row;
      _column = parsed.column;
    } else {
      _column++;
    }
    _address = CellAddress(_column, _row);
    _type = _attribute(event, 't');
    _style = int.tryParse(_attribute(event, 's') ?? '') ?? 0;
    _value.clear();
    _formula.clear();
    _hasFormula = false;
    _formulaType = null;
    _sharedIndex = null;
  }

  /// A fast `A1` parser for the millions of `r` attributes of big sheets.
  static CellAddress? _parseReference(String reference) {
    var column = 0, row = 0, i = 0;
    while (i < reference.length) {
      final unit = reference.codeUnitAt(i) & ~0x20;
      if (unit < 0x41 || unit > 0x5A) break;
      column = column * 26 + unit - 0x40;
      i++;
    }
    if (i == 0 || i == reference.length) return null;
    for (; i < reference.length; i++) {
      final digit = reference.codeUnitAt(i) - 0x30;
      if (digit < 0 || digit > 9) return null;
      row = row * 10 + digit;
    }
    return CellAddress(column - 1, row - 1);
  }

  void _endCell() {
    final address = _address;
    _address = null;
    if (address == null || !address.isValid) return;
    final styles = reader.styles;
    final style = _style >= 0 && _style < styles.length
        ? styles[_style]
        : CellStyle.plain;
    final formula = _hasFormula ? _formulaText(address) : null;
    if (formula != null && formula.isNotEmpty) {
      sheet.setCell(
        address,
        Cell(input: '=${formulaFromXlsx(formula)}', style: style),
      );
      return;
    }
    sheet.setCell(address, Cell(constant: _constant(style), style: style));
  }

  String? _formulaText(CellAddress address) {
    final text = _formula.toString();
    if (_formulaType != 'shared' || _sharedIndex == null) return text;
    if (text.isNotEmpty) {
      _sharedFormulas[_sharedIndex!] = _SharedFormula(address, text);
      return text;
    }
    final master = _sharedFormulas[_sharedIndex!];
    if (master == null) return null;
    return shiftFormula(
      master.text,
      address.column - master.master.column,
      address.row - master.master.row,
    );
  }

  CellValue _constant(CellStyle style) {
    if (_type == 'inlineStr') return _textValue(_inline.take());
    final raw = _value.toString();
    if (raw.isEmpty) return const EmptyValue();
    switch (_type) {
      case 's':
        final index = int.tryParse(raw.trim());
        final strings = reader.sharedStrings;
        return index != null && index >= 0 && index < strings.length
            ? _textValue(strings[index])
            : const EmptyValue();
      case 'str':
        return _textValue(unescapeText(raw));
      case 'b':
        return BoolValue(raw.trim() == '1' || raw.trim() == 'true');
      case 'e':
        final error = CellError.fromCode(raw.trim());
        return error == null ? TextValue(raw) : ErrorValue(error);
      case 'd':
        final serial = _serialFromIso(raw.trim());
        return serial == null ? TextValue(raw) : NumberValue(serial);
      default:
        final number = double.tryParse(raw.trim());
        if (number == null) return const EmptyValue();
        return NumberValue(_isDate(style) ? number + _dateShift : number);
    }
  }

  static CellValue _textValue(String value) =>
      value.isEmpty ? const EmptyValue() : TextValue(value);

  int get _dateShift => reader.date1904 ? _date1904Offset : 0;

  static bool _isDate(CellStyle style) =>
      style.format.kind == NumberKind.date ||
      style.format.kind == NumberKind.dateTime;

  static double? _serialFromIso(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    final utc = DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
    );
    return utc.difference(DateTime.utc(1899, 12, 30)).inMilliseconds /
        Duration.millisecondsPerDay;
  }
}
