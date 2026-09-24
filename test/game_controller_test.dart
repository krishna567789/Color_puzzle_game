import 'dart:io';

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

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
    controller.coins = 200;
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

    expect(controller.undo(), isTrue);

    expect(controller.movesCount, 0);
    expect(controller.tubes[0].topColor, red);
    expect(controller.tubes[1].isEmpty, isTrue);

    controller.dispose();
  });

  test('a hint points at the pour that finishes a tube, not the first one', () {
    final controller = GameController(loadProgress: false);
    controller.tubes = [
      Tube(initialColors: [red, red, blue]),
      Tube(),
      Tube(initialColors: [blue, blue, blue]),
    ];

    // Parking the lone blue in the empty tube is legal and comes first in scan
    // order, but it is the move that charges a player for going backwards.
    final hint = controller.findHintMove();
    expect(hint, isNotNull);
    expect(hint!.fromIndex, 0);
    expect(hint.toIndex, 2);

    controller.dispose();
  });

  test('a hint is offered whenever a pour exists, so only dead boards read as stuck', () {
    final live = GameController(loadProgress: false)
      ..tubes = [Tube(initialColors: [red]), Tube()];
    expect(live.findHintMove(), isNotNull);
    addTearDown(live.dispose);

    final dead = GameController(loadProgress: false)
      ..tubes = [
        Tube(initialColors: [red]),
        Tube(initialColors: [blue, blue]),
      ];
    expect(dead.findHintMove(), isNull);
    addTearDown(dead.dispose);
  });
}
