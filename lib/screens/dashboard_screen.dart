import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../widgets/dashboard/top_player_bar.dart';
import '../widgets/dashboard/mode_card.dart';
import '../widgets/dashboard/custom_bottom_nav.dart';
import 'game_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  void _navigateToGame() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TopPlayerBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Center Logo
                      Image.asset(
                        'assets/images/splash.png',
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                      // Top 3 Cards
                      Row(
                        children: [
                          Expanded(
                            child: ModeCard(
                              title: 'Classic',
                              subtitle: 'Mode',
                              icon: 'assets/icon/classicMode.png',

                              onTap: _navigateToGame,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Challenge',
                              subtitle: 'Mode',
                              icon: 'assets/icon/challengeMode.png',

                              onTap: _navigateToGame,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Daily',
                              subtitle: 'Challenge',
                              icon: 'assets/icon/daily chalenge.png',

                              onTap: _navigateToGame,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Bottom 4 Cards (Grid)
                      Row(
                        children: [
                          Expanded(
                            child: ModeCard(
                              title: 'Lucky\nSpin',
                              subtitle: '',
                              icon: 'assets/icon/lucky_spin.png',
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Events\n',
                              subtitle: '',
                              icon: 'assets/icon/challengeMode.png',

                              hasBadge: true,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Shop\n',
                              subtitle: '',
                              icon: 'assets/icon/challengeMode.png',

                              hasBadge: true,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Awards\n',
                              subtitle: '',
                              icon: 'assets/icon/challengeMode.png',

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
                _navigateToGame();
              }
            },
          );
        },
      ),
    );
  }
}
