import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../widgets/dashboard/top_player_bar.dart';
import '../widgets/dashboard/mode_card.dart';
import '../widgets/dashboard/custom_bottom_nav.dart';
import '../controllers/game_controller.dart';
import '../core/storage_service.dart';
import 'game_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);
  int _userLevel = 1;
  int _coins = 0;
  int _gems = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
                      // Center Logo with extra padding/leaves effect (simulated)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Image.asset(
                          'assets/images/splash.png',
                          height: 280,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Top 3 Cards (Modes)
                      Row(
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
                      const SizedBox(height: 20),
                      // Bottom 4-Column Grid
                      Row(
                        children: [
                          Expanded(
                            child: ModeCard(
                              title: 'Lucky Spin',
                              subtitle: '',
                              icon: 'assets/icon/lucky_spin.png',
                              isVertical: false,
                              ctaText: 'SPIN NOW',
                              onTap: () {},
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
                              onTap: () {},
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
                              onTap: () {},
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
                              onTap: () {},
                            ),
                          ),
                        ],
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
                // Play button navigates to game
                _navigateToGame(GameMode.classic);
              }
            },
          );
        },
      ),
    );
  }
}
