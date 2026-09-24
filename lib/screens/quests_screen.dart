import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/numbers.dart';
import '../core/storage_service.dart';
import '../core/audio_service.dart';
import '../core/progress_service.dart';
import '../game/rewards.dart';
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

  /// Which of the seven circles on the card today is.
  int _streakDay = 1;
  List<Quest> _quests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final coins = await StorageService.getCoins();
    final gems = await StorageService.getGems();
    // The streak itself is advanced once per launch by ProgressService, so the
    // screen only reports it.
    final streak = await StorageService.getLoginStreak();
    final quests = await ProgressService.todaysQuests();

    setState(() {
      _coins = coins;
      _gems = gems;
      _loginStreak = streak;
      _streakDay = ProgressService.streakDay(streak);
      _quests = quests;
    });
  }

  Future<void> _claimReward(
    BuildContext context,
    Quest quest,
    Offset buttonPosition,
  ) async {
    if (!await ProgressService.claimQuest(quest)) return;
    if (!context.mounted) return;

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
          _buildCurrencyDisplay(
            Icons.monetization_on,
            AppColors.goldCoin,
            compactAmount(_coins),
          ),
          const SizedBox(width: 8),
          _buildCurrencyDisplay(
            Icons.diamond,
            Colors.cyanAccent,
            compactAmount(_gems),
          ),
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
            child: Container(color: Colors.black.withValues(alpha: 0.7)),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
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
          colors: [
            Colors.purple.withValues(alpha: 0.6),
            Colors.deepPurple.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.purpleAccent.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _loginStreak > 1
                ? '7-DAY STREAK · $_loginStreak DAYS IN A ROW'
                : '7-DAY LOGIN STREAK',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Seven cells at their natural size need ~252dp, which a 320dp phone
          // only has after the card's own margins, so the cells share the width
          // instead of each asking for 36dp.
          LayoutBuilder(
            builder: (context, bounds) {
              final cellSize = math.min(36.0, bounds.maxWidth / 7);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  int day = index + 1;
                  bool isClaimed = day <= _streakDay;
                  bool isToday = day == _streakDay;
                  return SizedBox(
                    width: cellSize,
                    child: Column(
                      children: [
                        Container(
                          width: cellSize,
                          height: cellSize,
                          decoration: BoxDecoration(
                            color: isClaimed ? Colors.amber : Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isToday
                                  ? Colors.white
                                  : (isClaimed
                                        ? Colors.amberAccent
                                        : Colors.white24),
                              width: isToday ? 3 : 1,
                            ),
                            boxShadow: isClaimed
                                ? [
                                    BoxShadow(
                                      color: Colors.amber.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: isClaimed
                                ? Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: cellSize * 0.55,
                                  )
                                : Text(
                                    '$day',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontWeight: FontWeight.bold,
                                      fontSize: cellSize * 0.36,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Quoted straight from the payout table, so the card
                        // cannot advertise a day that pays something else.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Builder(
                            builder: (context) {
                              final payout = StreakReward.forStreak(day);
                              final paysGems = payout.gems > 0;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${paysGems ? payout.gems : payout.coins}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    paysGems
                                        ? Icons.diamond
                                        : Icons.monetization_on,
                                    color: paysGems
                                        ? Colors.cyanAccent
                                        : Colors.yellow,
                                    size: 10,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestCard(Quest quest) {
    bool canClaim = quest.isCompleted && !quest.isClaimed;

    // A 320dp phone has ~288dp of card to spend on icon + title + rewards, so
    // the chrome shrinks before the text does.
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 380;
        final sideGap = compact ? 10.0 : 16.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E153A).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: canClaim ? Colors.greenAccent : Colors.white12,
              width: canClaim ? 2 : 1,
            ),
            boxShadow: canClaim
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      blurRadius: 15,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: EdgeInsets.all(compact ? 8 : 12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(
                  quest.id.contains('win')
                      ? Icons.emoji_events
                      : Icons.play_circle_filled,
                  color: Colors.orangeAccent,
                  size: compact ? 24 : 30,
                ),
              ),
              SizedBox(width: sideGap),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quest.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                                canClaim
                                    ? Colors.greenAccent
                                    : Colors.cyanAccent,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${quest.currentProgress > quest.targetValue ? quest.targetValue : quest.currentProgress}/${quest.targetValue}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: sideGap),

              // Claim / Rewards
              if (quest.isClaimed)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: compact ? 28 : 36,
                  ),
                )
              else if (canClaim)
                Builder(
                  builder: (ctx) => GameButton(
                    width: compact ? 74 : 90,
                    height: 40,
                    onTap: () {
                      final box = ctx.findRenderObject() as RenderBox;
                      final pos = box.localToGlobal(Offset.zero);
                      _claimReward(context, quest, pos);
                    },
                    color: Colors.green,
                    child: const Text(
                      'CLAIM',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 64 : 90),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (quest.coinReward > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '${quest.coinReward}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.yellow,
                              size: 14,
                            ),
                          ],
                        ),
                      if (quest.gemReward > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '${quest.gemReward}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.diamond,
                              color: Colors.cyanAccent,
                              size: 14,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
