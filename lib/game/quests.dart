import 'dart:math';

import '../content/content_repository.dart';
import '../content/content_types.dart';
import '../models/quest_model.dart';

/// How many tasks a day's slate carries.
///
/// The catalogue is deliberately much larger than this. A screen full of fifteen
/// cards is a wall nobody reads, and a slate that changes every day is the
/// reason to come back - so a day draws this many and the rest wait their turn.
const int kDailyQuestCount = 5;

/// The most cards drawn from one counter on the same day.
///
/// Without it a day can draw four tasks that all ask for wins and reads like a
/// bug in the draw. Two of a kind is the point where a slate still looks like
/// five different ideas.
const int kDailyQuestsPerStat = 2;

/// The daily set.
///
/// The tasks themselves are content - `assets/content/quests.json` - so a day's
/// slate can be re-cut without a build. What stays here is how a task turns into
/// a card, and which handful of them a given day shows.
///
/// Progress is derived from today's counters rather than tracked per quest, so
/// a day that was never played simply starts at zero instead of leaving stale
/// half-finished tasks behind.
class QuestCatalog {
  /// Every task the shipped set offers. The screen shows [forDay], not this.
  static List<QuestSpec> get all => ContentRepository.content.quests;

  /// The tasks drawn for [dayKey], in catalogue order.
  ///
  /// The draw is seeded from the day rather than from the moment, so every
  /// device shows the same slate on the same date and a restart cannot reroll
  /// a task a player has already finished. That is also what makes a claim
  /// stamp meaningful: claiming today's card claims it for today.
  static List<QuestSpec> forDay(String dayKey) {
    final catalog = all;
    if (catalog.length <= kDailyQuestCount) return catalog;

    final random = Random(_seedOf(dayKey));
    // A rank per task rather than a shuffle. A shuffle depends on the order the
    // sort happens to visit ties in, and a tie means a day that draws a
    // different five on a second device. Breaking a tie by id makes the slate
    // the same number, everywhere.
    final ranked = [
      for (final quest in catalog)
        (order: random.nextDouble(), quest: quest),
    ]..sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.quest.id.compareTo(b.quest.id);
    });

    final picked = <QuestSpec>[];
    final perStat = <String, int>{};
    for (final entry in ranked) {
      if (picked.length == kDailyQuestCount) break;
      final used = perStat[entry.quest.stat] ?? 0;
      if (used >= kDailyQuestsPerStat) continue;
      perStat[entry.quest.stat] = used + 1;
      picked.add(entry.quest);
    }
    // A catalogue too thin to obey the variety rule still fills the slate; the
    // validator is what refuses that shape before it ships.
    for (final entry in ranked) {
      if (picked.length == kDailyQuestCount) break;
      if (!picked.contains(entry.quest)) picked.add(entry.quest);
    }
    return picked
      ..sort((a, b) => catalog.indexOf(a).compareTo(catalog.indexOf(b)));
  }

  /// The cards the quest screen shows.
  static List<Quest> forCounters({
    required String dayKey,
    required Map<String, int> counters,
    required Set<String> claimedIds,
  }) {
    return [
      for (final quest in forDay(dayKey))
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

  static QuestSpec? byId(String id) {
    for (final quest in all) {
      if (quest.id == id) return quest;
    }
    return null;
  }

  /// A 32-bit number made of the day's own digits. Not `String.hashCode`,
  /// which is free to change between runs and would reroll the slate under a
  /// player who had already finished it.
  static int _seedOf(String dayKey) {
    var hash = 0x811c9dc5;
    for (final unit in dayKey.codeUnits) {
      hash = (hash ^ unit) * 0x01000193 & 0xFFFFFFFF;
    }
    return hash;
  }
}
