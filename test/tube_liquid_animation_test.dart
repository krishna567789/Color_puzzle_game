import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const red = Color(0xFFF44336);
const blue = Color(0xFF2196F3);
const green = Color(0xFF4CAF50);

/// A pour is only believable if the liquid moves: a layer that appears at the
/// bottom of the glass in one frame reads as a teleport, not as pouring.
void main() {
  Widget host(Tube tube) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: TubeWidget(
          tube: tube,
          isSelected: false,
          isShaking: false,
          onTap: () {},
        ),
      ),
    ),
  );

  LiquidSegmentPainter painter(WidgetTester tester) {
    final found = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<LiquidSegmentPainter>()
        .toList();
    expect(found, hasLength(1), reason: 'one tube paints one liquid stack');
    return found.single;
  }

  testWidgets('an arriving layer grows out of the surface instead of appearing', (
    tester,
  ) async {
    final tube = Tube(initialColors: [red, blue]);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 50));

    expect(painter(tester).colors, hasLength(2));
    expect(painter(tester).fillFraction, 1.0);

    tube.colors.add(green);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 100));

    final mid = painter(tester);
    expect(mid.colors, hasLength(3), reason: 'the new layer is in the stack');
    expect(
      mid.fillFraction,
      inInclusiveRange(0.2, 0.8),
      reason: 'and it is only part way up its slot',
    );
    expect(mid.drainingColor, isNull);

    await tester.pump(const Duration(milliseconds: 200));
    expect(painter(tester).fillFraction, 1.0);
  });

  testWidgets('a leaving layer drains away instead of vanishing', (tester) async {
    final tube = Tube(initialColors: [red, blue, green]);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 50));
    expect(painter(tester).colors, hasLength(3));

    tube.colors.removeLast();
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 100));

    final mid = painter(tester);
    expect(mid.colors, hasLength(2), reason: 'the model has already dropped it');
    expect(
      mid.drainingColor,
      green,
      reason: 'but the paint still has it on its way out',
    );
    expect(mid.fillFraction, inInclusiveRange(0.2, 0.8));

    await tester.pump(const Duration(milliseconds: 200));
    final done = painter(tester);
    expect(done.drainingColor, isNull);
    expect(done.colors, hasLength(2));
  });

  testWidgets('a board that changes by more than one layer snaps', (tester) async {
    final tube = Tube(initialColors: [red]);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 50));

    tube.colors.addAll([blue, green, red, blue]);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 16));

    final jumped = painter(tester);
    expect(jumped.colors, hasLength(5));
    expect(jumped.fillFraction, 1.0, reason: 'a new deal is not a pour');
    expect(jumped.drainingColor, isNull);
  });

  testWidgets('an unrelated rebuild does not cut the level animation short', (
    tester,
  ) async {
    final tube = Tube(initialColors: [red, blue]);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 50));

    tube.colors.add(green);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 60));
    final started = painter(tester).fillFraction;
    expect(started, lessThan(1.0));

    // Same liquid, different tube state: the board rebuilds for the selection,
    // the tilt, the hint timer - none of which are about the level.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TubeWidget(
              tube: tube,
              isSelected: true,
              isShaking: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));

    expect(
      painter(tester).fillFraction,
      greaterThan(started),
      reason: 'the layer keeps rising where it was',
    );
    expect(painter(tester).drainingColor, isNull);
  });

  testWidgets('the growing layer is painted part way up its slot', (tester) async {
    final boundary = GlobalKey();
    final tube = Tube(initialColors: [red, blue]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundary,
              child: TubeWidget(
                tube: tube,
                isSelected: false,
                isShaking: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    /// How many pixels down the middle of the glass the top layer's colour runs.
    Future<int> topLayerHeight() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      late final ui.Image image;
      late final ByteData bytes;
      await tester.runAsync(() async {
        image = await render.toImage();
        bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      final column = (image.width / 2).round();
      var green = 0;
      for (var y = 0; y < image.height; y++) {
        final i = (y * image.width + column) * 4;
        if (bytes.getUint8(i) < 120 &&
            bytes.getUint8(i + 1) > 140 &&
            bytes.getUint8(i + 2) < 130) {
          green++;
        }
      }
      image.dispose();
      return green;
    }

    expect(await topLayerHeight(), 0, reason: 'nothing green on the board yet');

    tube.colors.add(green);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundary,
              child: TubeWidget(
                tube: tube,
                isSelected: false,
                isShaking: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final half = await topLayerHeight();
    expect(
      half,
      inInclusiveRange(8, 28),
      reason: 'half a segment height, not the whole slot',
    );

    await tester.pump(const Duration(milliseconds: 300));
    final full = await topLayerHeight();
    expect(
      full,
      greaterThan(half + 4),
      reason: 'and it finishes rising to a full 36-pixel layer',
    );
    expect(full, lessThanOrEqualTo(40));
  });

  /// The ripple is a two second sine two pixels tall, so redrawing the whole
  /// layer stack under it on every frame the engine draws buys nothing and
  /// costs a dozen tubes per board.
  testWidgets('an idle ripple repaints a third as often as the screen draws', (
    tester,
  ) async {
    final tube = Tube(initialColors: [red, blue]);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 50));

    final wave = painter(tester).wave;
    var repaints = 0;
    void count() => repaints++;
    wave.addListener(count);
    addTearDown(() => wave.removeListener(count));

    const frames = 30;
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      repaints,
      inInclusiveRange(frames ~/ 4, frames ~/ 2),
      reason: 'throttled, but not frozen',
    );
    expect(wave.value, greaterThan(0), reason: 'the surface keeps moving');
  });

  testWidgets('a tube with no loose surface stops repainting entirely', (
    tester,
  ) async {
    final tube = Tube(initialColors: [red, blue, green]);
    await tester.pumpWidget(host(tube));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final wave = painter(tester).wave;
    expect(wave.value, greaterThan(0), reason: 'an open top ripples');

    tube.colors.add(red);
    await tester.pumpWidget(host(tube));
    await tester.pump(const Duration(milliseconds: 50));

    var repaints = 0;
    void count() => repaints++;
    wave.addListener(count);
    addTearDown(() => wave.removeListener(count));

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(repaints, 0, reason: 'a packed column paints a flat top');
  });
}
