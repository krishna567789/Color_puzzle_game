import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:color_puzzle_game/core/audio_service.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/storage_service.dart';
import '../widgets/common/coin_animation_overlay.dart';
import 'package:flutter/services.dart';

class Reward {
  final String name;
  final int value;
  final String imageType; // 'coin', 'gem', or 'try_again'
  final Color color;

  Reward(this.name, this.value, this.imageType, this.color);
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
  double _currentRotation = 0.0;

  final List<Reward> _rewards = [
    Reward('50 Coins', 50, 'coin', Colors.amber),
    Reward('100 Coins', 100, 'coin', Colors.orange),
    Reward('1 Gem', 1, 'gem', Colors.purpleAccent),
    Reward('200 Coins', 200, 'coin', Colors.amberAccent),
    Reward('2 Gems', 2, 'gem', Colors.deepPurpleAccent),
    Reward('500 Coins', 500, 'coin', Colors.yellowAccent),
    Reward('Try Again', 0, 'try_again', Colors.grey),
    Reward('50 Coins', 50, 'coin', Colors.amber),
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
    final today = DateTime.now().toIso8601String().split('T')[0];
    setState(() {
      _canSpin = lastDate != today;
    });
  }

  void _spin() {
    if (_isSpinning || !_canSpin) return;

    setState(() {
      _isSpinning = true;
    });

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
      if (reward.name.contains('Gem')) {
        int gems = await StorageService.getGems();
        await StorageService.saveGems(gems + reward.value);
      } else {
        int coins = await StorageService.getCoins();
        await StorageService.saveCoins(coins + reward.value);
      }
    }

    // Save spin date
    final today = DateTime.now().toIso8601String().split('T')[0];
    await StorageService.setLastSpinDate(today);

    setState(() {
      _isSpinning = false;
      _canSpin = false;
    });

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
            ClipOval(
              child: Image.asset(
                reward.imageType == 'coin'
                    ? 'assets/icon/spin_coin.png'
                    : (reward.imageType == 'gem'
                          ? 'assets/icon/spin_gem.png'
                          : 'assets/icon/spin_try_again.png'),
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              ),
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
                if (reward.value > 0 && reward.name.contains('Coins')) {
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
            child: Center(
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
                        Shadow(color: AppColors.primaryButton, blurRadius: 20),
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
                  const SizedBox(height: 50),

                  // The Wheel
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Wheel Outer Glow
                      Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.purpleAccent.withValues(alpha: 0.3),
                              AppColors.primaryButton.withValues(alpha: 0.15),
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
                              size: const Size(310, 310),
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
                        width: 60,
                        height: 60,
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
                              color: AppColors.goldCoin.withValues(alpha: 0.8),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.white70, width: 2),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 36,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),

                      // Golden Pointer
                      Positioned(
                        top: -20,
                        child: Container(
                          width: 40,
                          height: 50,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.5),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          child: CustomPaint(painter: PointerPainter()),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 70),

                  // Spin Button
                  GestureDetector(
                    onTap: _spin,
                    child: Container(
                      width: 240,
                      height: 65,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _canSpin
                              ? [Colors.yellowAccent, Colors.orange]
                              : [Colors.grey.shade800, Colors.grey.shade900],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: _canSpin ? 0.8 : 0.2,
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
                        child: Text(
                          _canSpin ? 'SPIN NOW' : 'NEXT SPIN TOMORROW',
                          style: TextStyle(
                            color: _canSpin ? Colors.black87 : Colors.white54,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

    final sliceColors = [
      Colors.purple.shade800,
      Colors.deepOrange.shade700,
      Colors.teal.shade800,
      Colors.pink.shade800,
      Colors.blue.shade800,
      Colors.amber.shade800,
      Colors.blueGrey.shade800,
      Colors.red.shade800,
    ];

    for (int i = 0; i < rewards.length; i++) {
      // Draw arc with vibrant color
      final paint = Paint()
        ..color = sliceColors[i % sliceColors.length]
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
      ui.Image? img;
      if (rewards[i].imageType == 'coin')
        img = coinImg;
      else if (rewards[i].imageType == 'gem')
        img = gemImg;
      else
        img = tryAgainImg;

      if (img != null) {
        // Draw the image perfectly centered on the slice axis
        final rect = Rect.fromCenter(
          center: Offset(radius * 0.45, 0),
          width: 60,
          height: 60,
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            radius * 0.75 - (textPainter.width / 2),
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
