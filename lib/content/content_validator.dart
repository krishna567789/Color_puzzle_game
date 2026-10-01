/// The single authority on whether a content set is fit to ship.
///
/// The generator, the CI contract test and a future admin panel all call
/// [validateContent] on the same bundle, so "valid" cannot mean two things in
/// two places. It only reads what is already parsed: the cost of checking a
/// board is solvable belongs in the generator and in CI, not on a player's
/// launch screen.
library;

import '../game/achievements.dart';
import '../game/events.dart';
import '../game/liquid_patterns.dart';
import '../game/quests.dart';
import '../game/rewards.dart';
import 'content_types.dart';

/// Checks one asset path, when the caller can. A tool and CI can look at disk;
/// a running app usually cannot.
typedef ContentAssetChecker = bool Function(String path);

/// The power-up keys a price list has to cover. These mirror the names of
/// [GameController]'s `PowerUp` enum, and a test keeps the two in step.
const List<String> kPowerUpCostKeys = ['undo', 'hint', 'shuffle', 'addTube'];

/// The most a lucky wheel may pay on one wedge, in coins.
///
/// The wheel is a daily top-up next to a board's payout, not a salary: a single
/// wedge worth more than this would make the dial the cheapest thing in the game
/// to open, and the reward dialog would quote a number no level ever pays.
const int kWheelMaxCoins = 1000;

/// The most a lucky wheel may pay on one wedge, in gems. The cheapest bottle in
/// the shop costs a few dozen, so a wedge that paid more than this would hand
/// the sink back to the player faster than the economy can take it away.
const int kWheelMaxGems = 5;

/// How many wedges a dial may carry, and what a spin may pay on average.
///
/// Below the floor the wheel is a coin flip with a picture on it; above the
/// ceiling the numbers on the wedges collide at the smallest size the screen
/// draws it. The expected payout is the real check: a wheel pays one wedge per
/// spin and a spin is free every day, so the average is what the economy
/// actually receives, and a dial of duds with one jackpot still fails here.
const int kWheelMinSegments = 6;
const int kWheelMaxSegments = 24;
const int kWheelMaxExpectedCoins = 160;
const double kWheelMaxExpectedGems = 0.6;

/// The most colours a Challenge stage's board may carry.
///
/// A Challenge run ends when the move limit runs out, and that limit is set
/// from the shortest solution the search proved. Past this many colours the
/// search never concludes and par falls back to an estimate, so the limit would
/// be measured against a number nobody checked - a board the player can lose
/// without having done anything wrong. This has to match
/// `GameController.searchableColorCount`, and a test keeps the two in step.
const int kSideLadderColorCeiling = 9;

/// How short a ladder may get before it stops being a map. Anything below this
/// and the mode has no shape - a player clears it in one sitting and the
/// records on it measure nothing.
const int kSideLadderMinStages = 6;

/// Every problem with a content set, as `path: message` strings.
///
/// An empty list means the bundle is safe to serve: every id resolves, every
/// board is a real board, and nothing a player can tap is a dead end.
List<String> validateContent(
  GameContent content, {
  ContentAssetChecker? assetExists,
}) {
  final issues = ContentIssues();

  _validateColors(content, issues);
  _validateChapters(content, issues, assetExists);
  _validateCurve(content, issues);
  _validateLevels(content, issues);
  _validateModes(content, issues, assetExists);
  _validateQuests(content, issues);
  _validateEvents(content, issues, assetExists);
  _validateAchievements(content, issues);
  _validateShop(content, issues, assetExists);
  _validateWheel(content, issues);
  _validateRewards(content, issues);

  return issues.messages;
}

