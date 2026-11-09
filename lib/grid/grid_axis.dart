/// Positions along one direction of the grid (columns or rows), where most
/// sizes are the default and a few were changed.
class GridAxis {
  GridAxis({
    required this.defaultSize,
    required Map<int, double> sizes,
    required this.count,
    this.frozen = 0,
  }) : _keys = (sizes.keys.where((i) => i < count).toList()..sort()) {
    _sizes = [for (final key in _keys) sizes[key]!];
    _deltas = List<double>.filled(_keys.length + 1, 0);
    for (var i = 0; i < _keys.length; i++) {
      _deltas[i + 1] = _deltas[i] + _sizes[i] - defaultSize;
    }
  }

  final double defaultSize;
  final int count;
  final int frozen;
  final List<int> _keys;
  late final List<double> _sizes;
  late final List<double> _deltas;

  double sizeOf(int index) {
    final at = _search(index);
    return at < _keys.length && _keys[at] == index ? _sizes[at] : defaultSize;
  }

  /// First position of [index], counting from the start of the sheet.
  double start(int index) => index * defaultSize + _deltas[_search(index)];

  double end(int index) => start(index) + sizeOf(index);

  double get total => start(count);

  double get frozenExtent => start(frozen);

  /// The index at [position] from the start of the sheet.
  int indexAt(double position) {
    if (position <= 0) return 0;
    var low = 0, high = count - 1;
    while (low < high) {
      final middle = (low + high + 1) >> 1;
      if (start(middle) <= position) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  /// Number of changed sizes before [index].
  int _search(int index) {
    var low = 0, high = _keys.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_keys[middle] < index) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }
}

/// Where the axis is on screen: frozen indexes stay put and the rest moves
/// with [scroll]. [headerSize] is the room of the headers before the cells.
class AxisView {
  AxisView(
    this.axis, {
    required this.scroll,
    required this.headerSize,
    required this.extent,
  });

  final GridAxis axis;
  final double scroll;
  final double headerSize;

  /// Length of the visible area, headers included.
  final double extent;

  double get _scrolledOrigin => headerSize + axis.frozenExtent;

  /// Screen position of the start of [index].
  double screenStart(int index) => index < axis.frozen
      ? headerSize + axis.start(index)
      : _scrolledOrigin + axis.start(index) - axis.frozenExtent - scroll;

  double screenEnd(int index) => screenStart(index) + axis.sizeOf(index);

  /// The index under a screen position, or null over the header.
  int? indexAtScreen(double position) {
    if (position < headerSize) return null;
    if (position < _scrolledOrigin) return axis.indexAt(position - headerSize);
    return axis.indexAt(
      position - _scrolledOrigin + axis.frozenExtent + scroll,
    );
  }

  /// First index that shows in the scrolling part.
  int get firstScrolled => axis.indexAt(axis.frozenExtent + scroll);

  /// The indexes to paint, frozen ones first.
  Iterable<int> get visible sync* {
    for (var i = 0; i < axis.frozen && i < axis.count; i++) {
      yield i;
    }
    for (var i = firstScrolled; i < axis.count; i++) {
      if (screenStart(i) > extent) break;
      yield i;
    }
  }

  /// The furthest the scrolling part can move: the end of the used area plus
  /// a screen, so there is always room to keep going.
  double maxScroll(int usedCount) {
    final usedEnd = axis.start(usedCount) - axis.frozenExtent;
    final room = extent - _scrolledOrigin;
    final limit = axis.total - axis.frozenExtent - room;
    final wanted = usedEnd + room;
    return (wanted < limit ? wanted : limit).clamp(0.0, double.infinity);
  }
}
