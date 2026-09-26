import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/liquid_patterns.dart';
import '../models/tube_model.dart';

/// Pre-rendered bottle glass, keyed by the shop's skin ids.
///
/// The renders come from tools/bottle/render_skins.py: a front-orthographic
/// view of `tools/bottle/artifact.glb` at 4 px per millimetre, cropped to the
/// same 55 x 150 box `_getBottlePath` draws, with the middle left transparent so
/// the liquid painted underneath still shows through.
const Map<String, String> kBottleGlass = {
  'default_tube': 'assets/skins/default_tube.png',
  'neon_tube': 'assets/skins/neon_tube.png',
  'crystal_bottle': 'assets/skins/crystal_bottle.png',
  'wooden_tube': 'assets/skins/wooden_tube.png',
};

/// The three-quarter render the shop sells each skin with.
String bottleHeroPath(String skinId) => 'assets/skins/hero_$skinId.png';

class TubeWidget extends StatefulWidget {
  final Tube tube;
  final bool isSelected;
  final bool isShaking;
  final double tiltAngle;
  final Offset offset;
  final VoidCallback onTap;
  final String skinId;
  final bool isHinted;
  final double scale;

  /// Every layer wears its colourblind mark as well as its colour.
  final bool showPatterns;

  /// Refires the solved-tube sparkle: the level ending is a second reason to
  /// cheer, apart from the moment the tube itself was filled.
  final bool celebrate;

  const TubeWidget({
    super.key,
    required this.tube,
    required this.isSelected,
    required this.isShaking,
    this.tiltAngle = 0.0,
    this.offset = Offset.zero,
    required this.onTap,
    this.skinId = 'default_tube',
    this.isHinted = false,
    this.scale = 1.0,
    this.celebrate = false,
    this.showPatterns = false,
  });

  @override
  State<TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<TubeWidget> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _capController;
  late AnimationController _waveController;
  late AnimationController _glowController;

  /// The lean and the hover, eased by hand. `AnimatedContainer` restarts its
  /// tween every time the parent rebuilds - which a pour does twice a second -
  /// so the bottle kept sliding back towards upright instead of settling.
  late final AnimationController _poseController;
  late final Animation<double> _poseCurve;
  _TubePose _poseFrom = _TubePose.idle;
  _TubePose _poseTo = _TubePose.idle;

  /// The liquid the paint is allowed to show, which trails the model by one
  /// layer: a pour that appears instantly at the bottom of the glass reads as a
  /// teleport rather than as liquid arriving.
  List<Color> _shown = const [];

  /// The layer that has already left the tube, draining away above the stack.
  Color? _draining;
  late final AnimationController _fillController;

  late Animation<double> _shakeAnimation;
  late Animation<double> _capDropAnimation;
  bool _wasSolved = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _capController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _poseController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _poseCurve = CurvedAnimation(
      parent: _poseController,
      curve: Curves.easeOutCubic,
    );
    _poseFrom = _poseTo = _TubePose(widget.tiltAngle, widget.offset);
    _poseController.value = 1.0;

