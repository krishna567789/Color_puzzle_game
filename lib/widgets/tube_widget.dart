import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/tube_model.dart';

class TubeWidget extends StatefulWidget {
  final Tube tube;
  final bool isSelected;
  final bool isShaking;
  final bool isReceiving; // New: To trigger zigzag splash
  final double tiltAngle; // New: For pouring tilt
  final Offset offset;    // New: For moving towards target
  final VoidCallback onTap;

  const TubeWidget({
    super.key,
    required this.tube,
    required this.isSelected,
    required this.isShaking,
    this.isReceiving = false,
    this.tiltAngle = 0.0,
    this.offset = Offset.zero,
    required this.onTap,
  });

  @override
  State<TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<TubeWidget> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _splashController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _splashController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant TubeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShaking && !oldWidget.isShaking) {
      _shakeController.forward(from: 0.0);
    }
    if (widget.isReceiving && !oldWidget.isReceiving) {
      _splashController.repeat();
    } else if (!widget.isReceiving && oldWidget.isReceiving) {
      _splashController.stop();
      _splashController.reset();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_shakeController, _splashController]),
        builder: (context, child) {
          double xOffset = widget.isShaking ? _shakeAnimation.value : 0;
          double yOffset = widget.isSelected ? -40.0 : 0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()
              ..translate(xOffset + widget.offset.dx, yOffset + widget.offset.dy)
              ..rotateZ(widget.tiltAngle),
            transformAlignment: Alignment.topCenter,
            child: child,
          );
        },
        child: SizedBox(
          width: 70,
          height: 200,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Glass Bottle Body
              CustomPaint(
                size: const Size(60, 190),
                painter: BottlePainter(isSelected: widget.isSelected),
              ),
              
              // Liquid Inside
              Positioned(
                bottom: 5,
                child: ClipPath(
                  clipper: BottleClipper(),
                  child: Container(
                    width: 54,
                    height: 180,
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.tube.colors.length < widget.tube.capacity)
                          Expanded(
                            flex: widget.tube.capacity - widget.tube.colors.length,
                            child: Container(color: Colors.transparent),
                          ),
                        for (int i = widget.tube.colors.length - 1; i >= 0; i--)
                          Expanded(
                            flex: 1,
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 0.2),
                              decoration: BoxDecoration(
                                color: widget.tube.colors[i],
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    widget.tube.colors[i],
                                    Color.lerp(widget.tube.colors[i], Colors.white, 0.2)!,
                                    widget.tube.colors[i],
                                    Color.lerp(widget.tube.colors[i], Colors.black, 0.1)!,
                                  ],
                                  stops: const [0.0, 0.3, 0.6, 1.0],
                                ),
                              ),
                                child: Stack(
                                  children: [
                                    if (i == widget.tube.colors.length - 1)
                                      CustomPaint(
                                        painter: LiquidSurfacePainter(
                                          color: widget.tube.colors[i],
                                          splashValue: widget.isReceiving ? _splashController.value : 0.0,
                                        ),
                                        size: Size.infinite,
                                      ),
                                    // Bubbles
                                    CustomPaint(
                                      painter: BubblePainter(animationValue: _splashController.value),
                                      size: Size.infinite,
                                    ),
                                  ],
                                ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottle Glints/Highlights
              IgnorePointer(
                child: CustomPaint(
                  size: const Size(60, 190),
                  painter: BottleHighlightPainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BottlePainter extends CustomPainter {
  final bool isSelected;
  BottlePainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = _getBottlePath(size);

    // Subtle glow if selected
    if (isSelected) {
      canvas.drawShadow(path, Colors.white.withOpacity(0.5), 10, true);
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
    
    // Bottle Neck Detail
    final neckRimPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.4, 8),
        const Radius.circular(4),
      ),
      neckRimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BottleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return _getBottlePath(size);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Path _getBottlePath(Size size) {
  final path = Path();
  double w = size.width;
  double h = size.height;
  double neckWidth = w * 0.35;
  double bodyWidth = w * 0.9;
  double neckHeight = h * 0.15;

  // Start from top-left of neck
  path.moveTo((w - neckWidth) / 2, 5);
  // Neck right
  path.lineTo((w + neckWidth) / 2, 5);
  path.lineTo((w + neckWidth) / 2, neckHeight);
  
  // Shoulder right
  path.quadraticBezierTo(w, neckHeight + 10, w, neckHeight + 30);
  
  // Body right
  path.lineTo(w, h - 25);
  // Bottom right
  path.quadraticBezierTo(w, h, w - 25, h);
  
  // Bottom left
  path.lineTo(25, h);
  path.quadraticBezierTo(0, h, 0, h - 25);
  
  // Body left
  path.lineTo(0, neckHeight + 30);
  // Shoulder left
  path.quadraticBezierTo(0, neckHeight + 10, (w - neckWidth) / 2, neckHeight);
  
  path.close();
  return path;
}

class BottleHighlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Side vertical glint
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, size.height * 0.3, 4, size.height * 0.5),
        const Radius.circular(2),
      ),
      paint,
    );

    // Top shoulder glint
    final shoulderGlint = Path()
      ..moveTo(size.width * 0.2, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.15, size.width * 0.6, size.height * 0.2)
      ..lineTo(size.width * 0.6, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.17, size.width * 0.2, size.height * 0.22)
      ..close();
    
    canvas.drawPath(shoulderGlint, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BubblePainter extends CustomPainter {
  final double animationValue;
  BubblePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final math.Random random = math.Random(42); // Fixed seed for consistent bubbles
    for (int i = 0; i < 3; i++) {
      double x = size.width * (0.2 + random.nextDouble() * 0.6);
      double y = size.height * (0.2 + random.nextDouble() * 0.6);
      
      // Floating effect
      y -= (animationValue * 10) % 20;
      
      canvas.drawCircle(Offset(x, y), (2 + random.nextDouble() * 3).toDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) => 
      oldDelegate.animationValue != animationValue;
}

class LiquidSurfacePainter extends CustomPainter {
  final Color color;
  final double splashValue;

  LiquidSurfacePainter({required this.color, this.splashValue = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // A wavy surface highlight with zigzag reaction
    final path = Path();
    path.moveTo(0, 0);

    if (splashValue > 0) {
      // Create a "zigzag" or splash effect in the middle
      double midX = size.width / 2;
      double splashWidth = size.width * 0.4;
      double splashDepth = 15.0 * math.sin(splashValue * math.pi * 4); // Zigzag amplitude

      path.lineTo(midX - splashWidth / 2, 0);
      path.quadraticBezierTo(midX - splashWidth / 4, splashDepth, midX, splashDepth);
      path.quadraticBezierTo(midX + splashWidth / 4, splashDepth, midX + splashWidth / 2, 0);
      path.lineTo(size.width, 0);
    } else {
      path.quadraticBezierTo(size.width * 0.25, -4, size.width * 0.5, 0);
      path.quadraticBezierTo(size.width * 0.75, 4, size.width, 0);
    }

    path.lineTo(size.width, 20);
    path.lineTo(0, 20);
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Pouring impact point (small splash)
    if (splashValue > 0) {
      final splashPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, 0), 5 * math.sin(splashValue * math.pi), splashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LiquidSurfacePainter oldDelegate) => 
      oldDelegate.splashValue != splashValue;
}
