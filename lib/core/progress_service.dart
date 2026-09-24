import '../game/quests.dart';
import '../game/rewards.dart';
import '../models/quest_model.dart';
import 'analytics_service.dart';
import 'storage_service.dart';

/// Everything that accrues outside a single board: the login streak, today's
/// quest progress and the coin and gem grants that come with them.
///
/// Screens call these instead of touching balances themselves, so a reward is
/// paid exactly once per day no matter how often the screen is reopened.
class ProgressService {
  /// Advances the streak and pays today's day of it. Safe to call on every
  /// launch: the stored date decides both whether the streak moves and whether
  /// anything is credited, so a relaunch cannot double up.
  static Future<int> tickLoginStreak() async {
    final today = StorageService.todayKey;
    final lastLogin = await StorageService.getLastLoginDate();
    var streak = await StorageService.getLoginStreak();

    if (lastLogin == today) return streak;

    final yesterday = StorageService.dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    streak = lastLogin == yesterday ? streak + 1 : 1;
    await StorageService.setLoginStreak(streak);
    await StorageService.setLastLoginDate(today);

    if (await StorageService.claimStreakRewardToday()) {
      final reward = StreakReward.forStreak(streak);
      await grant(coins: reward.coins, gems: reward.gems);
      AnalyticsService.logEvent(
        'streak_reward',
        parameters: {'day': streakDay(streak)},
      );
    }
    return streak;
  }

  /// Which of the seven shown days the player is on. The streak itself keeps
  /// counting up, so a long run is still visible as a big number.
  static int streakDay(int streak) => StreakReward.dayOf(streak);

  static Future<List<Quest>> todaysQuests() async {
    final counters = await StorageService.getDailyCounters();
    final claimed = (await StorageService.getClaimedQuestsToday()).toSet();
    return QuestCatalog.forCounters(counters: counters, claimedIds: claimed);
  }

  /// Credits a quest and stamps it claimed. False when it was already claimed
  /// or is not finished, so a caller can rely on it before adding coins.
  static Future<bool> claimQuest(Quest quest) async {
    if (!quest.isCompleted) return false;
    if (!await StorageService.claimQuestToday(quest.id)) return false;
    await grant(coins: quest.coinReward, gems: quest.gemReward);
    AnalyticsService.logEvent(
      'quest_claimed',
      parameters: {
        'quest_id': quest.id,
        'coins': quest.coinReward,
        'gems': quest.gemReward,
      },
    );
    return true;
  }

  /// Adds to the wallet and writes it back in one step.
  static Future<void> grant({int coins = 0, int gems = 0}) async {
    if (coins != 0) {
      await StorageService.saveCoins(await StorageService.getCoins() + coins);
    }
    if (gems != 0) {
      await StorageService.saveGems(await StorageService.getGems() + gems);
    }
  }

  /// Removes from the wallet, refusing the whole purchase when it is short, so
  /// a balance can never go negative and no screen writes one of its own.
  static Future<bool> spend({int coins = 0, int gems = 0}) async {
    if (coins < 0 || gems < 0) return false;
    if (coins != 0 && await StorageService.getCoins() < coins) return false;
    if (gems != 0 && await StorageService.getGems() < gems) return false;
    await grant(coins: -coins, gems: -gems);
    return true;
  }

  static Future<void> recordDaily(Map<String, int> deltas) =>
      StorageService.bumpDailyCounters(deltas);
}
