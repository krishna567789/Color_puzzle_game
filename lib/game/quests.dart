import '../models/quest_model.dart';
import 'rewards.dart';

/// One day's task, and where its progress is counted from.
class DailyQuest {
  const DailyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.stat,
    required this.target,
    required this.coins,
    this.gems = 0,
  });

  final String id;
  final String title;
  final String description;
  final String stat;
  final int target;
  final int coins;
  final int gems;
}

/// The daily set.
///
/// Progress is derived from today's counters rather than tracked per quest, so
/// a day that was never played simply starts at zero instead of leaving stale
/// half-finished tasks behind.
class QuestCatalog {
  static const List<DailyQuest> daily = [
    DailyQuest(
      id: 'win_five',
      title: 'Colour Student',
      description: 'Win 5 levels today',
      stat: DailyStat.wins,
      target: 5,
      coins: 150,
    ),
    DailyQuest(
      id: 'earn_stars',
      title: 'Neat Pours',
      description: 'Collect 8 stars today',
      stat: DailyStat.stars,
      target: 8,
      coins: 100,
      gems: 1,
    ),
    DailyQuest(
      id: 'use_powerups',
      title: 'Tool Time',
      description: 'Use 3 power-ups',
      stat: DailyStat.powerUps,
      target: 3,
      coins: 80,
    ),
    DailyQuest(
      id: 'play_side_mode',
      title: 'Off The Map',
      description: 'Finish a challenge, time attack or daily',
      stat: DailyStat.sideModeWins,
      target: 1,
      coins: 120,
    ),
  ];

  /// The cards the quest screen shows.
  static List<Quest> forCounters({
    required Map<String, int> counters,
    required Set<String> claimedIds,
  }) {
    return [
      for (final quest in daily)
        Quest(
          id: quest.id,
          title: quest.title,
          description: quest.description,
          targetValue: quest.target,
          currentProgress: counters[quest.stat] ?? 0,
          coinReward: quest.coins,
          gemReward: quest.gems,
          isClaimed: claimedIds.contains(quest.id),
        ),
    ];
  }

  static DailyQuest? byId(String id) {
    for (final quest in daily) {
      if (quest.id == id) return quest;
    }
    return null;
  }
}
