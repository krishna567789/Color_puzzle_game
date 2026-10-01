import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/ad_manager.dart';
import '../frame_sequence.dart';
import 'coin_animation_overlay.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LevelCompleteDialog extends StatefulWidget {
  final int stars; // 1, 2, or 3 stars earned
  final int level;
  final int coinsEarned;
  final int gemsEarned;

  /// When this win closed a chapter, its name. The purse is already inside
  /// [coinsEarned] and [gemsEarned]; this only says where the extra came from.
  final String? chapterName;

  /// False on the last stage of a side mode's ladder, where there is no board
  /// left to take the player to. A Next that replays the board they just beat
  /// reads as a broken button, so the card drops it and says why.
  final bool hasNextStage;

  /// What the ribbon says, from the run that earned it: "LEVEL 42", "STAGE 7",
  /// "DAILY PUZZLE". A campaign level, a stage of a side mode's ladder and
  /// today's board are three different kinds of run, and only the controller
  /// knows which one this win came from. Null counts levels the way this card
  /// always did.
  final String? ribbon;

  /// Set instead of a payout line when the run earned stars but no purse -
  /// today's daily prize was already spent. The card shows this in place of the
  /// "YOU EARNED" box rather than a pair of zeroes.
  final String? rewardNote;
  final VoidCallback onNext;
  final VoidCallback onHome;

  const LevelCompleteDialog({
    super.key,
    required this.stars,
    required this.level,
    required this.coinsEarned,
    required this.gemsEarned,
    this.chapterName,
    this.hasNextStage = true,
    this.ribbon,
    this.rewardNote,
    required this.onNext,
    required this.onHome,
  });

  @override
  State<LevelCompleteDialog> createState() => _LevelCompleteDialogState();
}

