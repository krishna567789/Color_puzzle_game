/// The win card has to survive the smallest phone this game supports, under the
/// theme the game actually ships with, and with the ribbon wording the modes
/// hand it. A yellow-and-black overflow stripe across the one screen a player is
/// happiest on is a screenshot people send.
library;

import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/widgets/common/level_complete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

const _longestChapterName = 'Mixed Signals';

/// The longest thing any mode puts on the banner.
const _widestRibbon = 'DAILY PUZZLE';

void main() {
  for (final size in const [Size(320, 568), Size(360, 640), Size(390, 844)]) {
    for (final chapter in <String?>[null, _longestChapterName]) {
      testWidgets(
        'the win card fits ${size.width.toInt()}x${size.height.toInt()} '
        '${chapter == null ? 'after a level' : 'after a chapter'}',
        (tester) async {
          await useScreenSize(tester, size);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: Scaffold(
                body: Center(
                  child: LevelCompleteDialog(
                    stars: 3,
                    level: 20,
                    coinsEarned: 300,
                    gemsEarned: 3,
                    chapterName: chapter,
                    ribbon: chapter == null ? _widestRibbon : null,
                    onNext: () {},
                    onHome: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 800));
          expect(tester.takeException(), isNull);
          if (chapter != null) {
            expect(
              find.text(_longestChapterName.toUpperCase()),
              findsOneWidget,
              reason: 'the purse that arrived is the thing being celebrated',
            );
          } else {
            // One line, or the card under it has nowhere to go but off the box.
            expect(
              tester.getSize(find.text(_widestRibbon)).height,
              lessThan(45),
              reason: 'the banner wrapped, and the card no longer fits itself',
            );
          }
        },
      );
    }
  }

  testWidgets('a spent daily says so instead of paying zeroes', (tester) async {
    await useScreenSize(tester, const Size(320, 568));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: LevelCompleteDialog(
              stars: 3,
              level: 1,
              coinsEarned: 0,
              gemsEarned: 0,
              ribbon: _widestRibbon,
              rewardNote: "Today's prize is already claimed.\nCome back tomorrow.",
              onNext: () {},
              onHome: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(tester.takeException(), isNull);
    expect(find.text('YOU EARNED'), findsNothing);
    expect(find.text('+0'), findsNothing);
    expect(
      find.textContaining('already claimed'),
      findsOneWidget,
      reason: 'a run that paid nothing has to say it was spent, not broken',
    );
  });
}
