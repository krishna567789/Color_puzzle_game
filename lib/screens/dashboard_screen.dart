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
  int _selectedIndex = 0;

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
                              icon: 'assets/icons/classicMode.png',
                              iconColor: Colors.blueAccent,
                              onTap: _navigateToGame,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Challenge',
                              subtitle: 'Mode',
                              icon: 'assets/icons/challengeMode.png',
                              iconColor: AppColors.goldCoin,
                              onTap: _navigateToGame,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Daily',
                              subtitle: 'Challenge',
                              icon: 'assets/icons/challengeMode.png',
                              iconColor: Colors.orangeAccent,
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
                              icon: 'assets/icons/challengeMode.png',
                              iconColor: Colors.purpleAccent,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Events\n',
                              subtitle: '',
                              icon: 'assets/icons/challengeMode.png',
                              iconColor: Colors.redAccent,
                              hasBadge: true,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Shop\n',
                              subtitle: '',
                              icon: 'assets/icons/challengeMode.png',
                              iconColor: Colors.lightBlue,
                              hasBadge: true,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeCard(
                              title: 'Awards\n',
                              subtitle: '',
                              icon:'assets/icons/challengeMode.png',
                              iconColor: AppColors.goldCoin,
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
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 2) {
              // Play button navigates to game
              _navigateToGame();
            }
          });
        },
      ),
    );
  }
}
