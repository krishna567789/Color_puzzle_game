import 'dart:io';

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/game/level_design.dart';
import 'package:color_puzzle_game/screens/game_screen.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// The board used to be laid out at one scale and painted at its square, so the
/// bottles were bigger than the slots holding them: rows touched, and on a
/// 3 x 3 board the last row sat behind the power-up strip. These are the
/// properties the player actually needs - one bottle per slot, nothing under
/// the tools, nothing off the screen - across the board shapes the difficulty
/// curve produces.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
    stubAdsChannel();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  Future<void> pumpBoard(WidgetTester tester, int level, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: GameScreen(targetLevel: level, mode: GameMode.classic),
      ),
    );
    // The board loads its level from Hive on the first frame.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // L1 is 6 bottles, L21 the 3 x 3 board that was reported, L46 12 and L60 the
  // saturated 14. Between them the curve uses every row shape it can build.
  const boards = [1, 21, 46, 60];
  const phones = [
    Size(390, 844),
    Size(320, 568),
    Size(412, 915),
    Size(700, 1000),
  ];

  for (final level in boards) {
    for (final size in phones) {
      testWidgets(
        'level $level at ${size.width.toInt()}x${size.height.toInt()} '
        'keeps every bottle in its slot',
        (tester) async {
          await pumpBoard(tester, level, size);

          final tubes = tester
              .widgetList<TubeWidget>(find.byType(TubeWidget))
              .length;
          expect(tubes, LevelDesign.forLevel(level).tubeCount);

          final rects = [
            for (var i = 0; i < tubes; i++)
              tester.getRect(find.byType(TubeWidget).at(i)),
          ];

          for (final rect in rects) {
            expect(
              rect.left,
              greaterThanOrEqualTo(0),
              reason: 'a bottle hung off the left edge',
            );
            expect(
              rect.right,
              lessThanOrEqualTo(size.width),
              reason: 'a bottle hung off the right edge',
            );
            // The top bar is overlaid at the top of the stack, so the board has
            // to start below it rather than behind it.
            expect(
              rect.top,
              greaterThanOrEqualTo(96),
              reason: 'a bottle sat under the top bar',
            );
          }

          for (var a = 0; a < rects.length; a++) {
            for (var b = a + 1; b < rects.length; b++) {
              expect(
                rects[a].overlaps(rects[b]),
                isFalse,
                reason:
                    'bottle $a and bottle $b are painted on top of each other',
              );
            }
          }

          final tools = tester.getRect(find.byKey(const Key('bottomTools')));
          final lowest = rects
              .map((r) => r.bottom)
              .reduce((a, b) => a > b ? a : b);
          expect(
            lowest,
            lessThanOrEqualTo(tools.top),
            reason: 'the last row of bottles hides behind the power-ups',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
