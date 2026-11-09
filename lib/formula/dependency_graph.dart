import '../sheet/cell_address.dart';

/// A cell of the workbook.
typedef CellKey = ({int sheet, CellAddress address});

CellKey cellKey(int sheet, CellAddress address) =>
    (sheet: sheet, address: address);

class _Area {
  _Area(this.formula, this.sheet, this.range);
  final CellKey formula;
  final int sheet;
  final CellRange range;
}

/// Which formulas read which cells. Ranges are indexed by column, so finding
/// the readers of a cell does not scan every formula.
class DependencyGraph {
  // Ranges wider than this go to one list per sheet instead of per column.
  static const _maxIndexedColumns = 64;

  final _points = <CellKey, Set<CellKey>>{};
  final _byColumn = <int, Map<int, Set<_Area>>>{};
  final _wide = <int, Set<_Area>>{};
  final _registered = <CellKey, (List<CellKey>, List<_Area>)>{};

  void add(CellKey formula, Iterable<(int, CellRange)> precedents) {
    remove(formula);
    final points = <CellKey>[];
    final areas = <_Area>[];
    for (final (sheet, range) in precedents) {
      if (range.isSingle) {
        final key = cellKey(sheet, range.first);
        (_points[key] ??= {}).add(formula);
        points.add(key);
        continue;
      }
      final area = _Area(formula, sheet, range);
      areas.add(area);
      if (range.columns > _maxIndexedColumns) {
        (_wide[sheet] ??= {}).add(area);
      } else {
        final columns = _byColumn[sheet] ??= {};
        for (var c = range.first.column; c <= range.last.column; c++) {
          (columns[c] ??= {}).add(area);
        }
      }
    }
    _registered[formula] = (points, areas);
  }

  void remove(CellKey formula) {
    final registered = _registered.remove(formula);
    if (registered == null) return;
    final (points, areas) = registered;
    for (final key in points) {
      final readers = _points[key];
      readers?.remove(formula);
      if (readers != null && readers.isEmpty) _points.remove(key);
    }
    for (final area in areas) {
      final range = area.range;
      if (range.columns > _maxIndexedColumns) {
        _wide[area.sheet]?.remove(area);
        continue;
      }
      final columns = _byColumn[area.sheet];
      for (var c = range.first.column; c <= range.last.column; c++) {
        columns?[c]?.remove(area);
      }
    }
  }

  /// The formulas that read the cell [key].
  Set<CellKey> dependentsOf(CellKey key) {
    final (:sheet, :address) = key;
    final result = <CellKey>{...?_points[key]};
    for (final area in [
      ...?_byColumn[sheet]?[address.column],
      ...?_wide[sheet],
    ]) {
      if (area.range.contains(address)) result.add(area.formula);
    }
    return result;
  }

  void clear() {
    _points.clear();
    _byColumn.clear();
    _wide.clear();
    _registered.clear();
  }
}
