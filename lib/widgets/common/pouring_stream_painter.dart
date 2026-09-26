import 'package:flutter/material.dart';
import 'dart:math' as math;

/// The jet of liquid between a tilted bottle's lip and the tube it fills.
///
/// Drawn as a filled ribbon rather than a stroked line so the stream narrows as
/// it gathers speed the way a real jet does, and so highlights can ride down it
/// while liquid is moving.
class PouringStreamPainter extends CustomPainter {
  PouringStreamPainter({
    required this.startPoint,
    required this.endPoint,
    required this.color,
    required this.animationProgress,
    required this.streamWidth,
    required this.bendDirection,
    this.flowPhase = 0,
  });

  final Offset? startPoint;
  final Offset? endPoint;
  final Color color;

  /// 0 to 1 as the jet reaches the surface, 1 to 2 as it breaks apart.
  final double animationProgress;

  /// 0 to 1 once per flow cycle while the pour is running.
  final double flowPhase;

  /// Width of the jet at the lip; it thins from there downward.
  final double streamWidth;

  /// Which way the bottle tips, so the jet leaves the lip in that direction.
  final double bendDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final start = startPoint, end = endPoint;
    if (start == null || end == null) return;
    if (animationProgress <= 0 || animationProgress >= 2) return;

    final fall = end.dy - start.dy;
    if (fall <= 2) return;

    // A dropped thing speeds up, so the head of the jet covers its distance on
    // an accelerating curve instead of sliding down at a constant pace.
    final head = animationProgress <= 1
        ? Curves.easeInQuad.transform(animationProgress)
        : 1.0;
    // When the pour stops the jet does not blink out: it thins from the lip
    // downward until the last of it drops into the tube.
    final tail = animationProgress <= 1
        ? 0.0
        : ((animationProgress - 1) * 0.9).clamp(0.0, 1.0);
    if (head <= tail) return;

    final jet = _Jet(
      mouth: start,
      surface: end,
      flowPhase: flowPhase,
      streamWidth: streamWidth,
      bendDirection: bendDirection,
    );

    final body = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    jet.drawRibbon(canvas, body, tail, head);
    jet.drawFlow(canvas, tail, head);

    if (head >= 0.999 && tail <= 0) {
      jet.drawImpact(canvas, end, color);
    }
    if (tail > 0) {
      jet.drawLastDrop(canvas, body, tail, animationProgress - 1);
    }
  }

  @override
  bool shouldRepaint(covariant PouringStreamPainter oldDelegate) {
    return oldDelegate.startPoint != startPoint ||
        oldDelegate.endPoint != endPoint ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.flowPhase != flowPhase ||
        oldDelegate.streamWidth != streamWidth ||
        oldDelegate.bendDirection != bendDirection ||
        oldDelegate.color != color;
  }
}

/// One pour's worth of liquid: a short fall from the lip into the tube under it,
/// with a sideways exit and a gentle sway.
class _Jet {
  _Jet({
    required this.mouth,
    required this.surface,
    required this.flowPhase,
    required this.streamWidth,
    required this.bendDirection,
  });

  final Offset mouth;
  final Offset surface;
  final double flowPhase;
  final double streamWidth;

  static const double _sway = 0.9;
  static const int _samples = 16;

  /// +1 when the bottle tips to the right: the lip points that way, so the jet
  /// leaves sideways and bends back to vertical as it falls.
  final double bendDirection;

  late final double _fall = surface.dy - mouth.dy;

  /// How far the jet travels before it is falling straight down. That is the
  /// gap between the two bottles, not the whole drop: liquid running all the
  /// way down an empty tube still leaves the lip the same short way.
  late final double _air = math.min(_fall * 0.35, streamWidth * 4.5);

  /// The point the stream is vertical again by, on its way to the surface.
  late final Offset _plumb = Offset(surface.dx, mouth.dy + _air);

