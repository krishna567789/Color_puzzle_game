import 'dart:io';

import 'package:color_puzzle_game/core/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// The stores make a player able to delete their own data from inside the app,
/// so the wipe has to be reachable, complete, and careful about the one thing on
/// the box that the player paid for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  setUp(() async => StorageService.resetAllSettings());

  Future<void> playALongWay() async {
    await StorageService.saveLevel(40);
    await StorageService.saveCoins(3000);
    await StorageService.saveGems(77);
    await StorageService.saveLevelStars(39, 3);
    await StorageService.setMusic(false);
    await StorageService.setLeftHandedLayout(true);
    await StorageService.setTutorialCompleted(true);
    await StorageService.setLoginStreak(11);
  }

  test('a deletion takes everything the player earned', () async {
    await playALongWay();

    await StorageService.deletePlayerData();

    expect(await StorageService.getLevel(), 1);
    expect(await StorageService.getLevelStars(39), 0);
    expect(await StorageService.getCoins(), 500);
    expect(await StorageService.getGems(), 10);
    expect(await StorageService.getMusic(), isTrue);
    expect(await StorageService.getLeftHandedLayout(), isFalse);
    expect(await StorageService.getLoginStreak(), 0);
  });

  test('a deletion leaves the licence that was bought', () async {
    await playALongWay();
    await StorageService.setHasRemovedAds(true);
    expect(
      await StorageService.markPurchaseDelivered('receipt-1'),
      isTrue,
      reason: 'first sight of a receipt',
    );

    await StorageService.deletePlayerData();

    expect(await StorageService.getHasRemovedAds(), isTrue);
    expect(
      await StorageService.markPurchaseDelivered('receipt-1'),
      isFalse,
      reason: 'the same receipt must not pay out twice after a wipe',
    );
  });

  test('a payout queued before a deletion does not survive it', () async {
    await StorageService.saveCoins(300);

    // Both go through the wallet chain, so the order is settled, not raced.
    final grant = StorageService.addCoins(100);
    final delete = StorageService.deletePlayerData();
    await grant;
    await delete;

    expect(await StorageService.getCoins(), 500);
  });
}
