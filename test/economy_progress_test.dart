import 'dart:io';

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/content/content_repository.dart';
import 'package:color_puzzle_game/core/progress_service.dart';
import 'package:color_puzzle_game/core/storage_service.dart';
import 'package:color_puzzle_game/game/quests.dart';
import 'package:color_puzzle_game/game/rewards.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final red = const Color(0xFFFF2A2A);

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  setUp(() async => StorageService.resetAllSettings());

  /// Finishes a two tube board and waits for the payout to reach storage.
  ///
  /// Real time, not `tester.pump`: the win writes to Hive, and the fake async
  /// clock of a widget test never lets those disk futures complete.
  Future<GameController> winLevel({
    int level = 4,
    int? previousStars,
    int? par,
  }) async {
    if (previousStars != null) {
      await StorageService.saveLevelStars(level, previousStars);
    }
    final controller = GameController(loadProgress: false, targetLevel: level);
    addTearDown(controller.dispose);
    controller.tubes = [
      Tube(initialColors: [red, red, red], hiddenCount: 1),
      Tube(initialColors: [red]),
    ];
    if (par != null) controller.parMoves = par;

    controller.selectTube(1);
    controller.selectTube(0);
    for (var i = 0; i < 80 && !controller.winRewarded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(controller.isLevelComplete, isTrue);
    expect(controller.winRewarded, isTrue);
    return controller;
  }

  test('a win pays exactly what the end-of-level screen quotes', () async {
    // Read the wallet first: a controller built without progress holds no
    // balance of its own, so the only way to see what a win actually added is
    // to compare against what was stored before it.
    final coinsBefore = await StorageService.getCoins();
    final gemsBefore = await StorageService.getGems();
    final controller = await winLevel();

    expect(controller.starsEarned, 3);
    expect(controller.coinsEarned, LevelReward.coinsFor(level: 4, stars: 3));
    // The first three-star on a level is the one that earns the gem.
    expect(controller.gemsEarned, 1);
    // The win is credited as a delta, so it lands on top of the stored balance
    // instead of replacing it with the number this screen last saw.
    expect(
      await StorageService.getCoins(),
      coinsBefore + controller.coinsEarned,
    );
    expect(await StorageService.getGems(), gemsBefore + controller.gemsEarned);
    expect(await StorageService.getLevelStars(4), 3);
    expect(await StorageService.getPlayerXp(), LevelReward.xpFor(stars: 3));
    expect(await StorageService.getDailyCounter(DailyStat.wins), 1);
    expect(await StorageService.getDailyCounter(DailyStat.stars), 3);
    // The next level is unlocked by the win, not by pressing Next, so walking
    // back to the dashboard cannot put it back behind a lock.
    expect(controller.maxUnlockedLevel, 5);
    expect(await StorageService.getLevel(), 5);
  });

  test('replaying a level already three-starred pays no second gem', () async {
    final gemsBefore = await StorageService.getGems();
    final controller = await winLevel(previousStars: 3);

    expect(controller.starsEarned, 3);
    expect(controller.gemsEarned, 0);
    expect(
      await StorageService.getGems(),
      gemsBefore,
      reason: 'a replay must not touch the wallet at all',
    );
    expect(await StorageService.getLevelStars(4), 3);
  });

  test('a worse replay keeps the better rating and pays no gem', () async {
    // One pour against a par of zero is a two star finish, so the stored three
    // star must survive and the gem must not drop again.
    final controller = await winLevel(level: 9, previousStars: 3, par: 0);

    expect(controller.starsEarned, 2);
    expect(controller.gemsEarned, 0);
    expect(await StorageService.getLevelStars(9), 3);
  });

  test('a chapter pays its purse on the board that closes it, once', () async {
    final chapter = ContentRepository.content.chapters.first;
    final closing = ContentRepository.content.lastLevelOf(chapter);
    final coinsBefore = await StorageService.getCoins();
    final gemsBefore = await StorageService.getGems();

    final controller = await winLevel(level: closing);
    expect(controller.starsEarned, 3);
    expect(controller.chapterReward?.name, chapter.name);
    // The purse is inside what the screen quotes, so a promise and a grant
    // cannot disagree, and it is the level's own payout plus the chapter's.
    expect(
      controller.coinsEarned,
      LevelReward.coinsFor(level: closing, stars: 3) + chapter.rewardCoins,
    );
    expect(controller.gemsEarned, 1 + chapter.rewardGems);
    expect(await StorageService.getCoins(), coinsBefore + controller.coinsEarned);
    expect(await StorageService.getGems(), gemsBefore + controller.gemsEarned);
    expect(await StorageService.getClaimedChapters(), contains(chapter.id));

    // A replay pays the board again - it is a real win - and the chapter never.
    final replay = await winLevel(level: closing, previousStars: 3);
    expect(replay.chapterReward, isNull);
    expect(replay.coinsEarned, LevelReward.coinsFor(level: closing, stars: 3));
    expect(
      await StorageService.getCoins(),
      coinsBefore + controller.coinsEarned + replay.coinsEarned,
      reason: 'the closing board cannot be collected once per attempt',
    );
  });

  test('power-up prices start at the base and grow with the board', () {
    final early = GameController(loadProgress: false, targetLevel: 1);
    addTearDown(early.dispose);
    expect(early.costOf(PowerUp.hint), GameController.hintCost);

    final late = GameController(loadProgress: false, targetLevel: 90);
    addTearDown(late.dispose);
    expect(late.costOf(PowerUp.hint), greaterThan(GameController.hintCost));
    expect(
      late.costOf(PowerUp.hint),
      GameController.hintCost + 45,
      reason: 'L90 is nine steps of five over the base',
    );
  });

  test('the streak advances and pays once per day', () async {
    final yesterday = StorageService.dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    await StorageService.setLoginStreak(6);
    await StorageService.setLastLoginDate(yesterday);

    expect(await ProgressService.tickLoginStreak(), 7);
    expect(ProgressService.streakDay(7), 7);
    // Day seven pays the gem bonus, and nothing else is credited with it.
    expect(await StorageService.getGems(), 10 + StreakReward.gemBonusDay);
    expect(await StorageService.getCoins(), 500);

    await ProgressService.tickLoginStreak();
    expect(
      await StorageService.getGems(),
      15,
      reason: 'a second launch the same day must not pay again',
    );
  });

  test('a missed day restarts the streak at one', () async {
    await StorageService.setLoginStreak(5);
    await StorageService.setLastLoginDate('2020-01-01');

    expect(await ProgressService.tickLoginStreak(), 1);
    expect(ProgressService.streakDay(1), 1);
    expect(await StorageService.getCoins(), 500 + StreakReward.coinsPerDay);
  });

  test('quests read today counters and claim exactly once', () async {
    // A day draws five cards out of the catalogue, so this cannot name a task id
    // and expect it to be on the slate. It reads the slate the player sees and
    // tops up every counter but the one the last card is measured against.
    final slate = QuestCatalog.forDay(StorageService.todayKey);
    final leftOpen = slate.last;
    final finished = slate.firstWhere((spec) => spec.stat != leftOpen.stat);
    final wanted = <String, int>{};
    for (final spec in slate) {
      if (spec.stat == leftOpen.stat) continue;
      if ((wanted[spec.stat] ?? 0) < spec.target) {
        wanted[spec.stat] = spec.target;
      }
    }
    await ProgressService.recordDaily(wanted);

    var quests = await ProgressService.todaysQuests();
    expect(quests, hasLength(slate.length));
    final done = quests.firstWhere((quest) => quest.id == finished.id);
    // Topped up to the hardest card of that counter, so an easier one on the
    // same slate is over the line rather than exactly on it.
    expect(done.currentProgress, greaterThanOrEqualTo(done.targetValue));
    expect(done.isCompleted, isTrue);

    final partial = quests.firstWhere((quest) => quest.id == leftOpen.id);
    expect(partial.isCompleted, isFalse);
    expect(await ProgressService.claimQuest(partial), isFalse);

    expect(await ProgressService.claimQuest(done), isTrue);
    expect(await StorageService.getCoins(), 500 + done.coinReward);
    expect(await ProgressService.claimQuest(done), isFalse);
    expect(await StorageService.getCoins(), 500 + done.coinReward);

    quests = await ProgressService.todaysQuests();
    expect(
      quests.firstWhere((quest) => quest.id == finished.id).isClaimed,
      isTrue,
    );
  });

  test('every win pays XP, a replay included', () async {
    // Coins pay on replays too, so a board worth redoing for its stars is worth
    // the same XP. Nothing is bought with a player level yet, which is what
    // makes this the safe side of the rule to keep simple.
    await winLevel();
    final afterFirst = await StorageService.getPlayerXp();
    await winLevel();

    expect(afterFirst, LevelReward.xpFor(stars: 3));
    expect(await StorageService.getPlayerXp(), afterFirst * 2);
  });

  group('player level curve', () {
    test('starts at level one with an empty bar', () {
      final level = PlayerLevel.fromXp(0);
      expect(level.number, 1);
      expect(level.xpIntoLevel, 0);
      expect(level.xpForNextLevel, PlayerLevel.xpToNext(1));
      expect(level.fraction, 0);
    });

    test('two three-star wins is level two', () {
      final earned = LevelReward.xpFor(stars: 3) * 2;
      expect(earned, PlayerLevel.xpToNext(1));
      final level = PlayerLevel.fromXp(earned);
      expect(level.number, 2);
      expect(level.xpIntoLevel, 0);
      expect(level.fraction, 0);
    });

    test('the bar fills between the steps', () {
      final level = PlayerLevel.fromXp(LevelReward.xpFor(stars: 3));
      expect(level.number, 1);
      expect(level.xpIntoLevel, 40);
      expect(level.xpForNextLevel, 80);
      expect(level.fraction, 0.5);
    });

    test('one win short of a step stays on the level below it', () {
      final level = PlayerLevel.fromXp(PlayerLevel.xpToNext(1) - 1);
      expect(level.number, 1);
      expect(level.xpIntoLevel, 79);
      expect(level.fraction, closeTo(0.9875, 0.0001));
    });

    test('the steps keep growing, so a level means work', () {
      expect(PlayerLevel.xpToNext(1), 80);
      expect(PlayerLevel.xpToNext(2), 120);
      expect(PlayerLevel.fromXp(80 + 120).number, 3);
      expect(PlayerLevel.fromXp(80 + 120 - 1).number, 2);
    });

    test('a nonsense total cannot break the readout', () {
      expect(PlayerLevel.fromXp(-500).number, 1);
      expect(PlayerLevel.fromXp(-500).fraction, 0);
      expect(PlayerLevel.fromXp(5000000).number, greaterThan(1));
      expect(PlayerLevel.fromXp(5000000).fraction, inInclusiveRange(0, 1));
    });
  });
}
