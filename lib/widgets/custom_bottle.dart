import 'package:flutter/material.dart';

enum BottleType { tube, flask, potion, beaker }

class CustomBottleWidget extends StatelessWidget {
  final BottleType type;
  final Color liquidColor;
  final double fillLevel;
  final bool isGlowing;
  final double width;
  final double height;

  const CustomBottleWidget({
    super.key,
    required this.type,
    required this.liquidColor,
    this.fillLevel = 0.6,
    this.isGlowing = false,
    this.width = 60,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: BottlePainter(
          type: type,
          liquidColor: liquidColor,
          fillLevel: fillLevel,
          isGlowing: isGlowing,
        ),
      ),
    );
  }
}

class BottlePainter extends CustomPainter {
  final BottleType type;
  final Color liquidColor;
  final double fillLevel;
  final bool isGlowing;

  BottlePainter({
    required this.type,
    required this.liquidColor,
    required this.fillLevel,
    required this.isGlowing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Path bottlePath = _getBottlePath(size);
    
    // Draw Glow
    if (isGlowing) {
      final glowPaint = Paint()
        ..color = liquidColor.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
        ..style = PaintingStyle.fill;
      canvas.drawPath(bottlePath, glowPaint);
    }

    // Draw Back Glass
    final backGlassPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bottlePath, backGlassPaint);

    // Draw Liquid
    canvas.save();
    canvas.clipPath(bottlePath);
    
    final liquidHeight = size.height * (1.0 - fillLevel);
    final liquidRect = Rect.fromLTRB(0, liquidHeight, size.width, size.height);
    
    final liquidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          liquidColor.withValues(alpha: 0.8),
          liquidColor,
        ],
      ).createShader(liquidRect)
      ..style = PaintingStyle.fill;
      
    // Create liquid surface wave
    final liquidPath = Path();
    liquidPath.moveTo(0, liquidHeight);
    liquidPath.quadraticBezierTo(size.width / 4, liquidHeight - 4, size.width / 2, liquidHeight);
    liquidPath.quadraticBezierTo(size.width * 3 / 4, liquidHeight + 4, size.width, liquidHeight);
    liquidPath.lineTo(size.width, size.height);
    liquidPath.lineTo(0, size.height);
    liquidPath.close();

    canvas.drawPath(liquidPath, liquidPaint);
    
    // Liquid Top Highlight
    final topHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    final topHighlightPath = Path();
    topHighlightPath.moveTo(0, liquidHeight);
    topHighlightPath.quadraticBezierTo(size.width / 4, liquidHeight - 4, size.width / 2, liquidHeight);
    topHighlightPath.quadraticBezierTo(size.width * 3 / 4, liquidHeight + 4, size.width, liquidHeight);
    topHighlightPath.lineTo(size.width, liquidHeight + 3);
    topHighlightPath.quadraticBezierTo(size.width / 2, liquidHeight + 2, 0, liquidHeight + 3);
    topHighlightPath.close();
    
    canvas.drawPath(topHighlightPath, topHighlightPaint);
    
    canvas.restore();

    // Draw Front Glass Highlight (Left side curve)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final highlightPath = _getHighlightPath(size);
    canvas.drawPath(highlightPath, highlightPaint);

    // Draw Glass Border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(bottlePath, borderPaint);
    
    // Draw Cork / Rim
    final rimPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.fill;
      
    Rect rimRect;
    if (type == BottleType.tube || type == BottleType.beaker) {
       rimRect = Rect.fromLTRB(size.width * 0.1, -2, size.width * 0.9, 2);
    } else {
       rimRect = Rect.fromLTRB(size.width * 0.35, -2, size.width * 0.65, 2);
    }
    
    canvas.drawRRect(RRect.fromRectAndRadius(rimRect, const Radius.circular(2)), rimPaint);
  }

  Path _getBottlePath(Size size) {
    Path path = Path();
    final w = size.width;
    final h = size.height;

    switch (type) {
      case BottleType.tube:
        path.moveTo(w * 0.2, 0);
        path.lineTo(w * 0.2, h - w * 0.3);
        path.arcToPoint(
          Offset(w * 0.8, h - w * 0.3),
          radius: Radius.circular(w * 0.3),
          clockwise: false,
        );
        path.lineTo(w * 0.8, 0);
        break;
      case BottleType.flask:
        path.moveTo(w * 0.4, 0);
        path.lineTo(w * 0.4, h * 0.3);
        path.lineTo(w * 0.1, h * 0.9);
        path.quadraticBezierTo(w * 0.0, h, w * 0.2, h);
        path.lineTo(w * 0.8, h);
        path.quadraticBezierTo(w * 1.0, h, w * 0.9, h * 0.9);
        path.lineTo(w * 0.6, h * 0.3);
        path.lineTo(w * 0.6, 0);
        break;
      case BottleType.potion:
        path.moveTo(w * 0.4, 0);
        path.lineTo(w * 0.4, h * 0.4);
        path.quadraticBezierTo(0, h * 0.4, 0, h * 0.75);
        path.quadraticBezierTo(0, h, w * 0.5, h);
        path.quadraticBezierTo(w, h, w, h * 0.75);
        path.quadraticBezierTo(w, h * 0.4, w * 0.6, h * 0.4);
        path.lineTo(w * 0.6, 0);
        break;
      case BottleType.beaker:
        path.moveTo(w * 0.15, 0);
        path.lineTo(w * 0.15, h * 0.9);
        path.quadraticBezierTo(w * 0.15, h, w * 0.25, h);
        path.lineTo(w * 0.75, h);
        path.quadraticBezierTo(w * 0.85, h, w * 0.85, h * 0.9);
        path.lineTo(w * 0.85, 0);
        break;
    }
    path.close();
    return path;
  }

  Path _getHighlightPath(Size size) {
    Path path = Path();
    final w = size.width;
    final h = size.height;

    switch (type) {
      case BottleType.tube:
        path.moveTo(w * 0.3, h * 0.1);
        path.lineTo(w * 0.3, h * 0.7);
        break;
      case BottleType.flask:
        path.moveTo(w * 0.45, h * 0.1);
        path.lineTo(w * 0.45, h * 0.25);
        path.moveTo(w * 0.25, h * 0.5);
        path.lineTo(w * 0.15, h * 0.8);
        break;
      case BottleType.potion:
        path.moveTo(w * 0.45, h * 0.1);
        path.lineTo(w * 0.45, h * 0.35);
        path.moveTo(w * 0.15, h * 0.65);
        path.quadraticBezierTo(w * 0.15, h * 0.85, w * 0.3, h * 0.9);
        break;
      case BottleType.beaker:
        path.moveTo(w * 0.25, h * 0.1);
        path.lineTo(w * 0.25, h * 0.8);
        break;
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant BottlePainter oldDelegate) {
    return oldDelegate.type != type || 
           oldDelegate.liquidColor != liquidColor || 
           oldDelegate.fillLevel != fillLevel ||
           oldDelegate.isGlowing != isGlowing;
  }
}
