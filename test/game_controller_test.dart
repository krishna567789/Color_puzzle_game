import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final red = const Color(0xFFFF2A2A);
  final blue = const Color(0xFF1E88E5);

  test('a pour is valid only for an empty or matching-color tube', () {
    final controller = GameController(loadProgress: false);
    controller.tubes = [
      Tube(initialColors: [red]),
      Tube(initialColors: [blue]),
      Tube(),
      Tube(initialColors: [red, red, red, red]),
    ];

    expect(controller.canPour(0, 1), isFalse);
    expect(controller.canPour(0, 2), isTrue);
    expect(controller.canPour(0, 3), isFalse);
    expect(controller.canPour(1, 0), isFalse);

    controller.dispose();
  });

  test('undo restores the board and the consumed move', () async {
    final controller = GameController(loadProgress: false);
    controller.tubes = [
      Tube(initialColors: [red]),
      Tube(),
    ];

    controller.selectTube(0);
    controller.selectTube(1);
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(controller.movesCount, 1);
    expect(controller.tubes[0].isEmpty, isTrue);
    expect(controller.tubes[1].topColor, red);

    controller.undo();

    expect(controller.movesCount, 0);
    expect(controller.tubes[0].topColor, red);
    expect(controller.tubes[1].isEmpty, isTrue);

    controller.dispose();
  });
}
