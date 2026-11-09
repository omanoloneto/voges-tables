import '../sheet/cell_address.dart';

/// A cell of the workbook, packed in one integer: maps keyed by it hash and
/// compare much faster than by a record, and the calculator lives on them.
/// The row takes the low bits, which the hash tables use the most.
extension type const CellKey._(int _bits) implements Object {
  CellKey(int sheet, CellAddress address)
    : _bits =
          sheet << 34 |
          address.column << 20 |
          (address.row ^ _spread(address.column));

  int get sheet => _bits >> 34;
  int get column => _bits >> 20 & 0x3FFF;
  int get row => (_bits ^ _spread(column)) & 0xFFFFF;

  /// Mixes the column into the low bits too, so a long row of cells does
  /// not land in the same buckets.
  static int _spread(int column) => column * 0x9E3779B1 & 0xFFFFF;
  CellAddress get address => CellAddress(column, row);
}

CellKey cellKey(int sheet, CellAddress address) => CellKey(sheet, address);

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

  // Most cells have one reader: it is kept as is, and a set only for more.
  final _points = <CellKey, Object>{};
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
        final readers = _points[key];
        if (readers == null) {
          _points[key] = formula;
        } else if (readers is Set<CellKey>) {
          readers.add(formula);
        } else if (readers != formula) {
          _points[key] = <CellKey>{readers as CellKey, formula};
        }
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
      if (readers is Set<CellKey>) {
        readers.remove(formula);
        if (readers.length == 1) _points[key] = readers.first;
      } else if (readers == formula) {
        _points.remove(key);
      }
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
    final sheet = key.sheet, column = key.column, row = key.row;
    final readers = _points[key];
    final result = readers is Set<CellKey>
        ? {...readers}
        : <CellKey>{?(readers as CellKey?)};
    void collect(Set<_Area>? areas) {
      if (areas == null) return;
      for (final area in areas) {
        final range = area.range;
        if (column >= range.first.column &&
            column <= range.last.column &&
            row >= range.first.row &&
            row <= range.last.row) {
          result.add(area.formula);
        }
      }
    }

    collect(_byColumn[sheet]?[column]);
    collect(_wide[sheet]);
    return result;
  }

  void clear() {
    _points.clear();
    _byColumn.clear();
    _wide.clear();
    _registered.clear();
  }
}
