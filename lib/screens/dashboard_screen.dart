import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/ad_manager.dart';
import '../widgets/dashboard/top_player_bar.dart';
import '../widgets/dashboard/mode_card.dart';
import '../controllers/game_controller.dart';
import '../core/storage_service.dart';
import '../core/audio_service.dart';
import '../widgets/common/game_button.dart';
import '../widgets/common/bouncing_button.dart';
import 'game_screen.dart';
import 'shop_screen.dart';
import 'lucky_spin_screen.dart';
import 'achievements_screen.dart';
import 'events_screen.dart';
import 'level_map_screen.dart';
import 'quests_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _userLevel = 1;
  int _coins = 0;
  int _gems = 0;

  late AnimationController _entranceController;
  late AnimationController _bubbleController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    AudioService.playBGM();
    _loadBannerAd();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _entranceController.forward();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  Future<void> _loadUserData() async {
    final level = await StorageService.getLevel();
    final coins = await StorageService.getCoins();
    final gems = await StorageService.getGems();
    setState(() {
      _userLevel = level;
      _coins = coins;
      _gems = gems;
    });
  }

  void _loadBannerAd() {
    if (kIsWeb) return;
    _bannerAd = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _entranceController.dispose();
    _bubbleController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateToGame(GameMode mode) async {
    if (mode == GameMode.classic) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LevelMapScreen()),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GameScreen(mode: mode)),
      );
    }
    // Reload user data when returning
    _loadUserData();
  }

  Widget _buildAnimatedItem({required int index, required Widget child}) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(
          0.1 * index,
          0.1 * index + 0.6,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildSideIcon({
    required String title,
    required String icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: SizedBox(
        width: 75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Floating Icon
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.8),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Image.asset(icon, height: 60, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            // Highlighted Text Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: gradient.last.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required String title,
    required String icon,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    return BouncingButton(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 75,
            height: 85,
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: 0.4,
              ), // Dark translucent background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(icon, height: 42, fit: BoxFit.contain),
                    const SizedBox(height: 6),
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasBadge)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 4),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Stunning 2D Wizard Room Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/wizard_room_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Magic Bubbles & Glow Particles over the cauldron
          Positioned.fill(
            child: CustomPaint(
              painter: MagicBubblesPainter(animation: _bubbleController),
            ),
          ),
          // Dark Overlay for UI readability at the top/bottom
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                // Top Player Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TopPlayerBar(
                    level: _userLevel,
                    coins: _coins,
                    gems: _gems,
                  ),
                ),

                // Logo (Smaller, positioned higher)
                Positioned(
                  top: 90,
                  left: 0,
                  right: 0,
                  child: _buildAnimatedItem(
                    index: 0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _floatingController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, math.sin(_floatingController.value * math.pi) * 10),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/images/splash.png',
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                // Left Side (Challenge)
                Positioned(
                  left: 16,
                  top: MediaQuery.of(context).size.height * 0.28,
                  child: _buildAnimatedItem(
                    index: 1,
                    child: _buildSideIcon(
                      title: 'Challenge\n(Moves)',
                      icon: 'assets/icon/challengeMode.png',
                      gradient: AppColors.challengeGradient,
                      onTap: () => _navigateToGame(GameMode.challenge),
                    ),
                  ),
                ),

                // Right Side (Time Attack)
                Positioned(
                  right: 16,
                  top: MediaQuery.of(context).size.height * 0.28,
                  child: _buildAnimatedItem(
                    index: 1,
                    child: _buildSideIcon(
                      title: 'Time\nAttack',
                      icon: 'assets/icon/classicMode.png',
                      gradient: AppColors.timeAttackGradient,
                      onTap: () => _navigateToGame(GameMode.timeAttack),
                    ),
                  ),
                ),

                // Left Side (Daily) - Below Challenge
                Positioned(
                  left: 16,
                  top: MediaQuery.of(context).size.height * 0.45,
                  child: _buildAnimatedItem(
                    index: 2,
                    child: _buildSideIcon(
                      title: 'Daily',
                      icon: 'assets/icon/daily chalenge.png',
                      gradient: AppColors.dailyGradient,
                      onTap: () => _navigateToGame(GameMode.daily),
                    ),
                  ),
                ),

                // Bottom Center: Main PLAY (Classic)
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: _buildAnimatedItem(
                    index: 3,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(37.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF5CD615).withValues(alpha: 0.6 * _pulseController.value),
                                  blurRadius: 20 * _pulseController.value,
                                  spreadRadius: 5 * _pulseController.value,
                                ),
                              ],
                            ),
                            child: Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.03),
                              child: child,
                            ),
                          );
                        },
                        child: GameButton(
                          width: 240,
                          height: 75,
                          color: const Color(0xFF5CD615), // Magical vibrant green
                          onTap: () => _navigateToGame(GameMode.classic),
                          child: const Text(
                            'PLAY CLASSIC',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Row (Lucky Spin, Events, Shop, Achievements)
                Positioned(
                  bottom: _isBannerAdLoaded ? 60 : 5,
                  left: 10,
                  right: 10,
                  child: _buildAnimatedItem(
                    index: 4,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildBottomButton(
                            title: 'Lucky Spin',
                            icon: 'assets/icon/lucky_spin.png',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LuckySpinScreen(),
                              ),
                            );
                            _loadUserData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildBottomButton(
                          title: 'Events',
                          icon: 'assets/icon/events.png',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EventsScreen(),
                              ),
                            );
                            _loadUserData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildBottomButton(
                          title: 'Quests',
                          icon: 'assets/icon/daily chalenge.png',
                          hasBadge: true,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QuestsScreen(),
                              ),
                            );
                            _loadUserData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildBottomButton(
                          title: 'Shop',
                          icon: 'assets/icon/shop.png',
                          hasBadge: true,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ShopScreen(),
                              ),
                            );
                            _loadUserData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildBottomButton(
                          title: 'Trophies',
                          icon: 'assets/icon/achivement.png',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AchievementsScreen(),
                              ),
                            );
                            _loadUserData();
                          },
                        ),
                      ],
                    ),
                    ),
                  ),
                ),

                if (_isBannerAdLoaded && _bannerAd != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SafeArea(
                        child: SizedBox(
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MagicBubblesPainter extends CustomPainter {
  final Animation<double> animation;
  MagicBubblesPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // Fixed seed for consistent bubble paths

    // Cauldron position is roughly center bottom
    final centerX = size.width / 2;
    final startY = size.height * 0.69; // Exactly on the liquid surface

    // Liquid ellipse dimensions (to keep bubbles inside the rim)
    final surfaceWidth = 140.0;
    final surfaceHeight = 24.0;

    // 1. Boiling Surface Bubbles (stay strictly inside the liquid and pop)
    for (int i = 0; i < 20; i++) {
      double offsetX = (random.nextDouble() - 0.5) * surfaceWidth;
      double offsetY = (random.nextDouble() - 0.5) * surfaceHeight;
      double maxRadius = random.nextDouble() * 9 + 3;

      double phase = random.nextDouble();
      double speed = random.nextDouble() * 1.5 + 0.5;
      double t = (animation.value * speed + phase) % 1.0;

      // Bubbles grow and pop (sine wave scale)
      double scale = math.sin(t * math.pi);
      double currentRadius = maxRadius * scale;
      double opacity = scale.clamp(0.0, 1.0);

      if (currentRadius > 0.5) {
        final paint = Paint()
          ..color = Colors.purpleAccent.withValues(alpha: opacity * 0.8)
          ..style = PaintingStyle.fill;

        final innerPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.7)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(centerX + offsetX, startY + offsetY),
          currentRadius,
          paint,
        );
        canvas.drawCircle(
          Offset(
            centerX + offsetX - currentRadius * 0.3,
            startY + offsetY - currentRadius * 0.3,
          ),
          currentRadius * 0.25,
          innerPaint,
        );
      }
    }

    // 2. Flying Bubbles (spawn ONLY from liquid surface and float up)
    for (int i = 0; i < 25; i++) {
      double offsetX = (random.nextDouble() - 0.5) * surfaceWidth;
      double offsetY = (random.nextDouble() - 0.5) * surfaceHeight;
      double speed = random.nextDouble() * 0.5 + 0.5;
      double maxRadius = random.nextDouble() * 7 + 3;

      double phase = random.nextDouble();
      double t = (animation.value * speed + phase) % 1.0;

      // Bubble floats up and sways
      double currentY = (startY + offsetY) - (t * 400); // Float up from surface
      double currentX = centerX + offsetX + math.sin(t * math.pi * 4) * 20;

      // Fade out as it goes higher
      double opacity = (1.0 - t).clamp(0.0, 1.0);

      // Draw glowing bubble
      final paint = Paint()
        ..color = Colors.purpleAccent.withValues(alpha: opacity * 0.8)
        ..style = PaintingStyle.fill;

      final innerPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(currentX, currentY),
        maxRadius * (0.5 + 0.5 * math.sin(t * math.pi)),
        paint,
      );
      canvas.drawCircle(
        Offset(currentX - maxRadius * 0.2, currentY - maxRadius * 0.2),
        maxRadius * 0.2,
        innerPaint,
      );

      // Glowing particles/sparks around the room
      if (i % 3 == 0) {
        double sparkX = random.nextDouble() * size.width;
        double sparkY =
            (random.nextDouble() * size.height - (t * 200)) % size.height;
        final sparkPaint = Paint()
          ..color = Colors.amberAccent.withValues(
            alpha: opacity * random.nextDouble(),
          )
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(sparkX, sparkY),
          random.nextDouble() * 3,
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
