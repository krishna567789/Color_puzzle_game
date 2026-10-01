import 'dart:io';

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/game/board_layout.dart';
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
    await useScreenSize(tester, size);
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

  // A dealt board stops at the curve's own cap, but the add-tube power-up sells
  // bottles on top of it, so the content ceiling is the fullest grid any phone
  // in the catalogue can be asked to show. Those shapes are pure arithmetic, so
  // they are checked for every count rather than for the four levels above.
  group('every board up to the ceiling', () {
    for (final size in phones) {
      test('fits ${size.width.toInt()}x${size.height.toInt()}', () {
        final viewport = boardViewport(size);
        for (var count = 1; count <= GameController.maxBoardTubes; count++) {
          final layout = resolveBoardLayout(count, size);
          final rows = (count / layout.columns).ceil();
          final where = '$count bottles at '
              '${size.width.toInt()}x${size.height.toInt()}';
          expect(
            layout.columns,
            lessThanOrEqualTo(count),
            reason: '$where: an empty column is a column too many',
          );
          expect(
            (layout.columns * kTubeSlotWidth +
                        (layout.columns - 1) * kTubeGap) *
                layout.scale,
            lessThanOrEqualTo(viewport.width + 0.001),
            reason: '$where hangs off the page',
          );
          expect(
            layout.rowWidth,
            greaterThanOrEqualTo(
              (layout.columns * kTubeSlotWidth +
                      (layout.columns - 1) * kTubeGap) *
                  layout.scale,
            ),
            reason: '$where: the row box is narrower than the row, so the wrap '
                'breaks early and the grid grows taller than the screen',
          );
          expect(
            layout.rowWidth,
            lessThanOrEqualTo(viewport.width + 0.001),
            reason: '$where: the row box hangs off the page',
          );
          expect(
            (rows * kTubeSlotHeight + (rows - 1) * kRowGap) * layout.scale,
            lessThanOrEqualTo(viewport.height + 0.001),
            reason: '$where slides in under the power-up strip',
          );
          expect(
            layout.scale,
            greaterThanOrEqualTo(0.5),
            reason:
                '$where: below half size the colours are a test, not a game',
          );
        }
      });
    }
  });

  // Past the legibility floor the board cannot shrink any further, so it has to
  // degrade by scrolling rather than by spreading off the side of the phone or
  // painting bottles below half size.
  test('a board that cannot shrink further stays inside the page', () {
    const screen = Size(320, 400);
    final layout = resolveBoardLayout(GameController.maxBoardTubes, screen);
    final viewport = boardViewport(screen);

    expect(layout.scale, 0.5, reason: 'this board is meant to hit the floor');
    expect(
      (layout.columns * kTubeSlotWidth + (layout.columns - 1) * kTubeGap) *
          layout.scale,
      greaterThan(viewport.width),
      reason: 'the row the floor asks for is not actually too wide for it',
    );
    expect(
      layout.rowWidth,
      lessThanOrEqualTo(viewport.width),
      reason:
          'a row wider than the page overflows it instead of wrapping and '
              'scrolling',
    );
  });

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
