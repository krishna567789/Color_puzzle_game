import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class ModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String icon;
  final VoidCallback onTap;
  final bool hasBadge;
  final bool isVertical;
  final List<Color>? gradient;
  final String? ctaText;

  const ModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.hasBadge = false,
    this.isVertical = true,
    this.gradient,
    this.ctaText,
  });

  @override
  State<ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<ModeCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_pressController);
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 3D Bottom Shadow
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: AppColors.cardShadow,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            // Main Card Body
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.cardHighlight.withValues(alpha: 0.5), 
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.gradient ?? [AppColors.cardBackground, AppColors.cardShadow],
                ),
                boxShadow: [
                  if (widget.gradient != null)
                    BoxShadow(
                      color: widget.gradient!.first.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isVertical) ...[
                    const SizedBox(height: 4),
                    // Image with Glow
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (widget.gradient?.first ?? Colors.white).withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        Image.asset(widget.icon, height: 140, fit: BoxFit.cover),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 16, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        shadows: [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)],
                      ),
                    ),
                    Text(
                      widget.subtitle.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7), 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 3D "PLAY" Button
                    _build3DButton(),
                  ] else ...[
                    // Small Grid style (Lucky Spin, etc.)
                    Image.asset(widget.icon, height: 44, fit: BoxFit.contain),
                    const SizedBox(height: 8),
                    Text(
                      widget.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 10, 
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2)],
                      ),
                    ),
                    if (widget.ctaText != null)
                      Text(
                        widget.ctaText!.toUpperCase(),
                        style: TextStyle(
                          color: widget.gradient != null ? widget.gradient!.first : AppColors.primaryButton,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (widget.hasBadge)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red, 
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 5)],
                  ),
                  child: const Center(
                    child: Text('!', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _build3DButton() {
    return Stack(
      children: [
        // Button Bottom Layer (Depth)
        Container(
          height: 38,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Button Top Layer
        Container(
          height: 34,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: const Center(
            child: Text(
              'PLAY',
              style: TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.w900, 
                fontSize: 14,
                shadows: [Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 2)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