void _validateColors(GameContent content, ContentIssues issues) {
  final colors = content.colors;
  if (colors.length < 2) {
    issues.add('colors', 'a board needs at least two colours');
    return;
  }
  final seenIds = <String>{};
  final seenSwatches = <int>[];
  final seenPatterns = <LiquidPattern, String>{};
  for (final color in colors) {
    final path = 'colors/${color.id}';
    if (color.id.isEmpty) issues.add(path, 'an id is required');
    if (!seenIds.add(color.id)) issues.add(path, 'duplicate id');
    if ((color.argb >> 24) & 0xFF != 0xFF) {
      issues.add('$path.argb', 'a liquid must be opaque');
    }
    for (final other in seenSwatches) {
      if (other == color.argb) {
        issues.add('$path.argb', 'the same hue is already used');
      }
    }
    seenSwatches.add(color.argb);
    // Twelve hues are not twelve hues everyone can tell apart, which is why a
    // layer wears a shape as well as a colour. Two colours sharing a mark makes
    // that setting lie, so the palette can only grow as far as the marks do.
    final taken = seenPatterns[color.pattern];
    if (taken != null) {
      issues.add(
        '$path.pattern',
        'already worn by $taken, and colourblind mode needs every '
        'colour to read differently',
      );
    }
    seenPatterns[color.pattern] = color.id;
  }
}

void _validateChapters(
  GameContent content,
  ContentIssues issues,
  ContentAssetChecker? assetExists,
) {
  if (content.chapters.isEmpty) {
    issues.add('chapters', 'at least one chapter is needed');
    return;
  }
  if (content.levelsPerChapter < 1) {
    issues.add('levelsPerChapter', 'must be at least 1');
  }
  final seen = <String>{};
  for (var i = 0; i < content.chapters.length; i++) {
    final chapter = content.chapters[i];
    final path = 'chapters/${chapter.id}';
    if (!seen.add(chapter.id)) issues.add(path, 'duplicate id');
    if (chapter.name.isEmpty) issues.add('$path.name', 'required');
    final expected = 1 + i * content.levelsPerChapter;
    if (chapter.startsAtLevel != expected) {
      issues.add(
        '$path.startsAtLevel',
        'chapters run in blocks of ${content.levelsPerChapter}, '
        'so chapter ${i + 1} should start at $expected',
      );
    }
    // A chapter card with nothing on it is a badge nobody earned.
    if (chapter.rewardCoins == 0 && chapter.rewardGems == 0) {
      issues.add(path, 'ends without paying anything');
    }
    if ((chapter.accent >> 24) & 0xFF != 0xFF) {
      issues.add('$path.accent', 'a badge colour has to be opaque');
    }
    _validateChapterPalette(content, chapter, issues);
    if (assetExists != null && !assetExists(chapter.image)) {
      issues.add('$path.image', '${chapter.image} does not exist');
    }
  }
}

/// A chapter that names its own colours has to be able to fill its widest
/// board with them, and every id it lists has to be a colour the game paints.
/// Silence here means the chapter deals from the whole palette.
void _validateChapterPalette(
  GameContent content,
  ChapterSpec chapter,
  ContentIssues issues,
) {
  final palette = chapter.palette;
  if (palette.isEmpty) return;
  final path = 'chapters/${chapter.id}.palette';
  final known = {for (final color in content.colors) color.id};
  if (palette.length != palette.toSet().length) {
    issues.add(path, 'lists the same colour twice');
  }
  for (final id in palette) {
    if (!known.contains(id)) issues.add(path, '$id is not in the palette');
  }
  final last = content.lastLevelOf(chapter);
  final widest = content.curve.configFor(last).colorCount;
  if (palette.length < widest) {
    issues.add(
      path,
      'holds ${palette.length} colours and L$last asks for $widest',
    );
  }
}

