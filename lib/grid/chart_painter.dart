import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';
import '../sheet/chart.dart';
import '../workbook/workbook_controller.dart';

/// Office colors, in the order Excel gives them to series.
const chartColors = [
  Color(0xFF4472C4),
  Color(0xFFED7D31),
  Color(0xFFA5A5A5),
  Color(0xFFFFC000),
  Color(0xFF5B9BD5),
  Color(0xFF70AD47),
  Color(0xFF264478),
  Color(0xFF9E480E),
  Color(0xFF636363),
  Color(0xFF997300),
];

/// Most points a series draws; Excel itself stops at 32 000.
const maxChartPoints = 32000;

class ChartLine {
  const ChartLine(this.name, this.values);

  final String name;
  final List<double?> values;
}

/// What a chart shows, read from the cells once per change of the workbook.
class ChartSnapshot {
  ChartSnapshot({
    required this.kind,
    required this.title,
    required this.categories,
    required this.xValues,
    required this.series,
    required this.showLegend,
  });

  factory ChartSnapshot.of(WorkbookController controller, SheetChart chart) {
    List<CellAddress> cellsOf(CellRange range) {
      final cells = <CellAddress>[];
      for (var r = range.first.row; r <= range.last.row; r++) {
        for (var c = range.first.column; c <= range.last.column; c++) {
          if (cells.length == maxChartPoints) return cells;
          cells.add(CellAddress(c, r));
        }
      }
      return cells;
    }

    final series = <ChartLine>[];
    for (var i = 0; i < chart.series.length; i++) {
      final s = chart.series[i];
      final name = s.name == null
          ? s.title ?? 'Series ${i + 1}'
          : controller.chartText(s.name!, s.name!.range.first);
      series.add(
        ChartLine(name, [
          for (final cell in cellsOf(s.values.range))
            switch (controller.chartValue(s.values, cell)) {
              NumberValue(:final value) => value,
              _ => null,
            },
        ]),
      );
    }
    final categories = chart.categories;
    final labels = categories == null
        ? const <String>[]
        : [
            for (final cell in cellsOf(categories.range))
              controller.chartText(categories, cell),
          ];
    final xValues = categories == null
        ? null
        : [
            for (final cell in cellsOf(categories.range))
              switch (controller.chartValue(categories, cell)) {
                NumberValue(:final value) => value,
                _ => null,
              },
          ];
    return ChartSnapshot(
      kind: chart.kind,
      title:
          chart.title ??
          (series.length == 1 && chart.series.single.name != null
              ? series.single.name
              : null),
      categories: labels,
      xValues: xValues,
      series: series,
      showLegend: chart.showLegend,
    );
  }

  final ChartKind kind;
  final String? title;
  final List<String> categories;

  /// The categories as numbers, for scatter charts.
  final List<double?>? xValues;
  final List<ChartLine> series;
  final bool showLegend;

  int get pointCount => series.fold(0, (n, s) => math.max(n, s.values.length));

  String categoryAt(int index) =>
      index < categories.length ? categories[index] : '${index + 1}';
}

/// Paints a chart the way Excel's default style looks: title on top, legend
/// at the bottom, light grid lines and the Office palette.
class ChartPainter extends CustomPainter {
  ChartPainter(this.snapshot, {required this.emptyText, this.zoom = 1});

  final ChartSnapshot snapshot;
  final String emptyText;
  final double zoom;

