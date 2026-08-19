import 'package:flutter/material.dart';

class HandIndicator extends StatefulWidget {
  const HandIndicator({super.key});

  @override
  State<HandIndicator> createState() => _HandIndicatorState();
}

class _HandIndicatorState extends State<HandIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ripple 1
            _buildRipple(1.0, 0.5, Colors.cyanAccent),
            // Ripple 2
            _buildRipple(0.6, 0.8, Colors.white70),
            // Hand (Static Position with Glow)
            const Icon(
              Icons.touch_app,
              color: Colors.white,
              size: 50,
              shadows: [
                Shadow(color: Colors.cyanAccent, blurRadius: 15),
                Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRipple(double startAt, double opacity, Color color) {
    double progress = (_controller.value + startAt) % 1.0;
    return Opacity(
      opacity: (1 - progress) * opacity,
      child: Container(
        width: 30 + (progress * 100),
        height: 30 + (progress * 100),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
        ),
      ),
    );
  }
}
