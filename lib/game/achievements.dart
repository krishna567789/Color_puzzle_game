import '../content/content_types.dart';

/// What a long-run goal is measured against.
///
/// The goals themselves are content, in `assets/content/achievements.json`.
/// What stays here is the short list of counters the game actually keeps, and
/// how far each can ever go. The validator refuses a card that names a stat
/// that is not in [known], and refuses a goal past the ceiling this file says
/// is reachable, so an achievement nobody could ever finish cannot ship.
///
/// Reading a live value is deliberately not here: this is the rules layer and
/// it does not know about storage. `AchievementService` in core is the only
/// place a counter is actually read.
enum AchievementStat {
  /// Boards finished, however sloppily. Replays count, so this one climbs
  /// forever and a player is never capped out of it.
  totalWins,

  /// The stars on the campaign board records, which is the honest measure of
  /// how well the campaign has gone rather than how often it was opened.
  totalStars,

  /// Campaign boards finished at three stars.
  perfectLevels,

  /// The highest board number ever unlocked.
  reachedLevel,

  /// The player's own level, derived from career XP by `PlayerLevel`.
  playerLevel,

  /// Chapters whose closing board has been paid out.
  chaptersCleared,

  /// Stages of the side modes' own ladders that have been cleared.
  stagesCleared,

  /// Stars earned on the side modes' stages.
  sideModeStars,

  /// Shop rows this account owns - bottles and rooms, not wallet purchases.
  itemsOwned,

  /// Days in a row the player has opened the game. The streak counts up and
  /// never resets, so a goal on it is a goal about keeping the habit.
  loginStreak,
  ;

  /// The stat names as a content document spells them.
  static List<String> get known => [for (final stat in values) stat.name];

  /// The counter a document names, or null when it names nothing the game keeps.
  static AchievementStat? tryParse(String name) {
    for (final stat in values) {
      if (stat.name == name) return stat;
    }
    return null;
  }

  /// The most this counter can ever hold for [content], or null when the player
  /// can keep climbing past anything a document could ask for.
  ///
  /// A ceiling here is a promise the shipped set can be finished: three stars
  /// on every board that exists is the most stars there are, and every chapter
  /// paid is every chapter cleared. A goal above it is not a stretch, it is a
  /// card that sits half-filled forever.
  int? ceilingOf(GameContent content) => switch (this) {
    // Nothing caps how often a board can be replayed, how many days a player
    // can keep opening the game, or how much XP they can bank.
    AchievementStat.totalWins => null,
    AchievementStat.playerLevel => null,
    AchievementStat.loginStreak => null,
    AchievementStat.totalStars => _campaignLength(content) * 3,
    AchievementStat.perfectLevels => _campaignLength(content),
    // The level pointer sits one past the last board once it is all finished.
    AchievementStat.reachedLevel => _campaignLength(content) + 1,
    AchievementStat.chaptersCleared => content.chapters.length,
    AchievementStat.stagesCleared => _stageCount(content),
    AchievementStat.sideModeStars => _stageCount(content) * 3,
    AchievementStat.itemsOwned => content.shop
        .where((item) => !item.isIap)
        .length,
  };

  /// The boards the campaign runs to. The authored packs are only its first
  /// slice - the rest is dealt from the curve at run time - so this is the
  /// shape of the campaign, not a count of the files written for it. That is
  /// what lets the goals be checked before a generator has laid the boards.
  static int _campaignLength(GameContent content) {
    var last = 0;
    for (final chapter in content.chapters) {
      final end = content.lastLevelOf(chapter);
      if (end > last) last = end;
    }
    return last;
  }

  static int _stageCount(GameContent content) {
    var stages = 0;
    for (final mode in content.modes) {
      stages += mode.stageCount;
    }
    return stages;
  }
}