    // One layer moves per pour segment, so the level crosses in the same beat.
    _fillController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fillController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _draining != null && mounted) {
        setState(() => _draining = null);
      }
    });
    _shown = List.of(widget.tube.colors);
    _fillController.value = 1.0;

    // Only the loose surface and the drifting bubbles move, so a tube that is
    // empty or already packed stops ticking instead of burning a frame budget.
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (_surfaceIsLoose(widget.tube)) _waveController.repeat();

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

  /// True while the liquid has an open top to ripple: a full tube paints a flat
  /// column and an empty one paints nothing.
  bool _surfaceIsLoose(Tube tube) =>
      tube.colors.isNotEmpty && tube.colors.length < tube.capacity;

  /// Lines the painted stack up with the model, animating a single layer at a
  /// time. Anything bigger is a new board, an undo or a shuffle, and those are
  /// supposed to change at once.
  ///
  /// The model mutates its own list in place, so this keeps a copy: comparing
  /// identities would say "nothing changed" on every frame of a pour.
  void _syncLiquid() {
    final target = widget.tube.colors;
    final previous = _shown;
    final delta = target.length - previous.length;

    if (delta == 0) {
      // Same height. Colours can still change under it (a mystery layer
      // revealing), but a rebuild that is not about the liquid must not cut a
      // layer's animation short - the board rebuilds several times per segment.
      if (_fillController.isAnimating) return;
      _shown = List.of(target);
      _draining = null;
      return;
    }

    if (delta.abs() > 1) {
      _shown = List.of(target);
      _draining = null;
      _fillController.value = 1.0;
      return;
    }

    _shown = List.of(target);
    if (delta > 0) {
      // The newest layer grows up out of the surface under it.
      _draining = null;
    } else {
      // The layer that just left falls to nothing over the stack it came from.
      _draining = previous[target.length];
    }
    _fillController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant TubeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final target = _TubePose(widget.tiltAngle, widget.offset);
    if (target != _poseTo) {
      _poseFrom = _TubePose.lerp(_poseFrom, _poseTo, _poseCurve.value);
      _poseTo = target;
      _poseController.forward(from: 0.0);
    }

    _syncLiquid();

    if (widget.isShaking && !oldWidget.isShaking) {
      _shakeController.forward(from: 0.0);
    }

    if (_surfaceIsLoose(widget.tube)) {
      if (!_waveController.isAnimating) _waveController.repeat();
    } else if (_waveController.isAnimating) {
      _waveController.stop();
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

    if (widget.celebrate && !oldWidget.celebrate && isSolved) {
      _glowController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _capController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    _poseController.dispose();
    _fillController.dispose();
    super.dispose();
  }

  /// The glass the bottle is drawn with.
  ///
  /// A rendered skin brings its own glints, so the vector highlight layer only
  /// rides on the painter fallback; the focus ring is separate either way,
  /// because a static image cannot light up when the player picks it.
  List<Widget> _glassLayers() {
    final sprite = kBottleGlass[widget.skinId];
    if (sprite == null) {
      return [
        CustomPaint(
          size: const Size(55, 150),
          painter: BottlePainter(
            isSelected: widget.isSelected,
            skinId: widget.skinId,
            isHinted: widget.isHinted,
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            size: const Size(55, 150),
            painter: BottleHighlightPainter(),
          ),
        ),
      ];
    }
    return [
      Image.asset(
        sprite,
        width: 55,
        height: 150,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
      if (widget.isSelected || widget.isHinted)
        IgnorePointer(
          child: CustomPaint(
            size: const Size(55, 150),
            painter: BottleFocusPainter(hinted: widget.isHinted),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _shakeController,
          _capController,
          _glowController,
          _poseController,
          _fillController,
        ]),
        builder: (context, child) {
          double scale = widget.scale;
          double xOffset =
              (widget.isShaking ? _shakeAnimation.value : 0) * scale;
          double yOffset = (widget.isSelected ? -30.0 : 0) * scale;

          bool isPouring = widget.tiltAngle != 0.0;
          final pourPose = _TubePose.lerp(_poseFrom, _poseTo, _poseCurve.value);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(
                    xOffset + pourPose.offset.dx,
                    yOffset + pourPose.offset.dy,
                    0,
                    1,
                  )
                  ..rotateZ(pourPose.tilt),
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 55 * scale,
                  height: 160 * scale,
                  // The box and the paint are the same size now: `Transform.scale`
                  // left the bottle laid out at 55 x 160 and painted it at
                  // scale-squared, so every row bled into the next and the last
                  // row slid under the power-up strip.
                  child: FittedBox(
                    fit: BoxFit.fill,
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
                                opacity: math.sin(
                                  _glowController.value * math.pi,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.tube.colors.isNotEmpty
                                            ? widget.tube.colors.first
                                                  .withValues(alpha: 0.8)
                                            : Colors.white,
                                        blurRadius: 20 * scale,
                                        spreadRadius: 10 * scale,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Liquid Inside. The wave listens to its own
                          // controller, so a ripple repaints this one layer
                          // instead of rebuilding every tube each frame.
                          Positioned(
                            bottom: 4,
                            child: ClipPath(
                              clipper: BottleClipper(),
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  size: const Size(51, 144),
                                  painter: LiquidSegmentPainter(
                                    colors: _shown,
                                    hiddenCount: widget.tube.hiddenCount,
                                    wave: _waveController,
                                    drainingColor: _draining,
                                    showPatterns: widget.showPatterns,
                                    fillFraction: _draining == null
                                        ? _fillController.value
                                        : 1 - _fillController.value,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Glass Bottle Body, plus whatever glints it needs
                          ..._glassLayers(),

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
                                  color: widget.tube.colors.isNotEmpty
                                      ? widget.tube.colors.first
                                      : Colors.white,
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

/// Where one tube is in its pour: how far it has tipped and where it floats.
class _TubePose {
  const _TubePose(this.tilt, this.offset);

  static const _TubePose idle = _TubePose(0.0, Offset.zero);

  final double tilt;
  final Offset offset;

  static _TubePose lerp(_TubePose a, _TubePose b, double t) => _TubePose(
    a.tilt + (b.tilt - a.tilt) * t,
    Offset.lerp(a.offset, b.offset, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is _TubePose && other.tilt == tilt && other.offset == offset;

  @override
  int get hashCode => Object.hash(tilt, offset);
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
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.1),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.3),
        ],
        stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = skinId == 'neon_tube' ? 4.0 : 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = _getBottlePath(size);

    if (isSelected || skinId == 'neon_tube' || isHinted) {
      Color glowColor = isHinted ? Colors.amberAccent : _getGlowColor();
      canvas.drawShadow(
        path,
        glowColor.withValues(alpha: 0.6),
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
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.8),
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
      ..color = Colors.white.withValues(alpha: 0.1)
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

/// The picked-tube ring, for skins whose glass is a pre-rendered sprite.
class BottleFocusPainter extends CustomPainter {
  final bool hinted;
  const BottleFocusPainter({this.hinted = false});

  @override
  void paint(Canvas canvas, Size size) {
    final color = hinted ? Colors.amberAccent : Colors.white;
    final path = _getBottlePath(size);
    canvas.drawShadow(path, color.withValues(alpha: 0.6), 12, true);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant BottleFocusPainter oldDelegate) =>
      oldDelegate.hinted != hinted;
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
          .withValues(alpha: 0.6) // Stronger white highlight
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
      ..color = Colors.black.withValues(alpha: 0.2)
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
      ..color = Colors.brown.withValues(alpha: 0.3)
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
  final int hiddenCount;
  final Animation<double> wave;

  /// The layer that has already left the tube, painted above [colors] while it
  /// drains away. Null while a layer is arriving instead of leaving.
  final Color? drainingColor;

  /// How much of the top slot liquid fills, 0 to 1.
  final double fillFraction;

  /// Whether each layer also wears a shape, for players who cannot separate the
  /// palette by colour alone.
  final bool showPatterns;

  LiquidSegmentPainter({
    required this.colors,
    required this.hiddenCount,
    required this.wave,
    this.drainingColor,
    this.fillFraction = 1,
    this.showPatterns = false,
  }) : super(repaint: wave);

  static const double _height = 144;
  static const double _segmentHeight = _height / 4;

  /// Standing bubble layout per layer: horizontal position as a fraction of the
  /// bottle, radius and rise speed. Deterministic, so nothing has to be drawn
  /// from a fresh random sequence on every frame.
  static const List<(double, double, double)> _bubbleSlots = [
    (0.24, 1.6, 1.0),
    (0.63, 1.1, 1.7),
    (0.42, 1.9, 1.25),
    (0.78, 1.3, 1.5),
  ];

  static TextPainter? _mysteryMarker;

  @override
  void paint(Canvas canvas, Size size) {
    final layers = drainingColor == null ? colors : [...colors, drainingColor!];
    if (layers.isEmpty) return;

    final phase = wave.value * 2 * math.pi;
    final bubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < layers.length; i++) {
      final bool isHidden = i < hiddenCount;
      final Color segmentColor = isHidden ? Colors.grey.shade400 : layers[i];
      final double topY = size.height - ((i + 1) * _segmentHeight);
      final paint = Paint()
        ..color = segmentColor
        ..style = PaintingStyle.fill;

      // The layer being added or removed only fills part of its slot, and it
      // fills from the bottom of that slot up - liquid arrives at the surface,
      // it does not appear from the ceiling.
      final bool isTop = i == layers.length - 1;
      final height = isTop ? _segmentHeight * fillFraction : _segmentHeight;
      if (height <= 0.5) continue;
      final surfaceY = topY + _segmentHeight - height;
      final bool settled = height >= _segmentHeight - 0.5;

      // Only the uppermost loose segment ripples; a packed tube reads as still.
      final Path body;
      if (isTop && layers.length < 4 && settled) {
        body = Path()
          ..moveTo(0, topY + _segmentHeight)
          ..lineTo(size.width, topY + _segmentHeight);
        for (double x = size.width; x >= 0; x -= 2) {
          body.lineTo(
            x,
            surfaceY + math.sin((x / size.width) * math.pi * 2 + phase) * 2.0,
          );
        }
        body.close();
      } else {
        body = Path()..addRect(Rect.fromLTWH(0, surfaceY, size.width, height));
      }
      canvas.drawPath(body, paint);

      if (showPatterns && !isHidden) {
        // Clipped to the liquid itself, so a mark never smears onto the glass.
        canvas.save();
        canvas.clipPath(body);
        paintLiquidPattern(
          canvas,
          Rect.fromLTWH(0, surfaceY, size.width, height),
          liquidPatternFor(segmentColor),
          segmentColor,
        );
        canvas.restore();
      }

      if (isHidden) {
        _paintMysteryMarker(canvas, size, topY);
      } else if (!isTop || settled) {
        _drawBubbles(canvas, size, topY, bubblePaint, i, phase);
      }
    }
  }

  void _drawBubbles(
    Canvas canvas,
    Size size,
    double topY,
    Paint paint,
    int layerIndex,
    double phase,
  ) {
    for (int j = 0; j < 3; j++) {
      final (unitX, radius, speed) =
          _bubbleSlots[(layerIndex + j) % _bubbleSlots.length];
      final rise = (phase * speed * 15) % _segmentHeight;
      final x = unitX * size.width + math.sin(phase * 2 + j) * 2;
      final y = (topY + _segmentHeight) - rise;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _paintMysteryMarker(Canvas canvas, Size size, double topY) {
    final marker = _mysteryMarker ??= TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    marker.paint(
      canvas,
      Offset(
        (size.width - marker.width) / 2,
        topY + (_segmentHeight - marker.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant LiquidSegmentPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.hiddenCount != hiddenCount ||
        oldDelegate.drainingColor != drainingColor ||
        oldDelegate.fillFraction != fillFraction ||
        oldDelegate.showPatterns != showPatterns;
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
      ..color = color.withValues(alpha: 1.0 - progress)
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
