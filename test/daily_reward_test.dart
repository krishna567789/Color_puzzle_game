/// Today's board, and the one prize it carries.
///
/// The daily pays once a day, and until now only the controller knew that: the
/// tile on the dashboard and the card that closes a run both had a stored date
/// to read and never read it, so a replayed daily looked unclaimed and paid
/// zeroes like a bug. These are the claims that keep it looking spent instead.
library;

import 'dart:io';

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/core/storage_service.dart';
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
    stubAdsChannel();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  setUp(() async => StorageService.resetAllSettings());

  /// Beats today's board in one move and waits for the payout to reach storage.
  Future<GameController> winDaily() async {
    final controller = GameController(
      mode: GameMode.daily,
      loadProgress: false,
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
    expect(
      controller.winRewarded,
      isTrue,
      reason: "today's board paid nothing",
    );
    return controller;
  }

  test('the prize is claimed once for a date', () async {
    final today = StorageService.todayKey;

    expect(await StorageService.hasClaimedDailyReward(today), isFalse);
    expect(await StorageService.claimDailyReward(today), isTrue);
    expect(await StorageService.hasClaimedDailyReward(today), isTrue);
    expect(await StorageService.claimDailyReward(today), isFalse);
  });

  test("today's first win pays, and only the first", () async {
    // A new wallet is not empty - it opens with a starter purse - so every
    // claim here is a delta rather than an absolute balance.
    final coinsBefore = await StorageService.getCoins();
    final gemsBefore = await StorageService.getGems();
    final xpBefore = await StorageService.getPlayerXp();

    final first = await winDaily();

    expect(first.coinsEarned, 100);
    expect(first.gemsEarned, 1);
    expect(first.dailyPrizeAlreadyClaimed, isFalse);
    expect(await StorageService.getCoins(), coinsBefore + 100);
    expect(await StorageService.getGems(), gemsBefore + 1);
    final xp = await StorageService.getPlayerXp();
    expect(xp, greaterThan(xpBefore), reason: 'the first claim paid no XP');

    final replay = await winDaily();

    // The board is still beaten - it just has nothing left to hand over.
    expect(replay.isLevelComplete, isTrue);
    expect(replay.starsEarned, greaterThan(0));
    expect(replay.dailyPrizeAlreadyClaimed, isTrue, reason: 'replay looked new');
    expect(replay.coinsEarned, 0);
    expect(replay.gemsEarned, 0);
    expect(await StorageService.getCoins(), coinsBefore + 100);
    expect(await StorageService.getGems(), gemsBefore + 1);
    expect(
      await StorageService.getPlayerXp(),
      xp,
      reason: 'replaying one board levelled the player up again',
    );
  });

  test('a run dealt after the claim starts out knowing it', () async {
    await StorageService.claimDailyReward(StorageService.todayKey);

    final controller = GameController(mode: GameMode.daily);
    addTearDown(controller.dispose);
    for (var i = 0; i < 100 && !controller.hasClaimedDailyReward; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(
      controller.hasClaimedDailyReward,
      isTrue,
      reason: 'the run was dealt as if the prize were still there',
    );
  });

  test('the stored date the run writes is the one the tile reads', () async {
    // Two hand-rolled date formats used to disagree about the same day, so a
    // claim written by one surface could not be seen by the other.
    final first = await winDaily();
    expect(first.dailyPrizeAlreadyClaimed, isFalse);

    expect(
      await StorageService.hasClaimedDailyReward(StorageService.todayKey),
      isTrue,
      reason: 'the win claimed a date nothing else reads',
    );
  });
}
