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
  final bool isHinted;
  final double scale;

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
    this.isHinted = false,
    this.scale = 1.0,
  });

  @override
  State<TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<TubeWidget> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _splashController;
  late AnimationController _capController;
  late AnimationController _streamController;
  late AnimationController _waveController;
  late AnimationController _glowController;

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
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
      begin: -40.0,
      end: 2.0,
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
      _glowController.forward(from: 0.0);
    } else if (_wasSolved && !isSolved) {
      _capController.reset();
      _glowController.reset();
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
    _waveController.dispose();
    _glowController.dispose();
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
          _waveController,
          _glowController,
        ]),
        builder: (context, child) {
          double scale = widget.scale;
          double xOffset =
              (widget.isShaking ? _shakeAnimation.value : 0) * scale;
          double yOffset = (widget.isSelected ? -30.0 : 0) * scale;

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
                  width: 55 * scale,
                  height: 160 * scale,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 55,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.none,
                        children: [
                          // Magic Glow (Shows when solved)
                          if (_glowController.value > 0)
                            Positioned.fill(
                              child: Opacity(
                                opacity: math.sin(_glowController.value * math.pi),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.tube.colors.isNotEmpty 
                                            ? widget.tube.colors.first.withOpacity(0.8)
                                            : Colors.white,
                                        blurRadius: 20 * scale,
                                        spreadRadius: 10 * scale,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Tube Background
                          Image.asset(
                            'assets/blender/bottol.png',
                            width: 55,
                            height: 160,
                            color: Colors.white.withOpacity(0.1),
                            colorBlendMode: BlendMode.modulate,
                          ),

                          // Liquid Inside
                          Positioned(
                            bottom: 4,
                            child: ClipPath(
                              clipper: BottleClipper(),
                              child: CustomPaint(
                                size: const Size(51, 144),
                                painter: LiquidSegmentPainter(
                                  colors: widget.tube.colors,
                                  fillHeight: widget.tube.colors.length * (144.0 / 4),
                                  animationValue: 1.0,
                                  hiddenCount: widget.tube.hiddenCount,
                                  wavePhase: _waveController.value * 2 * math.pi,
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
                              isHinted: widget.isHinted,
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

                          // Magic Dust Particles
                          if (!isPouring && _glowController.value > 0)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: MagicDustPainter(
                                  progress: _glowController.value,
                                  color: widget.tube.colors.isNotEmpty ? widget.tube.colors.first : Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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

class BottlePainter extends CustomPainter {
  final bool isSelected;
  final String skinId;
  final bool isHinted;
  BottlePainter({
    required this.isSelected,
    this.skinId = 'default_tube',
    this.isHinted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.1),
          Colors.transparent,
          Colors.white.withOpacity(0.05),
          Colors.white.withOpacity(0.3),
        ],
        stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = skinId == 'neon_tube' ? 4.0 : 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = _getBottlePath(size);

    if (isSelected || skinId == 'neon_tube' || isHinted) {
      Color glowColor = isHinted ? Colors.amberAccent : _getGlowColor();
      canvas.drawShadow(
        path,
        glowColor.withOpacity(0.6),
        (isSelected || isHinted) ? 12 : 6,
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
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.9),
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.8),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // The top pill-shaped rim of the bottle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, -3, size.width * 0.5, 8),
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
      oldDelegate.isSelected != isSelected ||
      oldDelegate.skinId != skinId ||
      oldDelegate.isHinted != isHinted;
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
  final List<Color> colors;
  final double fillHeight;
  final double animationValue;
  final int hiddenCount;
  final double wavePhase;

  LiquidSegmentPainter({
    required this.colors,
    required this.fillHeight,
    required this.animationValue,
    this.hiddenCount = 0,
    this.wavePhase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;

    final double segmentHeight = size.height / 4;
    final double totalHeight = colors.length * segmentHeight;
    final double startY = size.height - totalHeight;

    for (int i = 0; i < colors.length; i++) {
      bool isHidden = i < hiddenCount;
      Color segmentColor = isHidden ? Colors.grey.shade400 : colors[i];
      
      final double topY = size.height - ((i + 1) * segmentHeight);
      
      // Draw wavy top only for the uppermost segment
      if (i == colors.length - 1 && colors.length < 4) {
        Path path = Path();
        path.moveTo(0, topY + segmentHeight); // Bottom left
        path.lineTo(size.width, topY + segmentHeight); // Bottom right
        
        // Wavy top edge
        for (double x = size.width; x >= 0; x -= 2) {
          double waveHeight = 2.0; // small wave
          double y = topY + math.sin((x / size.width) * math.pi * 2 + wavePhase) * waveHeight;
          path.lineTo(x, y);
        }
        path.close();
        
        final paint = Paint()
          ..color = segmentColor
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, paint);
      } else {
        // Normal flat segment
        final rect = Rect.fromLTWH(0, topY, size.width, segmentHeight);
        final paint = Paint()
          ..color = segmentColor
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, paint);
      }
      
      // Draw bubbles inside the liquid
      if (!isHidden) {
        _drawBubbles(canvas, size, topY, segmentHeight, segmentColor, i);
      }

      // Draw Mystery '?' Marker
      if (isHidden) {
        final textPainter = TextPainter(
          text: const TextSpan(
            text: '?',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            (size.width - textPainter.width) / 2,
            topY + (segmentHeight - textPainter.height) / 2,
          ),
        );
      }
    }
  }
  
  void _drawBubbles(Canvas canvas, Size size, double topY, double height, Color color, int layerIndex) {
    final random = math.Random(color.value + layerIndex);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
      
    int bubbleCount = random.nextInt(3) + 2;
    
    for (int j = 0; j < bubbleCount; j++) {
      double startX = random.nextDouble() * size.width;
      double speed = random.nextDouble() * 1.5 + 0.5;
      double yOffset = (wavePhase * speed * 15) % height;
      
      double bY = (topY + height) - yOffset;
      double bX = startX + math.sin(wavePhase * 2 + j) * 2;
      
      double radius = random.nextDouble() * 2 + 1;
      
      canvas.drawCircle(Offset(bX, bY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LiquidSegmentPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.fillHeight != fillHeight ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.hiddenCount != hiddenCount ||
        oldDelegate.wavePhase != wavePhase;
  }
}

class MagicDustPainter extends CustomPainter {
  final double progress;
  final Color color;

  MagicDustPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()
      ..color = color.withOpacity(1.0 - progress)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 15; i++) {
      double angle = random.nextDouble() * math.pi * 2;
      double speed = random.nextDouble() * 50 + 20;
      double distance = speed * progress;
      
      double x = size.width / 2 + math.cos(angle) * distance;
      double y = size.height / 2 + math.sin(angle) * distance - (progress * 40);
      
      double radius = random.nextDouble() * 2 + 1;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MagicDustPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