  /// Sideways out of the lip, then plumb. A single curve across the whole drop
  /// would lean the entire column over instead of just its top.
  Offset _at(double t) {
    final drop = t * _fall;
    final sway = math.sin((t * 2.6 - flowPhase) * math.pi * 2) *
        _sway *
        streamWidth *
        0.12 *
        t;
    if (drop >= _air) {
      return Offset(_plumb.dx + sway, mouth.dy + drop);
    }
    final k = _air == 0 ? 1.0 : drop / _air;
    final u = 1 - k;
    final exit = mouth + Offset(bendDirection * _air * 0.6, _air * 0.15);
    final entry = _plumb - Offset(0, _air * 0.35);
    return Offset(
      u * u * u * mouth.dx +
          3 * u * u * k * exit.dx +
          3 * u * k * k * entry.dx +
          k * k * k * _plumb.dx +
          sway,
      u * u * u * mouth.dy +
          3 * u * u * k * exit.dy +
          3 * u * k * k * entry.dy +
          k * k * k * _plumb.dy,
    );
  }

  Offset _normalAt(double t) {
    final delta = _at(math.min(1.0, t + 0.02)) - _at(math.max(0.0, t - 0.02));
    final length = delta.distance;
    if (length == 0) return const Offset(1, 0);
    final normal = Offset(-delta.dy / length, delta.dx / length);
    return normal.dx > 0 ? normal : -normal;
  }

  /// Widest at the lip, thinner the further the liquid has fallen.
  double _halfWidth(double t) {
    final narrowed = streamWidth * (0.62 - 0.16 * t);
    final pinch = 1 + 0.07 * math.sin((t * 5.5 - flowPhase) * math.pi * 2);
    return narrowed * pinch;
  }

  void drawRibbon(Canvas canvas, Paint paint, double tail, double head) {
    final path = Path();
    for (int i = 0; i <= _samples; i++) {
      final t = tail + (head - tail) * (i / _samples);
      final edge = _at(t) + _normalAt(t) * _halfWidth(t);
      i == 0 ? path.moveTo(edge.dx, edge.dy) : path.lineTo(edge.dx, edge.dy);
    }
    for (int i = _samples; i >= 0; i--) {
      final t = tail + (head - tail) * (i / _samples);
      final edge = _at(t) - _normalAt(t) * _halfWidth(t);
      path.lineTo(edge.dx, edge.dy);
    }
    path.close();
    canvas.drawPath(path, paint);

    // A falling head of liquid is a blob, not a cut edge.
    canvas.drawCircle(_at(head), _halfWidth(head), paint);
    if (tail > 0) canvas.drawCircle(_at(tail), _halfWidth(tail), paint);
  }

  /// Light on the near side plus streaks that travel down, so a held pour is
  /// visibly flowing rather than a painted stick.
  void drawFlow(Canvas canvas, double tail, double head) {
    final glint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final phase = (flowPhase + i / 3) % 1;
      final from = tail + (head - tail) * phase;
      final to = tail + (head - tail) * math.min(1.0, phase + 0.13);
      if (to <= from) continue;
      glint.strokeWidth = _halfWidth(from) * 0.6;
      canvas.drawLine(_at(from), _at(to), glint);
    }

    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      _at(tail) + _normalAt(tail) * _halfWidth(tail) * 0.5,
      _at(head) + _normalAt(head) * _halfWidth(head) * 0.5,
      edge,
    );
  }

  void drawImpact(Canvas canvas, Offset surface, Color color) {
    final ripple = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
      Rect.fromCenter(
        center: surface,
        width: streamWidth * 4.2,
        height: streamWidth * 1.5,
      ),
      ripple,
    );

    final spray = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final random = math.Random(surface.dy.round());
    for (int i = 0; i < 4; i++) {
      final angle = math.pi * (0.15 + 0.7 * random.nextDouble());
      final distance = streamWidth * (1.3 + random.nextDouble() * 1.5);
      canvas.drawCircle(
        Offset(
          surface.dx + math.cos(angle) * distance,
          surface.dy - math.sin(angle) * distance,
        ),
        streamWidth * (0.15 + random.nextDouble() * 0.16),
        spray,
      );
    }
  }

  void drawLastDrop(Canvas canvas, Paint paint, double tail, double leaving) {
    final drop = Offset.lerp(_at(tail), surface, leaving)!;
    canvas.drawCircle(
      drop,
      streamWidth * (0.45 - 0.15 * leaving),
      Paint()..color = paint.color.withValues(alpha: 1 - leaving),
    );
  }
}
