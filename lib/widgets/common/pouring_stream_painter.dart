import 'package:flutter/material.dart';
import 'dart:math' as math;

class PouringStreamPainter extends CustomPainter {
  final Offset? startPoint;
  final Offset? endPoint;
  final Color color;
  final double animationProgress; // 0.0 to 1.0 (pouring), 1.0 to 2.0 (stopping)
  final bool isTiltingRight;

  PouringStreamPainter({
    required this.startPoint,
    required this.endPoint,
    required this.color,
    required this.animationProgress,
    this.isTiltingRight = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (startPoint == null || endPoint == null || animationProgress == 0)
      return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Calculate dynamic points based on animation
    Offset p1 = startPoint!;
    Offset p2 = endPoint!;

    // Realistic pouring physics using cubic bezier
    // CP1: Shoots out horizontally from the bottle mouth
    double shootOffset = isTiltingRight ? 30.0 : -30.0;
    Offset cp1 = Offset(p1.dx + shootOffset, p1.dy + 5);

    // CP2: Gravity pulls it straight down into the target tube
    Offset cp2 = Offset(p2.dx, p2.dy - 60);

    Path fullPath = Path();
    fullPath.moveTo(p1.dx, p1.dy);
    fullPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);

    // Get path metrics to animate the stream length
    var pathMetrics = fullPath.computeMetrics().toList();
    if (pathMetrics.isEmpty) return;

    var metric = pathMetrics.first;
    double totalLength = metric.length;

    double currentStart = 0;
    double currentEnd = totalLength;

    if (animationProgress <= 1.0) {
      // Pouring down
      currentEnd = totalLength * animationProgress;
    } else {
      // Stopping (tail catching up)
      currentStart = totalLength * (animationProgress - 1.0);
    }

    if (currentStart >= currentEnd) return; // Stream finished

    Path animatedPath = metric.extractPath(currentStart, currentEnd);

    // Draw main stream
    canvas.drawPath(animatedPath, paint);

    // Draw highlight
    canvas.drawPath(animatedPath, highlightPaint);

    // Draw splashes at the end point if the stream has reached it
    if (animationProgress > 0.5 && animationProgress < 1.8) {
      _drawSplashes(canvas, p2, color);
    }
  }

  void _drawSplashes(Canvas canvas, Offset center, Color color) {
    final random = math.Random(
      center.hashCode,
    ); // Use consistent random for same splash
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      double angle = random.nextDouble() * math.pi; // Top half circle
      double distance = random.nextDouble() * 15 + 5;
      double size = random.nextDouble() * 3 + 1.5;

      Offset drop = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy - math.sin(angle) * distance,
      );

      canvas.drawCircle(drop, size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PouringStreamPainter oldDelegate) {
    return oldDelegate.startPoint != startPoint ||
        oldDelegate.endPoint != endPoint ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.color != color ||
        oldDelegate.isTiltingRight != isTiltingRight;
  }
}