void _validateCurve(GameContent content, ContentIssues issues) {
  final curve = content.curve;
  final path = 'levels/curve';
  if (curve.maxColorCount > content.colors.length) {
    issues.add(
      '$path.maxColorCount',
      'asks for ${curve.maxColorCount} colours but the palette holds '
      '${content.colors.length}',
    );
  }
  if (curve.maxTubeCount > curve.maxBoardTubes) {
    issues.add(
      '$path.maxTubeCount',
      'generates up to ${curve.maxTubeCount} bottles, and the board lays out '
      'at most ${curve.maxBoardTubes}',
    );
  }
  for (var level = 1; level <= 400; level++) {
    final spec = curve.configFor(level);
    if (spec.colorCount + spec.freeTubes > curve.maxTubeCount) {
      issues.add(
        '$path.maxTubeCount',
        'L$level needs ${spec.colorCount + spec.freeTubes} bottles, '
        'more than the board can show',
      );
      return;
    }
    if (spec.mysteryTubes > spec.colorCount + spec.freeTubes) {
      issues.add(
        '$path.maxMysteryTubes',
        'L$level hides more bottles than the board has',
      );
      return;
    }
  }
  var previousColors = 0;
  for (var level = 1; level <= 400; level++) {
    final count = curve.configFor(level).colorCount;
    if (count < previousColors) {
      issues.add(
        path,
        'L$level drops back to $count colours after $previousColors',
      );
      break;
    }
    previousColors = count;
  }
}

void _validateLevels(GameContent content, ContentIssues issues) {
  final palette = {for (final color in content.colors) color.id};
  final chapters = {for (final chapter in content.chapters) chapter.id};
  final seenIds = <String>{};

  for (final spec in content.levels.values) {
    final path = 'levels/${spec.id}';
    if (!seenIds.add(spec.id)) issues.add(path, 'duplicate id');
    if (!chapters.contains(spec.chapter)) {
      issues.add('$path.chapter', 'is not a chapter this content set has');
    }
    if (spec.capacity < 2) {
      issues.add('$path.capacity', 'a bottle holds at least two layers');
      continue;
    }
    if (spec.colors.length < 2) {
      issues.add('$path.colors', 'at least two colours are needed');
      continue;
    }
    if (spec.tubes.isEmpty) {
      issues.add('$path.tubes', 'an empty board is not a level');
      continue;
    }
    // The board lays out a known number of bottles. An authored level that asks
    // for more is a content mistake, so it is refused here rather than turning
    // into a screen that runs out of room mid-draw.
    if (spec.tubes.length > content.curve.maxBoardTubes) {
      issues.add(
        '$path.tubes',
        'has ${spec.tubes.length} bottles, and the board lays out at most '
        '${content.curve.maxBoardTubes}',
      );
    }
    if (spec.tubes.length <= spec.colors.length) {
      issues.add(
        '$path.tubes',
        'a board needs a spare bottle to work with',
      );
    }
    for (final color in spec.colors) {
      if (!palette.contains(color)) {
        issues.add('$path.colors', '$color is not in the palette');
      }
    }
    for (final duplicate in spec.colors) {
      if (spec.colors.where((color) => color == duplicate).length > 1) {
        issues.add('$path.colors', '$duplicate is listed twice');
      }
    }

    final counts = <String, int>{};
    for (var i = 0; i < spec.tubes.length; i++) {
      final tube = spec.tubes[i];
      if (tube.length > spec.capacity) {
        issues.add(
          '$path.tubes[$i]',
          'holds ${tube.length} layers in a ${spec.capacity}-layer bottle',
        );
      }
      for (var j = 0; j < tube.length; j++) {
        final color = tube[j];
        if (!palette.contains(color)) {
          issues.add('$path.tubes[$i][$j]', '$color is not in the palette');
        }
        counts[color] = (counts[color] ?? 0) + 1;
      }
      final hidden = i < spec.hidden.length ? spec.hidden[i] : 0;
      if (hidden >= tube.length && tube.isNotEmpty) {
        issues.add(
          '$path.hidden[$i]',
          'hides every layer of a bottle, leaving nothing to reason about',
        );
      }
    }
    if (spec.hidden.length > spec.tubes.length) {
      issues.add(
        '$path.hidden',
        'has ${spec.hidden.length} entries for ${spec.tubes.length} bottles',
      );
    }

    final expected = {for (final color in spec.colors) color: spec.capacity};
    if (counts.length != expected.length) {
      issues.add(
        '$path.colors',
        'lists ${expected.length} colours but the board holds '
        '${counts.length}',
      );
    }
    for (final entry in counts.entries) {
      if (entry.value != spec.capacity) {
        issues.add(
          path,
          '${entry.key} appears ${entry.value} times, and a sorted board '
          'needs exactly ${spec.capacity}',
        );
      }
    }
    if (spec.parMoves < 1) {
      issues.add('$path.parMoves', 'a solved board is not something to ship');
    }
    // A board that arrives already sorted hands the player a win for tapping
    // nothing, so it is refused at the contract rather than in a playtest.
    final untouched = spec.tubes.every(
      (tube) =>
          tube.isEmpty ||
          (tube.length == spec.capacity &&
              tube.every((color) => color == tube.first)),
    );
    if (untouched) {
      issues.add('$path.tubes', 'the board is already solved as dealt');
    }
  }
}

