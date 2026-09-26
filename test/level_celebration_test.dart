import 'dart:io';

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// Winning is a moment, not a state flip: the board has to cheer when it lands.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  const red = Color(0xFFFF2A2A);

  Future<void> runUntil(
    GameController controller,
    bool Function() done,
  ) async {
    for (var i = 0; i < 40 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('the win names the tube that finished the level', () async {
    final controller = GameController(loadProgress: false);
    addTearDown(controller.dispose);
    controller.tubes = [
      Tube(initialColors: [red, red, red]),
      Tube(initialColors: [red]),
    ];
    expect(controller.victoryTubeIndex, isNull);

    controller.selectTube(1);
    controller.selectTube(0);
    await runUntil(controller, () => controller.isLevelComplete);

    expect(controller.isLevelComplete, isTrue);
    expect(
      controller.victoryTubeIndex,
      0,
      reason: 'the celebration belongs where the last layer landed',
    );
  });

  testWidgets('a solved tube sparkles again when the level ends', (tester) async {
    final solved = Tube(initialColors: [red, red, red, red]);

    Widget host({required bool celebrate}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: TubeWidget(
            tube: solved,
            isSelected: false,
            isShaking: false,
            celebrate: celebrate,
            onTap: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(host(celebrate: false));
    await tester.pump(const Duration(milliseconds: 900));
    expect(
      dustPainters(tester),
      isEmpty,
      reason: 'the flash that came with solving is long over',
    );

    await tester.pumpWidget(host(celebrate: true));
    await tester.pump(const Duration(milliseconds: 100));
    final sparkles = dustPainters(tester);
    expect(
      sparkles,
      hasLength(1),
      reason: 'the win has to sparkle on the board, not only in the dialog',
    );
    expect(sparkles.single.progress, lessThan(0.5));

    await tester.pump(const Duration(milliseconds: 900));
    expect(
      dustPainters(tester).single.progress,
      1.0,
      reason: 'the sparkle plays once rather than looping',
    );
  });
}

Iterable<MagicDustPainter> dustPainters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<MagicDustPainter>();
