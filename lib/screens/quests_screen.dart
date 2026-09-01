import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/storage_service.dart';
import '../core/audio_service.dart';
import '../models/quest_model.dart';
import '../widgets/common/game_button.dart';
import '../widgets/common/coin_animation_overlay.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  int _coins = 0;
  int _gems = 0;
  int _loginStreak = 0;
  List<Quest> _quests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final coins = await StorageService.getCoins();
    final gems = await StorageService.getGems();
    
    // Login Streak Logic
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    
    String? lastLogin = await StorageService.getLastLoginDate();
    int streak = await StorageService.getLoginStreak();
    
    if (lastLogin != todayStr) {
      if (lastLogin == yesterdayStr) {
        streak++;
        if (streak > 7) streak = 1;
      } else if (lastLogin != null) {
        streak = 1;
      } else {
        streak = 1; // First time
      }
      await StorageService.setLoginStreak(streak);
      await StorageService.setLastLoginDate(todayStr);
    }
    
    // Load Quests
    final totalLevelsWon = await StorageService.getTotalLevelsWon();
    
    // We will hardcode some daily quests for demonstration based on total level progress
    final q1Data = await StorageService.getQuestData('daily_win_5');
    final q2Data = await StorageService.getQuestData('daily_play_3');
    
    setState(() {
      _coins = coins;
      _gems = gems;
      _loginStreak = streak;
      
      _quests = [
        Quest(
          id: 'daily_win_5',
          title: 'Master of Colors',
          description: 'Win 5 levels today',
          targetValue: 5,
          currentProgress: (totalLevelsWon % 5) + (q1Data['claimed'] ? 5 : 0), // Mock progress
          coinReward: 200,
          gemReward: 0,
          isClaimed: q1Data['claimed'],
        ),
        Quest(
          id: 'daily_play_3',
          title: 'Daily Challenger',
          description: 'Play 3 daily challenges',
          targetValue: 3,
          currentProgress: 1, // Mock progress
          coinReward: 100,
          gemReward: 1,
          isClaimed: q2Data['claimed'],
        ),
      ];
    });
  }

  Future<void> _claimReward(BuildContext context, Quest quest, Offset buttonPosition) async {
    if (!quest.isCompleted || quest.isClaimed) return;
    
    setState(() {
      _coins += quest.coinReward;
      _gems += quest.gemReward;
    });
    
    await StorageService.saveCoins(_coins);
    await StorageService.saveGems(_gems);
    await StorageService.saveQuestProgress(quest.id, true, quest.targetValue);
    
    CoinAnimationUtils.showCoinAnimation(
      context: context, 
      startOffset: buttonPosition, 
      endOffset: const Offset(300, 50), // roughly where the top coin icon is
    );
    AudioService.playWinSfx();
    
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'DAILY QUESTS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [Shadow(color: AppColors.primaryButton, blurRadius: 10)],
          ),
        ),
        centerTitle: true,
        actions: [
          _buildCurrencyDisplay(Icons.monetization_on, AppColors.goldCoin, _coins.toString()),
          const SizedBox(width: 8),
          _buildCurrencyDisplay(Icons.diamond, Colors.cyanAccent, _gems.toString()),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/wizard_room_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Streak Card
                _buildStreakCard(),
                
                const SizedBox(height: 20),
                
                // Quests List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _quests.length,
                    itemBuilder: (context, index) {
                      return _buildQuestCard(_quests[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDisplay(IconData icon, Color color, String amount) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withOpacity(0.6), Colors.deepPurple.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '7-DAY LOGIN STREAK',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              int day = index + 1;
              bool isClaimed = day <= _loginStreak;
              bool isToday = day == _loginStreak;
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isClaimed ? Colors.amber : Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday ? Colors.white : (isClaimed ? Colors.amberAccent : Colors.white24),
                        width: isToday ? 3 : 1,
                      ),
                      boxShadow: isClaimed ? [
                        BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10)
                      ] : [],
                    ),
                    child: Center(
                      child: isClaimed 
                        ? const Icon(Icons.check, color: Colors.black, size: 20)
                        : Text('$day', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(day == 7 ? '5' : '50', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      Icon(day == 7 ? Icons.diamond : Icons.monetization_on, color: day == 7 ? Colors.cyanAccent : Colors.yellow, size: 10),
                    ],
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestCard(Quest quest) {
    bool canClaim = quest.isCompleted && !quest.isClaimed;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E153A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canClaim ? Colors.greenAccent : Colors.white12,
          width: canClaim ? 2 : 1,
        ),
        boxShadow: canClaim ? [
          BoxShadow(color: Colors.greenAccent.withOpacity(0.2), blurRadius: 15),
        ] : [],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(
              quest.id.contains('win') ? Icons.emoji_events : Icons.play_circle_filled,
              color: Colors.orangeAccent,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quest.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                // Progress Bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: quest.progressPercent,
                          backgroundColor: Colors.black45,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            canClaim ? Colors.greenAccent : Colors.cyanAccent
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${quest.currentProgress > quest.targetValue ? quest.targetValue : quest.currentProgress}/${quest.targetValue}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // Claim / Rewards
          if (quest.isClaimed)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.check_circle, color: Colors.green, size: 36),
            )
          else if (canClaim)
            Builder(
              builder: (ctx) => GameButton(
                width: 90,
                height: 40,
                onTap: () {
                  final box = ctx.findRenderObject() as RenderBox;
                  final pos = box.localToGlobal(Offset.zero);
                  _claimReward(context, quest, pos);
                },
                color: Colors.green,
                child: const Text('CLAIM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (quest.coinReward > 0)
                  Row(
                    children: [
                      Text('${quest.coinReward}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 2),
                      const Icon(Icons.monetization_on, color: Colors.yellow, size: 14),
                    ],
                  ),
                if (quest.gemReward > 0)
                  Row(
                    children: [
                      Text('${quest.gemReward}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 2),
                      const Icon(Icons.diamond, color: Colors.cyanAccent, size: 14),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
