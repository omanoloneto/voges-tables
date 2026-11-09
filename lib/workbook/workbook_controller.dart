import 'package:flutter/foundation.dart';

import '../formula/calculator.dart';
import '../formula/format.dart';
import '../formula/input.dart';
import '../formula/locale.dart';
import '../formula/references.dart';
import '../sheet/cell_address.dart';
import '../sheet/cell_style.dart';
import '../sheet/cell_value.dart';
import '../sheet/workbook.dart';
import 'selection.dart';
import 'undo_history.dart';

/// Cells copied or cut, kept relative to the top left corner of the copy.
class CellClip {
  CellClip(this.sheet, this.range, this.cells, {required this.cut});

  final int sheet;
  final CellRange range;
  final Map<CellAddress, Cell> cells;
  final bool cut;
}

/// Everything the editor changes in the open workbook goes through here, so
/// undo, recalculation and the dirty flag stay right.
class WorkbookController extends ChangeNotifier {
  WorkbookController({required Workbook workbook, required this.locale})
    : _workbook = workbook,
      _calculator = Calculator(workbook);

  /// The interface language decides how formulas and numbers are typed.
  FormulaLocale Function() locale;

  /// Text results depend on the language (`=2.5&""` is "2,5" in Portuguese).
  void localeChanged() {
    if (_calculator.locale == locale()) return;
    _calculator.locale = locale();
    notifyListeners();
  }

  Workbook _workbook;
  Calculator _calculator;
  final _history = UndoHistory();
  var _active = 0;
  var _selection = Selection.origin;
  final Map<int, Selection> _selections = {};
  CellClip? _clip;

  String? name;
  String? path;
  var _dirty = false;
  var _revision = 0;

  Workbook get workbook => _workbook;
  int get activeSheet => _active;
  Sheet get sheet => _workbook.sheets[_active];
  Selection get selection => _selection;
  bool get dirty => _dirty;
  int get revision => _revision;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  bool get hasClip => _clip != null;
  CellClip? get clip => _clip;

  void load(Workbook workbook, {String? name, String? path}) {
    _workbook = workbook;
    _calculator = Calculator(workbook, locale: locale());
    _history.clear();
    _selections.clear();
    _active = 0;
    _selection = Selection.origin;
    _clip = null;
    this.name = name;
    this.path = path;
    _dirty = false;
    _revision++;
    notifyListeners();
  }

  void markSaved({required String name, required String? path}) {
    this.name = name;
    this.path = path;
    _dirty = false;
    notifyListeners();
  }

  void _changed() {
    _dirty = true;
    _revision++;
    notifyListeners();
  }

  // Reading.

  Cell cellAt(CellAddress address) => sheet.cellAt(address);

  CellValue valueAt(CellAddress address, [int? sheetIndex]) =>
      _calculator.valueAt(sheetIndex ?? _active, address);

  String displayAt(CellAddress address, [int? sheetIndex]) {
    final index = sheetIndex ?? _active;
    final cell = _workbook.sheets[index].cellAt(address);
    return formatValue(valueAt(address, index), cell.style.format, locale());
  }

  String editTextAt(CellAddress address) => editText(cellAt(address), locale());

  // Selection and sheets.

  void select(Selection selection) {
    final next = Selection(
      clampAddress(selection.anchor),
      clampAddress(selection.active),
    );
    if (next == _selection) return;
    _selection = next;
    notifyListeners();
  }

  void selectAll() {
    final used = sheet.usedRange;
    select(
      Selection(
        const CellAddress(0, 0),
        used?.last ?? const CellAddress(CellAddress.maxColumns - 1, 999),
      ),
    );
  }

  void showSheet(int index) {
    if (index == _active || index < 0 || index >= _workbook.sheets.length) {
      return;
    }
    _selections[_active] = _selection;
    _active = index;
    _selection = _selections[index] ?? Selection.origin;
    notifyListeners();
  }

  void addSheet(String name) {
    _workbook.sheets.add(Sheet(_uniqueSheetName(name)));
    _calculator.sheetsChanged();
    _changed();
    showSheet(_workbook.sheets.length - 1);
  }

  /// False when the name is empty, too long, uses a character Excel refuses or
  /// already belongs to another sheet.
  bool renameSheet(int index, String name) {
    final trimmed = name.trim();
    if (!isValidSheetName(trimmed)) return false;
    final other = _workbook.indexOf(trimmed);
    if (other >= 0 && other != index) return false;
    _workbook.sheets[index].name = trimmed;
    _calculator.sheetsChanged();
    _changed();
    return true;
  }

  void deleteSheet(int index) {
    if (_workbook.sheets.length < 2) return;
    _workbook.sheets.removeAt(index);
    _selections.clear();
    _history.clear();
    if (_clip?.sheet == index) _clip = null;
    _calculator.sheetsChanged();
    _active = _active.clamp(0, _workbook.sheets.length - 1);
    _selection = Selection.origin;
    _changed();
  }

