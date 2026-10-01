import 'dart:io';
import 'dart:ui' as ui;

import 'package:color_puzzle_game/widgets/common/level_complete_dialog.dart';
import 'package:color_puzzle_game/widgets/frame_sequence.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// The win card shows a real rendered bottle now, so the promise lives in
/// pixels rather than in code: if the frames stop moving, stop fitting, or stop
/// being shipped, the card silently regresses to a still image.
const directory = 'assets/anim/victory_spin';
const frameCount = 16;
const framePath = 55;

String frameAsset(int index) =>
    '$directory/frame_${index.toString().padLeft(2, '0')}.png';

/// The live win card, the way the game mounts it.
Widget winCard() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: LevelCompleteDialog(
            stars: 3,
            level: 12,
            coinsEarned: 40,
            gemsEarned: 0,
            onNext: () {},
            onHome: () {},
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every frame is shipped and declared', () async {
    for (var index = 1; index <= frameCount; index++) {
      final path = frameAsset(index);
      expect(File(path).existsSync(), isTrue, reason: path);
      final data = await rootBundle.load(path);
      expect(
        data.lengthInBytes,
        greaterThan(1000),
        reason: '$path is missing from pubspec.yaml or is a stub',
      );
    }
  });

  test('the sequence actually moves, and nothing is cropped', () async {
    final frames = <_Alpha>[];
    for (var index = 1; index <= frameCount; index++) {
      frames.add(await _decode(frameAsset(index)));
    }
    for (final frame in frames) {
      expect(
        frame.borderAlpha(),
        0,
        reason: 'a frame paints to the edge, so the bottle is cut off',
      );
    }
    for (var index = 0; index < frameCount; index++) {
      final next = (index + 1) % frameCount;
      final delta = frames[index].meanAlphaDifference(frames[next]);
      expect(
        delta,
        greaterThan(0.004),
        reason: 'frames ${index + 1} and ${next + 1} are the same picture, '
            'so the flipbook would freeze on screen',
      );
    }
  });

  testWidgets('the win card plays the flipbook', (tester) async {
    await useScreenSize(tester, const Size(390, 844));

    await tester.pumpWidget(winCard());
    expect(tester.takeException(), isNull);

    final first = _shownFrame(tester);
    expect(first, isNotNull, reason: 'no bottle is drawn on the win card');

    await tester.pump(Duration(milliseconds: framePath * 4));
    expect(_shownFrame(tester), isNot(first));

    await tester.pump(const Duration(days: 1));
    expect(tester.takeException(), isNull);
  });

  /// A widget can hold an [Image] that never reaches the screen, so the card is
  /// checked in pixels. Comparing two frames of what the card actually painted
  /// is the claim that survives a restyle: it says nothing about the colours
  /// behind the bottle, only that the bottle is on the card and it is turning.
  testWidgets('the flipbook paints on the win card', (tester) async {
    const pixelRatio = 2.0;
    final boundary = GlobalKey();
    await useScreenSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: Center(
              child: LevelCompleteDialog(
                stars: 3,
                level: 12,
                coinsEarned: 40,
                gemsEarned: 0,
                onNext: () {},
                onHome: () {},
              ),
            ),
          ),
        ),
      ),
    );

    late _Shot before;
    late _Shot after;
    late Rect box;
    await tester.runAsync(() async {
      // Real time, because the asset loader needs the event loop to decode.
      for (var i = 0; i < 10; i++) {
        await tester.pump(Duration(milliseconds: framePath));
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pump();

      final renderBox =
          tester.renderObject<RenderBox>(find.byType(FrameSequence));
      final origin = renderBox.localToGlobal(Offset.zero) * pixelRatio;
      box = Rect.fromLTWH(
        origin.dx.roundToDouble(),
        origin.dy.roundToDouble(),
        (renderBox.size.width * pixelRatio).roundToDouble(),
        (renderBox.size.height * pixelRatio).roundToDouble(),
      );
      before = await _capture(boundary, pixelRatio);

      // A quarter turn, so the two captures are different frames for sure.
      for (var i = 0; i < 4; i++) {
        await tester.pump(Duration(milliseconds: framePath));
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      after = await _capture(boundary, pixelRatio);
    });

    expect(
      box.width * box.height,
      greaterThan(0),
      reason: 'the flipbook has no size on the card, so it is not being laid out',
    );
    expect(after.width, before.width);
    expect(after.height, before.height);
    final width = before.width;
    // The rect below is in captured-pixel units, so a surface that is not the
    // logical size times the ratio would silently sample the wrong band.
    expect(width, (390 * pixelRatio).round());

    var moved = 0;
    for (var y = box.top.toInt(); y < box.bottom.toInt(); y++) {
      for (var x = box.left.toInt(); x < box.right.toInt(); x++) {
        final i = (y * width + x) * 4;
        final delta = (before.bytes[i] - after.bytes[i]).abs() +
            (before.bytes[i + 1] - after.bytes[i + 1]).abs() +
            (before.bytes[i + 2] - after.bytes[i + 2]).abs();
        if (delta > 30) moved++;
      }
    }
    printOnFailure('changed pixels in the bottle box: $moved of '
        '${(box.width * box.height).round()}');

    // Two frames a quarter-turn apart move about 40% of this box in the real
    // render. A third of that is still three times the silhouette's own
    // footprint, so a stopped, blank or mislaid bottle cannot get past it.
    expect(moved, greaterThan(3000),
        reason: 'the bottle is not being painted, or not turning, on the card');
  });
}

/// What the card really drew, as straight RGBA bytes.
Future<_Shot> _capture(GlobalKey boundary, double pixelRatio) async {
  final render =
      boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final shot = _Shot(
    image.width,
    image.height,
    data!.buffer.asUint8List(),
  );
  image.dispose();
  return shot;
}

class _Shot {
  final int width;
  final int height;
  final Uint8List bytes;

  _Shot(this.width, this.height, this.bytes);
}

int? _shownFrame(WidgetTester tester) {
  for (final image in tester.widgetList<Image>(find.byType(Image))) {
    final asset = image.image;
    if (asset is! AssetImage) continue;
    if (!asset.assetName.startsWith('$directory/')) continue;
    return int.tryParse(
      asset.assetName.split('frame_').last.replaceAll('.png', ''),
    );
  }
  return null;
}

class _Alpha {
  final int width;
  final int height;
  final Uint8List bytes;

  _Alpha(this.width, this.height, this.bytes);

  int _alphaAt(int x, int y) => bytes[(y * width + x) * 4 + 3];

  /// The loudest pixel anywhere on the frame border.
  int borderAlpha() {
    var loudest = 0;
    for (var x = 0; x < width; x++) {
      loudest = _loudest(loudest, _alphaAt(x, 0), _alphaAt(x, height - 1));
    }
    for (var y = 0; y < height; y++) {
      loudest = _loudest(loudest, _alphaAt(0, y), _alphaAt(width - 1, y));
    }
    return loudest;
  }

  int _loudest(int current, int a, int b) {
    final value = a > b ? a : b;
    return value > current ? value : current;
  }

  double meanAlphaDifference(_Alpha other) {
    expect(other.width, width);
    expect(other.height, height);
    var total = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final a = _alphaAt(x, y);
        final b = other._alphaAt(x, y);
        total += a > b ? a - b : b - a;
      }
    }
    return total / (width * height * 255);
  }
}

Future<_Alpha> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(
    await File(path).readAsBytes(),
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  addTearDown(image.dispose);
  final bytes = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  expect(bytes, isNotNull, reason: '$path has no raw pixels');
  return _Alpha(image.width, image.height, bytes!.buffer.asUint8List());
}