/// A side mode is its ladder: the stages are the map, and the records are kept
/// per stage, so a stage that repeats a board, sits past where the game can
/// grade a run fairly, or belongs to an id nothing keys off is a broken mode
/// rather than a cosmetic one.
void _validateModes(
  GameContent content,
  ContentIssues issues,
  ContentAssetChecker? assetExists,
) {
  final seen = <String>{};
  for (final mode in content.modes) {
    final path = 'modes/${mode.id}';
    if (!kSideModeIds.contains(mode.id)) {
      issues.add(
        '$path.id',
        '"${mode.id}" is not a side mode the game runs. Classic plays the '
        'campaign and the daily board has no ladder, so expected '
        '${kSideModeIds.join(', ')}',
      );
      continue;
    }
    if (!seen.add(mode.id)) issues.add(path, 'duplicate id');
    if (mode.name.isEmpty) issues.add('$path.name', 'required');
    if ((mode.accent >> 24) & 0xFF != 0xFF) {
      issues.add('$path.accent', 'a badge colour has to be opaque');
    }
    if (assetExists != null && !assetExists(mode.image)) {
      issues.add('$path.image', '${mode.image} does not exist');
    }
    if (mode.stageCount < kSideLadderMinStages) {
      issues.add(
        '$path.stages',
        'has ${mode.stageCount} stages, and a mode that short is not a map',
      );
    }
    var previous = 0;
    for (var i = 0; i < mode.stageCount; i++) {
      final anchor = mode.stages[i];
      if (anchor <= previous) {
        issues.add(
          '$path.stages[$i]',
          'sits at curve level $anchor, which is no harder than the stage '
          'before it',
        );
      }
      previous = anchor;
      if (mode.id != 'challenge') continue;
      final shape = content.curve.configFor(anchor);
      if (shape.colorCount > kSideLadderColorCeiling) {
        issues.add(
          '$path.stages[$i]',
          'deals a ${shape.colorCount}-colour board, and past '
          '$kSideLadderColorCeiling colours the move limit is set from an '
          'estimate no search proved',
        );
      }
    }
  }
  for (final id in kSideModeIds) {
    if (!seen.contains(id)) {
      issues.add('modes', '$id has no ladder, so its map has no stages');
    }
  }
}

void _validateQuests(GameContent content, ContentIssues issues) {
  if (content.quests.length < kDailyQuestCount) {
    issues.add(
      'quests/daily',
      'holds ${content.quests.length} tasks and a day draws '
      '$kDailyQuestCount, so the slate would ship short',
    );
  }
  final seen = <String>{};
  for (final quest in content.quests) {
    final path = 'quests/${quest.id}';
    if (!seen.add(quest.id)) issues.add(path, 'duplicate id');
    if (!DailyStat.known.contains(quest.stat)) {
      issues.add(
        '$path.stat',
        'counts nothing the game keeps track of, expected '
        '${DailyStat.known.join(', ')}',
      );
    } else {
      _validateQuestTarget(content, quest, issues);
    }
    if (quest.coins == 0 && quest.gems == 0) {
      issues.add(path, 'pays nothing');
    }
    if (quest.title.isEmpty || quest.description.isEmpty) {
      issues.add(path, 'needs a title and a description to show');
    }
  }
}

