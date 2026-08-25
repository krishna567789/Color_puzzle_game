import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/storage_service.dart';
import '../models/achievement_model.dart';
import '../core/audio_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _achievements = [];
  int _coins = 0;
  int _gems = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final totalWon = await StorageService.getTotalLevelsWon();
    final coins = await StorageService.getCoins();
    final gems = await StorageService.getGems();

    // Define achievement templates
    List<Achievement> templates = [
      Achievement(
        id: 'win_1',
        title: 'Beginner',
        description: 'Win your first level',
        goal: 1,
        rewardCoins: 100,
      ),
      Achievement(
        id: 'win_10',
        title: 'Amateur',
        description: 'Win 10 levels',
        goal: 10,
        rewardCoins: 500,
        rewardGems: 1,
      ),
      Achievement(
        id: 'win_50',
        title: 'Professional',
        description: 'Win 50 levels',
        goal: 50,
        rewardCoins: 2000,
        rewardGems: 5,
      ),
      Achievement(
        id: 'win_100',
        title: 'Grandmaster',
        description: 'Win 100 levels',
        goal: 100,
        rewardCoins: 5000,
        rewardGems: 10,
      ),
    ];

    List<Achievement> loaded = [];
    for (var a in templates) {
      final data = await StorageService.getAchievementData(a.id);
      a.isClaimed = data['claimed'] ?? false;
      // For these specific achievements, progress is totalLevelsWon
      a.currentProgress = totalWon;
      loaded.add(a);
    }

    setState(() {
      _achievements = loaded;
      _coins = coins;
      _gems = gems;
    });
  }

  Future<void> _claimReward(Achievement achievement) async {
    if (achievement.isClaimed || !achievement.isCompleted) return;

    setState(() {
      achievement.isClaimed = true;
      _coins += achievement.rewardCoins;
      _gems += achievement.rewardGems;
    });

    await StorageService.saveCoins(_coins);
    await StorageService.saveGems(_gems);
    await StorageService.saveAchievementProgress(
      achievement.id,
      true,
      achievement.currentProgress,
    );

    AudioService.playWinSfx();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Claimed ${achievement.rewardCoins} Coins ${achievement.rewardGems > 0 ? "and ${achievement.rewardGems} Gems" : ""}!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ACHIEVEMENTS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: [Shadow(color: AppColors.primaryButton, blurRadius: 20)],
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Magical Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/wizard_room_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.7)),
            ),
          ),

          SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                final a = _achievements[index];
                return _buildAchievementCard(a);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement a) {
    double progress = (a.currentProgress / a.goal).clamp(0.0, 1.0);
    bool canClaim = a.isCompleted && !a.isClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: canClaim
              ? AppColors.goldCoin
              : (a.isClaimed ? Colors.white24 : Colors.white12),
          width: canClaim ? 2 : 1,
        ),
        boxShadow: canClaim
            ? [
                BoxShadow(
                  color: AppColors.goldCoin.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ]
            : [],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: a.isCompleted
                            ? const LinearGradient(
                                colors: [
                                  Colors.amberAccent,
                                  AppColors.goldCoin,
                                ],
                              )
                            : const LinearGradient(
                                colors: [Colors.white10, Colors.black26],
                              ),
                        boxShadow: [
                          if (a.isCompleted)
                            BoxShadow(
                              color: AppColors.goldCoin.withValues(alpha: 0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: a.isCompleted
                          ? Image.asset(
                              'assets/icon/trophy_3d.png',
                              width: 36,
                              height: 36,
                            )
                          : Image.asset(
                              'assets/icon/trophy_3d.png',
                              width: 36,
                              height: 36,
                              color: Colors.white24,
                              colorBlendMode: BlendMode.modulate,
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Titles
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 1.2,
                              shadows: a.isCompleted
                                  ? [
                                      const Shadow(
                                        color: AppColors.goldCoin,
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action / Status
                    if (a.isClaimed)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 28,
                        ),
                      )
                    else if (canClaim)
                      ElevatedButton(
                        onPressed: () => _claimReward(a),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldCoin,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 10,
                          shadowColor: AppColors.goldCoin,
                        ),
                        child: const Text(
                          'CLAIM',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Progress Bar
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black45,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: a.isCompleted
                                    ? [Colors.amber, AppColors.goldCoin]
                                    : [
                                        Colors.cyanAccent,
                                        AppColors.primaryButton,
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: a.isCompleted
                                      ? AppColors.goldCoin
                                      : AppColors.primaryButton,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${a.currentProgress} / ${a.goal}',
                      style: TextStyle(
                        color: a.isCompleted
                            ? Colors.amberAccent
                            : Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Row(
                      children: [
                        if (a.rewardCoins > 0) ...[
                          Image.asset(
                            'assets/icon/coin_3d.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            a.rewardCoins.toString(),
                            style: const TextStyle(
                              color: AppColors.goldCoin,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (a.rewardGems > 0) ...[
                          Image.asset(
                            'assets/icon/gem_3d.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            a.rewardGems.toString(),
                            style: const TextStyle(
                              color: AppColors.purpleGem,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
