import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int? _lastFromIndex;
  int? _lastToIndex;
  Color? _lastColor;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    widget.controller.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (widget.controller.pouringFromIndex != null &&
        widget.controller.pouringToIndex != null &&
        widget.controller.pouringColor != null) {
      if (_lastFromIndex == null) {
        // Just started pouring
        _lastFromIndex = widget.controller.pouringFromIndex;
        _lastToIndex = widget.controller.pouringToIndex;
        _lastColor = widget.controller.pouringColor;
        _animationController.forward(from: 0.0);
      }
    } else {
      if (_lastFromIndex != null) {
        // Just stopped pouring
        _animationController
            .animateTo(2.0, duration: const Duration(milliseconds: 300))
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

  @override
  void dispose() {
    widget.controller.removeListener(_onGameStateChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lastFromIndex == null || _lastToIndex == null || _lastColor == null) {
      return const SizedBox.shrink();
    }

    Offset? startPos;
    Offset? endPos;

    if (_lastFromIndex! < widget.tubeKeys.length &&
        _lastToIndex! < widget.tubeKeys.length) {
      final sourceContext = widget.tubeKeys[_lastFromIndex!].currentContext;
      final targetContext = widget.tubeKeys[_lastToIndex!].currentContext;

      if (sourceContext != null && targetContext != null) {
        final sourceBox = sourceContext.findRenderObject() as RenderBox;
        final targetBox = targetContext.findRenderObject() as RenderBox;

        final sourceGlobal = sourceBox.localToGlobal(Offset.zero);
        final targetGlobal = targetBox.localToGlobal(Offset.zero);
        
        final localRenderBox = context.findRenderObject() as RenderBox?;
        if (localRenderBox != null) {
           final localSource = localRenderBox.globalToLocal(sourceGlobal);
           final localTarget = localRenderBox.globalToLocal(targetGlobal);
           
           // Calculate mouth positions
           double tiltDir = _lastToIndex! > _lastFromIndex! ? 1.0 : -1.0;
           
           startPos = Offset(
             localSource.dx + (tiltDir > 0 ? 50 : 5) + (tiltDir > 0 ? 30 : -30),
             localSource.dy - 120, // Adjust for the jump height during animation
           );
           
           endPos = Offset(
             localTarget.dx + 27, // Center of target tube
             localTarget.dy + 5,  // Top of target tube
           );
        }
      }
    }

    if (startPos == null || endPos == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: PouringStreamPainter(
              startPoint: startPos,
              endPoint: endPos,
              color: _lastColor!,
              animationProgress: _animationController.value,
            ),
          ),
        );
      },
    );
  }
}
