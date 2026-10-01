import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_puzzle_game/content/content_repository.dart';
import 'package:color_puzzle_game/game/liquid_patterns.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const liquidSize = Size(51, 144);

// The shipped palette, read from the content set rather than a list kept in
// a test: guarding a copy of the palette would let the real one drift.
final palette = ContentRepository.content.swatches;
final marks = ContentRepository.content.patternFor;

/// A layer of liquid is one of four identical slots that differ only by colour,
/// so for a player who cannot separate those colours the board is unreadable.
/// The fix has to be checked as pixels: a pattern that is defined but never
/// painted, or painted so faintly that it disappears at tube size, would still
/// pass every assertion on the mapping itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Paints a full four-layer tube of [color] and returns its raw pixels.
  ///
  /// Rasterising waits on the engine, so it runs in `runAsync` rather than under
  /// the fake clock of the test body.
  Future<Uint8List> render(
    WidgetTester tester,
    Color color, {
    required bool patterns,
  }) async {
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      LiquidSegmentPainter(
        colors: List.filled(4, color),
        hiddenCount: 0,
        wave: kAlwaysCompleteAnimation,
        showPatterns: patterns,
      ).paint(Canvas(recorder), liquidSize);
      final image = await recorder.endRecording().toImage(
        liquidSize.width.round(),
        liquidSize.height.round(),
      );
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      image.dispose();
      return data!.buffer.asUint8List();
    });
    expect(bytes, isNotNull, reason: 'the tube never rasterised');
    return bytes!;
  }

  /// Pixels that are not the liquid's own colour: the mark, plus the bubbles
  /// every layer always carries.
  Set<int> inked(Uint8List bytes, Color base) {
    final found = <int>{};
    for (var i = 0; i < bytes.length; i += 4) {
      if (bytes[i + 3] == 0) continue;
      final delta =
          (bytes[i] - base.r * 255).abs() +
          (bytes[i + 1] - base.g * 255).abs() +
          (bytes[i + 2] - base.b * 255).abs();
      if (delta > 60) found.add(i ~/ 4);
    }
    return found;
  }

  double dissimilarity(Set<int> a, Set<int> b) {
    final union = a.length + b.length - a.intersection(b).length;
    if (union == 0) return 0;
    return 1 - a.intersection(b).length / union;
  }

  test('the palette has one pattern per colour, and no repeats', () {
    expect(palette, isNotEmpty, reason: 'the content set did not load');
    expect(
      palette.map(marks).toSet(),
      hasLength(palette.length),
      reason: 'two colours wearing one mark is the bug this whole file guards',
    );
  });

  test('a colour the palette does not know still wears a stable mark', () {
    final stranger = const Color(0xFF7ED957);
    expect(marks(stranger), marks(stranger));
    expect(LiquidPattern.values, contains(marks(stranger)));
  });

  testWidgets('the mark is actually painted on the liquid', (tester) async {
    final plain = await render(tester, palette.first, patterns: false);
    final marked = await render(tester, palette.first, patterns: true);

    final plainInk = inked(plain, palette.first);
    final markedInk = inked(marked, palette.first);

    expect(
      markedInk.length,
      greaterThan(plainInk.length * 3),
      reason:
          'a pattern that adds no pixels is a setting that does nothing '
          '(plain ${plainInk.length}, marked ${markedInk.length})',
    );
    // The mark must sit inside the liquid, not on the glass around it.
    expect(markedInk, isNotEmpty);
  });

  testWidgets('no two palette colours end up looking alike', (tester) async {
    final marks = <String, Set<int>>{};
    for (final color in palette) {
      marks['${color.toARGB32()}'] = inked(
        await render(tester, color, patterns: true),
        color,
      );
    }

    var worst = 1.0, worstPair = '';
    for (var a = 0; a < palette.length; a++) {
      for (var b = a + 1; b < palette.length; b++) {
        final distance = dissimilarity(
          marks['${palette[a].toARGB32()}']!,
          marks['${palette[b].toARGB32()}']!,
        );
        if (distance < worst) {
          worst = distance;
          worstPair = '${palette[a]} vs ${palette[b]}';
        }
      }
    }
    expect(
      worst,
      greaterThan(0.25),
      reason:
          '$worstPair are only $worst apart - too close to read at tube size',
    );
  });

  testWidgets('the tube passes the setting down to the painter', (
    tester,
  ) async {
    Widget host(bool patterns) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: TubeWidget(
            tube: Tube(
              initialColors: const [Color(0xFFFF2A2A), Color(0xFF1E88E5)],
            ),
            isSelected: false,
            isShaking: false,
            showPatterns: patterns,
            onTap: () {},
          ),
        ),
      ),
    );

    LiquidSegmentPainter painter(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<LiquidSegmentPainter>()
        .single;

    await tester.pumpWidget(host(false));
    expect(painter(tester).showPatterns, isFalse);

    await tester.pumpWidget(host(true));
    expect(painter(tester).showPatterns, isTrue);
  });
}
