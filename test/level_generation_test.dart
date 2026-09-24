import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/game/level_design.dart';
import 'package:color_puzzle_game/game/water_sort_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('difficulty curve', () {
    test('colour count only ever grows and stops at the palette size', () {
      var previous = 0;
      for (var level = 1; level <= 300; level++) {
        final config = LevelDesign.forLevel(level);
        expect(
          config.colorCount,
          greaterThanOrEqualTo(previous),
          reason: 'L$level went backwards',
        );
        expect(config.colorCount, lessThanOrEqualTo(LevelDesign.maxColorCount));
        previous = config.colorCount;
      }
    });

    test('the board keeps getting harder after the colour count saturates', () {
      // L60 and L300 both max out at 12 colours, so difficulty has to come from
      // somewhere else or late levels are the same puzzle with a new number.
      final late12 = LevelDesign.forLevel(60);
      final veryLate = LevelDesign.forLevel(300);

      expect(late12.colorCount, LevelDesign.maxColorCount);
      expect(veryLate.capacity, greaterThan(late12.capacity));
      expect(veryLate.mysteryTubes, greaterThanOrEqualTo(late12.mysteryTubes));
      expect(veryLate.mixRounds, greaterThan(late12.mixRounds));
    });

    test('never asks for more tubes than the board can show', () {
      for (var level = 1; level <= 300; level++) {
        expect(
          LevelDesign.forLevel(level).tubeCount,
          lessThanOrEqualTo(14),
          reason: 'L$level overflows the tube grid',
        );
      }
    });

    test('level 1 is a tutorial, not a wall', () {
      final first = LevelDesign.forLevel(1);

      expect(first.colorCount, lessThanOrEqualTo(4));
      expect(first.freeTubes, greaterThanOrEqualTo(3));
      expect(first.mysteryTubes, 0);
    });

    test('chapters break the run into named blocks of 20', () {
      expect(LevelDesign.chapterIndex(1), 0);
      expect(LevelDesign.chapterIndex(20), 0);
      expect(LevelDesign.chapterIndex(21), 1);
      expect(LevelDesign.firstLevelOfChapter(1), 21);
      expect(LevelDesign.chapterName(35), contains('Chapter 2'));
    });
  });

  group('level generation', () {
    test('generated boards are provably winnable and never already solved', () {
      for (final level in [1, 3, 8, 16, 25, 40, 55, 70, 90]) {
        final controller = GameController(
          loadProgress: false,
          targetLevel: level,
        );
        addTearDown(controller.dispose);

        final report = WaterSortSolver.solve(controller.tubes);
        expect(
          report.outcome,
          isNot(SolveOutcome.unsolvable),
          reason: 'L$level dealt an unwinnable board',
        );
        expect(
          controller.tubes.any((t) => t.colors.length > 1 && !t.isComplete),
          isTrue,
          reason: 'L$level dealt a board with nothing to do',
        );
      }
    });

    test('a level reports a reference solution length that scales', () {
      final boards = <int, int>{};
      for (final level in [1, 10, 25, 45, 80]) {
        final controller = GameController(
          loadProgress: false,
          targetLevel: level,
        );
        addTearDown(controller.dispose);
        boards[level] = controller.parMoves;
      }

      for (final level in boards.keys) {
        expect(boards[level], greaterThan(0), reason: 'L$level has no par');
      }
      expect(boards[45], greaterThan(boards[1]!));
      expect(boards[80], greaterThan(boards[10]!));
    });

    test('the daily board is the same puzzle all day', () {
      List<int> segmentsOf(GameController controller) =>
          [for (final tube in controller.tubes) tube.colors.length];

      final first = GameController(
        mode: GameMode.daily,
        loadProgress: false,
      );
      final second = GameController(
        mode: GameMode.daily,
        loadProgress: false,
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      expect(segmentsOf(first), segmentsOf(second));
    });

    test('each round of a side mode digs deeper than the last', () {
      final challenge = GameController(
        mode: GameMode.challenge,
        loadProgress: false,
      );
      addTearDown(challenge.dispose);

      final opening = challenge.designLevel;
      expect(challenge.movesLimit, greaterThan(0));

      challenge.currentLevel = 4;
      expect(challenge.designLevel, greaterThan(opening));
    });
  });
}