/// Whether today can actually produce what the card asks for.
///
/// A quest is measured against a counter the game bumps as the player plays, and
/// every one of those has a ceiling a day can reach. A task past it is not hard,
/// it is broken: it sits on the slate unfillable, and the day it is drawn is a
/// day the player cannot finish.
void _validateQuestTarget(
  GameContent content,
  QuestSpec quest,
  ContentIssues issues,
) {
  final path = 'quests/${quest.id}.target';
  if (quest.stat == DailyStat.extraSpins) {
    // The wheel sells a fixed number of re-spins a day, so that is the whole
    // ceiling and it lives in another document.
    final sold = content.rewards.extraSpinsPerDay;
    if (quest.target > sold) {
      issues.add(
        path,
        'wants ${quest.target} spins and the wheel only sells $sold a day',
      );
    }
    return;
  }
  final ceiling = DailyStat.dailyCeilings[quest.stat];
  if (ceiling == null) return;
  if (quest.target > ceiling) {
    issues.add(
      path,
      'wants ${quest.target} of a counter a day of play banks at most $ceiling',
    );
  }
}

void _validateEvents(
  GameContent content,
  ContentIssues issues,
  ContentAssetChecker? assetExists,
) {
  if (content.events.isEmpty) {
    issues.add('events', 'the live calendar is empty');
  }
  final seen = <String>{};
  for (final event in content.events) {
    final path = 'events/${event.id}';
    if (!seen.add(event.id)) issues.add(path, 'duplicate id');
    final metric = EventMetric.tryParse(event.metric);
    if (metric == null) {
      issues.add(
        '$path.metric',
        'is not something a win can feed, expected $_metricKeys',
      );
    } else {
      final bankable = metric.dailyCeiling * event.openForDays;
      if (event.goal > bankable) {
        issues.add(
          '$path.goal',
          'wants ${event.goal} and ${event.openForDays} days of play bank at '
          'most $bankable ${event.metric}',
        );
      }
    }
    if (event.openForDays > event.cycleDays) {
      issues.add(
        '$path.openForDays',
        'stays open longer than its own ${event.cycleDays}-day cycle',
      );
    }
    if (event.rewardCoins == 0 && event.rewardGems == 0) {
      issues.add(path, 'pays nothing');
    }
    if (assetExists != null && !assetExists(event.bannerImage)) {
      issues.add('$path.bannerImage', '${event.bannerImage} does not exist');
    }
  }
}

void _validateAchievements(
  GameContent content,
  ContentIssues issues,
) {
  final seen = <String>{};
  final seenPlayGames = <String>{};
  final byStat = <String, List<AchievementSpec>>{};
  for (final achievement in content.achievements) {
    final path = 'achievements/${achievement.id}';
    if (!seen.add(achievement.id)) issues.add(path, 'duplicate id');
    final stat = AchievementStat.tryParse(achievement.stat);
    if (stat == null) {
      issues.add(
        '$path.stat',
        'is not a counter this game can read, expected '
        '${AchievementStat.known.join(', ')}',
      );
      continue;
    }
    // The other half of the promise: a goal the shipped set cannot reach is
    // not ambitious, it is a card that never fills.
    final ceiling = stat.ceilingOf(content);
    if (ceiling != null && achievement.goal > ceiling) {
      issues.add(
        '$path.goal',
        'wants ${achievement.goal} ${achievement.stat} and this content set '
        'has $ceiling at most',
      );
    }
    byStat.putIfAbsent(achievement.stat, () => []).add(achievement);
    if (achievement.rewardCoins == 0 && achievement.rewardGems == 0) {
      issues.add(path, 'pays nothing');
    }
    if (achievement.playGamesId.isNotEmpty &&
        !seenPlayGames.add(achievement.playGamesId)) {
      issues.add('$path.playGamesId', 'already mapped to another goal');
    }
  }
  _validateAchievementLadders(byStat, issues);
}