  static bool isValidSheetName(String name) =>
      name.isNotEmpty &&
      name.length <= 31 &&
      !RegExp(r"[\[\]:*?/\\]").hasMatch(name) &&
      !name.startsWith("'") &&
      !name.endsWith("'");

  String _uniqueSheetName(String base) {
    var name = base;
    for (var n = 2; _workbook.indexOf(name) >= 0; n++) {
      name = '$base $n';
    }
    return name;
  }

  // Editing cells.

  void _write(Change change, CellAddress address, Cell cell) {
    final current = sheet.cellAt(address);
    change.before.putIfAbsent(address, () => current);
    change.after[address] = cell;
    _calculator.setCell(_active, address, cell);
  }

  void _commit(Change change) {
    if (change.isEmpty) return;
    _history.record(change);
    _changed();
  }

  /// What the user typed in [address]. A suggested format (typing `10%` or a
  /// date) is applied only while the cell still has the general format.
  void enter(CellAddress address, String text) {
    final cell = parseInput(text, locale()).applyTo(cellAt(address));
    final change = Change(_active);
    _write(change, address, cell);
    _commit(change);
  }

  void clearContents() {
    final change = Change(_active);
    for (final address in _storedIn(_selection.range)) {
      final cell = cellAt(address);
      _write(change, address, Cell(style: cell.style));
    }
    _commit(change);
  }

  void clearFormats() {
    final change = Change(_active);
    for (final address in _storedIn(_selection.range)) {
      _write(change, address, cellAt(address).copyWith(style: CellStyle.plain));
    }
    _commit(change);
  }

  /// Stored cells inside [range], without walking a whole selected column.
  Iterable<CellAddress> _storedIn(CellRange range) {
    if (range.columns * range.rows <= sheet.cells.length) return range.cells;
    return sheet.cells.keys.where(range.contains).toList();
  }

  /// Changes the look of every selected cell, empty ones included, as long as
  /// the selection is not huge.
  void applyStyle(CellStyle Function(CellStyle style) update) {
    final range = _selection.range;
    final cells = range.columns * range.rows <= 100000
        ? range.cells
        : _storedIn(range);
    final change = Change(_active);
    for (final address in cells) {
      final cell = cellAt(address);
      final style = update(cell.style);
      if (style != cell.style) {
        _write(change, address, cell.copyWith(style: style));
      }
    }
    _commit(change);
  }

  CellStyle get activeStyle => cellAt(_selection.active).style;

  void setColumnWidth(int column, double width) {
    final change = Change(_active);
    change.widthsBefore[column] = sheet.columnWidths[column];
    change.widthsAfter[column] = width;
    sheet.columnWidths[column] = width;
    _commit(change);
  }

  void setRowHeight(int row, double height) {
    final change = Change(_active);
    change.heightsBefore[row] = sheet.rowHeights[row];
    change.heightsAfter[row] = height;
    sheet.rowHeights[row] = height;
    _commit(change);
  }

  void setFrozen({required int rows, required int columns}) {
    sheet
      ..frozenRows = rows
      ..frozenColumns = columns;
    _changed();
  }

  // Undo.

  void undo() => _replay(_history.takeUndo(), back: true);

  void redo() => _replay(_history.takeRedo(), back: false);

  void _replay(Change? change, {required bool back}) {
    if (change == null) return;
    showSheet(change.sheet);
    final cells = back ? change.before : change.after;
    cells.forEach(
      (address, cell) => _calculator.setCell(change.sheet, address, cell),
    );
    void sizes(Map<int, double?> values, Map<int, double> target) =>
        values.forEach((index, size) {
          if (size == null) {
            target.remove(index);
          } else {
            target[index] = size;
          }
        });
    final target = _workbook.sheets[change.sheet];
    sizes(back ? change.widthsBefore : change.widthsAfter, target.columnWidths);
    sizes(back ? change.heightsBefore : change.heightsAfter, target.rowHeights);
    if (cells.isNotEmpty) {
      final keys = cells.keys.toList()..sort();
      _selection = Selection(keys.first, keys.last);
    }
    _changed();
  }

  // Clipboard.

  void copy({bool cut = false}) {
    final range = _selection.range;
    final cells = <CellAddress, Cell>{};
    for (final address in _storedIn(range)) {
      cells[address.offset(-range.first.column, -range.first.row)] = cellAt(
        address,
      );
    }
    _clip = CellClip(_active, range, cells, cut: cut);
    notifyListeners();
  }

