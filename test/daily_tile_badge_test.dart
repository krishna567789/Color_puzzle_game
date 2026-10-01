/// The dashboard has to say when today's daily is already spent.
///
/// One widget test in this file, on purpose: pumping the dashboard fires a
/// login-streak write, and a Hive write started under a widget test's fake clock
/// never finishes - the box keeps its own write lock, so the next write in the
/// file would hang. The claim is therefore put on disk in `setUpAll`, before any
/// frame is drawn.
library;

import 'dart:io';

import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/core/storage_service.dart';
import 'package:color_puzzle_game/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
    stubAdsChannel();
    await StorageService.resetAllSettings();
    await StorageService.claimDailyReward(StorageService.todayKey);
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  testWidgets('a spent daily carries a claimed mark', (tester) async {
    await useScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const DashboardScreen(),
      ),
    );
    // The claimed state arrives off disk, which a fake clock never lets land.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull);
    expect(
      find.byIcon(Icons.check),
      findsOneWidget,
      reason: 'a spent daily still looked claimable on the tile',
    );
  });
}
