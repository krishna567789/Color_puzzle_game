import 'dart:io';

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/game/water_sort_solver.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// The generator, the solver and the rules the player actually plays against
/// are three separate implementations of "what a pour does". This drives the
/// solver's answer through the real controller, so they cannot drift apart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  /// Runs one pour the way the board does it, through the animation timers.
  Future<void> pour(WidgetTester tester, GameController c, int from, int to) async {
    c.selectTube(from);
    c.selectTube(to);
    for (var i = 0; i < 40 && (c.pouringFromIndex != null || c.isPouringLiquid); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a dealt classic level plays to its end with the solver alongside', (tester) async {
    final controller = GameController(loadProgress: false, targetLevel: 3);
    // Undo costs coins, and this test undoes a lot while probing for the move
    // the solver still counts as shortest.
    controller.coins = 100000;
    addTearDown(controller.dispose);

    final shortest = WaterSortSolver.solve(controller.tubes).pours;
    expect(shortest, greaterThan(0), reason: 'L3 should not start solved');

    var remaining = shortest!;
    var steps = 0;
    while (remaining > 0) {
      var advanced = false;
      for (var from = 0; from < controller.tubes.length && !advanced; from++) {
        for (var to = 0; to < controller.tubes.length && !advanced; to++) {
          if (!controller.canPour(from, to)) continue;
          await pour(tester, controller, from, to);
          final next = WaterSortSolver.solve(controller.tubes).pours ?? -1;
          if (next == remaining - 1) {
            remaining = next;
            advanced = true;
          } else {
            expect(controller.undo(), isTrue);
          }
        }
      }
      expect(advanced, isTrue, reason: 'no pour shortened the solution at depth $remaining');
      expect(++steps, lessThan(60), reason: 'the search should not wander');
    }

    expect(controller.isLevelComplete, isTrue);
    expect(controller.isStuck, isFalse);
    expect(controller.movesCount, shortest, reason: 'the board should need exactly its par');
  });

  test('topping up a tube that starts face-down still finishes the level', () async {
    final controller = GameController(loadProgress: false);
    addTearDown(controller.dispose);
    controller.tubes = [
      Tube(initialColors: [const Color(0xFFFF2A2A), const Color(0xFFFF2A2A), const Color(0xFFFF2A2A)], hiddenCount: 1),
      Tube(initialColors: [const Color(0xFFFF2A2A)]),
    ];

    controller.selectTube(1);
    controller.selectTube(0);
    for (var i = 0;
        i < 40 && (controller.pouringFromIndex != null || !controller.isLevelComplete);
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    expect(controller.isLevelComplete, isTrue);
  });
}