/// Goals on the same counter have to climb, and pay more as they do.
///
/// Two cards measuring the same thing at the same level is one card too many -
/// the screen shows both, both fill on the same win, and the player wonders
/// which is the bug. And a ladder where the harder goal pays less teaches the
/// player that the list is not worth reading.
void _validateAchievementLadders(
  Map<String, List<AchievementSpec>> byStat,
  ContentIssues issues,
) {
  for (final entry in byStat.entries) {
    final ladder = [...entry.value]
      ..sort((a, b) => a.goal.compareTo(b.goal));
    final firstAt = <int, AchievementSpec>{};
    AchievementSpec? previous;
    for (final card in ladder) {
      final already = firstAt[card.goal];
      if (already != null) {
        issues.add(
          'achievements/${card.id}.goal',
          'measures ${entry.key} ${card.goal} times, which '
          '${already.id} already does',
        );
        continue;
      }
      firstAt[card.goal] = card;
      final before = previous;
      previous = card;
      if (before == null) continue;
      if (card.rewardCoins < before.rewardCoins ||
          card.rewardGems < before.rewardGems) {
        issues.add(
          'achievements/${card.id}',
          'is the harder ${entry.key} goal than ${before.id} and pays less',
        );
      }
    }
  }
}

void _validateShop(
  GameContent content,
  ContentIssues issues,
  ContentAssetChecker? assetExists,
) {
  final seen = <String>{};
  final seenProducts = <String>{};
  for (final item in content.shop) {
    final path = 'shop/${item.id}';
    if (!seen.add(item.id)) issues.add(path, 'duplicate id');
    if (!ShopSpec.types.contains(item.type)) {
      issues.add('$path.type', 'is not a kind of thing the shop sells');
    }
    if (item.name.isEmpty || item.description.isEmpty) {
      issues.add(path, 'needs a name and a description to sell it');
    }
    if (item.isIap) {
      if (item.iapProductId.isEmpty) {
        issues.add('$path.iapProductId', 'a paid row needs a store product');
      } else if (!seenProducts.add(item.iapProductId)) {
        issues.add('$path.iapProductId', 'is already on sale');
      }
      if (item.coins > 0 || item.gems > 0) {
        issues.add(path, 'a store item cannot also cost wallet currency');
      }
      // A listing the till cannot honour is the worst kind of shop bug: the
      // player pays, the purchase completes, and nothing arrives.
      if (item.grantCoins == 0 && item.entitlement.isEmpty) {
        issues.add('$path.grantCoins', 'takes money and delivers nothing');
      }
      if (item.entitlement.isNotEmpty &&
          item.entitlement != ShopSpec.kRemoveAds) {
        issues.add(
          '$path.entitlement',
          '"${item.entitlement}" is not something the game can switch on, '
          'expected ${ShopSpec.kRemoveAds}',
        );
      }
      continue;
    }
    if (item.iapProductId.isNotEmpty) {
      issues.add(
        '$path.iapProductId',
        'only a store item may carry a product id',
      );
    }
    if (item.grantCoins > 0 || item.entitlement.isNotEmpty) {
      issues.add(
        path,
        'only a store item may grant coins or an entitlement',
      );
    }
    if (item.free) continue;
    if (item.coins == 0 && item.gems == 0) {
      issues.add(path, 'costs nothing without being marked free');
    }
    if (item.coins > 0 && item.gems > 0) {
      issues.add(path, 'asks for two currencies at once');
    }
    if (item.type == 'tubeSkin' && assetExists != null) {
      for (final asset in [item.glassImage, item.heroImage]) {
        if (!assetExists(asset)) {
          issues.add(path, 'no such skin image: $asset');
        }
      }
    }
    // A theme is the room the game paints, so it has to say what that room
    // looks like. An id the screen once branched on is gone: a row names either
    // the gradient it paints with or the art it wears, and a row that names
    // neither would sell a look nothing delivers.
    if (item.type == 'theme') {
      if (item.gradient.length < 2 && item.image.isEmpty) {
        issues.add(
          path,
          'paints nothing: a theme names a gradient of 2 to 4 colours or the '
          'image it wears',
        );
      }
      if (item.image.isNotEmpty && assetExists != null) {
        if (!assetExists(item.image)) {
          issues.add('$path.image', '${item.image} does not exist');
        }
      }
    }
  }
  for (final type in ['tubeSkin', 'theme']) {
    if (!content.shop.any((item) => item.type == type && item.free)) {
      issues.add('shop', 'a $type row marked free is what everyone starts with');
    }
  }
}

