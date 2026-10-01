import 'dart:io';

import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/core/storage_service.dart';
import 'package:color_puzzle_game/controllers/game_controller.dart'
    show GameMode;
import 'package:color_puzzle_game/content/content_repository.dart';
import 'package:color_puzzle_game/game/events.dart' show EventCalendar;
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
    await useScreenSize(tester, size);
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

  testWidgets('a side mode map draws its own ladder, not the campaign', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester, const LevelMapScreen(mode: GameMode.challenge));
    // The map scrolls to its own first stage; that timer has to be spent before
    // the test ends, or it fails on a pending timer.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 900));

    expect(tester.takeException(), isNull);
    expect(find.text('CHALLENGE'), findsOneWidget);
    expect(find.text('CHALLENGE · 12 STAGES'), findsOneWidget);
    // The campaign's chapters are a different trail. A player who came here for
    // Challenge should not be shown a chapter they cannot walk.
    expect(find.textContaining('CHAPTER'), findsNothing);

    // Tapping the stage has to carry the mode with it, or the board opens as a
    // campaign level and the stage's own records are never written. The row's
    // own tap handler is what is under test here, and a locked row would take no
    // action at all.
    final node = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.text('1'),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    node.onTap!();
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
    final opened = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(opened.mode, GameMode.challenge);
    expect(opened.targetLevel, 1);
  });

  testWidgets('the other ladder keeps its own name and its own card', (
    tester,
  ) async {
    await pumpAtPhoneSize(
      tester,
      const LevelMapScreen(mode: GameMode.timeAttack),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 900));

    expect(tester.takeException(), isNull);
    expect(find.text('TIME ATTACK'), findsOneWidget);
    expect(find.text('TIME ATTACK · 12 STAGES'), findsOneWidget);
    expect(find.textContaining('CHAPTER'), findsNothing);

    // Same walk as above: this mode's board has to open as its own stage, or
    // its records land on Challenge's ledger.
    final node = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.text('1'),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    node.onTap!();
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
    final opened = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(opened.mode, GameMode.timeAttack);
    expect(opened.targetLevel, 1);
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

  testWidgets('a bought theme paints the room the card previewed', (
    tester,
  ) async {
    // The shop card and the wall behind the board read the same row of
    // shop.json. A theme used to exist only as an `if (id == ...)` branch in two
    // screens, which is how a room could be sold for a picture the game never
    // showed.
    final forest = ContentRepository.content.themeFor('forest_theme')!;
    await tester.runAsync(
      () => StorageService.setSelectedTheme('forest_theme'),
    );
    await pumpAtPhoneSize(tester, const GameScreen(targetLevel: 1));

    expect(tester.takeException(), isNull);
    final painted = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<RadialGradient>()
        // Joined rather than compared as lists: two equal `List<int>`s are not
        // `==` to each other, and `contains` would never match.
        .map(
          (gradient) =>
              gradient.colors.map((color) => color.toARGB32()).join(','),
        )
        .toList();
    expect(
      painted,
      contains(forest.gradientColors.map((color) => color.toARGB32()).join(',')),
      reason: 'the card sold a green room and the board is wearing another',
    );

    // The free theme is the other half of the same rule: an image row. The
    // empty frame in between is what makes the screen re-read storage - pump
    // the same widget type twice and it keeps the State it already built.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => StorageService.setSelectedTheme('default_theme'),
    );
    await pumpAtPhoneSize(tester, const GameScreen(targetLevel: 1));

    expect(tester.takeException(), isNull);
    expect(
      tester.widgetList<Image>(find.byType(Image)).map((image) => image.image),
      contains(
        isA<AssetImage>().having(
          (asset) => asset.assetName,
          'assetName',
          ContentRepository.content.themeFor('default_theme')!.image,
        ),
      ),
      reason: 'the room a theme names is the room that gets drawn',
    );
  });

  testWidgets('the event board shows the live calendar on a phone', (
    tester,
  ) async {
    await pumpAtPhoneSize(tester, const EventsScreen());

    expect(tester.takeException(), isNull);
    // Twelve runs, and only the cards that fit the viewport get laid out, so
    // this promises the calendar's shape rather than one card's name: the board
    // opens on what is running now, and a preview never wedges in between.
    final now = DateTime.now();
    final liveByTitle = {
      for (final event in ContentRepository.content.events)
        event.title: event.windowAt(now).isOpen,
    };
    final painted = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .where(liveByTitle.containsKey)
        .toList();
    final flags = [for (final title in painted) liveByTitle[title]!];

    expect(painted, isNotEmpty, reason: 'the board painted no event card');
    expect(flags.first, isTrue, reason: 'the calendar opened on a preview');
    expect(
      flags,
      orderedEquals([...flags.where((open) => open), ...flags.where((open) => !open)]),
      reason: 'the live runs are meant to be the top of the list',
    );
    // The season cycle is 28 days long and open for all of it, so there is
    // always something wearing the LIVE mark.
    expect(find.text('LIVE'), findsWidgets);
  });

  testWidgets('the shop prices cosmetics in coins and in gems', (tester) async {
    await pumpAtPhoneSize(tester, const ShopScreen());

    expect(tester.takeException(), isNull);
    expect(find.text('BOTTLES'), findsOneWidget);
    // Neon Glow still costs coins, and the card the viewport shows first is one
    // of the coin rows; the flagship bottles are bought with gems and live
    // further down the grid, so this scrolls to the first of them rather than
    // trusting a row number that grows with the catalogue.
    expect(find.text('1000'), findsOneWidget);
    final gemPrice = '${ContentRepository.content.shop.firstWhere(
          (item) => item.type == 'tubeSkin' && item.gems > 0,
        ).gems}';
    await tester.dragUntilVisible(
      find.text(gemPrice),
      find.byType(GridView),
      const Offset(0, -200),
    );
    expect(find.text(gemPrice), findsOneWidget);
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
    // Nothing here claims today's prize, so no tile may wear the spent mark.
    expect(find.byIcon(Icons.check), findsNothing);
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