  /// Pastes the copied cells at the active cell; a selection that is a
  /// multiple of the copy is filled with repeats, as in Excel.
  void paste() {
    final clip = _clip;
    if (clip == null) return;
    final target = _selection.range;
    final repeatColumns = target.columns % clip.range.columns == 0
        ? target.columns ~/ clip.range.columns
        : 1;
    final repeatRows = target.rows % clip.range.rows == 0
        ? target.rows ~/ clip.range.rows
        : 1;
    final change = Change(_active);
    if (clip.cut && clip.sheet == _active) {
      for (final address in clip.range.cells) {
        if (sheet.cells.containsKey(address)) {
          _write(change, address, const Cell());
        }
      }
    }
    for (var rx = 0; rx < repeatColumns; rx++) {
      for (var ry = 0; ry < repeatRows; ry++) {
        final corner = target.first.offset(
          rx * clip.range.columns,
          ry * clip.range.rows,
        );
        for (var row = 0; row < clip.range.rows; row++) {
          for (var column = 0; column < clip.range.columns; column++) {
            final destination = corner.offset(column, row);
            if (!destination.isValid) continue;
            final source = clip.cells[CellAddress(column, row)] ?? const Cell();
            final columns =
                destination.column - (clip.range.first.column + column);
            final rows = destination.row - (clip.range.first.row + row);
            _write(
              change,
              destination,
              _moved(source, columns, rows, cut: clip.cut),
            );
          }
        }
      }
    }
    if (clip.cut) _clip = null;
    final last = target.first.offset(
      clip.range.columns * repeatColumns - 1,
      clip.range.rows * repeatRows - 1,
    );
    _selection = Selection(target.first, clampAddress(last));
    _commit(change);
  }

  /// A cut keeps the formulas pointing where they pointed; a copy shifts them.
  Cell _moved(Cell cell, int columns, int rows, {required bool cut}) {
    if (!cell.isFormula || cut) return cell;
    return cell.copyWith(input: shiftReferences(cell.input, columns, rows));
  }

  /// Pastes text from another program: tab-separated rows, as spreadsheets
  /// and tables in browsers copy them.
  void pasteText(String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    if (lines.isEmpty) return;
    final start = _selection.range.first;
    final change = Change(_active);
    var width = 1;
    for (var row = 0; row < lines.length; row++) {
      final values = lines[row].split('\t');
      if (values.length > width) width = values.length;
      for (var column = 0; column < values.length; column++) {
        final address = start.offset(column, row);
        if (!address.isValid) continue;
        _write(
          change,
          address,
          parseInput(values[column], locale()).applyTo(cellAt(address)),
        );
      }
    }
    _selection = Selection(
      start,
      clampAddress(start.offset(width - 1, lines.length - 1)),
    );
    _commit(change);
  }

  /// The selection as tab-separated text, for other programs.
  String selectionAsText() {
    final range = _selection.range;
    final buffer = StringBuffer();
    final last = sheet.usedRange?.last;
    final lastRow = last == null
        ? range.first.row
        : (range.last.row < last.row ? range.last.row : last.row);
    final lastColumn = last == null
        ? range.first.column
        : (range.last.column < last.column ? range.last.column : last.column);
    for (var row = range.first.row; row <= lastRow; row++) {
      final values = [
        for (var column = range.first.column; column <= lastColumn; column++)
          displayAt(CellAddress(column, row)),
      ];
      buffer.write(values.join('\t'));
      buffer.write('\n');
    }
    return buffer.toString();
  }

  // Fill handle.

  /// Extends the selection to [target], continuing number series and
  /// shifting formulas, as dragging Excel's fill handle does.
  void fillTo(CellRange target) {
    final source = _selection.range;
    if (target == source) return;
    final change = Change(_active);
    final down = target.rows > source.rows;
    if (down) {
      final upwards = target.first.row < source.first.row;
      for (
        var column = source.first.column;
        column <= source.last.column;
        column++
      ) {
        final seed = [
          for (var row = source.first.row; row <= source.last.row; row++)
            CellAddress(column, row),
        ];
        final targets = upwards
            ? [
                for (
                  var row = source.first.row - 1;
                  row >= target.first.row;
                  row--
                )
                  CellAddress(column, row),
              ]
            : [
                for (
                  var row = source.last.row + 1;
                  row <= target.last.row;
                  row++
                )
                  CellAddress(column, row),
              ];
        _fillLine(change, upwards ? seed.reversed.toList() : seed, targets);
      }
    } else {
      final leftwards = target.first.column < source.first.column;
      for (var row = source.first.row; row <= source.last.row; row++) {
        final seed = [
          for (
            var column = source.first.column;
            column <= source.last.column;
            column++
          )
            CellAddress(column, row),
        ];
        final targets = leftwards
            ? [
                for (
                  var column = source.first.column - 1;
                  column >= target.first.column;
                  column--
                )
                  CellAddress(column, row),
              ]
            : [
                for (
                  var column = source.last.column + 1;
                  column <= target.last.column;
                  column++
                )
                  CellAddress(column, row),
              ];
        _fillLine(change, leftwards ? seed.reversed.toList() : seed, targets);
      }
    }
    _selection = Selection(target.first, target.last);
    _commit(change);
  }

