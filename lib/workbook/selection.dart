import '../sheet/cell_address.dart';

/// The selected cells: [anchor] is where the selection started and [active]
/// the cell that receives typing; the range spans both.
class Selection {
  const Selection(this.anchor, this.active, [this._range]);

  const Selection.single(CellAddress cell)
    : anchor = cell,
      active = cell,
      _range = null;

  static const origin = Selection.single(CellAddress(0, 0));

  final CellAddress anchor;
  final CellAddress active;

  /// Set when merged cells make the selection bigger than its corners.
  final CellRange? _range;

  CellRange get range => _range ?? CellRange(anchor, active);

  Selection extendTo(CellAddress cell) => Selection(anchor, cell);

  Selection withRange(CellRange range) => Selection(anchor, active, range);

  @override
  bool operator ==(Object other) =>
      other is Selection &&
      other.anchor == anchor &&
      other.active == active &&
      other.range == range;

  @override
  int get hashCode => Object.hash(anchor, active, range);
}

CellAddress clampAddress(CellAddress cell) => CellAddress(
  cell.column.clamp(0, CellAddress.maxColumns - 1),
  cell.row.clamp(0, CellAddress.maxRows - 1),
);
