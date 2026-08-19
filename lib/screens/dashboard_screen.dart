import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../widgets/dashboard/top_player_bar.dart';
import '../widgets/dashboard/mode_card.dart';
import '../widgets/dashboard/custom_bottom_nav.dart';
import '../controllers/game_controller.dart';
import '../core/storage_service.dart';
import '../core/audio_service.dart';
import 'game_screen.dart';
import 'shop_screen.dart';
import 'lucky_spin_screen.dart';
import 'achievements_screen.dart';
import 'events_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);
  int _userLevel = 1;
  int _coins = 0;
  int _gems = 0;
  
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    AudioService.playBGM();
    
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _entranceController.forward();
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

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  void _navigateToGame(GameMode mode) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(mode: mode)),
    );
    // Reload user data when returning from game
    _loadUserData();
  }

  Widget _buildAnimatedItem({required int index, required Widget child}) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(0.2 * index, 0.2 * index + 0.6, curve: Curves.easeOutBack),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            TopPlayerBar(
              level: _userLevel,
              coins: _coins,
              gems: _gems,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Center Logo with Entrance
                      _buildAnimatedItem(
                        index: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Image.asset(
                            'assets/images/splash.png',
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Top 3 Cards (Modes)
                      _buildAnimatedItem(
                        index: 1,
                        child: Row(
                          children: [
                            Expanded(
                              child: ModeCard(
                                title: 'Classic',
                                subtitle: 'Mode',
                                icon: 'assets/icon/classicMode.png',
                                gradient: AppColors.classicGradient,
                                onTap: () => _navigateToGame(GameMode.classic),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ModeCard(
                                title: 'Challenge',
                                subtitle: 'Mode',
                                icon: 'assets/icon/challengeMode.png',
                                gradient: AppColors.challengeGradient,
                                onTap: () => _navigateToGame(GameMode.challenge),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ModeCard(
                                title: 'Daily',
                                subtitle: 'Challenge',
                                icon: 'assets/icon/daily chalenge.png',
                                gradient: AppColors.dailyGradient,
                                onTap: () => _navigateToGame(GameMode.daily),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Bottom 4-Column Grid
                      _buildAnimatedItem(
                        index: 2,
                        child: Row(
                          children: [
                            Expanded(
                              child: ModeCard(
                                title: 'Lucky Spin',
                                subtitle: '',
                                icon: 'assets/icon/lucky_spin.png',
                                isVertical: false,
                                ctaText: 'SPIN NOW',
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LuckySpinScreen()),
                                  );
                                  _loadUserData();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ModeCard(
                                title: 'Events',
                                subtitle: '',
                                icon: 'assets/icon/events.png',
                                isVertical: false,
                                ctaText: 'JOIN NOW',
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const EventsScreen()),
                                  );
                                  _loadUserData();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ModeCard(
                                title: 'Shop',
                                subtitle: '',
                                icon: 'assets/icon/shop.png',
                                isVertical: false,
                                ctaText: 'BUY NOW',
                                hasBadge: true,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ShopScreen()),
                                  );
                                  _loadUserData();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ModeCard(
                                title: 'Achievements',
                                subtitle: '',
                                icon: 'assets/icon/achivement.png',
                                isVertical: false,
                                ctaText: 'VIEW ALL',
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AchievementsScreen()),
                                  );
                                  _loadUserData();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _selectedIndexNotifier,
        builder: (context, selectedIndex, child) {
          return CustomBottomNav(
            selectedIndex: selectedIndex,
            onItemSelected: (index) {
              _selectedIndexNotifier.value = index;
              if (index == 2) {
                _navigateToGame(GameMode.classic);
              }
            },
          );
        },
      ),
    );
  }
}
