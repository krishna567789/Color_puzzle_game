import 'dart:io';
import 'dart:ui' as ui;

import 'package:color_puzzle_game/models/tube_model.dart';
import 'package:color_puzzle_game/widgets/tube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// tools/bottle/render_skins.py crops the 55 x 150 mm box at 4 px per mm, and
/// `_getBottlePath` draws that box in logical pixels, so 1 mm is 1 dp.
const pxPerMm = 4.0;

/// The glass is a pre-rendered sprite now, so the promise the vector painter
/// used to keep by construction has to be re-checked against pixels: what the
/// art draws must be what the liquid is clipped to. A sprite a millimetre
/// narrower than `BottleClipper` lets the bottom layer sit outside the wall, and
/// every bit of maths in the project would still look perfect.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const skins = [
    'default_tube',
    'neon_tube',
    'crystal_bottle',
    'wooden_tube',
  ];

  Future<Rgba> decode(String path) async {
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    final image = (await codec.getNextFrame()).image;
    addTearDown(image.dispose);
    final bytes = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    expect(bytes, isNotNull, reason: '$path has no raw pixels');
    return Rgba(image.width, image.height, bytes!.buffer.asUint8List());
  }

  test('every skin the shop sells has a sprite and a hero render', () {
    for (final id in skins) {
      expect(File('assets/skins/$id.png').existsSync(), isTrue, reason: id);
      expect(
        File('assets/skins/hero_$id.png').existsSync(),
        isTrue,
        reason: 'the shop card for $id',
      );
    }
  });

  test('the sprites are declared assets, not just files on disk', () async {
    for (final id in skins) {
      for (final path in [
        'assets/skins/$id.png',
        'assets/skins/hero_$id.png',
      ]) {
        final data = await rootBundle.load(path);
        expect(
          data.lengthInBytes,
          greaterThan(1000),
          reason: '$path is missing from pubspec.yaml or is a stub',
        );
      }
    }
  });

  testWidgets('a rendered skin replaces the vector glass', (tester) async {
    for (final id in skins) {
      await tester.pumpWidget(host(id));
      expect(
        painterTypes(tester),
        isNot(contains('BottlePainter')),
        reason: '$id draws from art, not from the painter',
      );
      expect(
        tester.widgetList<Image>(find.byType(Image)).map((image) => image.image),
        contains(
          isA<AssetImage>().having(
            (asset) => asset.assetName,
            'assetName',
            'assets/skins/$id.png',
          ),
        ),
        reason: '$id has a sprite to load',
      );
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(host('a_skin_not_rendered'));
    expect(
      painterTypes(tester),
      contains('BottlePainter'),
      reason: 'an unknown skin still has to look like a bottle',
    );
  });

  testWidgets('the picked ring survives the switch to art', (tester) async {
    await tester.pumpWidget(host('neon_tube'));
    expect(
      painterTypes(tester),
      isNot(contains('BottleFocusPainter')),
      reason: 'an idle bottle wears no ring',
    );

    await tester.pumpWidget(host('neon_tube', selected: true));
    expect(
      painterTypes(tester),
      contains('BottleFocusPainter'),
      reason: 'a static sprite cannot light up on its own',
    );

    await tester.pumpWidget(host('neon_tube', selected: true, hinted: true));
    expect(
      focusPainter(tester).hinted,
      isTrue,
      reason: 'a hint is not the same signal as a selection',
    );
  });

  test('the drawn wall is where the liquid is clipped', () async {
    final clip = BottleClipper().getClip(const Size(55, 150));
    for (final id in skins) {
      final sprite = await decode('assets/skins/$id.png');
      expect(
        sprite.width,
        (55 * pxPerMm).round(),
        reason: '$id is not cropped to the bottle box',
      );
      expect(
        sprite.height,
        (150 * pxPerMm).round(),
        reason: '$id is not cropped to the bottle box',
      );

      final covered = sprite.outlineCoverage(clip);
      expect(
        covered,
        greaterThan(0.9),
        reason:
            '$id leaves ${((1 - covered) * 100).round()}% of the clip edge '
            'unpainted, so liquid would sit outside the visible glass',
      );

      final leaks = sprite.pixelsBeyond(clip, mm: 2.0);
      expect(
        leaks,
        0,
        reason: '$id paints more than 2mm outside the bottle it clips to',
      );
    }
  });

  test('the hero renders sit on nothing', () async {
    for (final id in skins) {
      final hero = await decode('assets/skins/hero_$id.png');
      // A hero with a background would put a coloured slab over the shop card.
      expect(
        hero.maxCornerAlpha(),
        0,
        reason: '$id was rendered without a transparent film',
      );
    }
  });

  test('the glass stays clear enough to read the liquid through', () async {
    for (final id in skins) {
      final sprite = await decode('assets/skins/$id.png');
      // The middle of the body: the layers live in here, and the player has to
      // tell one from the next at a glance.
      final haze = sprite.meanAlphaIn(
        const Rect.fromLTRB(14, 40, 41, 100),
        pxPerMm: pxPerMm,
      );
      expect(
        haze,
        lessThan(0.12),
        reason: '$id washes out the liquid it is supposed to show',
      );
    }
  });
}

