import 'dart:io';

import 'package:color_puzzle_game/core/progress_service.dart';
import 'package:color_puzzle_game/core/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// The wallet is written from several places at once - a win payout, a store
/// receipt, a quest claim - and every one of them used to read the balance,
/// change their own copy and write it back. Whichever finished last discarded
/// the money the others had just added.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  setUp(() async => StorageService.resetAllSettings());

  test('every payout arriving at the same moment lands', () async {
    await StorageService.saveCoins(500);

    await Future.wait([
      ProgressService.grant(coins: 100),
      StorageService.addCoins(250),
      ProgressService.grant(coins: 20),
    ]);

    expect(await StorageService.getCoins(), 870);
  });

  test('two racing purchases cannot both be honoured', () async {
    await StorageService.saveCoins(100);

    final results = await Future.wait([
      ProgressService.spend(coins: 100),
      ProgressService.spend(coins: 100),
    ]);

    expect(
      results.where((paid) => paid).length,
      1,
      reason: 'both went through',
    );
    expect(await StorageService.getCoins(), 0);
  });

  test('a balance never goes below zero', () async {
    await StorageService.saveGems(3);

    expect(await StorageService.addGems(-9999), 0);
    expect(await StorageService.getGems(), 0);
  });

  test('a purchase is refused whole when one half cannot be paid', () async {
    await StorageService.saveCoins(500);
    await StorageService.saveGems(1);

    expect(await ProgressService.spend(coins: 100, gems: 5), isFalse);
    expect(
      await StorageService.getCoins(),
      500,
      reason: 'took the coins anyway',
    );
  });
}
