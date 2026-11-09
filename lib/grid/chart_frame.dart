import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'chart_painter.dart';

enum _Handle {
  move,
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

/// A chart over the cells: a click selects it, dragging moves it and the
/// handles of a selected chart resize it. The frame is in screen pixels;
/// [onChanged] gets the new one when the mouse is released.
class ChartFrame extends StatefulWidget {
  const ChartFrame({
    required this.rect,
    required this.snapshot,
    required this.selected,
    required this.zoom,
    required this.emptyText,
    required this.onSelect,
    required this.onChanged,
    super.key,
  });

  final Rect rect;
  final ChartSnapshot snapshot;
  final bool selected;
  final double zoom;
  final String emptyText;
  final VoidCallback onSelect;
  final ValueChanged<Rect> onChanged;

  @override
  State<ChartFrame> createState() => _ChartFrameState();
}

class _ChartFrameState extends State<ChartFrame> {
  static const _handleSize = 8.0;
  static const _minSize = 40.0;
  static const _accent = Color(0xFF1D6B3E);

  Rect? _dragging;
  _Handle? _handle;

  Rect get _rect => _dragging ?? widget.rect;

  void _start(_Handle handle) {
    widget.onSelect();
    _handle = handle;
    _dragging = widget.rect;
  }

  void _update(Offset delta) {
    final rect = _dragging;
    final handle = _handle;
    if (rect == null || handle == null) return;
    var left = rect.left, top = rect.top, right = rect.right;
    var bottom = rect.bottom;
    switch (handle) {
      case _Handle.move:
        left += delta.dx;
        right += delta.dx;
        top += delta.dy;
        bottom += delta.dy;
      case _Handle.topLeft:
        left += delta.dx;
        top += delta.dy;
      case _Handle.top:
        top += delta.dy;
      case _Handle.topRight:
        right += delta.dx;
        top += delta.dy;
      case _Handle.right:
        right += delta.dx;
      case _Handle.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
      case _Handle.bottom:
        bottom += delta.dy;
      case _Handle.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
      case _Handle.left:
        left += delta.dx;
    }
    final minSize = _minSize * widget.zoom;
    if (right - left < minSize) {
      if (handle == _Handle.left ||
          handle == _Handle.topLeft ||
          handle == _Handle.bottomLeft) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }
    if (bottom - top < minSize) {
      if (handle == _Handle.top ||
          handle == _Handle.topLeft ||
          handle == _Handle.topRight) {
        top = bottom - minSize;
      } else {
        bottom = top + minSize;
      }
    }
    setState(() => _dragging = Rect.fromLTRB(left, top, right, bottom));
  }

  void _end() {
    final rect = _dragging;
    _dragging = null;
    _handle = null;
    if (rect != null && rect != widget.rect) widget.onChanged(rect);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    final chart = GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onTapDown: (_) => widget.onSelect(),
      onPanStart: (_) => _start(_Handle.move),
      onPanUpdate: (details) => _update(details.delta),
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: RepaintBoundary(
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.selected ? _accent : const Color(0xFFBFBFBF),
                width: widget.selected ? 1.5 : 1,
              ),
            ),
            child: CustomPaint(
              painter: ChartPainter(
                widget.snapshot,
                emptyText: widget.emptyText,
                zoom: widget.zoom,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
    if (!widget.selected) {
      return Positioned.fromRect(rect: rect, child: chart);
    }
    const half = _handleSize / 2;
    Widget handle(_Handle kind, Alignment at, MouseCursor cursor) {
      return Positioned(
        left: (at.x + 1) / 2 * rect.width,
        top: (at.y + 1) / 2 * rect.height,
        width: _handleSize,
        height: _handleSize,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: (_) => _start(kind),
            onPanUpdate: (details) => _update(details.delta),
            onPanEnd: (_) => _end(),
            onPanCancel: _end,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _accent, width: 1.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: rect.left - half,
      top: rect.top - half,
      width: math.max(0, rect.width) + _handleSize,
      height: math.max(0, rect.height) + _handleSize,
      child: Stack(
        children: [
          Positioned(
            left: half,
            top: half,
            width: rect.width,
            height: rect.height,
            child: chart,
          ),
          handle(
            _Handle.topLeft,
            Alignment.topLeft,
            SystemMouseCursors.resizeUpLeftDownRight,
          ),
          handle(
            _Handle.top,
            Alignment.topCenter,
            SystemMouseCursors.resizeUpDown,
          ),
          handle(
            _Handle.topRight,
            Alignment.topRight,
            SystemMouseCursors.resizeUpRightDownLeft,
          ),
          handle(
            _Handle.right,
            Alignment.centerRight,
            SystemMouseCursors.resizeLeftRight,
          ),
          handle(
            _Handle.bottomRight,
            Alignment.bottomRight,
            SystemMouseCursors.resizeUpLeftDownRight,
          ),
          handle(
            _Handle.bottom,
            Alignment.bottomCenter,
            SystemMouseCursors.resizeUpDown,
          ),
          handle(
            _Handle.bottomLeft,
            Alignment.bottomLeft,
            SystemMouseCursors.resizeUpRightDownLeft,
          ),
          handle(
            _Handle.left,
            Alignment.centerLeft,
            SystemMouseCursors.resizeLeftRight,
          ),
        ],
      ),
    );
  }
}
