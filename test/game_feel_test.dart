import 'dart:io';

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:color_puzzle_game/screens/game_screen.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// The board has to feel like glass and water, not like a spreadsheet that
/// redraws. Four things carry that: picking a bottle up is a movement, an undo
/// plays the pour backwards, a refused tap says why, and the bottles that would
/// take the pour are marked before the player guesses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
    stubAdsChannel();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  Widget host(Tube tube, {bool selected = false}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: TubeWidget(tube: tube, isSelected: selected, isShaking: false, onTap: () {}),
      ),
    ),
  );

  LiquidSegmentPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<LiquidSegmentPainter>()
      .single;

  double lift(WidgetTester tester) {
    final transform = tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(TubeWidget),
            matching: find.byType(Transform),
          ),
        )
        .single;
    return transform.transform.getTranslation().y;
  }

  testWidgets('picking a bottle up lifts it, instead of jumping it', (
    tester,
  ) async {
    final tube = Tube(initialColors: [const Color(0xFFF44336)]);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 50));
    expect(lift(tester), 0.0, reason: 'on the shelf it sits at its own height');

    await tester.pumpWidget(host(tube, selected: true));
    await tester.pump(const Duration(milliseconds: 60));

    final mid = lift(tester);
    expect(mid, lessThan(0.0), reason: 'it is on its way up');
    expect(mid, greaterThan(-30.0), reason: 'and has not arrived yet');

    await tester.pump(const Duration(milliseconds: 250));
    expect(lift(tester), closeTo(-30.0, 0.5));

    // Setting it back down is the same movement in the other direction.
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 60));
    expect(lift(tester), greaterThan(-30.0));
    await tester.pump(const Duration(milliseconds: 250));
    expect(lift(tester), closeTo(0.0, 0.5));
  });

  testWidgets('an undo hands the layers back one at a time', (tester) async {
    final poured = Tube(initialColors: [
      const Color(0xFFF44336),
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFF44336),
    ]);
    await tester.pumpWidget(host(poured));
    await tester.pump(const Duration(milliseconds: 50));
    expect(painter(tester).colors, hasLength(4));

    // What an undo does: the board is handed a different tube, two layers
    // shorter, all in one frame.
    final reverted = Tube(initialColors: [
      const Color(0xFFF44336),
      const Color(0xFF2196F3),
    ]);
    await tester.pumpWidget(host(reverted));
    await tester.pump(const Duration(milliseconds: 100));

    final mid = painter(tester);
    expect(
      mid.colors,
      hasLength(3),
      reason: 'only the layer still draining is above the model',
    );
    expect(mid.drainingColor, const Color(0xFFF44336));
    expect(mid.fillFraction, inInclusiveRange(0.2, 0.8));

    await tester.pump(const Duration(milliseconds: 200));
    final next = painter(tester);
    expect(
      next.drainingColor,
      const Color(0xFF4CAF50),
      reason: 'and then the one under it goes back too',
    );

    await tester.pump(const Duration(milliseconds: 400));
    final done = painter(tester);
    expect(done.colors, hasLength(2), reason: 'it ends where the model is');
    expect(done.drainingColor, isNull);
  });

  testWidgets('a board that rearranges underneath still lands at once', (
    tester,
  ) async {
    final before = Tube(initialColors: [
      const Color(0xFFF44336),
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
    ]);
    await tester.pumpWidget(host(before));
    await tester.pump(const Duration(milliseconds: 50));

    // A shuffle: the same height, different colours underneath, so there is no
    // pour to play back.
    final after = Tube(initialColors: [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFF44336),
    ]);
    await tester.pumpWidget(host(after));
    await tester.pump(const Duration(milliseconds: 16));

    expect(painter(tester).colors, hasLength(3));
    expect(painter(tester).fillFraction, 1.0);
    expect(painter(tester).drainingColor, isNull);
  });

  test('the board marks the bottles that would take the pour', () {
    final controller = GameController(loadProgress: false);
    const red = Color(0xFFF44336);
    const blue = Color(0xFF2196F3);
    controller.tubes = [
      Tube(initialColors: [blue, red]),
      Tube(initialColors: [blue, red, red]),
      Tube(initialColors: [blue, blue]),
      Tube(capacity: 4),
      Tube(initialColors: [blue, red, blue, red]),
    ];

    expect(
      controller.acceptsFromSelected(0),
      isFalse,
      reason: 'nothing is held up yet, so nothing is marked',
    );

    controller.selectedTubeIndex = 0;
    expect(
      controller.acceptsFromSelected(1),
      isTrue,
      reason: 'red onto red, with room left',
    );
    expect(controller.acceptsFromSelected(2), isFalse, reason: 'wrong colour');
    expect(controller.acceptsFromSelected(3), isTrue, reason: 'empty takes all');
    expect(
      controller.acceptsFromSelected(4),
      isFalse,
      reason: 'a full bottle has nowhere to put it',
    );
    expect(
      controller.acceptsFromSelected(0),
      isFalse,
      reason: 'a bottle cannot pour into itself',
    );
    controller.dispose();
  });

  test('a refused tap says what was refused', () {
    final controller = GameController(loadProgress: false);
    const red = Color(0xFFF44336);
    const blue = Color(0xFF2196F3);
    controller.tubes = [
      Tube(initialColors: [blue, red]),
      Tube(initialColors: [red, red, red, red]),
      Tube(initialColors: [blue, blue]),
    ];
    controller.selectedTubeIndex = 0;

    expect(controller.blockReason(0, 1), 'That bottle is full');
    expect(controller.blockReason(0, 2), 'The colours do not match');
    expect(controller.blockReason(0, 0), 'Pick a second bottle');
    controller.dispose();
  });

  testWidgets('a rejected pour puts the reason on screen', (tester) async {
    await useScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: GameScreen(targetLevel: 21, mode: GameMode.classic),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    final tubes = tester
        .widgetList<TubeWidget>(find.byType(TubeWidget))
        .toList();
    final richest = tubes.indexOf(
      tubes.reduce(
        (a, b) => a.tube.colors.length >= b.tube.colors.length ? a : b,
      ),
    );

    await tester.tap(find.byType(TubeWidget).at(richest));
    await tester.pump();
    expect(
      tester.widget<TubeWidget>(find.byType(TubeWidget).at(richest)).isSelected,
      isTrue,
    );

    // Read the board again: the widgets held before the tap are the state the
    // tap replaced.
    final held = tester
        .widgetList<TubeWidget>(find.byType(TubeWidget))
        .toList();
    final marked = held
        .asMap()
        .entries
        .where((e) => e.value.canReceive && e.key != richest)
        .length;
    expect(
      marked,
      greaterThan(0),
      reason: 'the bottles that would take it are ringed before the guess',
    );

    // A bottle that is not ringed, has water in it and has room: the only
    // reason it cannot take the pour is the colour on top.
    final blocked = held.indexWhere(
      (t) =>
          !t.canReceive &&
          !t.isSelected &&
          t.tube.isNotEmpty &&
          !t.tube.isFull,
    );
    expect(blocked, greaterThanOrEqualTo(0), reason: 'the board offers a refusal');

    await tester.tap(find.byType(TubeWidget).at(blocked));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('The colours do not match'),
      findsOneWidget,
      reason: 'the shake came with a sentence',
    );
    expect(
      tester.widget<TubeWidget>(find.byType(TubeWidget).at(richest)).isSelected,
      isFalse,
      reason: 'and the held bottle is set back down',
    );

    await tester.pump(const Duration(milliseconds: 2000));
    // The clear is a timer, and the switcher needs a beat to fade the line out.
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('The colours do not match'),
      findsNothing,
      reason: 'it retires itself rather than sitting on the board',
    );
  });

  testWidgets('the HUD counts the bottles the level still wants', (
    tester,
  ) async {
    await useScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: GameScreen(targetLevel: 21, mode: GameMode.classic),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    final controller = GameController(
      loadProgress: false,
      targetLevel: 21,
      mode: GameMode.classic,
    );
    addTearDown(controller.dispose);
    expect(controller.tubesToSort, greaterThan(0));

    final tubes = tester
        .widgetList<TubeWidget>(find.byType(TubeWidget))
        .toList();
    final sorted = tubes.where((t) => t.tube.isComplete).length;
    expect(
      find.text('$sorted / ${controller.tubesToSort}'),
      findsOneWidget,
      reason: 'the counter on screen is the counter in the controller',
    );
  });
}
