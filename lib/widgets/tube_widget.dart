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

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
    
    _capDropAnimation = Tween<double>(begin: -80, end: -8).animate(
      CurvedAnimation(parent: _capController, curve: Curves.bounceOut)
    );

    if (_isSolved(widget.tube)) {
      _capController.value = 1.0;
    }
  }

  bool _isSolved(Tube tube) {
    return tube.isFull && tube.colors.isNotEmpty && tube.colors.every((c) => c == tube.colors.first);
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
    
    bool wasSolved = _isSolved(oldWidget.tube);
    bool isSolved = _isSolved(widget.tube);
    if (!wasSolved && isSolved) {
      _capController.forward(from: 0.0);
    } else if (wasSolved && !isSolved) {
      _capController.reset();
    }
    
    bool isPouringOld = oldWidget.tiltAngle != 0.0;
    bool isPouringNew = widget.tiltAngle != 0.0;

    if (!isPouringOld && isPouringNew) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && widget.tiltAngle != 0.0) {
          _streamController.forward(from: 0.0);
        }
      });
    } else if (isPouringOld && !isPouringNew) {
      _streamController.animateTo(2.0, duration: const Duration(milliseconds: 200)).then((_) {
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
        animation: Listenable.merge([_shakeController, _splashController, _capController, _streamController]),
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
                                      margin: const EdgeInsets.symmetric(vertical: 0.1),
                                      decoration: BoxDecoration(
                                        color: widget.tube.colors[i],
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color.lerp(widget.tube.colors[i], Colors.white, 0.1)!,
                                            widget.tube.colors[i],
                                            widget.tube.colors[i],
                                            Color.lerp(widget.tube.colors[i], Colors.black, 0.25)!,
                                          ],
                                          stops: const [0.0, 0.1, 0.8, 1.0],
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
                                        ],
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
                           child: CustomPaint(
                             size: const Size(28, 28),
                             painter: DiamondCapPainter(),
                           )
                         ),
                         
                      // Pour stream
                      if ((isPouring || _streamController.value > 1.0) && widget.pouringColor != null)
                        Positioned(
                          top: 10,
                          left: _lastTiltAngle > 0 ? 55 : -5, 
                          child: Transform.rotate(
                            angle: -_lastTiltAngle, 
                            alignment: Alignment.topCenter,
                            child: CustomPaint(
                              size: Size(12, _lastTargetOffset != null ? _lastTargetOffset!.distance : 0),
                              painter: StreamPainter(
                                progress: _streamController.value,
                                color: widget.pouringColor!,
                              ),
                            )
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
      ..color = isSelected ? _getSelectedBorderColor() : _getBorderColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = skinId == 'neon_tube' ? 4.0 : 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = _getBottlePath(size);

    if (isSelected || skinId == 'neon_tube') {
      canvas.drawShadow(path, _getGlowColor().withOpacity(0.6), isSelected ? 12 : 6, true);
    }

    canvas.drawPath(path, glassPaint);
    canvas.drawPath(path, borderPaint);
    
    // Add specific details based on skin
    if (skinId == 'crystal_bottle') {
       _drawCrystalFacets(canvas, size);
    }

    final neckRimPaint = Paint()
      ..color = _getBorderColor().withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.28, -2, size.width * 0.44, 6),
        const Radius.circular(3),
      ),
      neckRimPaint,
    );
  }

  Color _getGlassColor() {
    switch(skinId) {
      case 'neon_tube': return Colors.purpleAccent;
      case 'crystal_bottle': return Colors.blueAccent;
      case 'wooden_tube': return Colors.brown;
      default: return Colors.cyanAccent;
    }
  }

  Color _getBorderColor() {
    switch(skinId) {
      case 'neon_tube': return Colors.purpleAccent.withOpacity(0.6);
      case 'wooden_tube': return Colors.brown[400]!;
      default: return Colors.white.withOpacity(0.5);
    }
  }

  Color _getSelectedBorderColor() {
    switch(skinId) {
      case 'neon_tube': return Colors.white;
      case 'wooden_tube': return Colors.orangeAccent;
      default: return Colors.white;
    }
  }

  Color _getGlowColor() {
    switch(skinId) {
      case 'neon_tube': return Colors.purple;
      case 'wooden_tube': return Colors.orange;
      default: return Colors.white;
    }
  }

  void _drawCrystalFacets(Canvas canvas, Size size) {
    final facetPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width * 0.3, size.height * 0.2), Offset(size.width * 0.7, size.height * 0.5), facetPaint);
    canvas.drawLine(Offset(size.width * 0.7, size.height * 0.2), Offset(size.width * 0.3, size.height * 0.5), facetPaint);
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
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.3, 4, size.height * 0.5),
        const Radius.circular(2),
      ),
      paint,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, size.height * 0.4, 2, size.height * 0.3),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.white.withOpacity(0.15)..style=PaintingStyle.fill,
    );

    final shoulderGlint = Path()
      ..moveTo(size.width * 0.15, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.15, size.width * 0.5, size.height * 0.2)
      ..lineTo(size.width * 0.45, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.17, size.width * 0.15, size.height * 0.22)
      ..close();
    
    canvas.drawPath(shoulderGlint, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LiquidSurfacePainter extends CustomPainter {
  final Color color;
  final double splashValue;

  LiquidSurfacePainter({required this.color, this.splashValue = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);

    if (splashValue > 0) {
      double midX = size.width / 2;
      double splashWidth = size.width * 0.7;
      double splashDepth = 12.0 * math.sin(splashValue * math.pi * 5); 

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
    
    if (splashValue > 0) {
      final splashPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, -2 + 8 * math.sin(splashValue * math.pi)), 3, splashPaint);
      canvas.drawCircle(Offset(size.width / 2 - 8, -4 + 6 * math.sin(splashValue * math.pi)), 2, splashPaint);
      canvas.drawCircle(Offset(size.width / 2 + 8, -3 + 10 * math.sin(splashValue * math.pi)), 2, splashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LiquidSurfacePainter oldDelegate) => 
      oldDelegate.splashValue != splashValue;
}

class DiamondCapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
      
    final path = Path();
    path.moveTo(size.width / 2, 0); 
    path.lineTo(size.width, size.height / 2); 
    path.lineTo(size.width / 2, size.height); 
    path.lineTo(0, size.height / 2); 
    path.close();
    
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    final highlightPath = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(highlightPath, highlightPaint);
    
    final borderPaint = Paint()
      ..color = Colors.orange[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
