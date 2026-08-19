import 'package:flutter/material.dart';

class GameButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color color;
  final double width;
  final double height;

  const GameButton({
    super.key,
    required this.onTap,
    required this.child,
    this.color = const Color(0xFF00C2FF),
    this.width = 200,
    this.height = 55,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _push = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _push = 5.0),
      onTapUp: (_) {
        setState(() => _push = 0.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _push = 0.0),
      child: SizedBox(
        width: widget.width,
        height: widget.height + 5,
        child: Stack(
          children: [
            // Shadow / Bottom Part
            Positioned(
              bottom: 0,
              child: Container(
                width: widget.width,
                height: widget.height - 2,
                decoration: BoxDecoration(
                  color: Color.lerp(widget.color, Colors.black, 0.4),
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),
            ),
            // Top Part
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              top: _push,
              child: Container(
                width: widget.width,
                height: widget.height - 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(widget.color, Colors.white, 0.3)!,
                      widget.color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  border: Border.all(color: Colors.white24, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(child: widget.child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
