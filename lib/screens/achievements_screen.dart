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
      Achievement(id: 'win_1', title: 'Beginner', description: 'Win your first level', goal: 1, rewardCoins: 100),
      Achievement(id: 'win_10', title: 'Amateur', description: 'Win 10 levels', goal: 10, rewardCoins: 500, rewardGems: 1),
      Achievement(id: 'win_50', title: 'Professional', description: 'Win 50 levels', goal: 50, rewardCoins: 2000, rewardGems: 5),
      Achievement(id: 'win_100', title: 'Grandmaster', description: 'Win 100 levels', goal: 100, rewardCoins: 5000, rewardGems: 10),
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
    await StorageService.saveAchievementProgress(achievement.id, true, achievement.currentProgress);
    
    AudioService.playWinSfx();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Claimed ${achievement.rewardCoins} Coins ${achievement.rewardGems > 0 ? "and ${achievement.rewardGems} Gems" : ""}!'),
        backgroundColor: Colors.green,
      ),
    );
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
        title: const Text('ACHIEVEMENTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _achievements.length,
        itemBuilder: (context, index) {
          final a = _achievements[index];
          return _buildAchievementCard(a);
        },
      ),
    );
  }

  Widget _buildAchievementCard(Achievement a) {
    double progress = (a.currentProgress / a.goal).clamp(0.0, 1.0);
    bool canClaim = a.isCompleted && !a.isClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: canClaim ? AppColors.goldCoin.withOpacity(0.5) : AppColors.cardBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: a.isCompleted ? AppColors.goldCoin.withOpacity(0.1) : Colors.white10,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: a.isCompleted ? AppColors.goldCoin : Colors.white24,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      a.description,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (a.isClaimed)
                const Icon(Icons.check_circle, color: Colors.green, size: 28)
              else if (canClaim)
                ElevatedButton(
                  onPressed: () => _claimReward(a),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldCoin,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CLAIM', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(a.isCompleted ? AppColors.goldCoin : AppColors.primaryButton),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${a.currentProgress} / ${a.goal}',
                style: TextStyle(color: a.isCompleted ? AppColors.goldCoin : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (a.rewardCoins > 0) ...[
                    const Icon(Icons.monetization_on, color: AppColors.goldCoin, size: 14),
                    const SizedBox(width: 4),
                    Text(a.rewardCoins.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 12),
                  ],
                  if (a.rewardGems > 0) ...[
                    const Icon(Icons.diamond, color: AppColors.purpleGem, size: 14),
                    const SizedBox(width: 4),
                    Text(a.rewardGems.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
