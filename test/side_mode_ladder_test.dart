/// The ladders the side modes walk.
///
/// Challenge and Time Attack used to borrow the campaign's unlocked level and
/// ride three levels past it, which meant they had no map, no end and no record
/// of their own. These tests are the four things that has to stay true now: a
/// stage is dealt from its ladder, a ladder keeps its own unlocks and bests,
/// the campaign is not part of either, and a ladder ends.
library;

import 'dart:io';

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/content/content_repository.dart';
import 'package:color_puzzle_game/core/storage_service.dart';
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

  /// Opens a run the way the dashboard does - with the saved numbers read in -
  /// and waits for its board to be dealt. Real time, not `tester.pump`: Hive
  /// writes never complete under a widget test's fake clock.
  Future<GameController> open(GameMode mode) async {
    final controller = GameController(mode: mode);
    addTearDown(controller.dispose);
    for (var i = 0; i < 100 && controller.tubes.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(controller.tubes, isNotEmpty, reason: '$mode never dealt a board');
    return controller;
  }

  /// Beats [stage] of [mode] in one move, which is inside any par, and waits for
  /// the payout to reach storage.
  Future<GameController> winStage(
    GameMode mode, {
    required int stage,
  }) async {
    final controller = GameController(
      mode: mode,
      loadProgress: false,
      targetLevel: stage,
    );
    addTearDown(controller.dispose);
    controller.tubes = [
      Tube(initialColors: [red, red, red]),
      Tube(initialColors: [red]),
    ];

    controller.selectTube(1);
    controller.selectTube(0);
    for (var i = 0; i < 100 && !controller.winRewarded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(controller.isLevelComplete, isTrue);
    expect(controller.winRewarded, isTrue, reason: 'stage $stage paid nothing');
    return controller;
  }

  int anchorOf(String ladderId, int stage) =>
      ContentRepository.content.stageAnchor(ladderId, stage)!;

  test('a ladder opens on its own first stage, wherever the campaign is', () async {
    // The number the side modes used to read. If one ever borrows it again, a
    // player who has never opened Challenge lands on a board from chapter 4.
    await StorageService.saveLevel(60);

    final campaign = await open(GameMode.classic);
    expect(
      campaign.currentLevel,
      60,
      reason: 'the campaign did not resume where it stopped',
    );

    for (final (mode, id) in [
      (GameMode.challenge, 'challenge'),
      (GameMode.timeAttack, 'timeAttack'),
    ]) {
      final run = await open(mode);
      expect(run.currentLevel, 1, reason: '$id opened somewhere else');
      expect(
        run.designLevel,
        anchorOf(id, 1),
        reason: '$id stage 1 is not the curve level its ladder names',
      );
    }
  });

  test('a stage number means a stage, not a campaign level', () async {
    final content = ContentRepository.content;
    for (final (mode, id) in [
      (GameMode.challenge, 'challenge'),
      (GameMode.timeAttack, 'timeAttack'),
    ]) {
      final run = GameController(
        mode: mode,
        loadProgress: false,
        targetLevel: 5,
      );
      addTearDown(run.dispose);
      expect(run.currentLevel, 5);
      expect(run.designLevel, anchorOf(id, 5));

      // A request past the end of the ladder plays its last stage rather than a
      // board nothing dealt.
      final past = GameController(
        mode: mode,
        loadProgress: false,
        targetLevel: content.stageCountOf(id) + 40,
      );
      addTearDown(past.dispose);
      expect(past.currentLevel, content.stageCountOf(id));
      expect(past.designLevel, anchorOf(id, content.stageCountOf(id)));
    }
  });

  test('beating a stage opens the next one and leaves the campaign alone', () async {
    final unlockedBefore = await StorageService.getLevel();
    final starsOn60Before = await StorageService.getLevelStars(60);

    await winStage(GameMode.challenge, stage: 6);

    expect(
      await StorageService.getModeProgress('challenge'),
      7,
      reason: 'the ladder did not open the next stage',
    );
    expect(
      await StorageService.getLevel(),
      unlockedBefore,
      reason: 'a side mode win cannot unlock campaign levels',
    );
    expect(await StorageService.getLevelStars(60), starsOn60Before);
    // The stage's own rating is filed where the stage's own map reads it.
    expect(await StorageService.getModeStars('challenge', 6), 3);
    expect(await StorageService.getModeStarsByStage('challenge'), contains(6));
  });

  test('two ladders never read each other\'s records', () async {
    await winStage(GameMode.timeAttack, stage: 11);
    expect(await StorageService.getModeProgress('timeAttack'), 12);
    expect(await StorageService.getModeStars('timeAttack', 11), 3);

    expect(
      await StorageService.getModeProgress('challenge'),
      lessThan(11),
      reason: 'a Time Attack best unlocked a Challenge stage',
    );
    expect(await StorageService.getModeStars('challenge', 11), 0);
    expect(
      (await StorageService.getModeStarsByStage('challenge')).keys,
      isNot(contains(11)),
    );
  });

  test('a stage pays its first three-star once, however often it is replayed', () async {
    final gemsBefore = await StorageService.getGems();
    final first = await winStage(GameMode.challenge, stage: 9);
    expect(first.gemsEarned, greaterThan(0));

    final again = await winStage(GameMode.challenge, stage: 9);
    expect(again.starsEarned, 3);
    expect(
      again.gemsEarned,
      0,
      reason: 'the same stage paid the first-clear gem twice',
    );
    expect(await StorageService.getGems(), gemsBefore + first.gemsEarned);
  });

  test('a side mode pays a share of a campaign win, at its own curve level', () async {
    const id = 'challenge';
    final run = await winStage(GameMode.challenge, stage: 4);
    expect(
      run.coinsEarned,
      LevelReward.coinsFor(
        level: anchorOf(id, 4),
        stars: run.starsEarned,
        sideMode: true,
      ),
      reason: 'a ladder stage should pay like the campaign board it stands on',
    );
  });

  test('the last stage has no next one', () async {
    final last = ContentRepository.content.stageCountOf('challenge');
    final onLast = GameController(
      mode: GameMode.challenge,
      loadProgress: false,
      targetLevel: last,
    );
    addTearDown(onLast.dispose);
    expect(onLast.hasNextStage, isFalse);
    expect(onLast.winRibbon, 'STAGE $last');
    // Walking off the end must not deal stage last again and pay for it twice.
    await onLast.nextLevel();
    expect(onLast.currentLevel, last);

    final onFirst = GameController(
      mode: GameMode.challenge,
      loadProgress: false,
      targetLevel: 1,
    );
    addTearDown(onFirst.dispose);
    expect(onFirst.hasNextStage, isTrue);
    await onFirst.nextLevel();
    expect(onFirst.currentLevel, 2);

    final campaign = GameController(
      loadProgress: false,
      targetLevel: 12,
    );
    addTearDown(campaign.dispose);
    expect(campaign.hasNextStage, isTrue);
    expect(campaign.winRibbon, 'LEVEL 12');
  });
}
