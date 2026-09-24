import 'dart:io';

import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/screens/achievements_screen.dart';
import 'package:color_puzzle_game/screens/dashboard_screen.dart';
import 'package:color_puzzle_game/screens/events_screen.dart';
import 'package:color_puzzle_game/screens/game_screen.dart';
import 'package:color_puzzle_game/screens/level_map_screen.dart';
import 'package:color_puzzle_game/screens/lucky_spin_screen.dart';
import 'package:color_puzzle_game/screens/quests_screen.dart';
import 'package:color_puzzle_game/screens/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// Screens are laid out at a phone size on purpose: every layout here is
/// composed for portrait, and the 800x600 test default hides the overflow a
/// 390dp device shows on the first frame.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
    stubAdsChannel();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  /// Every screen here loads its body from Hive on the first frame, and a fake
  /// clock never lets that disk read come back, so the pumps alternate real
  /// waiting with frames. The liquid wave runs on a repeat() controller, so
  /// waiting for the tree to settle on its own is not an option either.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: screen,
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpAtPhoneSize(WidgetTester tester, Widget screen) =>
      pumpScreen(tester, screen);

  testWidgets('the level map renders chapter banners without overflow', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester, const LevelMapScreen());
    // The map auto-scrolls to the current level 500ms in and animates for
    // 800ms; leaving that timer pending fails the test at teardown.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 900));

    expect(tester.takeException(), isNull);
    expect(find.text('CHAPTER 1 · FIRST POURS'), findsOneWidget);
  });

  testWidgets('the board lays out with all four priced power-ups', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester, const GameScreen(targetLevel: 7));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    expect(find.text('50'), findsNWidgets(3));
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('the event board shows the live calendar on a phone', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester, const EventsScreen());

    expect(tester.takeException(), isNull);
    // Only the two cards that fit the viewport are laid out, so assert on
    // those; the rest of the calendar is verified by the catalog tests.
    expect(find.text('SEASON OF SPLASH'), findsOneWidget);
    expect(find.text('STAR HUNT'), findsOneWidget);
    // The season cycle is 28 days long, so there is always something live.
    expect(find.text('LIVE'), findsWidgets);
  });

  testWidgets('the shop prices cosmetics in coins and in gems', (tester) async {
    await pumpAtPhoneSize(tester, const ShopScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('BOTTLES'), findsOneWidget);
    // Neon Glow still costs coins; the flagship bottle is bought with gems.
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.byIcon(Icons.diamond), findsWidgets);
  });

  testWidgets('a fresh account is offered the free spin', (tester) async {
    await pumpAtPhoneSize(tester, const LuckySpinScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('SPIN NOW'), findsOneWidget);
  });

  testWidgets('the achievement list reads the real win count', (tester) async {
    await pumpAtPhoneSize(tester, const AchievementsScreen());

    expect(tester.takeException(), isNull);
    // Cards print their titles in caps.
    expect(find.text('BEGINNER'), findsOneWidget);
    expect(find.text('GRANDMASTER'), findsOneWidget);
  });

  testWidgets('the home menu lays out its HUD and mode cards', (tester) async {
    await pumpAtPhoneSize(tester, const DashboardScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('PLAY CLASSIC'), findsOneWidget);
    // The level and its bar come from stored XP, not from the level number, so
    // a fresh account reads level one with the whole first step still to go.
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0 / 80'), findsOneWidget);
  });

  // A 320x568 screen is the smallest phone still in the Play catalogue, and a
  // late level is the fullest board. If either overflows, the frame reports it.
  group('on the smallest supported phone', () {
    const tiny = Size(320, 568);

    testWidgets('a deep board still fits', (tester) async {
      await pumpScreen(tester, const GameScreen(targetLevel: 40), size: tiny);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the shop keeps its tabs and prices', (tester) async {
      await pumpScreen(tester, const ShopScreen(), size: tiny);
      expect(tester.takeException(), isNull);
      expect(find.text('PREMIUM'), findsOneWidget);
    });

    testWidgets('the event cards keep their badges', (tester) async {
      await pumpScreen(tester, const EventsScreen(), size: tiny);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the wheel keeps its spin button', (tester) async {
      await pumpScreen(tester, const LuckySpinScreen(), size: tiny);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('SPIN'), findsWidgets);
    });

    testWidgets('the home menu keeps its play button', (tester) async {
      await pumpScreen(tester, const DashboardScreen(), size: tiny);
      expect(tester.takeException(), isNull);
      expect(find.text('PLAY CLASSIC'), findsOneWidget);
    });

    testWidgets('the quest rows keep their reward chips', (tester) async {
      await pumpScreen(tester, const QuestsScreen(), size: tiny);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the achievement cards keep their titles', (tester) async {
      await pumpScreen(tester, const AchievementsScreen(), size: tiny);
      expect(tester.takeException(), isNull);
    });
  });
}
