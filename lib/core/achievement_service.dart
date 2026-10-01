import '../game/achievements.dart';
import '../game/rewards.dart';
import 'storage_service.dart';

/// How far this account has come on every counter an achievement can measure.
///
/// The goals, the copy and the payouts are content. What lives here is the one
/// reading of each counter, so the achievements screen and the Play Games
/// mirror cannot disagree about whether a goal has been reached - and so a
/// screen never invents a progress number of its own.
class AchievementService {
  /// Every counter, read once. Callers index the result by the stat a card
  /// names, which is why this reads all ten rather than one at a time: the
  /// screen shows them all and a read per card would hit storage thirty times.
  static Future<Map<AchievementStat, int>> readAll() async {
    final wins = await StorageService.getTotalLevelsWon();
    final levelStars = await StorageService.getAllLevelStars();
    final xp = await StorageService.getPlayerXp();
    final chapters = await StorageService.getClaimedChapters();
    final modeProgress = await StorageService.getAllModeProgress();
    final modeStars = await StorageService.getAllModeStars();
    final owned = await StorageService.getOwnedItems();
    final streak = await StorageService.getLoginStreak();

    var stageStars = 0;
    modeStars.forEach((_, stars) => stageStars += stars);

    // A mode's stored number is the highest stage it may be entered from, which
    // is one ahead of the last stage actually finished.
    var stages = 0;
    modeProgress.forEach((_, stage) {
      if (stage > 1) stages += stage - 1;
    });

    return {
      AchievementStat.totalWins: wins,
      AchievementStat.totalStars: levelStars.values.fold(
        0,
        (sum, stars) => sum + stars,
      ),
      AchievementStat.perfectLevels: levelStars.values
          .where((stars) => stars >= 3)
          .length,
      AchievementStat.reachedLevel: await StorageService.getLevel(),
      AchievementStat.playerLevel: PlayerLevel.fromXp(xp).number,
      AchievementStat.chaptersCleared: chapters.length,
      AchievementStat.stagesCleared: stages,
      AchievementStat.sideModeStars: stageStars,
      AchievementStat.itemsOwned: owned.length,
      AchievementStat.loginStreak: streak,
    };
  }

  /// What a card named [stat] has reached, or zero for a stat this build does
  /// not read. The validator refuses such a card before it ships; this is what
  /// keeps a hand-written bundle from throwing on a screen.
  static int progressOf(Map<AchievementStat, int> counters, String stat) =>
      counters[AchievementStat.tryParse(stat)] ?? 0;
}
