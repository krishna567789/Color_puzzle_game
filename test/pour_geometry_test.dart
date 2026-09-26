import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:color_puzzle_game/game/pour_geometry.dart';

/// The board is laid out at a scale, so every tube box here is what the wrap
/// actually reports: 55x160 logical units multiplied by that scale.
const tubeSize = Size(60.5, 176);

/// A phone the size the game is designed for.
const screen = Rect.fromLTWH(0, 0, 390, 844);

/// The tube's contents are scaled once by the board and again inside its own
/// box, so the glass it paints hangs below the rect the layout gave it. Where
/// the rim actually is: the glass is 150 tall and bottom aligned, and its lip
/// rrect is centred 1 below the top of that glass.
double rimY(Offset topLeft) =>
    topLeft.dy + (tubeSize.height - 150 + 1) * _paintScale;

/// Where `TubeWidget` paints the top of a stack of `layers` layers: a 144-tall
/// column with a 4 gap under it, split into four.
double surfaceY(Offset topLeft, int layers) =>
    topLeft.dy + (tubeSize.height - 4 - 36 * layers) * _paintScale;

double get _paintScale => tubeSize.height / 160;

void main() {
  PourGeometry geometryFor({
    required Offset sourceTopLeft,
    required Offset targetTopLeft,
    double tilt = 1.5708,
    Rect bounds = screen,
    int targetLayers = 0,
  }) => PourGeometry.forTubes(
    sourceTopLeft: sourceTopLeft,
    sourceSize: tubeSize,
    targetTopLeft: targetTopLeft,
    targetSize: tubeSize,
    tilt: tilt,
    bounds: bounds,
    targetLayers: targetLayers,
    targetCapacity: 4,
  );

  group('pour geometry', () {
    test('the jet leaves the lip directly over the tube it fills', () {
      final geo = geometryFor(
        sourceTopLeft: const Offset(32, 300),
        targetTopLeft: const Offset(280, 300),
      );

      expect(geo.mouth.dx, closeTo(280 + tubeSize.width / 2, 0.001));
      expect(geo.landing.dx, closeTo(geo.mouth.dx, 0.001));
    });

    test('the bottle hovers at its rim, not a bottle-length above it', () {
      const target = Offset(280, 300);
      final geo = geometryFor(
        sourceTopLeft: const Offset(32, 300),
        targetTopLeft: target,
      );

      // The old pour hoisted the bottle a whole tube-height above the target and
      // started the stream beside it; liquid that crosses that much open air
      // reads as falling out of the sky rather than leaving a mouth.
      final clearance = rimY(target) - geo.mouth.dy;
      expect(clearance, greaterThan(0));
      expect(clearance, lessThan(tubeSize.height * 0.2));
    });

    test('the stream runs down to the surface it is feeding', () {
      const target = Offset(280, 520);
      // Inside the glass the drop can be as long as it needs to be: what has to
      // stay short is the air between the two bottles. Ending the jet at the
      // neck left the new layer appearing at the bottom with nothing feeding it.
      for (final layers in [0, 1, 2, 3]) {
        final geo = geometryFor(
          sourceTopLeft: const Offset(32, 300),
          targetTopLeft: target,
          targetLayers: layers,
        );

        expect(geo.mouth.dy, lessThan(rimY(target)));
        expect(geo.landing.dy, closeTo(surfaceY(target, layers), 0.001));
        expect(geo.landing.dx, closeTo(geo.mouth.dx, 0.001));
      }

      final empty = geometryFor(
        sourceTopLeft: const Offset(32, 300),
        targetTopLeft: target,
      );
      final nearlyFull = geometryFor(
        sourceTopLeft: const Offset(32, 300),
        targetTopLeft: target,
        targetLayers: 3,
      );
      expect(
        nearlyFull.landing.dy - nearlyFull.mouth.dy,
        lessThan(empty.landing.dy - empty.mouth.dy),
        reason: 'the jet shortens as the tube fills',
      );
      expect(
        nearlyFull.landing.dy,
        greaterThan(nearlyFull.mouth.dy),
        reason: 'and never runs back up out of the glass',
      );
    });

    test('the bottle leans towards the target, not towards the index order', () {
      final rightward = geometryFor(
        sourceTopLeft: const Offset(32, 300),
        targetTopLeft: const Offset(280, 300),
        tilt: 1.5708,
      );
      // Pouring into a tube numbered higher but sitting to the left still has to
      // tip left, or the bottle ends up reaching across the board.
      final leftward = geometryFor(
        sourceTopLeft: const Offset(280, 300),
        targetTopLeft: const Offset(32, 520),
        tilt: 1.5708,
      );

      expect(rightward.tilt, greaterThan(0));
      expect(leftward.tilt, lessThan(0));
      expect(
        leftward.hoverOffset.dx - rightward.hoverOffset.dx,
        isNot(closeTo(0, 1)),
      );
    });

    test('the hover puts the bottle exactly where the stream says it is', () {
      const source = Offset(32, 300);
      final geo = geometryFor(
        sourceTopLeft: source,
        targetTopLeft: const Offset(280, 300),
      );

      // TubeWidget rotates around the top-centre of the tube box and GameScreen
      // hands it `hoverOffset`; the pouring lip is the rim point the tilt swings
      // lowest. Re-doing that transform must reproduce the mouth the stream
      // starts from, which is the whole point of sharing this geometry.
      final pivot = source + Offset(tubeSize.width / 2, 0);
      final lip = pivot + geo.hoverOffset + _lipOffset(tubeSize, geo);

      expect(lip.dx, closeTo(geo.mouth.dx, 0.001));
      expect(lip.dy, closeTo(geo.mouth.dy, 0.001));
    });

    test('a tipped bottle over the edge column still fits on screen', () {
      // Directly above its target the lean carries no information about the
      // pour, so it is free to pick the side with room. Tipping it the other
      // way drags a whole bottle-length off the left edge.
      const leftColumn = Offset(16, 300);
      final geo = geometryFor(
        sourceTopLeft: leftColumn,
        targetTopLeft: const Offset(16, 520),
      );

      final pivot = leftColumn + Offset(tubeSize.width / 2, 0) + geo.hoverOffset;
      // The far corner of the body, measured from the pivot the tube turns on.
      final baseOuter = _rotate(
        Offset(tubeSize.width / 2, tubeSize.height),
        geo.tilt,
      );
      final baseX = pivot.dx + baseOuter.dx;
      expect(
        baseX,
        greaterThan(0),
        reason: 'the base of the bottle has to stay on the board',
      );
      expect(geo.tilt, lessThan(0));
    });
  });
}

Offset _rotate(Offset point, double angle) => Offset(
  point.dx * math.cos(angle) - point.dy * math.sin(angle),
  point.dx * math.sin(angle) + point.dy * math.cos(angle),
);

/// The lowest point of the neck rim once the tube has tipped over the angle this
/// pour resolved to. Mirrors the constants in [PourGeometry].
Offset _lipOffset(Size tube, PourGeometry geo) {
  final rim = Offset(
    (geo.tilt >= 0 ? 1 : -1) * tube.width * 0.2,
    (tube.height - 150 + 1) * (tube.height / 160),
  );
  return Offset(
    rim.dx * math.cos(geo.tilt) - rim.dy * math.sin(geo.tilt),
    rim.dx * math.sin(geo.tilt) + rim.dy * math.cos(geo.tilt),
  );
}
