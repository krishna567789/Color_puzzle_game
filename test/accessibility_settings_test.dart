import 'dart:io';

import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/core/storage_service.dart';
import 'package:color_puzzle_game/screens/game_screen.dart';
import 'package:color_puzzle_game/screens/settings_screen.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// An accessibility option that is not persisted, or that is persisted but never
/// read by the screen it belongs to, is a switch that lies to the player. Both
/// halves are checked here: the write reaches Hive, and the board honours it.
///
/// The order of these tests is load-bearing. A Hive write fired from a widget
/// callback runs in the test's fake-async zone and its disk half never finishes
/// there, which leaves the box holding its own write lock. Reads are served from
/// the box's in-memory frames so they stay fine, but any *further* write - a
/// teardown reset included - waits on that lock forever. So the test that taps a
/// switch runs last and nothing after it touches storage.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
    stubAdsChannel();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

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
    // The board and the settings list both read Hive on the first frame, and a
    // fake clock never lets that read come back.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  LiquidSegmentPainter firstLiquidPainter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((paint) => paint.painter)
      .whereType<LiquidSegmentPainter>()
      .first;

  test('both options default to off', () async {
    expect(await StorageService.getColorblindPatterns(), isFalse);
    expect(await StorageService.getLeftHandedLayout(), isFalse);
  });

  testWidgets('the default board keeps its centred tools and plain liquid', (
    tester,
  ) async {
    await pumpScreen(tester, const GameScreen(targetLevel: 7));

    expect(firstLiquidPainter(tester).showPatterns, isFalse);
    final tools = tester.getRect(find.byKey(const Key('bottomTools')));
    expect(tools.center.dx, closeTo(390 / 2, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the settings list offers both options on a small phone', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const SettingsScreen(),
      size: const Size(320, 568),
    );

    expect(find.text('Layer Patterns'), findsOneWidget);
    expect(find.text('Left-Handed Controls'), findsOneWidget);
    // Five switches now, and the list has to keep fitting a 320 x 568 screen.
    expect(find.byType(Switch), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the board reads both settings back from storage', (
    tester,
  ) async {
    // Written on the real clock, so the box is idle again by the time the board
    // opens: `runAsync` only parks the outer await, and `pump` releases it.
    await tester.runAsync(() async {
      await StorageService.setColorblindPatterns(true);
      await StorageService.setLeftHandedLayout(true);
    });
    await tester.pump();

    await pumpScreen(tester, const GameScreen(targetLevel: 7));

    expect(
      firstLiquidPainter(tester).showPatterns,
      isTrue,
      reason: 'the stored setting never reached the liquid',
    );
    // Mirrored means the whole strip sits against the left edge, not centred.
    final tools = tester.getRect(find.byKey(const Key('bottomTools')));
    expect(tools.left, closeTo(20, 2));
    expect(tools.center.dx, lessThan(390 / 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('flipping a settings switch is what the next screen reads', (
    tester,
  ) async {
    await pumpScreen(tester, const SettingsScreen());

    // Both on, because the previous test stored them that way and nothing can
    // reset the box after this point without hanging on it.
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[3].value, isTrue);
    expect(switches[4].value, isTrue);

    // The accessibility section sits below the fold on a phone.
    for (final index in [3, 4]) {
      final switchFinder = find.byType(Switch).at(index);
      await tester.ensureVisible(switchFinder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(switchFinder);
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The taps only prove `setState` ran; the same keys read back into a fresh
    // screen are what prove they went through storage.
    await pumpScreen(tester, const SettingsScreen());

    final reloaded = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(reloaded[3].value, isFalse);
    expect(reloaded[4].value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
