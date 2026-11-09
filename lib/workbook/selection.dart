import '../sheet/cell_address.dart';

/// The selected cells: [anchor] is where the selection started and [active]
/// the cell that receives typing; the range spans both.
class Selection {
  const Selection(this.anchor, this.active);

  const Selection.single(CellAddress cell) : anchor = cell, active = cell;

  static const origin = Selection.single(CellAddress(0, 0));

  final CellAddress anchor;
  final CellAddress active;

  CellRange get range => CellRange(anchor, active);

  Selection extendTo(CellAddress cell) => Selection(anchor, cell);

  @override
  bool operator ==(Object other) =>
      other is Selection && other.anchor == anchor && other.active == active;

  @override
  int get hashCode => Object.hash(anchor, active);
}

CellAddress clampAddress(CellAddress cell) => CellAddress(
  cell.column.clamp(0, CellAddress.maxColumns - 1),
  cell.row.clamp(0, CellAddress.maxRows - 1),
);
