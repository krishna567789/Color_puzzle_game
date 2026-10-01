import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:color_puzzle_game/core/audio_service.dart';
import 'package:flutter/material.dart';
import '../content/content_repository.dart';
import '../core/app_colors.dart';
import '../core/progress_service.dart';
import '../core/storage_service.dart';
import '../game/rewards.dart';
import '../widgets/common/coin_animation_overlay.dart';
import '../widgets/frame_sequence.dart';
import 'package:flutter/services.dart';

/// Frames in each pre-rendered reward flipbook. Matches `FRAMES` in
/// tools/anim/render_spin_rewards.py, which test/flipbook_frames_test.dart
/// checks both ends of.
const int _flipbookFrames = 16;

/// One wedge, as the dial draws it and the dialog reports it.
class Reward {
  final String name;
  final int value;

  /// Which prize icon sits on the wedge: 'coin', 'gem' or 'try_again'.
  final String imageType;

  Reward(this.name, this.value, this.imageType);
}

class LuckySpinScreen extends StatefulWidget {
  const LuckySpinScreen({super.key});

  @override
  State<LuckySpinScreen> createState() => _LuckySpinScreenState();
}

class _LuckySpinScreenState extends State<LuckySpinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool _isSpinning = false;
  bool _canSpin = true;

  /// Paid re-spins still available today.
  int _extraSpinsLeft = 0;
  int _gems = 0;
  double _currentRotation = 0.0;

  /// The wedges, in the order the dial paints them.
  ///
  /// Content, so a prize can be retuned without a build - and so the same
  /// validator that refuses a shop row which delivers nothing can refuse a dial
  /// that mints coins. Every wedge is equally likely, because the wheel stops on
  /// a random angle rather than on a weighted table, which is the assumption
  /// behind the average payout the contract checks.
  late final List<Reward> _rewards = [
    for (final segment in ContentRepository.content.wheel)
      Reward(
        segment.label,
        segment.amount,
        switch (segment.kind) {
          'gems' => 'gem',
          'nothing' => 'try_again',
          _ => 'coin',
        },
      ),
  ];

  ui.Image? _coinImg;
  ui.Image? _gemImg;
  ui.Image? _tryAgainImg;

  @override
  void initState() {
    super.initState();
    _checkSpinAvailability();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSpinEnd();
      }
    });

    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final coinData = await rootBundle.load('assets/icon/spin_coin.png');
      final gemData = await rootBundle.load('assets/icon/spin_gem.png');
      final tryAgainData = await rootBundle.load(
        'assets/icon/spin_try_again.png',
      );

      _coinImg = await decodeImageFromList(coinData.buffer.asUint8List());
      _gemImg = await decodeImageFromList(gemData.buffer.asUint8List());
      _tryAgainImg = await decodeImageFromList(
        tryAgainData.buffer.asUint8List(),
      );

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading spin images: $e');
    }
  }

  Future<void> _checkSpinAvailability() async {
    final lastDate = await StorageService.getLastSpinDate();
    final usedExtraSpins = await StorageService.getDailyCounter(
      DailyStat.extraSpins,
    );
    final gems = await StorageService.getGems();
    if (!mounted) return;
    setState(() {
      _canSpin = lastDate != StorageService.todayKey;
      _extraSpinsLeft = (SpinReward.extraSpinsPerDay - usedExtraSpins).clamp(
        0,
        SpinReward.extraSpinsPerDay,
      );
      _gems = gems;
    });
  }

  /// Today's free turn, or a paid one after it.
  Future<void> _spin() async {
    if (_isSpinning) return;

    if (_canSpin) {
      setState(() => _isSpinning = true);
    } else {
      if (_extraSpinsLeft <= 0) {
        AudioService.playErrorSfx();
        return;
      }
      if (!await ProgressService.spend(gems: SpinReward.extraSpinGems)) {
        AudioService.playErrorSfx();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not enough gems for an extra spin.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      await StorageService.bumpDailyCounters({DailyStat.extraSpins: 1});
      setState(() {
        _extraSpinsLeft--;
        _gems -= SpinReward.extraSpinGems;
        _isSpinning = true;
      });
    }

    AudioService.playClickSfx();

    // Random rotation (min 5 full turns + random offset)
    double randomAngle = math.Random().nextDouble() * math.pi * 2;
    double totalRotation = (math.pi * 2 * 8) + randomAngle;

    _animation = Tween<double>(
      begin: _currentRotation,
      end: _currentRotation + totalRotation,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward(from: 0.0);
  }

  void _onSpinEnd() async {
    _currentRotation = _animation.value % (math.pi * 2);

    // Calculate which segment it landed on
    // 0 is top, 2*pi is full circle. Pointer is at the top.
    // Segments are clockwise.
    double segmentAngle = (math.pi * 2) / _rewards.length;
    // Offset by half segment to center the hit
    int index =
        ((math.pi * 2 - _currentRotation) / segmentAngle).floor() %
        _rewards.length;

    final reward = _rewards[index];

    // Save reward
    if (reward.value > 0) {
      await ProgressService.grant(
        coins: reward.imageType == 'coin' ? reward.value : 0,
        gems: reward.imageType == 'gem' ? reward.value : 0,
      );
    }

    // Only the free turn stamps the day; a paid re-spin must not eat tomorrow's.
    if (_canSpin) {
      await StorageService.setLastSpinDate(StorageService.todayKey);
    }
    await _checkSpinAvailability();
    if (!mounted) return;

    setState(() => _isSpinning = false);

    AudioService.playWinSfx();
    _showRewardDialog(context, reward);
  }

  void _showRewardDialog(BuildContext outerContext, Reward reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'LUCKY SPIN!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A coin turning through its own edge is the one celebration a
            // rotated PNG cannot fake, so the prizes that pay out are the
            // pre-rendered flipbooks. Only the dud stays a still.
            if (reward.imageType == 'try_again')
              Image.asset(
                'assets/icon/spin_try_again.png',
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              )
            else
              FrameSequence(
                directory: reward.imageType == 'coin'
                    ? 'assets/anim/spin_coin'
                    : 'assets/anim/spin_gem',
                frameCount: _flipbookFrames,
                width: 108,
                height: 108,
              ),
            const SizedBox(height: 16),
            Text(
              reward.value > 0
                  ? 'YOU WON ${reward.name.toUpperCase()}!'
                  : 'BETTER LUCK NEXT TIME!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (reward.imageType == 'coin') {
                  CoinAnimationUtils.showCoinAnimation(
                    context: outerContext,
                    startOffset: Offset(
                      MediaQuery.of(outerContext).size.width / 2,
                      MediaQuery.of(outerContext).size.height / 2,
                    ),
                    endOffset: const Offset(40, 50),
                    coinCount: 10,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'COLLECT',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // fallback
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Image with Blur
          Positioned.fill(
            child: Image.asset(
              'assets/images/wizard_room_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) {
                // Everything here used to be a fixed size (a 310dp wheel inside
                // a 400dp glow), which pushed the spin button off any phone
                // with less than ~700dp of viewport.
                const sidePadding = 16.0;
                // The app bar is drawn over the body, so leave room for the
                // back button.
                const topPadding = 44.0;
                const bottomPadding = 12.0;
                final availableWidth = bounds.maxWidth - sidePadding * 2;
                final wheelSize = math
                    .min(availableWidth * 0.88, bounds.maxHeight * 0.40)
                    .clamp(160.0, 310.0);
                final glowSize = wheelSize * 1.29;
                final gemSize = wheelSize * 0.194;
                // 310dp was the original wheel diameter, so the pointer keeps
                // its exact proportions there.
                final pointerScale = wheelSize / 310;
                final gap = (bounds.maxHeight * 0.045).clamp(12.0, 44.0);

                // The scroller is the safety net: on a device with larger text
                // or an unusually short viewport the column simply scrolls
                // instead of overflowing.
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    sidePadding,
                    topPadding,
                    sidePadding,
                    bottomPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: bounds.maxHeight - topPadding - bottomPadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'LUCKY SPIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(
                                color: AppColors.primaryButton,
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'SPIN THE WHEEL & WIN PRIZES!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: gap),

                        // The Wheel
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Wheel Outer Glow
                            Container(
                              width: glowSize,
                              height: glowSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.purpleAccent.withValues(alpha: 0.3),
                                    AppColors.primaryButton.withValues(
                                      alpha: 0.15,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.3, 0.6, 1.0],
                                ),
                              ),
                            ),

                            // Animated Wheel
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _animation.value,
                                  child: CustomPaint(
                                    size: Size(wheelSize, wheelSize),
                                    painter: WheelPainter(
                                      rewards: _rewards,
                                      coinImg: _coinImg,
                                      gemImg: _gemImg,
                                      tryAgainImg: _tryAgainImg,
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Center Magical Gem
                            Container(
                              width: gemSize,
                              height: gemSize,
                              decoration: BoxDecoration(
                                gradient: const RadialGradient(
                                  colors: [
                                    Colors.white,
                                    AppColors.goldCoin,
                                    Colors.orange,
                                  ],
                                  stops: [0.1, 0.6, 1.0],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.goldCoin.withValues(
                                      alpha: 0.8,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white70,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                // The coin that pays out, turning in the hub.
                                // Its frames are already in the bundle for the
                                // reward dialog, so the wheel gets a live
                                // centre for no extra bytes - and the gradient
                                // underneath stays as the socket it turns in.
                                child: FrameSequence(
                                  directory: 'assets/anim/spin_coin',
                                  frameCount: _flipbookFrames,
                                ),
                              ),
                            ),

                            // Golden Pointer
                            Positioned(
                              top: -20 * pointerScale,
                              child: Container(
                                width: 40 * pointerScale,
                                height: 50 * pointerScale,
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                                child: CustomPaint(painter: PointerPainter()),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: gap),

                        // Spin Button
                        GestureDetector(
                          onTap: _isSpinning ? null : _spin,
                          child: Container(
                            width: math.min(240.0, bounds.maxWidth - 48),
                            height: 65,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _canSpin
                                    ? [Colors.yellowAccent, Colors.orange]
                                    : _extraSpinsLeft > 0
                                    ? [
                                        Colors.cyanAccent,
                                        Colors.deepPurpleAccent,
                                      ]
                                    : [
                                        Colors.grey.shade800,
                                        Colors.grey.shade900,
                                      ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(32.5),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: _canSpin || _extraSpinsLeft > 0
                                      ? 0.8
                                      : 0.2,
                                ),
                                width: 2,
                              ),
                              boxShadow: [
                                if (_canSpin)
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.6),
                                    blurRadius: 25,
                                    offset: const Offset(0, 8),
                                  ),
                              ],
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    _canSpin
                                        ? 'SPIN NOW'
                                        : _extraSpinsLeft > 0
                                        ? 'EXTRA SPIN · ${SpinReward.extraSpinGems} '
                                              'GEMS'
                                        : 'NEXT SPIN TOMORROW',
                                    style: TextStyle(
                                      color: _canSpin || _extraSpinsLeft > 0
                                          ? Colors.black87
                                          : Colors.white54,
                                      fontSize: _canSpin ? 18 : 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.diamond,
                              color: Colors.cyanAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$_gems gems · $_extraSpinsLeft of '
                                '${SpinReward.extraSpinsPerDay} extra spins left',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Reward> rewards;
  final ui.Image? coinImg;
  final ui.Image? gemImg;
  final ui.Image? tryAgainImg;

  WheelPainter({
    required this.rewards,
    required this.coinImg,
    required this.gemImg,
    required this.tryAgainImg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);
    final double arcAngle = (math.pi * 2) / rewards.length;

    // A wedge's colour says what is in it before the number is readable: warm
    // for coins, purple for gems, grey for the dud. The dial now carries twice
    // the wedges it used to, so a fixed palette could no longer be one colour
    // per wedge.
    const coinWedges = [
      Colors.amberAccent,
      Colors.deepOrangeAccent,
      Colors.yellowAccent,
      Colors.orangeAccent,
    ];
    Color wedgeColor(int index) => switch (rewards[index].imageType) {
      'gem' => Colors.deepPurpleAccent,
      'try_again' => Colors.blueGrey,
      _ => coinWedges[index % coinWedges.length],
    };

    // How much room a wedge actually has, measured where the prize is drawn.
    // A dial of sixteen wedges is half as wide as the eight this used to carry,
    // so the art and the number follow the wedge instead of running over the
    // two either side of it.
    final spread = math.sin(arcAngle / 2) * 2;
    final iconSize = math.min(60.0, radius * 0.45 * spread * 1.15);
    final numberSize = math.min(18.0, radius * 0.78 * spread / 2.6);

    for (int i = 0; i < rewards.length; i++) {
      // Draw arc with vibrant color
      final paint = Paint()
        ..color = wedgeColor(i)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * arcAngle - math.pi / 2,
        arcAngle,
        true,
        paint,
      );

      // Draw inner border/glow for slice
      final innerBorderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * arcAngle - math.pi / 2,
        arcAngle,
        true,
        innerBorderPaint,
      );

      // Draw Icon and Text
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * arcAngle - math.pi / 2 + arcAngle / 2);

      // Draw Icon Image
      final ui.Image? img = switch (rewards[i].imageType) {
        'coin' => coinImg,
        'gem' => gemImg,
        _ => tryAgainImg,
      };

      if (img != null) {
        // Draw the image perfectly centered on the slice axis
        final rect = Rect.fromCenter(
          center: Offset(radius * 0.45, 0),
          width: iconSize,
          height: iconSize,
        );
        canvas.save();
        // Use screen blend mode to perfectly drop any faint dark artifacts
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          rect,
          Paint()..blendMode = BlendMode.screen,
        );
        canvas.restore();
      }

      // Draw Value Text only if value > 0 (Remove 'TRY AGAIN' text)
      if (rewards[i].value > 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${rewards[i].value}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: numberSize,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            radius * 0.78 - (textPainter.width / 2),
            -textPainter.height / 2, // Centered vertically on the slice axis
          ),
        );
      }
      canvas.restore();
    }

    // Outer Golden Border
    final outerPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Colors.amber, Colors.orange, Colors.yellow, Colors.amber],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final outerShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, radius, outerShadow);
    canvas.drawCircle(center, radius, outerPaint);

    // Inner Golden Rim
    final innerOuterPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 6, innerOuterPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.yellow, Colors.orange],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black54
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path()
      ..moveTo(size.width / 2, size.height) // Bottom point
      ..lineTo(0, 10) // Top left
      ..lineTo(size.width / 2, 0) // Top center dip
      ..lineTo(size.width, 10) // Top right
      ..close();

    canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);
    canvas.drawPath(path, paint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
