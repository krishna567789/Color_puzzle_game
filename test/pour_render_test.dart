import 'dart:io';
import 'dart:ui' as ui;

import 'package:color_puzzle_game/core/app_theme.dart';
import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:color_puzzle_game/screens/game_screen.dart';
import 'package:color_puzzle_game/widgets/common/pouring_stream_effect.dart';
import 'package:color_puzzle_game/widgets/common/pouring_stream_painter.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// The numbers behind the pour are covered by pour_geometry_test.dart. What only
/// a render can show is whether the stream is painted at all, and where: a jet
/// that quietly resolves to nothing still leaves the maths looking perfect.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    sandbox = await useTestStorage();
    stubAdsChannel();
  });

  tearDownAll(() async => sandbox.delete(recursive: true));

  testWidgets('a pour paints from the lip down into the tube it fills', (
    tester,
  ) async {
    final boundary = GlobalKey();
    // A real phone, through the view rather than the surface: `setSurfaceSize`
    // alone leaves MediaQuery reporting the 800x600 test window, and the board
    // scales itself from MediaQuery.
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: RepaintBoundary(
          key: boundary,
          child: const GameScreen(targetLevel: 7),
        ),
      ),
    );
    // The board comes out of Hive on the first frame, and a fake clock never
    // lets that read come back on its own.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<void> snap(String name) => tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });

    final tubes = find.byType(TubeWidget);
    final count = tubes.evaluate().length;
    final board = List<Tube>.generate(
      count,
      (i) => tester.widget<TubeWidget>(tubes.at(i)).tube,
    );

    // The same rule the controller pours on: a matching top colour, or an empty
    // tube, into room that is left. The deepest such pour is the one to check -
    // a single layer would let the stream end anywhere near the bottle and pass.
    int? from, to;
    var layers = 0;
    for (var f = 0; f < count; f++) {
      if (board[f].isEmpty) continue;
      final run = _topRun(board[f].colors);
      for (var t = 0; t < count; t++) {
        if (t == f || board[t].isFull) continue;
        if (board[t].isNotEmpty && board[t].topColor != board[f].topColor) {
          continue;
        }
        final room = board[t].capacity - board[t].colors.length;
        final moved = run < room ? run : room;
        if (moved > layers) {
          layers = moved;
          from = f;
          to = t;
        }
      }
    }
    expect(
      layers,
      greaterThanOrEqualTo(2),
      reason: 'level 7 has to offer a pour of more than one layer',
    );
    // The tubes in `board` are the very objects the controller mutates, so the
    // counts have to be written down before the pour, not read back after it.
    final before = List<int>.generate(count, (i) => board[i].colors.length);
    final pouredColor = board[from!].topColor;

    await tester.tap(tubes.at(from));
    await tick(tester, 80);
    await tester.tap(tubes.at(to!));

    // 400ms of lift, then the jet reaches down and the liquid starts across.
    await tick(tester, 300);
    await snap('pour_lift');
    await tick(tester, 200);
    await snap('pour_reaching');
    // One more layer every 200ms after that. The jet's end chases the rising
    // surface, so the reading is taken a beat after the last layer lands: by
    // then the two agree, and the pour has not started breaking apart yet.
    await tick(tester, 200 * (layers - 1));
    await snap('pour_pouring');

    final painter = _jetPainter(tester);
    expect(painter.startPoint, isNotNull, reason: 'the jet has to be painting');
    expect(painter.endPoint, isNotNull);

    final effectTopLeft = tester
        .getRect(find.byType(PouringStreamEffect))
        .topLeft;
    final target = tester.getRect(tubes.at(to));
    final poured = board[to].colors.length - before[to];
    expect(poured, layers, reason: 'the deal offered a $layers-layer pour');
    // Where TubeWidget paints the top of the stack the bottle now holds, layers
    // it already had included: a 144 column with a 4 gap under it, scaled once
    // more than the box it sits in.
    final paintScale = target.height / 160;
    final surfaceY = target.top +
        (target.height -
                4 -
                144 * board[to].colors.length / board[to].capacity) *
            paintScale -
        effectTopLeft.dy;

    expect(
      painter.endPoint!.dy,
      closeTo(surfaceY, 4),
      reason: 'the stream has to end on the liquid it is feeding',
    );
    expect(
      painter.startPoint!.dx,
      closeTo(painter.endPoint!.dx, 0.001),
      reason: 'and leave the lip straight over the tube',
    );
    // The air gap: long enough to see the bottle, short enough to believe it.
    final rimY =
        target.top + (target.height - 149) * paintScale - effectTopLeft.dy;
    expect(
      rimY - painter.startPoint!.dy,
      inInclusiveRange(1, target.height * 0.2),
    );
    expect(painter.color, pouredColor);

    expect(tester.takeException(), isNull);
    expect(poured, greaterThan(0), reason: 'the pour moves liquid');
    // The lifting bottle may lean over the header, but nothing of it may leave
    // the screen: an off-board bottle is what made the pour look broken.
    final lifted = tester.getRect(tubes.at(from));
    expect(lifted.top, greaterThanOrEqualTo(0));
    expect(lifted.left, greaterThanOrEqualTo(0));
    expect(lifted.right, lessThanOrEqualTo(390));

    // Let the pour finish so no timer is left pending at teardown.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every pour kicks the surface, and the spray moves', (
    tester,
  ) async {
    final boundary = GlobalKey();
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: RepaintBoundary(
          key: boundary,
          child: const GameScreen(targetLevel: 7),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    /// The deepest legal pour on the board as it stands right now: which two
    /// bottles, what colour, and how many layers land.
    (int, int, Color, int)? nextPour() {
      final tubes = find.byType(TubeWidget);
      final count = tubes.evaluate().length;
      (int, int, Color, int)? best;
      for (var f = 0; f < count; f++) {
        final from = tester.widget<TubeWidget>(tubes.at(f)).tube;
        if (from.isEmpty) continue;
        final run = _topRun(from.colors);
        for (var t = 0; t < count; t++) {
          if (t == f) continue;
          final to = tester.widget<TubeWidget>(tubes.at(t)).tube;
          if (to.isFull) continue;
          if (to.isNotEmpty && to.topColor != from.topColor) continue;
          final room = to.capacity - to.colors.length;
          final moved = run < room ? run : room;
          if (best == null || moved > best.$4) {
            best = (f, t, from.topColor!, moved);
          }
        }
      }
      return best;
    }

    var surface = Offset.zero;
    var jet = 0.0;
    var wet = Colors.white;
    var target = 0;
    int? first, second;

    /// The top of the liquid in the tube being filled, on the screen. Measured
    /// from the tube rather than from the jet, because the jet's end is eased
    /// towards a rising surface and lags it.
    double liquidTop() {
      final tube = tester.widget<TubeWidget>(find.byType(TubeWidget).at(target));
      final rect = tester.getRect(find.byType(TubeWidget).at(target));
      final paintScale = rect.height / 160;
      return rect.top +
          (rect.height - 4 - 36 * tube.tube.colors.length) * paintScale;
    }

    /// Droplets either side of the jet, above the liquid, where nothing else
    /// of that colour can be.
    Future<int> spray() async {
      final counted = await tester.runAsync(() async {
        final top = liquidTop();
        final render =
            boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        final width = image.width;
        image.dispose();
        final bytes = data!.buffer.asUint8List();
        final argb = wet.toARGB32();
        final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
        final yTop = ((surface.dy - jet * 6) * 2).round();
        final yBottom = ((top - jet * 1.2) * 2).round();
        final xLeft = ((surface.dx - jet * 5) * 2).round();
        final xRight = ((surface.dx + jet * 5) * 2).round();
        var lit = 0;
        for (var y = yTop; y < yBottom; y++) {
          for (var x = xLeft; x < xRight; x++) {
            // The jet itself runs down the middle; only spray counts here.
            if ((x / 2 - surface.dx).abs() < jet * 1.3) continue;
            final i = (y * width + x) * 4;
            final off =
                (bytes[i] - r).abs() +
                (bytes[i + 1] - g).abs() +
                (bytes[i + 2] - b).abs();
            if (off < 110) lit++;
          }
        }
        return lit;
      });
      return counted!;
    }

    /// Runs one whole pour and returns how many layers it moved and how many
    /// times the surface kicked, photographing the spray twice while the
    /// droplets are still in the air.
    Future<(int, int)> runPour() async {
      final pour = nextPour();
      expect(pour, isNotNull, reason: 'level 7 has to offer a legal pour');
      final (from, to, colour, layers) = pour!;
      wet = colour;
      target = to;
      // The jet speaks in the overlay's own coordinates; the picture is the
      // whole screen, so the overlay's offset has to be added back in.
      final overlay = tester.getRect(find.byType(PouringStreamEffect)).topLeft;
      final tubes = find.byType(TubeWidget);
      final had = tester.widget<TubeWidget>(tubes.at(to)).tube.colors.length;
      await tester.tap(tubes.at(from));
      await tick(tester, 80);
      await tester.tap(tubes.at(to));
      var previous = 0.0;
      var kicked = 0;
      // 400ms of lift, one layer per 200ms after it, and the last splash needs
      // its 340ms to run out.
      for (var i = 0; i < (940 + 200 * layers) ~/ 16; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final painter = _jetPainter(tester);
        // Every kick crosses the middle of its 340ms exactly once, so counting
        // the crossings counts the kicks.
        if (previous < 0.45 && painter.splash >= 0.45) kicked++;
        previous = painter.splash;
        if (painter.endPoint != null) {
          surface = painter.endPoint! + overlay;
          jet = painter.streamWidth;
        }
        if (first == null && painter.splash > 0.42 && painter.splash < 0.56) {
          first = await spray();
        } else if (first != null &&
            second == null &&
            painter.splash > 0.72 &&
            painter.splash < 0.86) {
          second = await spray();
        }
      }
      final filled = tester.widget<TubeWidget>(tubes.at(to)).tube.colors.length;
      expect(
        filled - had,
        layers,
        reason: 'the engine moved a different amount than the deal offered',
      );
      return (layers, kicked);
    }

    final (firstLayers, firstKicks) = await runPour();
    expect(
      firstLayers,
      greaterThanOrEqualTo(2),
      reason: 'the deal has to offer a pour of more than one layer',
    );
    expect(
      firstKicks,
      greaterThanOrEqualTo(firstLayers),
      reason:
          'a $firstLayers-layer pour landed that many times but kicked the '
          'surface fewer',
    );
    expect(first, isNotNull, reason: 'the splash window was never reached');
    expect(second, isNotNull);
    expect(first!, greaterThan(0), reason: 'no droplets above the surface');
    expect(
      (first! - second!).abs(),
      greaterThan(first! * 0.15),
      reason: 'the spray is the same picture 200ms apart, so it is not moving',
    );

    // Let the pour finish, then pour again: the next layer has to kick too.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final (secondLayers, secondKicks) = await runPour();
    expect(
      secondKicks,
      greaterThanOrEqualTo(secondLayers),
      reason: 'the second pour did not kick the surface again',
    );

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });
}

/// How many layers of one colour sit on top of a tube, which is how many a
/// single pour takes.
int _topRun(List<Color> colors) {
  if (colors.isEmpty) return 0;
  final top = colors.last;
  var run = 0;
  for (var i = colors.length - 1; i >= 0 && colors[i] == top; i--) {
    run++;
  }
  return run;
}

/// The pour's own clocks run on frames, so advance the clock the way a device
/// does instead of in one big jump.
Future<void> tick(WidgetTester tester, int ms) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The painter behind the live jet.
PouringStreamPainter _jetPainter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(PouringStreamEffect),
      matching: find.byType(CustomPaint),
    ),
  );
  expect(paint.painter, isA<PouringStreamPainter>());
  return paint.painter! as PouringStreamPainter;
}
