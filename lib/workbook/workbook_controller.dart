import 'package:flutter/foundation.dart';

import '../formula/formula.dart';
import '../sheet/cell_address.dart';
import '../sheet/cell_style.dart';
import '../sheet/cell_value.dart';
import '../sheet/chart.dart';
import '../sheet/structure.dart';
import '../sheet/workbook.dart';
import 'chart_builder.dart';
import 'find.dart';
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
    final next = _withMerges(
      clampAddress(selection.anchor),
      clampAddress(selection.active),
    );
    if (next == _selection) return;
    _selection = next;
    notifyListeners();
  }

  /// A selection covers whole merges; clicking a merged cell selects all of
  /// it with its top left cell active, as in Excel.
  Selection _withMerges(CellAddress anchor, CellAddress active) {
    if (sheet.merges.isEmpty) return Selection(anchor, active);
    final merge = sheet.mergeAt(active);
    if (merge != null && merge.contains(anchor)) {
      return Selection(merge.first, merge.first, merge);
    }
    final range = sheet.expandToMerges(CellRange(anchor, active));
    return range == CellRange(anchor, active)
        ? Selection(anchor, active)
        : Selection(anchor, active, range);
  }

  /// The cell that typing goes to: the top left one of a merge.
  CellAddress get editCell {
    final active = _selection.active;
    return sheet.mergeAt(active)?.first ?? active;
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

  /// Records a write; [_commit] makes them all at once, so the calculator
  /// evaluates the dependents a single time.
  void _write(Change change, CellAddress address, Cell cell) {
    final current = sheet.cellAt(address);
    change.before.putIfAbsent(address, () => current);
    change.after[address] = cell;
  }

  void _commit(Change change) {
    if (change.isEmpty) return;
    _apply(change.sheet, change.after);
    _history.record(change);
    _changed();
  }

  void _apply(int sheet, Map<CellAddress, Cell> cells) => _calculator.setCells({
    for (final MapEntry(:key, :value) in cells.entries)
      cellKey(sheet, key): value,
  });

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

  // Merged cells.

  /// The merge under the active cell, if any.
  CellRange? get activeMerge => sheet.mergeAt(_selection.active);

  /// Merges the selection into one cell that keeps the top left content;
  /// merges inside it are replaced. With [center] the text is centered, as
  /// Excel's "Merge & Center" does. Nothing happens for a single cell or a
  /// whole row or column.
  void mergeSelection({bool center = true}) {
    final range = _selection.range;
    if (range.isSingle || wholeRowsSelected || wholeColumnsSelected) return;
    final change = Change(_active)
      ..mergesBefore = sheet.merges
      ..mergesAfter = [
        for (final merge in sheet.merges)
          if (!merge.intersects(range)) merge,
        range,
      ];
    for (final address in _storedIn(range)) {
      if (address == range.first) continue;
      final cell = cellAt(address);
      if (cell.input.isNotEmpty || cell.constant is! EmptyValue) {
        _write(change, address, Cell(style: cell.style));
      }
    }
    if (center) {
      final first = cellAt(range.first);
      _write(
        change,
        range.first,
        first.copyWith(
          style: first.style.copyWith(horizontal: HorizontalAlign.center),
        ),
      );
    }
    _apply(change.sheet, change.after);
    sheet.merges = change.mergesAfter!;
    _history.record(change);
    _selection = Selection(range.first, range.first, range);
    _changed();
  }

  /// Splits every merge that touches the selection.
  void unmergeSelection() {
    final range = _selection.range;
    final kept = [
      for (final merge in sheet.merges)
        if (!merge.intersects(range)) merge,
    ];
    if (kept.length == sheet.merges.length) return;
    final change = Change(_active)
      ..mergesBefore = sheet.merges
      ..mergesAfter = kept;
    sheet.merges = kept;
    _history.record(change);
    _changed();
  }

  /// Content of cells that a merge would clear, so the editor can warn.
  bool get mergeWouldClear {
    final range = _selection.range;
    for (final address in _storedIn(range)) {
      if (address == range.first) continue;
      final cell = cellAt(address);
      if (cell.input.isNotEmpty || cell.constant is! EmptyValue) return true;
    }
    return false;
  }

  // Find and replace.

  List<CellAddress>? _found;
  (FindQuery, int, int)? _foundFor;

  /// Every cell of the active sheet that matches, by rows. Kept until the
  /// workbook or the query changes, so going to the next match is a binary
  /// search instead of a scan of the sheet.
  List<CellAddress> findAll(FindQuery query) {
    final key = (query, _active, _revision);
    if (_foundFor == key) return _found!;
    final found = <CellAddress>[];
    if (!query.isEmpty) {
      final merges = sheet.merges.isNotEmpty;
      sheet.cells.forEach((address, cell) {
        if (cell.input.isEmpty && cell.constant is EmptyValue) return;
        if (merges && (sheet.mergeAt(address)?.first ?? address) != address) {
          return;
        }
        final text = query.inFormulas
            ? editText(cell, locale())
            : displayAt(address);
        if (query.matches(text)) found.add(address);
      });
      found.sort();
    }
    _found = found;
    _foundFor = key;
    return found;
  }

  /// Selects the next match after the active cell (or before it), wrapping
  /// around the sheet. Null when nothing matches.
  CellAddress? findNext(FindQuery query, {bool backwards = false}) {
    final found = findAll(query);
    if (found.isEmpty) return null;
    final from = _selection.active;
    var low = 0, high = found.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (found[middle].compareTo(from) <= 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final CellAddress next;
    if (backwards) {
      var index = low - 1;
      if (index >= 0 && found[index] == from) index--;
      next = found[index < 0 ? found.length - 1 : index];
    } else {
      next = found[low < found.length ? low : 0];
    }
    select(Selection.single(next));
    return next;
  }

  /// Replaces in the active cell when it matches, then goes to the next
  /// match. Replacing always works on what was typed, as in Excel.
  CellAddress? replaceNext(FindQuery query, String replacement) {
    final active = editCell;
    final text = editTextAt(active);
    if (query.matches(text)) {
      enter(active, query.replace(text, replacement));
    }
    return findNext(query);
  }

  /// Replaces every match of the sheet in one change; returns how many
  /// cells changed.
  int replaceAll(FindQuery query, String replacement) {
    if (query.isEmpty) return 0;
    final change = Change(_active);
    for (final address in findAll(query)) {
      final text = editTextAt(address);
      if (!query.matches(text)) continue;
      final updated = query.replace(text, replacement);
      if (updated == text) continue;
      _write(
        change,
        address,
        parseInput(updated, locale()).applyTo(cellAt(address)),
      );
    }
    _commit(change);
    return change.after.length;
  }

  // Charts.

  /// Makes a chart of the selection, or of the block around the active cell
  /// when only one cell is selected. Returns its index, or null when there
  /// are no numbers to draw.
  int? insertChart(ChartKind kind) {
    final range = _selection.range.isSingle
        ? currentRegion(sheet, _selection.active)
        : _selection.range;
    final chart = buildChart(
      sheet: sheet,
      range: range,
      kind: kind,
      valueAt: valueAt,
    );
    if (chart == null) return null;
    _setCharts([...sheet.charts, chart]);
    return sheet.charts.length - 1;
  }

  void updateChart(int index, SheetChart chart) {
    if (index < 0 || index >= sheet.charts.length) return;
    _setCharts([...sheet.charts]..[index] = chart);
  }

  void deleteChart(int index) {
    if (index < 0 || index >= sheet.charts.length) return;
    _setCharts([...sheet.charts]..removeAt(index));
  }

  void _setCharts(List<SheetChart> charts) {
    final change = Change(_active)
      ..chartsBefore = sheet.charts
      ..chartsAfter = List.unmodifiable(charts);
    sheet.charts = change.chartsAfter!;
    _history.record(change);
    _changed();
  }

  /// The values a chart reads from [data], by its sheet name; empty when
  /// that sheet is gone.
  CellValue chartValue(ChartData data, CellAddress address) {
    final index = _workbook.indexOf(data.sheet);
    return index < 0 ? const EmptyValue() : valueAt(address, index);
  }

  String chartText(ChartData data, CellAddress address) {
    final index = _workbook.indexOf(data.sheet);
    return index < 0 ? '' : displayAt(address, index);
  }

  // Undo.

  void undo() => _replay(_history.takeUndo(), back: true);

  void redo() => _replay(_history.takeRedo(), back: false);

  void _replay(HistoryEntry? entry, {required bool back}) {
    if (entry == null) return;
    showSheet(entry.sheet);
    switch (entry) {
      case Change():
        _replayCells(entry, back: back);
      case StructureChange():
        _replayStructure(entry, back: back);
    }
    _changed();
  }

  void _replayCells(Change change, {required bool back}) {
    final cells = back ? change.before : change.after;
    _apply(change.sheet, cells);
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
    if (back ? change.mergesBefore : change.mergesAfter case final merges?) {
      target.merges = merges;
    }
    if (back ? change.chartsBefore : change.chartsAfter case final charts?) {
      target.charts = charts;
    }
    if (cells.isNotEmpty) {
      final keys = cells.keys.toList()..sort();
      _selection = Selection(keys.first, keys.last);
    }
  }

  /// Undo runs the opposite edit, then puts back the texts it could not
  /// rebuild (references that became `#REF!` or ranges that lost cells) and
  /// the deleted cells.
  void _replayStructure(StructureChange change, {required bool back}) {
    final target = _workbook.sheets[change.sheet];
    if (!back) {
      change.result = _calculator.changeStructure(change.edit)!;
      _moveLayouts(change.edit);
      return;
    }
    final edit = change.edit, inverse = edit.inverse;
    _calculator.changeStructure(inverse);
    final fixes = <CellKey, Cell>{};
    change.result.rewritten.forEach((key, text) {
      final address = key.sheet == edit.sheet
          ? inverse.moveCell(key.address)
          : key.address;
      if (address == null) return;
      final cell = _workbook.sheets[key.sheet].cellAt(address);
      if (cell.input != text) {
        fixes[cellKey(key.sheet, address)] = cell.copyWith(input: text);
      }
    });
    change.result.removed.forEach(
      (address, cell) => fixes[cellKey(edit.sheet, address)] = cell,
    );
    _calculator.setCells(fixes);
    change.layout.restore(target);
    for (var i = 0; i < change.charts.length; i++) {
      _workbook.sheets[i].charts = change.charts[i];
    }
  }

  // Rows and columns.

  bool get wholeRowsSelected =>
      _selection.range.columns == CellAddress.maxColumns;
  bool get wholeColumnsSelected => _selection.range.rows == CellAddress.maxRows;

  /// Inserts as many rows as the selection has, above it. False when that
  /// would push filled cells off the end of the sheet.
  bool insertRows() => _changeStructure(
    SheetAxis.rows,
    _selection.range.first.row,
    _selection.range.rows,
  );

  bool insertColumns() => _changeStructure(
    SheetAxis.columns,
    _selection.range.first.column,
    _selection.range.columns,
  );

  void deleteRows() => _changeStructure(
    SheetAxis.rows,
    _selection.range.first.row,
    -_selection.range.rows,
  );

  void deleteColumns() => _changeStructure(
    SheetAxis.columns,
    _selection.range.first.column,
    -_selection.range.columns,
  );

  bool _changeStructure(SheetAxis axis, int at, int count) {
    final edit = StructureEdit(
      sheet: _active,
      axis: axis,
      at: at,
      count: count,
    );
    final layout = SheetLayout.of(sheet);
    final charts = [for (final s in _workbook.sheets) s.charts];
    final result = _calculator.changeStructure(edit);
    if (result == null) return false;
    _moveLayouts(edit);
    _clip = null;
    _history.record(StructureChange(edit, layout, charts, result));
    _changed();
    return true;
  }

  void _moveLayouts(StructureEdit edit) {
    final edited = _workbook.sheets[edit.sheet];
    edited.moveLayout(edit);
    final name = edited.name.toLowerCase();
    for (var i = 0; i < _workbook.sheets.length; i++) {
      final target = _workbook.sheets[i];
      if (target.charts.isEmpty) continue;
      target.charts = [
        for (final chart in target.charts)
          ?chart.moved(edit, name, onEditedSheet: i == edit.sheet),
      ];
    }
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
    if (sheet.merges.any((merge) => merge.intersects(range))) return;
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
