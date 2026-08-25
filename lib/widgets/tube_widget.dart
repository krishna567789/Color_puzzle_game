import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/tube_model.dart';

class TubeWidget extends StatefulWidget {
  final Tube tube;
  final bool isSelected;
  final bool isShaking;
  final bool isReceiving;
  final double tiltAngle;
  final Offset offset;
  final VoidCallback onTap;
  final Color? pouringColor;
  final Offset? targetOffset;
  final String skinId;

  const TubeWidget({
    super.key,
    required this.tube,
    required this.isSelected,
    required this.isShaking,
    this.isReceiving = false,
    this.tiltAngle = 0.0,
    this.offset = Offset.zero,
    required this.onTap,
    this.pouringColor,
    this.targetOffset,
    this.skinId = 'default_tube',
  });

  @override
  State<TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<TubeWidget> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _splashController;
  late AnimationController _capController;
  late AnimationController _streamController;

  late Animation<double> _shakeAnimation;
  late Animation<double> _capDropAnimation;
  double _lastTiltAngle = 0.0;
  Offset? _lastTargetOffset;
  bool _wasSolved = false;

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

    _capController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _streamController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      upperBound: 2.0,
    );

    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    _capDropAnimation = Tween<double>(
      begin: -100,
      end: -15,
    ).animate(CurvedAnimation(parent: _capController, curve: Curves.bounceOut));

    _wasSolved = _isSolved(widget.tube);
    if (_wasSolved) {
      _capController.value = 1.0;
    }
  }

  bool _isSolved(Tube tube) {
    return tube.isFull &&
        tube.colors.isNotEmpty &&
        tube.colors.every((c) => c == tube.colors.first);
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

    bool isSolved = _isSolved(widget.tube);
    if (!_wasSolved && isSolved) {
      _capController.forward(from: 0.0);
    } else if (_wasSolved && !isSolved) {
      _capController.reset();
    }
    _wasSolved = isSolved;

    bool isPouringOld = oldWidget.tiltAngle != 0.0;
    bool isPouringNew = widget.tiltAngle != 0.0;

    if (!isPouringOld && isPouringNew) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && widget.tiltAngle != 0.0) {
          _streamController.forward(from: 0.0);
        }
      });
    } else if (isPouringOld && !isPouringNew) {
      _streamController
          .animateTo(2.0, duration: const Duration(milliseconds: 200))
          .then((_) {
            if (mounted) _streamController.value = 0.0;
          });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _splashController.dispose();
    _capController.dispose();
    _streamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _shakeController,
          _splashController,
          _capController,
          _streamController,
        ]),
        builder: (context, child) {
          double xOffset = widget.isShaking ? _shakeAnimation.value : 0;
          double yOffset = widget.isSelected ? -30.0 : 0;

          bool isPouring = widget.tiltAngle != 0.0;
          if (isPouring) {
            _lastTiltAngle = widget.tiltAngle;
            if (widget.targetOffset != null) {
              _lastTargetOffset = widget.targetOffset;
            }
          }
          double pourX = isPouring ? widget.offset.dx : 0;
          double pourY = isPouring ? widget.offset.dy : 0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                transform: Matrix4.identity()
                  ..translate(xOffset + pourX, yOffset + pourY)
                  ..rotateZ(widget.tiltAngle),
                transformAlignment: Alignment.topCenter,
                child: SizedBox(
                  width: 55,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Liquid Inside
                      Positioned(
                        bottom: 8,
                        child: ClipPath(
                          clipper: BottleClipper(),
                          child: Container(
                            width: 53,
                            height: 144,
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (widget.tube.colors.length <
                                    widget.tube.capacity)
                                  Expanded(
                                    flex:
                                        widget.tube.capacity -
                                        widget.tube.colors.length,
                                    child: Container(color: Colors.transparent),
                                  ),
                                for (
                                  int i = widget.tube.colors.length - 1;
                                  i >= 0;
                                  i--
                                )
                                  Expanded(
                                    flex: 1,
                                    child: ClipPath(
                                      clipper:
                                          i == widget.tube.colors.length - 1
                                          ? WavyTopClipper(
                                              splashValue: widget.isReceiving
                                                  ? _splashController.value
                                                  : 0.0,
                                            )
                                          : null,
                                      child: CustomPaint(
                                        painter: LiquidSegmentPainter(
                                          widget.tube.colors[i],
                                          isTopSegment: i == widget.tube.colors.length - 1,
                                          splashValue: widget.isReceiving ? _splashController.value : 0.0,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 0.1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Glass Bottle Body
                      CustomPaint(
                        size: const Size(55, 150),
                        painter: BottlePainter(
                          isSelected: widget.isSelected,
                          skinId: widget.skinId,
                        ),
                      ),

                      // Bottle Glints/Highlights
                      IgnorePointer(
                        child: CustomPaint(
                          size: const Size(55, 150),
                          painter: BottleHighlightPainter(),
                        ),
                      ),

                      // Diamond Cap (Shows when solved)
                      if (!isPouring && _capController.value > 0)
                        Positioned(
                          top: _capDropAnimation.value,
                          child: Image.asset(
                            'assets/blender/bottol_cap.png',
                            width: 36,
                            height: 32,
                            errorBuilder: (context, error, stackTrace) {
                              return CustomPaint(
                                size: const Size(22, 18),
                                painter: CorkCapPainter(),
                              );
                            },
                          ),
                        ),

                      // Pour stream
                      if ((isPouring || _streamController.value > 1.0) &&
                          widget.pouringColor != null)
                        Positioned(
                          top: 10,
                          left: _lastTiltAngle > 0 ? 55 : -5,
                          child: Transform.rotate(
                            angle: -_lastTiltAngle,
                            alignment: Alignment.topCenter,
                            child: CustomPaint(
                              size: Size(
                                12,
                                _lastTargetOffset != null
                                    ? _lastTargetOffset!.distance
                                    : 0,
                              ),
                              painter: StreamPainter(
                                progress: _streamController.value,
                                color: widget.pouringColor!,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class StreamPainter extends CustomPainter {
  final double progress;
  final Color color;

  StreamPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 2.0 || size.height == 0) return;

    double topY = 0;
    double bottomY = size.height;

    if (progress <= 1.0) {
      topY = 0;
      bottomY = size.height * progress;
    } else {
      topY = size.height * (progress - 1.0);
      bottomY = size.height;
    }

    final path = Path();
    path.moveTo(4, topY);
    path.lineTo(8, topY);

    double taperPoint = bottomY - 15;
    if (taperPoint < topY) taperPoint = topY;

    path.lineTo(8, taperPoint);
    path.quadraticBezierTo(6, bottomY, 4, taperPoint);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawLine(Offset(6, topY), Offset(6, bottomY), shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StreamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class BottlePainter extends CustomPainter {
  final bool isSelected;
  final String skinId;
  BottlePainter({required this.isSelected, this.skinId = 'default_tube'});

  @override
  void paint(Canvas canvas, Size size) {
    final glassPaint = Paint()
      ..color = _getGlassColor().withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isSelected
          ? Colors.white
          : const Color(0xFF90CAF9).withOpacity(
              0.9,
            ) // Light blue border like the image
      ..style = PaintingStyle.stroke
      ..strokeWidth = skinId == 'neon_tube'
          ? 4.0
          : 3.5 // Thicker border
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = _getBottlePath(size);

    if (isSelected || skinId == 'neon_tube') {
      canvas.drawShadow(
        path,
        _getGlowColor().withOpacity(0.6),
        isSelected ? 12 : 6,
        true,
      );
    }

    canvas.drawPath(path, glassPaint);
    canvas.drawPath(path, borderPaint);

    // Add specific details based on skin
    if (skinId == 'crystal_bottle') {
      _drawCrystalFacets(canvas, size);
    }

    final neckRimPaint = Paint()
      ..color = const Color(0xFF90CAF9).withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // The top pill-shaped rim of the bottle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, -2, size.width * 0.5, 6),
        const Radius.circular(4),
      ),
      neckRimPaint,
    );
  }

  Color _getGlassColor() {
    switch (skinId) {
      case 'neon_tube':
        return Colors.purpleAccent;
      case 'crystal_bottle':
        return Colors.blueAccent;
      case 'wooden_tube':
        return Colors.brown;
      default:
        return Colors.cyanAccent;
    }
  }

  Color _getBorderColor() {
    switch (skinId) {
      case 'neon_tube':
        return Colors.purpleAccent.withOpacity(0.6);
      case 'wooden_tube':
        return Colors.brown[400]!;
      default:
        return Colors.white.withOpacity(0.5);
    }
  }

  Color _getSelectedBorderColor() {
    switch (skinId) {
      case 'neon_tube':
        return Colors.white;
      case 'wooden_tube':
        return Colors.orangeAccent;
      default:
        return Colors.white;
    }
  }

  Color _getGlowColor() {
    switch (skinId) {
      case 'neon_tube':
        return Colors.purple;
      case 'wooden_tube':
        return Colors.orange;
      default:
        return Colors.white;
    }
  }

  void _drawCrystalFacets(Canvas canvas, Size size) {
    final facetPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.2),
      Offset(size.width * 0.7, size.height * 0.5),
      facetPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.2),
      Offset(size.width * 0.3, size.height * 0.5),
      facetPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BottlePainter oldDelegate) =>
      oldDelegate.isSelected != isSelected || oldDelegate.skinId != skinId;
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
  double neckWidth = w * 0.4;
  double neckHeight = h * 0.15;

  path.moveTo((w - neckWidth) / 2, 5);
  path.lineTo((w + neckWidth) / 2, 5);
  path.lineTo((w + neckWidth) / 2, neckHeight);

  path.quadraticBezierTo(w, neckHeight + 8, w, neckHeight + 25);
  path.lineTo(w, h - 15);
  path.quadraticBezierTo(w, h, w - 15, h);
  path.lineTo(15, h);
  path.quadraticBezierTo(0, h, 0, h - 15);
  path.lineTo(0, neckHeight + 25);
  path.quadraticBezierTo(0, neckHeight + 8, (w - neckWidth) / 2, neckHeight);

  path.close();
  return path;
}

class BottleHighlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
          .withOpacity(0.6) // Stronger white highlight
      ..style = PaintingStyle.fill;

    // Highlight on the neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.15,
          size.height * 0.12,
          3.5,
          size.height * 0.08,
        ),
        const Radius.circular(2),
      ),
      paint,
    );

    // Highlight on the main body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.1,
          size.height * 0.35,
          4.5,
          size.height * 0.3,
        ),
        const Radius.circular(2.5),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WavyTopClipper extends CustomClipper<Path> {
  final double splashValue;
  WavyTopClipper({this.splashValue = 0.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 5);

    if (splashValue > 0) {
      double midX = size.width / 2;
      double splashDepth = 15.0 * math.sin(splashValue * math.pi * 5);
      path.quadraticBezierTo(midX / 2, splashDepth, midX, splashDepth);
      path.quadraticBezierTo(midX + midX / 2, splashDepth, size.width, 5);
    } else {
      // Gentle wave for static top liquid
      path.quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, 5);
      path.quadraticBezierTo(size.width * 0.75, 10, size.width, 5);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WavyTopClipper oldClipper) =>
      oldClipper.splashValue != splashValue;
}

class CorkCapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. The Cork Base
    final paint = Paint()
      ..color =
          const Color(0xFFC19A6B) // Tan/Wood color
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, paint);

    // 2. Inner shadow/texture at the bottom
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height - 4, size.width, 4),
        const Radius.circular(2),
      ),
      shadow,
    );

    // 3. Wood grain details (small lines)
    final grainPaint = Paint()
      ..color = Colors.brown.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.4, size.height * 0.3),
      grainPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.6, size.height * 0.6),
      Offset(size.width * 0.8, size.height * 0.6),
      grainPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.7),
      Offset(size.width * 0.5, size.height * 0.7),
      grainPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LiquidSegmentPainter extends CustomPainter {
  final Color baseColor;
  final bool isTopSegment;
  final double splashValue;

  LiquidSegmentPainter(this.baseColor, {this.isTopSegment = false, this.splashValue = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Cylindrical gradient
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color.lerp(baseColor, Colors.black, 0.4)!,
        baseColor,
        Color.lerp(baseColor, Colors.white, 0.3)!,
        baseColor,
        Color.lerp(baseColor, Colors.black, 0.6)!,
      ],
      stops: const [0.0, 0.2, 0.7, 0.9, 1.0],
    );
    
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
    
    // Top surface ellipse for 3D depth
    if (isTopSegment && splashValue == 0) {
      final ellipseRect = Rect.fromLTWH(0, -6, size.width, 12);
      final topSurfaceColor = Color.lerp(baseColor, Colors.white, 0.4)!;
      
      final topPaint = Paint()
        ..color = topSurfaceColor
        ..style = PaintingStyle.fill;
        
      canvas.drawOval(ellipseRect, topPaint);
      
      // Inner shadow/rim on the ellipse
      final rimPaint = Paint()
        ..color = Color.lerp(baseColor, Colors.black, 0.2)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawOval(ellipseRect, rimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LiquidSegmentPainter oldDelegate) => 
    oldDelegate.baseColor != baseColor || oldDelegate.splashValue != splashValue;
}