  void _fillLine(
    Change change,
    List<CellAddress> seed,
    List<CellAddress> targets,
  ) {
    final cells = [for (final address in seed) cellAt(address)];
    final step = _seriesStep(cells);
    for (var i = 0; i < targets.length; i++) {
      final from = seed[i % seed.length];
      final cell = cells[i % seed.length];
      final to = targets[i];
      if (step != null) {
        final last = (cells.last.constant as NumberValue).value;
        _write(
          change,
          to,
          cell.copyWith(
            constant: NumberValue(last + step * (i + 1)),
            input: '',
          ),
        );
      } else {
        _write(
          change,
          to,
          _moved(cell, to.column - from.column, to.row - from.row, cut: false),
        );
      }
    }
  }

  /// Two or more numbers in a row make a series with their average step;
  /// anything else is repeated.
  double? _seriesStep(List<Cell> cells) {
    if (cells.length < 2) return null;
    final numbers = <double>[];
    for (final cell in cells) {
      final constant = cell.constant;
      if (cell.isFormula || constant is! NumberValue) return null;
      numbers.add(constant.value);
    }
    return (numbers.last - numbers.first) / (numbers.length - 1);
  }

  // Sorting.

  /// Sorts the rows of the selection by the active cell's column. Empty
  /// values go last in both directions, as in Excel.
  void sortSelection({required bool ascending}) {
    final range = _selection.range;
    if (range.rows < 2) return;
    final used = sheet.usedRange;
    if (used == null) return;
    final lastRow = range.last.row < used.last.row
        ? range.last.row
        : used.last.row;
    final lastColumn = range.last.column < used.last.column
        ? range.last.column
        : used.last.column;
    final rows = [for (var row = range.first.row; row <= lastRow; row++) row];
    final key = _selection.active.column;
    int compare(int a, int b) {
      final va = valueAt(CellAddress(key, a)),
          vb = valueAt(CellAddress(key, b));
      final ea = va is EmptyValue, eb = vb is EmptyValue;
      if (ea || eb) return ea == eb ? a - b : (ea ? 1 : -1);
      final result = compareValues(va, vb);
      return result != 0 ? (ascending ? result : -result) : a - b;
    }

    final order = [...rows]..sort(compare);
    final snapshot = {
      for (final row in rows)
        for (var column = range.first.column; column <= lastColumn; column++)
          CellAddress(column, row): cellAt(CellAddress(column, row)),
    };
    final change = Change(_active);
    for (var i = 0; i < rows.length; i++) {
      final from = order[i], to = rows[i];
      for (var column = range.first.column; column <= lastColumn; column++) {
        final cell = snapshot[CellAddress(column, from)]!;
        _write(
          change,
          CellAddress(column, to),
          _moved(cell, 0, to - from, cut: false),
        );
      }
    }
    _commit(change);
  }

  /// Numbers before text, text without case, as Excel sorts.
  static int compareValues(CellValue a, CellValue b) {
    int rank(CellValue v) => switch (v) {
      NumberValue() => 0,
      TextValue() => 1,
      BoolValue() => 2,
      ErrorValue() => 3,
      EmptyValue() => 4,
    };
    final ra = rank(a), rb = rank(b);
    if (ra != rb) return ra - rb;
    return switch ((a, b)) {
      (NumberValue(value: final x), NumberValue(value: final y)) => x.compareTo(
        y,
      ),
      (TextValue(value: final x), TextValue(value: final y)) =>
        x.toLowerCase().compareTo(y.toLowerCase()),
      (BoolValue(value: final x), BoolValue(value: final y)) =>
        (x ? 1 : 0) - (y ? 1 : 0),
      _ => 0,
    };
  }

  // Status bar.

  /// Sum, average and count of the numbers in the selection, as the status
  /// bar shows them; null with fewer than two cells selected.
  SelectionStats? get stats {
    final range = _selection.range;
    if (range.isSingle) return null;
    var sum = 0.0, numbers = 0, filled = 0;
    for (final address in _storedIn(range)) {
      final value = valueAt(address);
      if (value is EmptyValue) continue;
      filled++;
      if (value is NumberValue) {
        sum += value.value;
        numbers++;
      }
    }
    if (filled == 0) return null;
    return SelectionStats(sum: sum, numbers: numbers, count: filled);
  }
}

class SelectionStats {
  const SelectionStats({
    required this.sum,
    required this.numbers,
    required this.count,
  });

  final double sum;
  final int numbers;
  final int count;

  double? get average => numbers == 0 ? null : sum / numbers;
}