class _LevelCompleteDialogState extends State<LevelCompleteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _starController;
  final GlobalKey _coinIconKey = GlobalKey();
  bool _isAnimatingCoin = false;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _starController.forward();
    });
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  void _onCollect(VoidCallback action) {
    if (_isAnimatingCoin) return;
    // A run that paid nothing has no coins to fly, and twelve that were not
    // won is a worse lie than a card that moves on at once.
    if (widget.coinsEarned <= 0) {
      action();
      return;
    }
    setState(() => _isAnimatingCoin = true);

    final startOffset = CoinAnimationUtils.getOffsetFromKey(_coinIconKey,
        fallback: Offset(MediaQuery.of(context).size.width / 2,
            MediaQuery.of(context).size.height / 2));
    final endOffset = const Offset(40, 50); // Target top left for game screen

    CoinAnimationUtils.showCoinAnimation(
      context: context,
      startOffset: startOffset,
      endOffset: endOffset,
      coinCount: widget.coinsEarned > 12 ? 12 : widget.coinsEarned,
      onComplete: () {
        if (mounted) {
          setState(() => _isAnimatingCoin = false);
          action();
        }
      },
    );
  }

  Widget _buildAnimatedStar(int starIndex, {bool isCenter = false}) {
    bool isEarned = widget.stars >= starIndex;

    double start = (starIndex - 1) * 0.2; // 0.0, 0.2, 0.4
    double end = start + 0.4; // 0.4, 0.6, 0.8

    Animation<double> scaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.0,
              end: 1.4,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
            weight: 40,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.4,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.elasticOut)),
            weight: 60,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _starController,
            curve: Interval(start, end, curve: Curves.linear),
          ),
        );

    return AnimatedBuilder(
      animation: _starController,
      builder: (context, child) {
        double scale = isEarned ? scaleAnim.value : 0.8;
        if (scale == 0.0 && isEarned) scale = 0.0;

        return Transform.scale(
          scale: scale,
          child: Transform.translate(
            offset: Offset(0, isCenter ? -20 : 0),
            child: Icon(
              Icons.star_rounded,
              size: 85,
              color: isEarned ? Colors.amber : Colors.black45,
              shadows: isEarned
                  ? [
                      const Shadow(
                        color: Colors.deepOrange,
                        blurRadius: 4,
                        offset: Offset(0, 3),
                      ),
                      const Shadow(
                        color: Colors.yellowAccent,
                        blurRadius: 15,
                        offset: Offset(0, 0),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = screenWidth * 0.9;
    if (dialogWidth > 400) dialogWidth = 400;
    // Its artwork is a fixed size, so a width-only ratio squeezes it out of
    // the box on narrow phones.
    double dialogHeight = math.max(dialogWidth * 1.45, 548.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      elevation: 0,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Spinning Sunburst Background (100% Flutter, 0 MB)
            Positioned.fill(
              child: Transform.scale(
                scale: 1.8,
                child: const SpinningSunburst(),
              ),
            ),

            // 2. 3D Wooden Board (100% Flutter)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B4226), Color(0xFF3E2312)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: const Color(0xFF9E6539), width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, 15),
                    blurRadius: 20,
                  ),
                  // 3D Highlight
                  BoxShadow(
                    color: Colors.white24,
                    offset: Offset(0, 2),
                    blurRadius: 0,
                    spreadRadius: -3,
                  ),
                ],
              ),
            ),

            // 3. The UI Overlay
            //
            // The board is a fixed box, but the content of it is text, and text
            // is as tall as the font the app actually ships with. A card sized
            // to today's metrics is one font change away from painting overflow
            // stripes across its own buttons, so the overlay is laid out at its
            // natural height and the whole thing scales down together when that
            // height is more than the board has. Never up: the board keeps its
            // size, and the sunburst behind it does not move.
            LayoutBuilder(
              builder: (context, board) => FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: board.maxHeight),
                  child: SizedBox(
                    width: board.maxWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // === TOP SECTION (Crown & Ribbon) ===
                        Column(
                          children: [
                            const SizedBox(height: 15),
                            // The bottle the player just filled, turning on its own. A
                            // rendered flipbook carries the game's own shading, where
                            // the trophy glyph this replaces read as generic UI.
                            const FrameSequence(
                              directory: 'assets/anim/victory_spin',
                              frameCount: 16,
                              width: 46,
                              height: 104,
                            ),

                            // Ribbon Placeholder
                            Container(
                              transform: Matrix4.translationValues(0, -10, 0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[600],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[900]!, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    offset: Offset(0, 4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                // The ribbon says what kind of run this was, and
                                // the wording is not under the card's control:
                                // 'DAILY PUZZLE' is wider than the banner on a
                                // narrow phone. Wrapping it to a second line
                                // would push everything under it down, so the
                                // words shrink instead.
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.ribbon ?? 'LEVEL ${widget.level}',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'COMPLETE!',
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // === MIDDLE SECTION (3D Stars using Flutter) ===
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildAnimatedStar(1),
                            const SizedBox(width: 5),
                            _buildAnimatedStar(2, isCenter: true),
                            const SizedBox(width: 5),
                            _buildAnimatedStar(3),
                          ],
                        ),

                        // === BOTTOM SECTION (Rewards & Buttons) ===
                        Column(
                          children: [
                            if (widget.chapterName != null) ...[
                              Text(
                                widget.chapterName!.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFFD166),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            // A daily whose prize is already spent pays nothing, and a
                            // card reading "+0 +0" looks like a broken reward rather
                            // than a finished run. The note says which it was.
                            if (widget.rewardNote != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                child: Text(
                                  widget.rewardNote!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD166),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else ...[
                              const Text(
                                'YOU EARNED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Rewards Box
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/blender/coin.png',
                                      key: _coinIconKey,
                                      width: 28,
                                      height: 28,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+${widget.coinsEarned}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 25),
                                    const Icon(
                                      Icons.diamond,
                                      color: Colors.purpleAccent,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+${widget.gemsEarned}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // The chapter line took this gap's room, so the card stays
                            // the height it was.
                            SizedBox(height: widget.chapterName == null ? 20 : 4),

                            // NEXT Button. A mode's ladder has an end, and pressing
                            // Next past it would deal the board the player just beat
                            // back to them, so the last stage shows Home alone.
                            if (widget.hasNextStage) ...[
                              ElevatedButton(
                                onPressed: () {
                                  AdManager.showInterstitialAd();
                                  _onCollect(() => widget.onNext());
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF64D224),
                                  minimumSize: const Size(220, 55),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 5,
                                ),
                                child: const Text(
                                  'NEXT',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),
                            ],

                            // HOME Button
                            ElevatedButton(
                              onPressed: () {
                                AdManager.showInterstitialAd();
                                _onCollect(() => widget.onHome());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2490D2),
                                minimumSize: const Size(220, 55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 5,
                              ),
                              child: const Text(
                                'HOME',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ).animate().scaleXY(
        begin: 0.5,
        end: 1.0,
        duration: 700.ms,
        curve: Curves.elasticOut,
      ).fadeIn(duration: 300.ms),
    );
  }
}

// ==========================================
// 🌟 100% Flutter Native Spinning Rays (0 MB)
// ==========================================
class SpinningSunburst extends StatefulWidget {
  const SpinningSunburst({super.key});

  @override
  State<SpinningSunburst> createState() => _SpinningSunburstState();
}

class _SpinningSunburstState extends State<SpinningSunburst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(painter: SunburstPainter()),
    );
  }
}

class SunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width > size.height ? size.width : size.height;

    final path = Path();
    int rays = 12; // 12 किरणें
    for (int i = 0; i < rays; i++) {
      double angle1 = (i * 2 * math.pi) / rays;
      double angle2 = ((i + 0.3) * 2 * math.pi) / rays;

      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + radius * math.cos(angle1),
        center.dy + radius * math.sin(angle1),
      );
      path.lineTo(
        center.dx + radius * math.cos(angle2),
        center.dy + radius * math.sin(angle2),
      );
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
