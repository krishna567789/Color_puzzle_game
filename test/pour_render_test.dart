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

    /// The pour's animations are driven by frames, so advance the clock the way a
    /// device does instead of in one big jump.
    Future<void> tick(int ms) async {
      for (var elapsed = 0; elapsed < ms; elapsed += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
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
    // tube, into room that is left.
    int? from, to;
    for (var f = 0; f < count && from == null; f++) {
      if (board[f].isEmpty) continue;
      for (var t = 0; t < count; t++) {
        if (t == f || board[t].isFull) continue;
        if (board[t].isNotEmpty && board[t].topColor != board[f].topColor) {
          continue;
        }
        from = f;
        to = t;
        break;
      }
    }
    expect(from, isNotNull, reason: 'level 7 has to offer a legal pour');
    // The tubes in `board` are the very objects the controller mutates, so the
    // counts have to be written down before the pour, not read back after it.
    final before = List<int>.generate(count, (i) => board[i].colors.length);
    final pouredColor = board[from!].topColor;

    await tester.tap(tubes.at(from));
    await tick(80);
    await tester.tap(tubes.at(to!));

    // 400ms of lift, then the jet reaches down and the liquid starts across.
    await tick(300);
    await snap('pour_lift');
    await tick(200);
    await snap('pour_reaching');
    // The jet's own intro is 180ms; past that it is running at full length.
    await tick(120);
    await snap('pour_pouring');

    final painter = _jetPainter(tester);
    expect(painter.startPoint, isNotNull, reason: 'the jet has to be painting');
    expect(painter.endPoint, isNotNull);

    final effectTopLeft = tester
        .getRect(find.byType(PouringStreamEffect))
        .topLeft;
    final target = tester.getRect(tubes.at(to));
    final poured = board[to].colors.length - before[to];
    // Where TubeWidget paints the top of a `poured`-layer stack: a 144 column
    // with a 4 gap under it, scaled once more than the box it sits in.
    final paintScale = target.height / 160;
    final surfaceY = target.top +
        (target.height - 4 - 36 * poured) * paintScale -
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
