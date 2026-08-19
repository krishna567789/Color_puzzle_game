import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../screens/settings_screen.dart';

class TopPlayerBar extends StatelessWidget {
  final int level;
  final int coins;
  final int gems;

  const TopPlayerBar({
    super.key,
    required this.level,
    required this.coins,
    required this.gems,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Avatar with Circular Progress
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E2855), width: 3),
                ),
              ),
              CircularProgressIndicator(
                value: (level % 10) / 10.0,
                strokeWidth: 3,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.goldCoin),
              ),
              ClipOval(
                child: Image.asset(
                  'assets/images/onboarding1.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Player & XP Bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Player',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.stars, color: AppColors.goldCoin, size: 16),
                    const SizedBox(width: 4),
                    Text('Level $level', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                // XP Progress Bar
                Container(
                  width: 100,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2855),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.6,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFB800), Color(0xFFFF8A00)]),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text('${(level * 100) + 865} / ${(level + 1) * 300}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
          // Currency Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1231),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2855)),
            ),
            child: Column(
              children: [
                _buildCurrencyRow(Icons.monetization_on, AppColors.goldCoin, coins.toString()),
                const SizedBox(height: 6),
                _buildCurrencyRow(Icons.diamond, AppColors.purpleGem, gems.toString()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Settings Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2855),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings, color: Colors.white70, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyRow(IconData icon, Color color, String amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(width: 6),
        const Icon(Icons.add_circle, color: Colors.white38, size: 16),
      ],
    );
  }
}
