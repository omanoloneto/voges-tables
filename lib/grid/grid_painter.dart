import 'package:flutter/material.dart';

import '../sheet/cell_address.dart';
import '../sheet/cell_style.dart';
import '../sheet/cell_value.dart';
import '../sheet/workbook.dart';
import '../workbook/workbook_controller.dart';
import 'grid_axis.dart';

/// Colors of the grid. The cells stay paper white in both themes, as cell
/// colors in files assume a white page.
class GridColors {
  const GridColors({
    required this.header,
    required this.headerText,
    required this.headerSelected,
    required this.headerSelectedText,
    required this.accent,
  });

  factory GridColors.of(ColorScheme scheme) => GridColors(
    header: scheme.surfaceContainerHigh,
    headerText: scheme.onSurfaceVariant,
    headerSelected: scheme.primaryContainer,
    headerSelectedText: scheme.onPrimaryContainer,
    accent: const Color(0xFF1D6B3E),
  );

  final Color header;
  final Color headerText;
  final Color headerSelected;
  final Color headerSelectedText;
  final Color accent;

  static const paper = Color(0xFFFFFFFF);
  static const line = Color(0xFFDADCE0);
  static const ink = Color(0xFF1F1F1F);
}

class GridPainter extends CustomPainter {
  GridPainter({
    required this.controller,
    required this.columns,
    required this.rows,
    required this.colors,
    required this.zoom,
    required this.textCache,
    this.editing,
    this.fillPreview,
    super.repaint,
  });

  final WorkbookController controller;
  final AxisView columns;
  final AxisView rows;
  final GridColors colors;
  final double zoom;
  final TextCache textCache;

  /// The cell under the text editor: its text is not painted.
  final CellAddress? editing;

  /// The range the fill handle is being dragged to.
  final CellRange? fillPreview;

  static const fillHandleSize = 7.0;

