import 'package:flutter/material.dart';

/// The icon's colors, from light green to dark.
const logoShades = [
  Color(0xFF7DD69A),
  Color(0xFF4FB572),
  Color(0xFF3A9C5E),
  Color(0xFF2E844F),
  Color(0xFF21603A),
];

/// Blocks of the table in the icon, as in `assets/icon`: darker downwards and
/// lighter to the right.
const _rows = 4, _columns = 2;

class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 24, this.outlined = false, super.key});

  final double size;

  /// Light outline so the icon does not vanish against the ribbon.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: const _TablePainter(),
          child: Center(
            child: Text(
              'T',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.64,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Voges Tables',
      child: outlined
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.24),
                border: Border.all(color: const Color(0xB3FFFFFF)),
              ),
              child: logo,
            )
          : logo,
    );
  }
}

Color _shade(double t) {
  final position = t.clamp(0.0, 1.0) * (logoShades.length - 1);
  final index = position.floor().clamp(0, logoShades.length - 2);
  return Color.lerp(
    logoShades[index],
    logoShades[index + 1],
    position - index,
  )!;
}

class _TablePainter extends CustomPainter {
  const _TablePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width / _columns, height = size.height / _rows;
    for (var row = 0; row < _rows; row++) {
      for (var column = 0; column < _columns; column++) {
        canvas.drawRect(
          Rect.fromLTWH(column * width, row * height, width + 1, height + 1),
          Paint()..color = _shade(0.12 + row * 0.28 - column * 0.08),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TablePainter oldDelegate) => false;
}
