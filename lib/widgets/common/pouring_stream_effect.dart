import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../game/pour_geometry.dart';
import 'pouring_stream_painter.dart';

class PouringStreamEffect extends StatefulWidget {
  final GameController controller;
  final List<GlobalKey> tubeKeys;

  const PouringStreamEffect({
    super.key,
    required this.controller,
    required this.tubeKeys,
  });

  @override
  State<PouringStreamEffect> createState() => _PouringStreamEffectState();
}

class _PouringStreamEffectState extends State<PouringStreamEffect>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  /// Runs only while liquid is actually moving, so the jet can show flow.
  /// Without it a four-segment pour paints a frozen line for most of its life.
  late AnimationController _flowController;

  /// One run per layer that lands, so the surface is kicked each time instead
  /// of showing a single splash for the whole pour.
  late AnimationController _splashController;

  int? _lastFromIndex;
  int? _lastToIndex;
  Color? _lastColor;

  /// How full the target was on the previous notification, and which splash of
  /// this pour we are on.
  int? _pouredLayers;
  int _splashSeed = 0;

  /// Where the jet is currently ending, eased towards the rising surface.
  Offset? _smoothedLanding;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    widget.controller.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (widget.controller.isPouringLiquid &&
        widget.controller.pouringFromIndex != null &&
        widget.controller.pouringToIndex != null &&
        widget.controller.pouringColor != null) {
      if (_lastFromIndex == null) {
        // Just started pouring
        _lastFromIndex = widget.controller.pouringFromIndex;
        _lastToIndex = widget.controller.pouringToIndex;
        _lastColor = widget.controller.pouringColor;
        _smoothedLanding = null;
        _pouredLayers = _targetLayers();
        _animationController.forward(from: 0.0);
        _flowController.repeat();
      } else {
        // Each segment of the pour hands over one more layer. That is the moment
        // liquid actually reaches the surface, so it is the moment to splash.
        final arrived = _targetLayers();
        if (arrived != null &&
            _pouredLayers != null &&
            arrived > _pouredLayers!) {
          _splashSeed++;
          _splashController.forward(from: 0.0);
        }
        _pouredLayers = arrived;
      }
    } else if (!widget.controller.isPouringLiquid) {
      if (_lastFromIndex != null) {
        // Just stopped pouring
        _flowController.stop();
        _pouredLayers = null;
        _animationController
            .animateTo(2.0, duration: const Duration(milliseconds: 260))
            .then((_) {
          if (mounted) {
            setState(() {
              _lastFromIndex = null;
              _lastToIndex = null;
              _lastColor = null;
              _animationController.value = 0.0;
            });
          }
        });
      }
    }
  }

  /// How many layers the tube being filled holds right now.
  int? _targetLayers() {
    final to = widget.controller.pouringToIndex;
    if (to == null || to >= widget.controller.tubes.length) return null;
    return widget.controller.tubes[to].colors.length;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGameStateChanged);
    _animationController.dispose();
    _flowController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The paint layer stays in the tree between pours on purpose. Resolving the
    // jet needs this widget's own render box, and a state that only appears for
    // the duration of a pour has no box on its very first frame - which is the
    // frame the jet has to start drawing on.
    return AnimatedBuilder(
      animation: Listenable.merge([
        _animationController,
        _flowController,
        _splashController,
      ]),
      builder: (context, child) {
        // Re-read every frame: the bottle is still settling into its hover for
        // the first beats of the pour, and a jet pinned to where it started
        // would come out of thin air beside the lip.
        final placement = _lastFromIndex == null
            ? null
            : _resolvePlacement();
        return IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: PouringStreamPainter(
              startPoint: placement?.mouth,
              endPoint: placement?.landing,
              color: _lastColor ?? Colors.transparent,
              animationProgress: _animationController.value,
              flowPhase: _flowController.value,
              streamWidth: placement?.width ?? 0.0,
              bendDirection: placement?.bend ?? 1.0,
              splash: placement == null ? 0 : _splashController.value,
              splashSeed: _splashSeed,
              ceiling: placement?.ceiling ?? 0.0,
            ),
          ),
        );
      },
    );
  }

  /// Works the jet out from the two tubes' own boxes. Returns null for the odd
  /// frame where a tube has no render box yet, which the next rebuild fixes.
  _StreamPlacement? _resolvePlacement() {
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) return null;

    final sourceBox = _tubeBox(_lastFromIndex!);
    final targetBox = _tubeBox(_lastToIndex!);
    // The board can be swapped out from under a pour - finishing the level
    // navigates away - and a detached box has no path to the overlay to
    // project along.
    if (sourceBox == null || targetBox == null) return null;

    final size = MediaQuery.sizeOf(context);
    final target = widget.controller.tubes[_lastToIndex!];
    final geometry = PourGeometry.forTubes(
      sourceTopLeft: sourceBox.localToGlobal(Offset.zero),
      sourceSize: sourceBox.size,
      targetTopLeft: targetBox.localToGlobal(Offset.zero),
      targetSize: targetBox.size,
      tilt: widget.controller.pourTiltAngle,
      bounds: Rect.fromLTWH(0, 0, size.width, size.height),
      targetLayers: target.colors.length,
      targetCapacity: target.capacity,
    );

    final landing = overlayBox.globalToLocal(geometry.landing);
    final width = targetBox.size.width * 0.11;
    // The neck of the tube being filled, in this overlay's units: a splash in a
    // nearly-full glass has nowhere to go but back down.
    final rim = overlayBox.globalToLocal(
      targetBox.localToGlobal(Offset(0, PourGeometry.rimInBox(targetBox.size))),
    );
    return _StreamPlacement(
      mouth: overlayBox.globalToLocal(geometry.mouth),
      landing: _easeSurface(landing),
      width: width,
      bend: geometry.tilt >= 0 ? 1.0 : -1.0,
      ceiling: rim.dy + width * 0.4,
    );
  }

  /// Each layer that arrives moves the surface a whole step, and a jet whose end
  /// snaps up the tube with it looks broken. The surface is chased, not jumped.
  Offset _easeSurface(Offset landing) {
    final previous = _smoothedLanding;
    final eased = previous == null || previous.dx != landing.dx
        ? landing
        : Offset(landing.dx, previous.dy + (landing.dy - previous.dy) * 0.35);
    _smoothedLanding = eased;
    return eased;
  }

  /// A tube's own box, or null when it is not on screen to be measured.
  RenderBox? _tubeBox(int index) {
    if (index < 0 || index >= widget.tubeKeys.length) return null;
    final box = widget.tubeKeys[index].currentContext?.findRenderObject()
        as RenderBox?;
    if (box == null || !box.attached) return null;
    return box;
  }
}

/// Where one pour's jet runs, in the overlay's own coordinates.
class _StreamPlacement {
  const _StreamPlacement({
    required this.mouth,
    required this.landing,
    required this.width,
    required this.bend,
    required this.ceiling,
  });

  final Offset mouth;
  final Offset landing;
  final double width;
  final double bend;

  /// The top of the neck the splash has to fit under.
  final double ceiling;
}