/// The dial's wedges, and what one turn of it can pay.
///
/// Every wedge is equally likely - the screen lands on a random angle, not on a
/// weighted table - so the average across the dial is exactly what a day of free
/// spins puts into the wallet. That is the number this checks, which is why a
/// dial of duds with one jackpot hidden in it fails: the jackpot is the payout,
/// spread over every spin.
void _validateWheel(GameContent content, ContentIssues issues) {
  final segments = content.wheel;
  if (segments.isEmpty) {
    issues.add('wheel/segments', 'a dial with no wedges cannot be spun');
    return;
  }
  if (segments.length < kWheelMinSegments) {
    issues.add(
      'wheel/segments',
      '${segments.length} wedges is not a wheel, expected at least '
      '$kWheelMinSegments',
    );
  }
  if (segments.length > kWheelMaxSegments) {
    issues.add(
      'wheel/segments',
      '${segments.length} wedges do not fit the dial the screen draws, '
      'expected at most $kWheelMaxSegments',
    );
  }

  final seen = <String>{};
  var coinTotal = 0;
  var gemTotal = 0;
  var pays = 0;
  var duds = 0;
  for (final segment in segments) {
    final path = 'wheel/${segment.id}';
    if (!seen.add(segment.id)) issues.add(path, 'duplicate id');
    switch (segment.kind) {
      case 'coins':
        if (segment.amount == 0) {
          issues.add(path, 'a coin wedge that pays 0 is a dud wearing a number');
        } else if (segment.amount > kWheelMaxCoins) {
          issues.add(
            '$path.amount',
            'pays more than any board does, so the dial becomes the '
            'cheapest thing to open',
          );
        }
        coinTotal += segment.amount;
        pays++;
      case 'gems':
        if (segment.amount == 0) {
          issues.add(path, 'a gem wedge that pays 0 is a dud wearing a number');
        } else if (segment.amount > kWheelMaxGems) {
          issues.add(
            '$path.amount',
            'hands back more than a bottle costs, and the sink loses',
          );
        }
        gemTotal += segment.amount;
        pays++;
      default:
        if (segment.amount != 0) {
          issues.add(
            '$path.amount',
            'a dud cannot hold ${segment.amount}; the wedge says one thing '
            'and the purse does another',
          );
        }
        duds++;
    }
  }
  if (pays == 0) {
    issues.add('wheel/segments', 'nothing on the dial pays, so it is not a prize');
  }
  if (duds == 0) {
    issues.add(
      'wheel/segments',
      'every wedge pays, which makes the daily turn pure minting',
    );
  }

  final expectedCoins = coinTotal / segments.length;
  if (expectedCoins > kWheelMaxExpectedCoins) {
    issues.add(
      'wheel',
      'pays ${expectedCoins.toStringAsFixed(0)} coins a spin on average and '
      'the economy carries $kWheelMaxExpectedCoins at most',
    );
  }
  final expectedGems = gemTotal / segments.length;
  if (expectedGems > kWheelMaxExpectedGems) {
    issues.add(
      'wheel',
      'pays ${expectedGems.toStringAsFixed(2)} gems a spin on average and '
      'the sink takes $kWheelMaxExpectedGems back at most',
    );
  }
}

void _validateRewards(GameContent content, ContentIssues issues) {
  final rewards = content.rewards;
  for (final key in kPowerUpCostKeys) {
    if (!rewards.powerUpCosts.containsKey(key)) {
      issues.add('rewards/powerUps.costs.$key', 'every power-up needs a price');
    }
  }
  if (rewards.streakCycle < 2) {
    issues.add('rewards/streak.cycleDays', 'a streak of one day is not a cycle');
  }
  if (rewards.levelXpBase < 1 || rewards.levelXpStep < 1) {
    issues.add('rewards/player', 'an experience curve has to climb');
  }
}

/// The metrics a win can feed, spelled the way a document spells them. The
/// storage keys they persist under are a separate matter, so progress a player
/// already banked survives a rename here.
final List<String> _metricKeys = [
  for (final metric in EventMetric.values) metric.name,
];
