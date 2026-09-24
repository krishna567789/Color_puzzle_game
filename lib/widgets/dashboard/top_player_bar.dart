import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/numbers.dart';
import '../../game/rewards.dart';
import '../../screens/settings_screen.dart';

/// The player's own level, not the level they are playing: both the ring and
/// the bar read the same [PlayerLevel] fraction, so they cannot disagree.
class TopPlayerBar extends StatelessWidget {
  final PlayerLevel progress;
  final int coins;
  final int gems;

  const TopPlayerBar({
    super.key,
    required this.progress,
    required this.coins,
    required this.gems,
  });

  @override
  Widget build(BuildContext context) {
    // On a 320dp phone the bar has to give the player block room for the
    // currency pills, so every fixed size here is a fraction of one scale
    // factor instead of a literal.
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 360;
        final avatarSize = compact ? 44.0 : 54.0;
        final coinIconSize = compact ? 18.0 : 22.0;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpace.m : AppSpace.l,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Avatar with Circular Progress
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E2855),
                        width: 3,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: avatarSize,
                    height: avatarSize,
                    child: CircularProgressIndicator(
                      value: progress.fraction,
                      strokeWidth: 3,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.goldCoin,
                      ),
                    ),
                  ),
                  ClipOval(
                    child: Image.asset(
                      'assets/images/onboarding1.png',
                      width: avatarSize - 10,
                      height: avatarSize - 10,
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.stars,
                          color: AppColors.goldCoin,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Level ${progress.number}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // XP Progress Bar
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2855),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.fraction,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB800), Color(0xFFFF8A00)],
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${progress.xpIntoLevel} / ${progress.xpForNextLevel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // Currency Container
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1231),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E2855)),
                ),
                child: Column(
                  children: [
                    _buildCurrencyRow(
                      Image.asset(
                        'assets/icon/coin_3d.png',
                        width: coinIconSize,
                        height: coinIconSize,
                      ),
                      compactAmount(coins),
                    ),
                    const SizedBox(height: 6),
                    _buildCurrencyRow(
                      Image.asset(
                        'assets/icon/gem_3d.png',
                        width: coinIconSize,
                        height: coinIconSize,
                      ),
                      compactAmount(gems),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Settings Button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2855),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrencyRow(Widget icon, String amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 68),
          child: Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.add_circle, color: Colors.white38, size: 16),
      ],
    );
  }
}
