import 'package:color_puzzle_game/game/water_sort_solver.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const red = Color(0xFFFF2A2A);
  const blue = Color(0xFF1E88E5);
  const green = Color(0xFF2AFA2A);

  List<Tube> board(List<List<Color>> tubes, {int capacity = 4}) {
    return [
      for (final colors in tubes)
        Tube(capacity: capacity, initialColors: List.of(colors)),
    ];
  }

  group('WaterSortSolver', () {
    test('an already finished board needs zero pours', () {
      final report = WaterSortSolver.solve(
        board([
          [red, red, red, red],
          [blue, blue, blue, blue],
          [],
        ]),
      );

      expect(report.outcome, SolveOutcome.solved);
      expect(report.pours, 0);
    });

    test('finds the shortest solution, not just any solution', () {
      // A single pour of the lone blue finishes this, so anything above 1 means
      // the search is no longer breadth-first.
      final report = WaterSortSolver.solve(
        board([
          [blue],
          [blue, blue, blue],
          [red, red, red, red],
        ]),
      );

      expect(report.outcome, SolveOutcome.solved);
      expect(report.pours, 1);
    });

    test('proves a locked board unsolvable', () {
      // Both tubes are full and mismatched with nowhere to pour.
      final report = WaterSortSolver.solve(
        board([
          [red, blue],
          [blue, red],
        ], capacity: 2),
        nodeBudget: 5000,
      );

      expect(report.outcome, SolveOutcome.unsolvable);
      expect(report.isSolvable, isFalse);
      expect(report.isConclusive, isTrue);
    });

    test('respects the node budget instead of running forever', () {
      final report = WaterSortSolver.solve(
        board([
          [red, blue, green, red],
          [blue, green, red, blue],
          [green, red, blue, green],
          [],
          [],
        ]),
        nodeBudget: 1,
      );

      expect(report.outcome, SolveOutcome.searchLimitReached);
      expect(report.isConclusive, isFalse);
      expect(report.pours, isNull);
    });

    test('treats tubes of equal content as the same state', () {
      // The two scrambled tubes are interchangeable, so the visited set must not
      // count their swap as new progress.
      final a = WaterSortSolver.solve(
        board([
          [red, blue],
          [blue, red],
          [],
        ], capacity: 2),
      );
      final b = WaterSortSolver.solve(
        board([
          [blue, red],
          [red, blue],
          [],
        ], capacity: 2),
      );

      expect(a.pours, b.pours);
      expect(a.statesExplored, b.statesExplored);
    });
  });
}
