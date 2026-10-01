/// The economy, in one place.
///
/// Every number a screen shows a player is produced here, so a reward cannot be
/// promised in a dialog and then not granted by the controller. The formulas are
/// Dart; the values they run on are content, from
/// `assets/content/rewards.json`.
library;

import '../content/content_repository.dart';
import '../content/content_types.dart';

/// The numbers this economy runs on. A balancing decision changes the document,
/// not this file.
RewardTuning get _tuning => ContentRepository.content.rewards;

/// What finishing a board pays out.
class LevelReward {
  const LevelReward({
    required this.stars,
    required this.coins,
    required this.xp,
    required this.gems,
    required this.isNewBest,
  });

  /// 1..3, graded against the shortest solution the solver proved for this
  /// exact board.
  final int stars;
  final int coins;

  /// Feeds [PlayerLevel], the arc the dashboard HUD shows.
  final int xp;

  /// Non-zero only the first time a level is cleared at three stars. Gems are
  /// meant to be scarce enough that a skin is a multi-day goal.
  final int gems;
  final bool isNewBest;

  static int starsFor({required int moves, required int par}) =>
      moves <= par
      ? 3
      : (moves <= par + _tuning.twoStarSlack ? 2 : 1);

  /// Coins rise with the level, because a late level costs more thinking, and
  /// with stars, because sloppy play should not pay like careful play. A
  /// three-star level is worth about one power-up, so farming a board by
  /// undoing every mistake stays roughly coin neutral.
  static int coinsFor({
    required int level,
    required int stars,
    bool sideMode = false,
  }) {
    final base = _tuning.coinBase + level ~/ _tuning.coinPerLevels;
    return _grade(base * stars ~/ 3, sideMode);
  }

  /// A three-star board pays the full 40 and sloppy play pays proportionally
  /// less. Unlike coins this does not rise with the level number: a curve the
  /// player's own boards can outrun stops meaning anything.
  static int xpFor({required int stars, bool sideMode = false}) =>
      _grade(_tuning.xpForThreeStars * stars ~/ 3, sideMode);

  /// Side modes pay a percentage of a classic win, rounded down.
  static int _grade(int classic, bool sideMode) => sideMode
      ? classic * _tuning.sideModePercent ~/ 100
      : classic;

  static LevelReward forWin({
    required int level,
    required int moves,
    required int par,
    required int previousBestStars,
    bool sideMode = false,
  }) {
    final stars = starsFor(moves: moves, par: par);
    final isNewBest = stars > previousBestStars;
    return LevelReward(
      stars: stars,
      coins: coinsFor(level: level, stars: stars, sideMode: sideMode),
      xp: xpFor(stars: stars, sideMode: sideMode),
      gems: stars == 3 && isNewBest ? _tuning.firstThreeStarGems : 0,
      isNewBest: isNewBest,
    );
  }
}

/// The player's own level, driven by the XP every finished board pays.
///
/// Only the career total is stored and the level is derived from it, so a cloud
/// merge has one number to make agree and that number can only go up.
class PlayerLevel {
  const PlayerLevel({
    required this.number,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });

  /// 1-based level shown next to the avatar.
  final int number;

  /// XP banked inside the current level.
  final int xpIntoLevel;

  /// XP that leaves the current level behind.
  final int xpForNextLevel;

  /// 0..1 through the current level, what the HUD ring and bar draw.
  double get fraction => xpIntoLevel / xpForNextLevel;

  /// Stepping out of level [number] costs this. The step grows by a flat 40, so
  /// level 2 is two three-star wins away and level 20 another two hundred.
  static int xpToNext(int number) =>
      _tuning.levelXpBase + number * _tuning.levelXpStep;

  static PlayerLevel fromXp(int totalXp) {
    var remaining = totalXp < 0 ? 0 : totalXp;
    var number = 1;
    while (remaining >= xpToNext(number)) {
      remaining -= xpToNext(number);
      number++;
    }
    return PlayerLevel(
      number: number,
      xpIntoLevel: remaining,
      xpForNextLevel: xpToNext(number),
    );
  }
}

/// A day's login-streak payout. Day 7 pays gems instead of coins and the
/// streak starts over, which is the card the player is shown.
class StreakReward {
  const StreakReward({required this.coins, required this.gems});

  final int coins;
  final int gems;

  static int get cycleLength => _tuning.streakCycle;
  static int get coinsPerDay => _tuning.streakCoins;
  static int get gemBonusDay => _tuning.streakGems;

  static int dayOf(int streak) => ((streak - 1) % cycleLength) + 1;

  static StreakReward forStreak(int streak) => dayOf(streak) == cycleLength
      ? StreakReward(coins: 0, gems: gemBonusDay)
      : StreakReward(coins: coinsPerDay, gems: 0);
}

/// What a day's play is counted in. Keys are stable because they are the ids
/// the quest list reads.
class DailyStat {
  static const wins = 'wins';
  static const stars = 'stars';

  /// Boards finished at three stars, so a task about playing carefully is not
  /// the same task as one about playing a lot.
  static const threeStarWins = 'threeStarWins';
  static const powerUps = 'powerUps';
  static const sideModeWins = 'sideModeWins';

  /// Paid re-spins used today, so the gem sink below has a daily ceiling.
  static const extraSpins = 'extraSpins';

  /// Every counter a quest or an event may be measured against. The content
  /// validator refuses a task that names anything else, so a card that could
  /// never fill cannot ship.
  static const known = [
    wins,
    stars,
    threeStarWins,
    powerUps,
    sideModeWins,
    extraSpins,
  ];

  /// The most boards a player realistically finishes in one day.
  ///
  /// This is the one judgement [dailyCeilings] rests on, and it is deliberately
  /// generous: a day of this game is a few minutes on a phone, and someone
  /// grinding a chapter will pass twenty boards without trying. A task that
  /// asks for more than this many of anything is not hard, it is unreachable,
  /// and the day it is drawn is a day the player cannot finish.
  static const boardsPerDay = 20;

  /// What one day can put in each counter, keyed by [known].
  ///
  /// [extraSpins] is absent on purpose: its ceiling is a number in another
  /// document, so the validator reads that instead of a copy kept here.
  static const dailyCeilings = <String, int>{
    wins: boardsPerDay,
    stars: boardsPerDay * 3,
    threeStarWins: boardsPerDay,
    powerUps: boardsPerDay * 3,
    sideModeWins: boardsPerDay,
  };
}

/// The lucky wheel.
///
/// One turn is free every day and anything beyond that is bought with gems,
/// which is where the rare currency goes: three gems per extra turn, two turns
/// a day, so a hoard can be spent but a day's take is capped.
class SpinReward {
  static int get extraSpinsPerDay => _tuning.extraSpinsPerDay;
  static int get extraSpinGems => _tuning.extraSpinGems;
}