  Sheet get sheet => controller.sheet;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(zoom);
    final logical = size / zoom;
    canvas.drawRect(Offset.zero & logical, Paint()..color = GridColors.paper);
    final visibleColumns = columns.visible.toList();
    final visibleRows = rows.visible.toList();
    _paintRegion(
      canvas,
      logical,
      visibleColumns,
      visibleRows,
      frozenColumns: true,
      frozenRows: true,
    );
    _paintRegion(
      canvas,
      logical,
      visibleColumns,
      visibleRows,
      frozenColumns: false,
      frozenRows: true,
    );
    _paintRegion(
      canvas,
      logical,
      visibleColumns,
      visibleRows,
      frozenColumns: true,
      frozenRows: false,
    );
    _paintRegion(
      canvas,
      logical,
      visibleColumns,
      visibleRows,
      frozenColumns: false,
      frozenRows: false,
    );
    _paintHeaders(canvas, logical, visibleColumns, visibleRows);
    _paintFrozenLines(canvas, logical);
    canvas.restore();
  }

  /// One of the four panes: frozen corner, frozen rows, frozen columns and
  /// the scrolling cells, each clipped so they never cover each other.
  void _paintRegion(
    Canvas canvas,
    Size size,
    List<int> visibleColumns,
    List<int> visibleRows, {
    required bool frozenColumns,
    required bool frozenRows,
  }) {
    final frozenX = columns.axis.frozen, frozenY = rows.axis.frozen;
    if (frozenColumns && frozenX == 0) return;
    if (frozenRows && frozenY == 0) return;
    final left = frozenColumns
        ? columns.headerSize
        : columns.headerSize + columns.axis.frozenExtent;
    final top = frozenRows
        ? rows.headerSize
        : rows.headerSize + rows.axis.frozenExtent;
    final right = frozenColumns ? left + columns.axis.frozenExtent : size.width;
    final bottom = frozenRows ? top + rows.axis.frozenExtent : size.height;
    if (right <= left || bottom <= top) return;
    final region = Rect.fromLTRB(left, top, right, bottom);
    final columnList = [
      for (final c in visibleColumns)
        if ((c < frozenX) == frozenColumns) c,
    ];
    final rowList = [
      for (final r in visibleRows)
        if ((r < frozenY) == frozenRows) r,
    ];
    if (columnList.isEmpty || rowList.isEmpty) return;
    canvas.save();
    canvas.clipRect(region);
    _paintFills(canvas, columnList, rowList);
    _paintLines(canvas, region, columnList, rowList);
    _paintTexts(canvas, region, columnList, rowList);
    _paintBorders(canvas, columnList, rowList);
    _paintClip(canvas);
    _paintSelection(canvas);
    canvas.restore();
  }

  Rect cellRect(CellAddress cell) => Rect.fromLTRB(
    columns.screenStart(cell.column),
    rows.screenStart(cell.row),
    columns.screenEnd(cell.column),
    rows.screenEnd(cell.row),
  );

  Rect rangeRect(CellRange range) => Rect.fromLTRB(
    columns.screenStart(range.first.column),
    rows.screenStart(range.first.row),
    columns.screenEnd(range.last.column),
    rows.screenEnd(range.last.row),
  );

  void _paintFills(Canvas canvas, List<int> columnList, List<int> rowList) {
    for (final row in rowList) {
      for (final column in columnList) {
        final fill = sheet.cells[CellAddress(column, row)]?.style.fillColor;
        if (fill == null) continue;
        canvas.drawRect(
          cellRect(CellAddress(column, row)),
          Paint()..color = Color(fill),
        );
      }
    }
  }

  void _paintLines(
    Canvas canvas,
    Rect region,
    List<int> columnList,
    List<int> rowList,
  ) {
    final paint = Paint()
      ..color = GridColors.line
      ..strokeWidth = 1 / zoom;
    for (final column in columnList) {
      final x = columns.screenEnd(column) - 0.5 / zoom;
      canvas.drawLine(Offset(x, region.top), Offset(x, region.bottom), paint);
    }
    for (final row in rowList) {
      final y = rows.screenEnd(row) - 0.5 / zoom;
      canvas.drawLine(Offset(region.left, y), Offset(region.right, y), paint);
    }
  }

  void _paintTexts(
    Canvas canvas,
    Rect region,
    List<int> columnList,
    List<int> rowList,
  ) {
    for (final row in rowList) {
      for (final column in columnList) {
        final address = CellAddress(column, row);
        if (address == editing) continue;
        final cell = sheet.cells[address];
        if (cell == null ||
            (cell.input.isEmpty && cell.constant is EmptyValue)) {
          continue;
        }
        _paintCellText(canvas, region, address, cell, columnList.last);
      }
    }
  }

  void _paintCellText(
    Canvas canvas,
    Rect region,
    CellAddress address,
    Cell cell,
    int lastColumn,
  ) {
    final value = controller.valueAt(address);
    var text = controller.displayAt(address);
    if (text.isEmpty) return;
    final style = cell.style;
    final rect = cellRect(address);
    final align = _alignOf(style.horizontal, value);
    var painter = textCache.layout(
      text,
      style,
      wrapWidth: style.wrap ? rect.width - 6 : null,
    );
    var area = rect;
    if (!style.wrap && painter.width > rect.width - 6) {
      if (value is NumberValue) {
        final hashes = (rect.width / textCache.layout('#', style).width)
            .floor()
            .clamp(1, 255);
        text = '#' * hashes;
        painter = textCache.layout(text, style);
      } else if (align == TextAlign.left) {
        var right = address.column;
        while (right < lastColumn &&
            _isBlank(CellAddress(right + 1, address.row))) {
          if (columns.screenEnd(right) - rect.left >= painter.width + 6) break;
          right++;
        }
        area = Rect.fromLTRB(
          rect.left,
          rect.top,
          columns.screenEnd(right),
          rect.bottom,
        );
      }
    }
    final dx = switch (align) {
      TextAlign.right => area.right - 3 - painter.width,
      TextAlign.center => area.left + (area.width - painter.width) / 2,
      _ => area.left + 3,
    };
    final dy = switch (style.vertical) {
      VerticalAlign.top => area.top + 2,
      VerticalAlign.middle => area.top + (area.height - painter.height) / 2,
      VerticalAlign.bottom => area.bottom - 3 - painter.height,
    };
    canvas.save();
    canvas.clipRect(area.intersect(region));
    painter.paint(canvas, Offset(dx, dy));
    canvas.restore();
  }

  bool _isBlank(CellAddress address) {
    final cell = sheet.cells[address];
    return cell == null || (!cell.isFormula && cell.constant is EmptyValue);
  }

  static TextAlign _alignOf(HorizontalAlign align, CellValue value) =>
      switch (align) {
        HorizontalAlign.left => TextAlign.left,
        HorizontalAlign.center => TextAlign.center,
        HorizontalAlign.right => TextAlign.right,
        HorizontalAlign.general => switch (value) {
          NumberValue() => TextAlign.right,
          BoolValue() || ErrorValue() => TextAlign.center,
          _ => TextAlign.left,
        },
      };

  void _paintBorders(Canvas canvas, List<int> columnList, List<int> rowList) {
    final paint = Paint()
      ..color = GridColors.ink
      ..strokeWidth = 1;
    for (final row in rowList) {
      for (final column in columnList) {
        final borders = sheet.cells[CellAddress(column, row)]?.style.borders;
        if (borders == null || borders.isEmpty) continue;
        final r = cellRect(CellAddress(column, row));
        if (borders.top) canvas.drawLine(r.topLeft, r.topRight, paint);
        if (borders.bottom) canvas.drawLine(r.bottomLeft, r.bottomRight, paint);
        if (borders.left) canvas.drawLine(r.topLeft, r.bottomLeft, paint);
        if (borders.right) canvas.drawLine(r.topRight, r.bottomRight, paint);
      }
    }
  }

  void _paintClip(Canvas canvas) {
    final clip = controller.clip;
    if (clip == null || clip.sheet != controller.activeSheet) return;
    final rect = rangeRect(clip.range).deflate(1);
    final paint = Paint()
      ..color = colors.accent
      ..strokeWidth = 2 / zoom
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    void dashed(Offset a, Offset b) {
      final length = (b - a).distance;
      final direction = (b - a) / length;
      for (var d = 0.0; d < length; d += dash * 2) {
        canvas.drawLine(
          a + direction * d,
          a + direction * (d + dash).clamp(0, length),
          paint,
        );
      }
    }

    dashed(rect.topLeft, rect.topRight);
    dashed(rect.topRight, rect.bottomRight);
    dashed(rect.bottomRight, rect.bottomLeft);
    dashed(rect.bottomLeft, rect.topLeft);
  }

  void _paintSelection(Canvas canvas) {
    final selection = controller.selection;
    final rect = rangeRect(selection.range);
    if (!selection.range.isSingle) {
      final active = cellRect(selection.active);
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect)
          ..addRect(active),
      );
      canvas.drawRect(
        rect,
        Paint()..color = colors.accent.withValues(alpha: 0.12),
      );
      canvas.restore();
    }
    final border = Paint()
      ..color = colors.accent
      ..strokeWidth = 2 / zoom
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect.deflate(0.5 / zoom), border);
    if (fillPreview case final preview?) {
      canvas.drawRect(
        rangeRect(preview).deflate(0.5 / zoom),
        Paint()
          ..color = colors.accent.withValues(alpha: 0.7)
          ..strokeWidth = 1.5 / zoom
          ..style = PaintingStyle.stroke,
      );
    }
    final handle = Rect.fromCenter(
      center: rect.bottomRight,
      width: fillHandleSize / zoom,
      height: fillHandleSize / zoom,
    );
    canvas.drawRect(
      handle.inflate(1 / zoom),
      Paint()..color = GridColors.paper,
    );
    canvas.drawRect(handle, Paint()..color = colors.accent);
  }

  void _paintHeaders(
    Canvas canvas,
    Size size,
    List<int> visibleColumns,
    List<int> visibleRows,
  ) {
    final range = controller.selection.range;
    final headerPaint = Paint()..color = colors.header;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, rows.headerSize),
      headerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, columns.headerSize, size.height),
      headerPaint,
    );
    final line = Paint()
      ..color = GridColors.line
      ..strokeWidth = 1 / zoom;
    final frozenX = columns.headerSize + columns.axis.frozenExtent;
    final frozenY = rows.headerSize + rows.axis.frozenExtent;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(columns.headerSize, 0, size.width, rows.headerSize),
    );
    for (final column in visibleColumns) {
      final left = columns.screenStart(column),
          right = columns.screenEnd(column);
      if (column >= columns.axis.frozen && right <= frozenX) continue;
      final selected =
          column >= range.first.column && column <= range.last.column;
      final rect = Rect.fromLTRB(left, 0, right, rows.headerSize);
      if (selected) {
        canvas.drawRect(rect, Paint()..color = colors.headerSelected);
      }
      canvas.drawLine(
        Offset(right - 0.5 / zoom, 0),
        Offset(right - 0.5 / zoom, rows.headerSize),
        line,
      );
      _headerText(canvas, CellAddress.columnName(column), rect, selected);
    }
    canvas.restore();

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(0, rows.headerSize, columns.headerSize, size.height),
    );
    for (final row in visibleRows) {
      final top = rows.screenStart(row), bottom = rows.screenEnd(row);
      if (row >= rows.axis.frozen && bottom <= frozenY) continue;
      final selected = row >= range.first.row && row <= range.last.row;
      final rect = Rect.fromLTRB(0, top, columns.headerSize, bottom);
      if (selected) {
        canvas.drawRect(rect, Paint()..color = colors.headerSelected);
      }
      canvas.drawLine(
        Offset(0, bottom - 0.5 / zoom),
        Offset(columns.headerSize, bottom - 0.5 / zoom),
        line,
      );
      _headerText(canvas, '${row + 1}', rect, selected);
    }
    canvas.restore();

    canvas.drawLine(
      Offset(0, rows.headerSize - 0.5),
      Offset(size.width, rows.headerSize - 0.5),
      line,
    );
    canvas.drawLine(
      Offset(columns.headerSize - 0.5, 0),
      Offset(columns.headerSize - 0.5, size.height),
      line,
    );
    final corner = Rect.fromLTWH(0, 0, columns.headerSize, rows.headerSize);
    canvas.drawRect(corner, headerPaint);
    final triangle = Path()
      ..moveTo(corner.right - 4, corner.bottom - 12)
      ..lineTo(corner.right - 4, corner.bottom - 4)
      ..lineTo(corner.right - 12, corner.bottom - 4)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()..color = colors.headerText.withValues(alpha: 0.5),
    );
  }

  void _headerText(Canvas canvas, String text, Rect rect, bool selected) {
    final painter = textCache.header(
      text,
      selected ? colors.headerSelectedText : colors.headerText,
      bold: selected,
    );
    if (painter.width > rect.width - 2) return;
    painter.paint(
      canvas,
      rect.center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintFrozenLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9AA0A6)
      ..strokeWidth = 1.5 / zoom;
    if (columns.axis.frozen > 0) {
      final x = columns.headerSize + columns.axis.frozenExtent;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    if (rows.axis.frozen > 0) {
      final y = rows.headerSize + rows.axis.frozenExtent;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => true;
}

/// Laid out texts, reused while scrolling; cleared when it grows too much.
class TextCache {
  static const _limit = 4000;

  final Map<(String, CellStyle, double?), TextPainter> _cells = {};
  final Map<(String, Color, bool), TextPainter> _headers = {};

  TextPainter layout(String text, CellStyle style, {double? wrapWidth}) {
    final key = (text, style, wrapWidth);
    final cached = _cells[key];
    if (cached != null) return cached;
    if (_cells.length > _limit) _clear(_cells);
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyleOf(style)),
      textDirection: TextDirection.ltr,
      maxLines: wrapWidth == null ? 1 : null,
    )..layout(maxWidth: wrapWidth ?? double.infinity);
    return _cells[key] = painter;
  }

  TextPainter header(String text, Color color, {required bool bold}) {
    final key = (text, color, bold);
    final cached = _headers[key];
    if (cached != null) return cached;
    if (_headers.length > _limit) _clear(_headers);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return _headers[key] = painter;
  }

  static TextStyle textStyleOf(CellStyle style) => TextStyle(
    color: Color(style.textColor ?? 0xFF1F1F1F),
    fontSize: style.fontSize * 4 / 3,
    fontWeight: style.bold ? FontWeight.w700 : FontWeight.w400,
    fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
    decoration: TextDecoration.combine([
      if (style.underline) TextDecoration.underline,
      if (style.strike) TextDecoration.lineThrough,
    ]),
    height: 1.15,
  );

  void _clear(Map<Object, TextPainter> map) {
    for (final painter in map.values) {
      painter.dispose();
    }
    map.clear();
  }

  void dispose() {
    _clear(_cells);
    _clear(_headers);
  }
}
