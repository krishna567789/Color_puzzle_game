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
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Ripple 1
                _buildRipple(1.0, 0.5, Colors.cyanAccent),
                // Ripple 2
                _buildRipple(0.6, 0.8, Colors.white70),
              ],
            );
          },
        ),
        // Hand (Static Position with Glow)
        const Icon(
          Icons.pan_tool_alt,
          color: Colors.white,
          size: 50,
          shadows: [
            Shadow(color: Colors.cyanAccent, blurRadius: 15),
            Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
      ],
    );
  }

  Widget _buildRipple(double startDelay, double maxOpacity, Color color) {
    double rawProgress = (_controller.value + startDelay) % 1.0;
    
    // Apply easing curves for smooth, natural animation
    double sizeProgress = Curves.easeOutQuart.transform(rawProgress);
    double fadeProgress = Curves.easeOut.transform(1 - rawProgress);
    
    return Opacity(
      opacity: fadeProgress * maxOpacity,
      child: Container(
        width: 40 + (sizeProgress * 100),
        height: 40 + (sizeProgress * 100),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color, 
            width: 2.0 + (fadeProgress * 3.0), // Border gets thinner as it expands
          ),
        ),
      ),
    );
  }
}
