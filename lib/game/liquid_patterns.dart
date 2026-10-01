import 'dart:ui';

/// The mark a layer of liquid wears in colourblind mode.
///
/// Twelve hues are not twelve hues everyone can tell apart, and no amount of
/// tuning fixes that - deuteranopia collapses red with green and orange with
/// lime on its own. A shape does. The set is ordered so the pairs a
/// colour-vision test would flag land far apart: red takes dots, green takes
/// rings, orange takes a diagonal and lime its mirror.
///
/// Which colour wears which mark is content. See `assets/content/colors.json`,
/// where a palette entry pairs an id with a hue and one of these shapes. A
/// palette can only grow as far as this set reaches, which is why the content
/// validator refuses two colours wearing the same mark.
enum LiquidPattern {
  dots,
  rings,
  horizontalStripes,
  verticalStripes,
  diagonalDown,
  diagonalUp,
  crossHatch,
  grid,
  zigzag,
  triangles,
  checker,
  plus,
}

/// Ink for a mark over [background]: light on dark liquids, dark on light ones,
/// so the shape stays readable whatever the hue is worth.
Color _inkFor(Color background) {
  final luminance =
      0.299 * background.r + 0.587 * background.g + 0.114 * background.b;
  return luminance > 0.62 ? const Color(0x99000000) : const Color(0xB8FFFFFF);
}

/// How far apart the marks sit. A layer is 51 x 36 logical pixels, so anything
/// tighter turns to mush and anything looser only draws once.
const double _step = 9;

/// Paints [pattern] across [band]. The caller clips to the liquid's own shape,
/// so a mark never escapes onto the glass.
void paintLiquidPattern(
  Canvas canvas,
  Rect band,
  LiquidPattern pattern,
  Color background,
) {
  final ink = Paint()
    ..color = _inkFor(background)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void rows(void Function(double y) draw) {
    for (var y = band.top + _step / 2; y < band.bottom; y += _step) {
      draw(y);
    }
  }

  void columns(void Function(double x) draw) {
    for (var x = band.left + _step / 2; x < band.right; x += _step) {
      draw(x);
    }
  }

  /// A mark that sits on a grid of points needs its own spacing and its own
  /// phase. A field of dots and a field of crosses laid on the same lattice are
  /// one shape to someone who cannot see the difference between their colours,
  /// which is the entire point of the setting.
  void lattice(
    double spacing,
    double phaseX,
    double phaseY,
    bool stagger,
    void Function(Offset) at,
  ) {
    var row = 0;
    for (var y = band.top + phaseY; y < band.bottom; y += spacing) {
      final shift = stagger ? (row++ % 2) * (spacing / 2) : 0.0;
      for (var x = band.left + phaseX + shift; x < band.right; x += spacing) {
        at(Offset(x, y));
      }
    }
  }

  switch (pattern) {
    case LiquidPattern.dots:
      ink.style = PaintingStyle.fill;
      lattice(8, 4, 4, true, (point) {
        canvas.drawCircle(point, 1.8, ink);
      });
    case LiquidPattern.rings:
      final centre = Offset(band.center.dx, band.center.dy);
      canvas.drawCircle(centre, 4.5, ink);
      canvas.drawCircle(centre, 10.5, ink);
    case LiquidPattern.horizontalStripes:
      rows(
        (y) =>
            canvas.drawLine(Offset(band.left, y), Offset(band.right, y), ink),
      );
    case LiquidPattern.verticalStripes:
      columns(
        (x) =>
            canvas.drawLine(Offset(x, band.top), Offset(x, band.bottom), ink),
      );
    case LiquidPattern.diagonalDown:
    case LiquidPattern.diagonalUp:
      final down = pattern == LiquidPattern.diagonalDown;
      final path = Path();
      for (var d = -band.height; d < band.width; d += _step) {
        final start = Offset(band.left + d, band.top);
        final end = Offset(band.left + d + band.height, band.bottom);
        path.moveTo(start.dx, start.dy);
        path.lineTo(
          down ? end.dx : band.left + d - band.height + band.width,
          end.dy,
        );
      }
      canvas.drawPath(path, ink);
    case LiquidPattern.crossHatch:
      final path = Path();
      for (var d = -band.height; d < band.width; d += _step) {
        path.moveTo(band.left + d, band.top);
        path.lineTo(band.left + d + band.height, band.bottom);
        path.moveTo(band.left + d + band.height, band.top);
        path.lineTo(band.left + d, band.bottom);
      }
      canvas.drawPath(path, ink);
    case LiquidPattern.grid:
      rows(
        (y) =>
            canvas.drawLine(Offset(band.left, y), Offset(band.right, y), ink),
      );
      columns(
        (x) =>
            canvas.drawLine(Offset(x, band.top), Offset(x, band.bottom), ink),
      );
    case LiquidPattern.zigzag:
      final path = Path();
      var first = true;
      for (var y = band.top + _step / 2; y < band.bottom; y += _step) {
        for (var x = band.left; x <= band.right; x += _step / 2) {
          final peak = ((x / (_step / 2)).round() % 2 == 0) ? 0.0 : 3.0;
          final point = Offset(x, y + peak);
          if (first) {
            path.moveTo(point.dx, point.dy);
            first = false;
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
      }
      canvas.drawPath(path, ink);
    case LiquidPattern.triangles:
      ink.style = PaintingStyle.fill;
      const size = 3.6;
      lattice(11, 5, 6, false, (centre) {
        canvas.drawPath(
          Path()
            ..moveTo(centre.dx, centre.dy - size)
            ..lineTo(centre.dx + size, centre.dy + size)
            ..lineTo(centre.dx - size, centre.dy + size)
            ..close(),
          ink,
        );
      });
    case LiquidPattern.checker:
      ink.style = PaintingStyle.fill;
      const size = 4.6;
      lattice(15, 8, 2, true, (centre) {
        canvas.drawRect(
          Rect.fromLTWH(centre.dx - size / 2, centre.dy - size / 2, size, size),
          ink,
        );
      });
    case LiquidPattern.plus:
      lattice(13, 10, 9, false, (centre) {
        canvas.drawLine(
          Offset(centre.dx - 2.8, centre.dy),
          Offset(centre.dx + 2.8, centre.dy),
          ink,
        );
        canvas.drawLine(
          Offset(centre.dx, centre.dy - 2.8),
          Offset(centre.dx, centre.dy + 2.8),
          ink,
        );
      });
  }
}
