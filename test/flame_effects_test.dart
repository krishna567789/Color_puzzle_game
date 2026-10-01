import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_puzzle_game/controllers/game_controller.dart';
import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/effects/effects_game.dart';
import 'package:color_puzzle_game/screens/game_screen.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// The celebration is now a Flame canvas stretched over a Flutter board. Two
/// things have to stay true for that to be an upgrade: the particles retire
/// themselves when they land, and the layer never stands between a thumb and a
/// bottle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
    stubAdsChannel();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  testWidgets('a burst appears, runs out and takes itself off the tree', (
    tester,
  ) async {
    final game = EffectsGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget(game: game)),
      ),
    );
    await tester.pump();

    game.celebrate(at: const Offset(120, 200), colors: const [Colors.red]);
    game.celebrate(at: Offset.zero, colors: const []);

    // A component only joins the world on the next tick, so the highest count
    // seen across the run is what says the coloured burst spawned and the
    // colourless call invented nothing.
    var peak = 0;
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (game.liveEffects > peak) peak = game.liveEffects;
    }

    expect(peak, 1);
    expect(
      game.liveEffects,
      0,
      reason: 'past the longest strip life, nothing is left to draw',
    );

    game.dispose();
  });

  testWidgets('the effects layer covers the board but not the taps', (
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

    expect(find.bySubtype<GameWidget>(), findsOneWidget);

    final tubes = tester
        .widgetList<TubeWidget>(find.byType(TubeWidget))
        .toList();
    // An empty bottle cannot be picked up, so aim at one that has liquid.
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
      reason: 'the tap reached the bottle, not the particle canvas',
    );
  });

  testWidgets('the burst paints, then the canvas is clear again', (
    tester,
  ) async {
    final boundary = GlobalKey();
    final game = EffectsGame();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: Colors.black,
              child: GameWidget(game: game),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Future<int> redPixels() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      late final ui.Image image;
      late final ByteData bytes;
      await tester.runAsync(() async {
        image = await render.toImage(pixelRatio: 1);
        bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      var count = 0;
      for (var i = 0; i < bytes.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) > 140 &&
            bytes.getUint8(i + 1) < 110 &&
            bytes.getUint8(i + 2) < 110) {
          count++;
        }
      }
      image.dispose();
      return count;
    }

    expect(await redPixels(), 0, reason: 'an idle board has no confetti');

    game.celebrate(at: const Offset(400, 300), colors: const [Colors.red]);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      await redPixels(),
      greaterThan(300),
      reason: 'the strips are on screen, not just in the component tree',
    );

    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(await redPixels(), 0, reason: 'and they all land');

    game.dispose();
  });
}
