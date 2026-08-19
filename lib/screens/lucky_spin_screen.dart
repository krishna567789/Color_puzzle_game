import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/storage_service.dart';
import '../core/audio_service.dart';

class Reward {
  final String name;
  final int value;
  final IconData icon;
  final Color color;

  Reward(this.name, this.value, this.icon, this.color);
}

class LuckySpinScreen extends StatefulWidget {
  const LuckySpinScreen({super.key});

  @override
  State<LuckySpinScreen> createState() => _LuckySpinScreenState();
}

class _LuckySpinScreenState extends State<LuckySpinScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  bool _isSpinning = false;
  bool _canSpin = true;
  double _currentRotation = 0.0;
  
  final List<Reward> _rewards = [
    Reward('50 Coins', 50, Icons.monetization_on, Colors.amber),
    Reward('100 Coins', 100, Icons.monetization_on, Colors.orange),
    Reward('1 Gem', 1, Icons.diamond, Colors.purpleAccent),
    Reward('200 Coins', 200, Icons.monetization_on, Colors.amberAccent),
    Reward('2 Gems', 2, Icons.diamond, Colors.deepPurpleAccent),
    Reward('500 Coins', 500, Icons.monetization_on, Colors.yellowAccent),
    Reward('Try Again', 0, Icons.refresh, Colors.grey),
    Reward('50 Coins', 50, Icons.monetization_on, Colors.amber),
  ];

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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward(from: 0.0);
  }

  void _onSpinEnd() async {
    _currentRotation = _animation.value % (math.pi * 2);
    
    // Calculate which segment it landed on
    // 0 is top, 2*pi is full circle. Pointer is at the top.
    // Segments are clockwise.
    double segmentAngle = (math.pi * 2) / _rewards.length;
    // Offset by half segment to center the hit
    int index = ((math.pi * 2 - _currentRotation) / segmentAngle).floor() % _rewards.length;
    
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
    _showRewardDialog(reward);
  }

  void _showRewardDialog(Reward reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('LUCKY SPIN!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(reward.icon, color: reward.color, size: 80),
            const SizedBox(height: 16),
            Text(
              reward.value > 0 ? 'YOU WON ${reward.name.toUpperCase()}!' : 'BETTER LUCK NEXT TIME!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('COLLECT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('LUCKY SPIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SPIN THE WHEEL & WIN PRIZES!',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 40),
            
            // The Wheel
            Stack(
              alignment: Alignment.center,
              children: [
                // Wheel Outer Glow
                Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryButton.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 5),
                    ],
                  ),
                ),
                
                // Animated Wheel
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animation.value,
                      child: CustomPaint(
                        size: const Size(300, 300),
                        painter: WheelPainter(rewards: _rewards),
                      ),
                    );
                  },
                ),
                
                // Center Cap
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
                    border: Border.all(color: AppColors.primaryButton, width: 3),
                  ),
                  child: const Center(child: Icon(Icons.star, color: AppColors.goldCoin, size: 20)),
                ),
                
                // Pointer (Static)
                Positioned(
                  top: -10,
                  child: Transform.rotate(
                    angle: math.pi,
                    child: Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 50),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 60),
            
            // Spin Button
            GestureDetector(
              onTap: _spin,
              child: Container(
                width: 220,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _canSpin 
                      ? [AppColors.primaryButton, const Color(0xFF0080FF)] 
                      : [Colors.grey, Colors.blueGrey],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    if (_canSpin)
                      BoxShadow(color: AppColors.primaryButton.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Center(
                  child: Text(
                    _canSpin ? 'SPIN NOW' : 'NEXT SPIN TOMORROW',
                    style: TextStyle(
                      color: _canSpin ? Colors.black : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Reward> rewards;
  WheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);
    final double arcAngle = (math.pi * 2) / rewards.length;

    for (int i = 0; i < rewards.length; i++) {
      final paint = Paint()
        ..color = i % 2 == 0 ? AppColors.cardBackground : const Color(0xFF1E2855)
        ..style = PaintingStyle.fill;

      // Draw arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * arcAngle - math.pi / 2,
        arcAngle,
        true,
        paint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * arcAngle - math.pi / 2,
        arcAngle,
        true,
        borderPaint,
      );

      // Draw Icon/Text
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * arcAngle + arcAngle / 2);
      
      // Draw small dot/indicator for value
      final textPainter = TextPainter(
        text: TextSpan(
          text: rewards[i].value > 0 ? '${rewards[i].value}' : '?',
          style: TextStyle(color: rewards[i].color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(radius * 0.6, -textPainter.height / 2));
      
      canvas.restore();
    }
    
    // Outer border
    final outerPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, outerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
