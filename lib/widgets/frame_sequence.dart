import 'package:flutter/material.dart';

/// Plays a pre-rendered Blender frame sequence, `frame_01.png` onwards.
///
/// The celebrations in this game are drawn with Flutter shapes, which read as
/// UI rather than as the bottle the player just filled. A short flipbook costs a
/// few hundred kilobytes and carries the real shading of the 3D model, and it
/// has no runtime cost the way a live GLB renderer would.
///
/// See tools/anim/render_victory_spin.py for how the frames are made.
class FrameSequence extends StatefulWidget {
  const FrameSequence({
    super.key,
    required this.directory,
    required this.frameCount,
    this.width,
    this.height,
    this.frameDuration = const Duration(milliseconds: 55),
    this.loop = true,
    this.fit = BoxFit.contain,
  });

  /// Asset folder holding the frames, without a trailing slash.
  final String directory;
  final int frameCount;
  final double? width;
  final double? height;
  final Duration frameDuration;
  final bool loop;
  final BoxFit fit;

  @override
  State<FrameSequence> createState() => _FrameSequenceState();
}

class _FrameSequenceState extends State<FrameSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.frameDuration * widget.frameCount,
    );
    if (widget.loop) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decoding sixteen PNGs while the sequence is already playing is what makes
    // a flipbook stutter, so every frame is pulled into the image cache first.
    for (var index = 1; index <= widget.frameCount; index++) {
      precacheImage(AssetImage(_path(index)), context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _path(int index) =>
      '${widget.directory}/frame_${index.toString().padLeft(2, '0')}.png';

  int get _frameIndex =>
      (_controller.value * widget.frameCount).floor().clamp(1, widget.frameCount);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Image.asset(
          _path(_frameIndex),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          // A missing frame should not take the win screen down with it.
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        );
      },
    );
  }
}