Widget host(
  String skinId, {
  bool selected = false,
  bool hinted = false,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: TubeWidget(
        tube: Tube(initialColors: const [Color(0xFFF44336), Color(0xFF2196F3)]),
        isSelected: selected,
        isShaking: false,
        isHinted: hinted,
        onTap: () {},
        skinId: skinId,
      ),
    ),
  ),
);

List<String> painterTypes(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<Object>()
    .map((painter) => painter.runtimeType.toString())
    .toList();

BottleFocusPainter focusPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<BottleFocusPainter>()
    .single;

/// Straight RGBA bytes of a decoded PNG.
class Rgba {
  final int width;
  final int height;
  final Uint8List bytes;

  Rgba(this.width, this.height, this.bytes);

  int _alphaAt(int x, int y) => bytes[(y * width + x) * 4 + 3];

  /// The loudest of the four corners, which for art meant to sit on a card has
  /// to be empty.
  int maxCornerAlpha() => [
    _alphaAt(0, 0),
    _alphaAt(width - 1, 0),
    _alphaAt(0, height - 1),
    _alphaAt(width - 1, height - 1),
  ].reduce((a, b) => a > b ? a : b);

  /// Fraction of the clip path's outline this image actually paints.
  ///
  /// A rendered wall is a bright ring about a pixel wide, so the test looks for
  /// glass *near* each edge point rather than on the exact pixel: what has to
  /// hold is that the liquid is never clipped to space the bottle does not draw.
  /// The mouth line is skipped — the bottle opens there, and no glass crosses it.
  double outlineCoverage(Path clip, {double toleranceMm = 1.5}) {
    final reach = (toleranceMm * pxPerMm).round();
    var hit = 0, total = 0;
    for (final metric in clip.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 0.5) {
        final point = metric.getTangentForOffset(d)?.position;
        if (point == null) continue;
        if (point.dy <= 5.001 &&
            point.dx > 16.5 &&
            point.dx < 38.5) {
          continue;
        }
        final centreX = (point.dx * pxPerMm).round();
        final centreY = (point.dy * pxPerMm).round();
        total++;
        var painted = false;
        for (var y = centreY - reach; y <= centreY + reach && !painted; y++) {
          for (var x = centreX - reach; x <= centreX + reach && !painted; x++) {
            if (x < 0 || y < 0 || x >= width || y >= height) continue;
            if (_alphaAt(x, y) >= 30) painted = true;
          }
        }
        if (painted) hit++;
      }
    }
    return total == 0 ? 0 : hit / total;
  }

  /// Pixels painted more than `mm` away from the clip path.
  ///
  /// The mouth is not measured: the render gives the bottle a lip a couple of
  /// millimetres wider than the neck bore, which is what a real bottle does, and
  /// the clip path tops out flat below it. Liquid never reaches that band.
  int pixelsBeyond(Path clip, {required double mm}) {
    final near = _spread(_insideMask(clip), (mm * pxPerMm).round());
    var leaks = 0;
    for (var y = (6 * pxPerMm).round(); y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_alphaAt(x, y) < 40) continue;
        if (!near[y * width + x]) leaks++;
      }
    }
    return leaks;
  }

  List<bool> _insideMask(Path clip) => List<bool>.generate(
    width * height,
    (i) => clip.contains(
      Offset((i % width + 0.5) / pxPerMm, (i ~/ width + 0.5) / pxPerMm),
    ),
  );

  /// Grow a mask by `radius` pixels along both axes. Only pixels already set are
  /// expanded, which keeps 132k of them quick.
  List<bool> _spread(List<bool> mask, int radius) {
    final rows = List<bool>.filled(width * height, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!mask[y * width + x]) continue;
        for (var dx = -radius; dx <= radius; dx++) {
          final column = x + dx;
          if (column >= 0 && column < width) rows[y * width + column] = true;
        }
      }
    }
    final out = List<bool>.filled(width * height, false);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!rows[y * width + x]) continue;
        for (var dy = -radius; dy <= radius; dy++) {
          final row = y + dy;
          if (row >= 0 && row < height) out[row * width + x] = true;
        }
      }
    }
    return out;
  }

  double meanAlphaIn(Rect box, {required double pxPerMm}) {
    var total = 0.0;
    var count = 0;
    for (
      var y = (box.top * pxPerMm).round();
      y < (box.bottom * pxPerMm).round();
      y++
    ) {
      for (
        var x = (box.left * pxPerMm).round();
        x < (box.right * pxPerMm).round();
        x++
      ) {
        total += _alphaAt(x, y) / 255;
        count++;
      }
    }
    return total / count;
  }
}