  static const _ink = Color(0xFF595959);
  static const _grid = Color(0xFFD9D9D9);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(zoom);
    final frame = Offset.zero & size / zoom;
    canvas.drawRect(frame, Paint()..color = Colors.white);
    var area = frame.deflate(10);
    if (snapshot.title case final title? when title.isNotEmpty) {
      final painter = _text(title, 15, bold: false, maxWidth: area.width);
      painter.paint(
        canvas,
        Offset(area.center.dx - painter.width / 2, area.top),
      );
      area = Rect.fromLTRB(
        area.left,
        area.top + painter.height + 8,
        area.right,
        area.bottom,
      );
    }
    final pie = snapshot.kind == ChartKind.pie;
    final legendNames = pie
        ? [for (var i = 0; i < snapshot.pointCount; i++) snapshot.categoryAt(i)]
        : [for (final s in snapshot.series) s.name];
    if (snapshot.showLegend && legendNames.isNotEmpty) {
      area = _legend(canvas, area, legendNames);
    }
    if (area.width < 20 || area.height < 20) return;
    if (snapshot.pointCount == 0) {
      final painter = _text(emptyText, 12, maxWidth: area.width);
      painter.paint(canvas, area.center - painter.size.center(Offset.zero));
      return;
    }
    switch (snapshot.kind) {
      case ChartKind.pie:
        _pie(canvas, area);
      case ChartKind.scatter:
        _scatter(canvas, area);
      case ChartKind.bar:
        _bars(canvas, area);
      case ChartKind.column || ChartKind.line || ChartKind.area:
        _vertical(canvas, area);
    }
  }

  Rect _legend(Canvas canvas, Rect area, List<String> names) {
    const box = 9.0, gap = 6.0, spacing = 14.0;
    final painters = [
      for (final name in names.take(50))
        _text(name, 11, maxWidth: area.width - box - gap),
    ];
    final rows = <List<int>>[[]];
    var width = 0.0;
    for (var i = 0; i < painters.length; i++) {
      final item = box + gap + painters[i].width + spacing;
      if (width + item > area.width && rows.last.isNotEmpty) {
        rows.add([]);
        width = 0;
      }
      rows.last.add(i);
      width += item;
    }
    const lineHeight = 16.0;
    final visibleRows = rows.take(3).toList();
    var y = area.bottom - visibleRows.length * lineHeight;
    for (final row in visibleRows) {
      final total = row.fold(
        0.0,
        (sum, i) => sum + box + gap + painters[i].width + spacing,
      );
      var x = area.center.dx - (total - spacing) / 2;
      for (final i in row) {
        canvas.drawRect(
          Rect.fromLTWH(x, y + (lineHeight - box) / 2, box, box),
          Paint()..color = chartColors[i % chartColors.length],
        );
        x += box + gap;
        painters[i].paint(
          canvas,
          Offset(x, y + (lineHeight - painters[i].height) / 2),
        );
        x += painters[i].width + spacing;
      }
      y += lineHeight;
    }
    return Rect.fromLTRB(
      area.left,
      area.top,
      area.right,
      area.bottom - visibleRows.length * lineHeight - 6,
    );
  }

  /// Column, line and area charts: categories along the bottom.
  void _vertical(Canvas canvas, Rect area) {
    final (low, high, step) = _scale(_allValues(), zero: true);
    final plot = _valueAxis(canvas, area, low, high, step, vertical: true);
    final count = snapshot.pointCount;
    final band = plot.width / count;
    _categoryLabels(canvas, plot, count, band);
    final kind = snapshot.kind;
    double y(double value) =>
        plot.bottom - (value - low) / (high - low) * plot.height;
    final zeroY = y(low <= 0 && high >= 0 ? 0 : low);
    final seriesCount = snapshot.series.length;
    for (var s = 0; s < seriesCount; s++) {
      final values = snapshot.series[s].values;
      final color = chartColors[s % chartColors.length];
      if (kind == ChartKind.column) {
        final groupWidth = band * 0.7;
        final barWidth = groupWidth / seriesCount;
        final paint = Paint()..color = color;
        for (var i = 0; i < values.length; i++) {
          final value = values[i];
          if (value == null) continue;
          final x = plot.left + i * band + (band - groupWidth) / 2;
          canvas.drawRect(
            Rect.fromLTRB(
              x + s * barWidth,
              math.min(y(value), zeroY),
              x + (s + 1) * barWidth - (barWidth > 4 ? 1 : 0),
              math.max(y(value), zeroY),
            ),
            paint,
          );
        }
        continue;
      }
      final path = Path();
      var open = false;
      Offset? first, last;
      for (var i = 0; i < values.length; i++) {
        final value = values[i];
        if (value == null) {
          open = false;
          continue;
        }
        final point = Offset(plot.left + (i + 0.5) * band, y(value));
        if (open) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          open = true;
        }
        first ??= point;
        last = point;
      }
      if (kind == ChartKind.area && first != null && last != null) {
        final fill = Path.from(path)
          ..lineTo(last.dx, zeroY)
          ..lineTo(first.dx, zeroY)
          ..close();
        canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.55));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.25
          ..strokeJoin = StrokeJoin.round,
      );
      if (kind == ChartKind.line && band >= 8) {
        final dot = Paint()..color = color;
        for (var i = 0; i < values.length; i++) {
          final value = values[i];
          if (value == null) continue;
          canvas.drawCircle(
            Offset(plot.left + (i + 0.5) * band, y(value)),
            3,
            dot,
          );
        }
      }
    }
  }

  /// Horizontal bars, with the first category at the bottom as in Excel.
  void _bars(Canvas canvas, Rect area) {
    final (low, high, step) = _scale(_allValues(), zero: true);
    final count = snapshot.pointCount;
    final labelWidth = math.min(area.width * 0.3, _widestLabel(count) + 6);
    final plot = _valueAxis(
      canvas,
      Rect.fromLTRB(area.left + labelWidth, area.top, area.right, area.bottom),
      low,
      high,
      step,
      vertical: false,
    );
    final band = plot.height / count;
    double x(double value) =>
        plot.left + (value - low) / (high - low) * plot.width;
    final zeroX = x(low <= 0 && high >= 0 ? 0 : low);
    if (band >= 10) {
      for (var i = 0; i < count; i++) {
        final painter = _text(snapshot.categoryAt(i), 11, maxWidth: labelWidth);
        final center = plot.bottom - (i + 0.5) * band;
        painter.paint(
          canvas,
          Offset(plot.left - 6 - painter.width, center - painter.height / 2),
        );
      }
    }
    final seriesCount = snapshot.series.length;
    final groupHeight = band * 0.7;
    final barHeight = groupHeight / seriesCount;
    for (var s = 0; s < seriesCount; s++) {
      final paint = Paint()..color = chartColors[s % chartColors.length];
      final values = snapshot.series[s].values;
      for (var i = 0; i < values.length; i++) {
        final value = values[i];
        if (value == null) continue;
        final bottom = plot.bottom - i * band - (band - groupHeight) / 2;
        canvas.drawRect(
          Rect.fromLTRB(
            math.min(x(value), zeroX),
            bottom - (s + 1) * barHeight,
            math.max(x(value), zeroX),
            bottom - s * barHeight,
          ),
          paint,
        );
      }
    }
  }

  void _scatter(Canvas canvas, Rect area) {
    final xs = snapshot.xValues;
    final count = snapshot.pointCount;
    double xAt(int i) {
      final value = xs != null && i < xs.length ? xs[i] : null;
      return value ?? (i + 1).toDouble();
    }

    final (yLow, yHigh, yStep) = _scale(_allValues(), zero: false);
    final (xLow, xHigh, xStep) = _scale([
      for (var i = 0; i < count; i++) xAt(i),
    ], zero: false);
    final plot = _valueAxis(canvas, area, yLow, yHigh, yStep, vertical: true);
    _numberLabels(canvas, plot, xLow, xHigh, xStep);
    for (var s = 0; s < snapshot.series.length; s++) {
      final paint = Paint()..color = chartColors[s % chartColors.length];
      final values = snapshot.series[s].values;
      for (var i = 0; i < values.length; i++) {
        final value = values[i];
        if (value == null) continue;
        canvas.drawCircle(
          Offset(
            plot.left + (xAt(i) - xLow) / (xHigh - xLow) * plot.width,
            plot.bottom - (value - yLow) / (yHigh - yLow) * plot.height,
          ),
          3.5,
          paint,
        );
      }
    }
  }

  void _pie(Canvas canvas, Rect area) {
    final values = snapshot.series.first.values;
    final total = values.fold(
      0.0,
      (sum, v) => v != null && v > 0 ? sum + v : sum,
    );
    if (total <= 0) return;
    final radius = math.min(area.width, area.height) / 2 - 4;
    final center = area.center;
    final circle = Rect.fromCircle(center: center, radius: radius);
    var angle = -math.pi / 2;
    final edge = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null || value <= 0) continue;
      final sweep = value / total * 2 * math.pi;
      final paint = Paint()..color = chartColors[i % chartColors.length];
      canvas.drawArc(circle, angle, sweep, true, paint);
      canvas.drawArc(circle, angle, sweep, true, edge);
      if (sweep > 0.25) {
        final label = _text(
          '${(value / total * 100).round()}%',
          11,
          color: Colors.white,
        );
        final middle = angle + sweep / 2;
        final at =
            center + Offset(math.cos(middle), math.sin(middle)) * radius * 0.65;
        label.paint(canvas, at - label.size.center(Offset.zero));
      }
      angle += sweep;
    }
  }

  List<double> _allValues() => [
    for (final s in snapshot.series)
      for (final v in s.values) ?v,
  ];

  /// Round numbers for the value axis, as Excel picks them.
  static (double, double, double) _scale(
    List<double> values, {
    required bool zero,
  }) {
    if (values.isEmpty) return (0, 1, 0.2);
    var low = values.reduce(math.min), high = values.reduce(math.max);
    if (zero) {
      low = math.min(low, 0);
      high = math.max(high, 0);
    }
    if (low == high) {
      high = low + 1;
      if (!zero) low -= 1;
    }
    final rough = (high - low) / 5;
    final magnitude = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final step = [1.0, 2.0, 2.5, 5.0, 10.0]
        .map((m) => m * magnitude)
        .firstWhere((s) => s >= rough, orElse: () => 10 * magnitude);
    return ((low / step).floor() * step, (high / step).ceil() * step, step);
  }

  /// Draws the value axis with its grid lines and gives back the plot area.
  Rect _valueAxis(
    Canvas canvas,
    Rect area,
    double low,
    double high,
    double step, {
    required bool vertical,
  }) {
    final labels = <(double, TextPainter)>[];
    for (var v = low; v <= high + step / 2; v += step) {
      labels.add((v, _text(_number(v, step), 11)));
    }
    final widest = labels.fold(0.0, (w, l) => math.max(w, l.$2.width));
    final plot = vertical
        ? Rect.fromLTRB(
            area.left + widest + 6,
            area.top + 4,
            area.right - 4,
            area.bottom - 18,
          )
        : Rect.fromLTRB(
            area.left,
            area.top + 4,
            area.right - 8,
            area.bottom - 18,
          );
    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (final (value, painter) in labels) {
      final t = (value - low) / (high - low);
      if (vertical) {
        final y = plot.bottom - t * plot.height;
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
        painter.paint(
          canvas,
          Offset(plot.left - 6 - painter.width, y - painter.height / 2),
        );
      } else {
        final x = plot.left + t * plot.width;
        canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
        painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 4));
      }
    }
    return plot;
  }

  void _categoryLabels(Canvas canvas, Rect plot, int count, double band) {
    final every = math.max(1, (40 / band).ceil());
    for (var i = 0; i < count; i += every) {
      final painter = _text(
        snapshot.categoryAt(i),
        11,
        maxWidth: band * every - 2,
      );
      painter.paint(
        canvas,
        Offset(
          plot.left + (i + 0.5) * band - painter.width / 2,
          plot.bottom + 4,
        ),
      );
    }
  }

  void _numberLabels(
    Canvas canvas,
    Rect plot,
    double low,
    double high,
    double step,
  ) {
    for (var v = low; v <= high + step / 2; v += step) {
      final painter = _text(_number(v, step), 11);
      final x = plot.left + (v - low) / (high - low) * plot.width;
      painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 4));
    }
  }

  double _widestLabel(int count) {
    var widest = 0.0;
    for (var i = 0; i < math.min(count, 200); i++) {
      widest = math.max(widest, _text(snapshot.categoryAt(i), 11).width);
    }
    return widest;
  }

  static String _number(double value, double step) {
    final decimals = step >= 1 ? 0 : (-math.log(step) / math.ln10).ceil();
    final text = value.toStringAsFixed(decimals.clamp(0, 6));
    return text == '-0' ? '0' : text;
  }

  static TextPainter _text(
    String text,
    double size, {
    bool bold = false,
    double maxWidth = double.infinity,
    Color color = _ink,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: math.max(0, maxWidth));

  @override
  bool shouldRepaint(ChartPainter oldDelegate) =>
      !identical(oldDelegate.snapshot, snapshot) ||
      oldDelegate.emptyText != emptyText ||
      oldDelegate.zoom != zoom;
}
