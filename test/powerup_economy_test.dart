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
  final blue = const Color(0xFF1E88E5);

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  /// A controller with a hand-built board and no timer running.
  GameController controllerWith(List<Tube> tubes, {int coins = 500}) {
    final controller = GameController(loadProgress: false);
    controller.coins = coins;
    controller.tubes = tubes;
    return controller;
  }

  group('power-up pricing', () {
    test('charging a hint deducts exactly its price', () {
      final controller = controllerWith([
        Tube(initialColors: [red]),
        Tube(initialColors: [blue]),
        Tube(),
      ]);

      expect(controller.canUsePowerUp(PowerUp.hint), isTrue);
      expect(controller.requestHint(), isTrue);
      expect(controller.coins, 500 - GameController.hintCost);
      expect(controller.activeHint, isNotNull);

      controller.dispose();
    });

    test('an ad-funded power-up costs no coins', () {
      final controller = controllerWith(
        [Tube(initialColors: [red]), Tube()],
        coins: 0,
      );

      expect(controller.requestHint(adFunded: true), isTrue);
      expect(controller.coins, 0);
      expect(controller.activeHint, isNotNull);

      controller.dispose();
    });

    test('a power-up that cannot apply is never charged', () {
      // Red on top of a full red tube: no legal pour exists on this board.
      final controller = controllerWith([
        Tube(initialColors: [red]),
        Tube(initialColors: [red, red, red, red]),
      ]);

      expect(controller.canUsePowerUp(PowerUp.hint), isFalse);
      expect(controller.requestHint(), isFalse);
      expect(controller.coins, 500);
      expect(controller.activeHint, isNull);

      controller.dispose();
    });

    test('the balance can never go negative', () {
      final controller = controllerWith([Tube(initialColors: [red])], coins: 10);
      final tubeCount = controller.tubes.length;

      expect(controller.addExtraTube(), isFalse);
      expect(controller.tubes.length, tubeCount);
      expect(controller.coins, 10);

      controller.dispose();
    });

    test('a bottle the board has no room for is never sold', () {
      final ceiling = GameController.maxBoardTubes;
      final controller = controllerWith(
        [for (var i = 0; i < ceiling - 1; i++) Tube(initialColors: [red])],
        coins: 100000,
      );

      expect(controller.addExtraTube(), isTrue);
      expect(controller.tubes.length, ceiling);
      // The HUD greys the button off on this same answer.
      expect(controller.canUsePowerUp(PowerUp.addTube), isFalse);

      final coins = controller.coins;
      expect(controller.addExtraTube(), isFalse);
      expect(controller.addExtraTube(adFunded: true), isFalse);
      expect(controller.tubes.length, ceiling);
      expect(
        controller.coins,
        coins,
        reason: 'the ceiling has to stop the sale, not only the bottle',
      );

      controller.dispose();
    });

    test('undo is unavailable until a move has been made', () {
      final controller = controllerWith([Tube(initialColors: [red]), Tube()]);

      expect(controller.canUsePowerUp(PowerUp.undo), isFalse);
      expect(controller.undo(), isFalse);
      expect(controller.coins, 500);

      controller.dispose();
    });

    test('extra chances are capped', () {
      final controller = controllerWith([Tube(initialColors: [red])]);
      controller.isGameOver = true;

      for (var i = 0; i < GameController.maxExtraChances + 2; i++) {
        controller.isGameOver = true;
        controller.useExtraChance(false, isAd: true);
      }

      expect(controller.extraChancesUsed, GameController.maxExtraChances);

      controller.dispose();
    });
  });

  group('purchase ledger', () {
    test('the same purchase id is only delivered once', () async {
      expect(await StorageService.markPurchaseDelivered('order-1'), isTrue);
      expect(await StorageService.markPurchaseDelivered('order-1'), isFalse);
    });

    test('concurrent replays of one purchase are serialised', () async {
      final results = await Future.wait([
        StorageService.markPurchaseDelivered('order-race'),
        StorageService.markPurchaseDelivered('order-race'),
        StorageService.markPurchaseDelivered('order-race'),
      ]);

      expect(results.where((r) => r).length, 1);
    });

    test('an id-less purchase is still delivered', () async {
      expect(await StorageService.markPurchaseDelivered(''), isTrue);
    });
  });
}
