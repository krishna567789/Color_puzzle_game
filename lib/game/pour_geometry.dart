import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// Where a pouring bottle floats and where its liquid leaves it.
///
/// The hover transform (GameScreen) and the stream (PouringStreamEffect) used
/// to guess each other's numbers, so the bottle ended up a whole tube-height
/// away from the top of the stream and the liquid looked like it fell out of
/// the sky. Both now read this one geometry, which works out the tilted
/// bottle's own pour spout, so the jet always starts at its lip.
class PourGeometry {
  const PourGeometry._({
    required this.hoverOffset,
    required this.tilt,
    required this.mouth,
    required this.landing,
  });

  /// Translate the pouring tube needs so its spout sits over the target.
  final Offset hoverOffset;

  /// The angle that hover is built for, leaning the way the layout points.
  final double tilt;

  /// Global position of the spout, after the bottle has tipped over.
  final Offset mouth;

  /// Global position the stream lands at: the surface of the liquid already in
  /// the target, so the jet runs down the tube instead of stopping at its neck.
  final Offset landing;

  /// How far the spout hovers above the target's rim. It is deliberately small:
  /// liquid that falls further than a finger's width through the *air* stops
  /// looking like it came out of the bottle at all.
  static const double _clearance = 0.11;

  /// Half the neck opening, as a fraction of the tube's width (`_getBottlePath`
  /// gives the neck 0.4 of the width).
  static const double _neckHalfOverWidth = 0.2;

  /// The glass is 150 tall and the neck's rim pill is centred 1 above its top,
  /// while the liquid column is 144 tall with a 4 gap under it. All of them are
  /// measured from the bottom of the tube's own box, in that box's units.
  static const double _glassHeight = 150;
  static const double _rimCentreOverGlassTop = 1;
  static const double _liquidBottomGap = 4;
  static const double _liquidColumnHeight = 144;

  /// A tube's box is `160 * scale` tall and its contents are then scaled by
  /// `scale` again, so the glass it draws hangs below the rect the board laid
  /// out. The pour has to aim at the glass the player sees: at scale 1.1 the
  /// rim sits 30 below the top of a 176 box, not the 12 the rect implies, and
  /// aiming at the rect started the stream beside the bottle's neck.
  static double _paintedY(Size box, double fromBoxTop) =>
      fromBoxTop * box.height / 160;

  static double _rimCentre(Size box) =>
      _paintedY(box, box.height - _glassHeight + _rimCentreOverGlassTop);

  static double _liquidSurface(Size box, int layers, int capacity) {
    final filled = layers.clamp(0, capacity).toDouble();
    return _paintedY(
      box,
      box.height -
          _liquidBottomGap -
          _liquidColumnHeight * (filled / capacity),
    );
  }

  /// Builds the pour for one source/target pair.
  ///
  /// [bounds] is the visible area in the same global coordinates. It only
  /// decides which way a bottle tips when the target sits directly under it,
  /// where either lean pours correctly but one of them drags the body off the
  /// edge of the screen.
  ///
  /// [targetLayers] and [targetCapacity] say how full the tube being filled is;
  /// the jet has to end on that surface, not at a fixed depth in its neck.
  static PourGeometry forTubes({
    required Offset sourceTopLeft,
    required Size sourceSize,
    required Offset targetTopLeft,
    required Size targetSize,
    required double tilt,
    required Rect bounds,
    required int targetLayers,
    required int targetCapacity,
  }) {
    final centreX = targetTopLeft.dx + targetSize.width / 2;
    final sourceCentreX = sourceTopLeft.dx + sourceSize.width / 2;
    final sign = _pickLean(centreX, sourceCentreX, sourceSize.width, bounds);
    final angle = sign * tilt.abs();

    // The rim of the tube being filled, not the top of its box: a bottle that
    // hovers a tube-height above the glass pours from off the board.
    final rimY = targetTopLeft.dy + _rimCentre(targetSize);
    final mouth = Offset(centreX, rimY - targetSize.height * _clearance);

    // The tube rotates around the top-centre of its box, and the lip of the
    // neck that actually pours is a point on the rim. Tipping over moves that
    // point, so the hover has to hand back exactly what the tilt took away.
    final rimPoint = Offset(
      sign * sourceSize.width * _neckHalfOverWidth,
      _rimCentre(sourceSize),
    );
    final spout = _rotate(rimPoint, angle);

    return PourGeometry._(
      tilt: angle,
      hoverOffset:
          mouth - spout - (sourceTopLeft + Offset(sourceSize.width / 2, 0)),
      mouth: mouth,
      landing: Offset(
        centreX,
        targetTopLeft.dy + _liquidSurface(targetSize, targetLayers, targetCapacity),
      ),
    );
  }

  /// Which way to tip the bottle. Positive means the body trails to the left
  /// and the lip points right, which is the natural lean when the target sits
  /// to the right of the source.
  static double _pickLean(
    double targetCentreX,
    double sourceCentreX,
    double sourceWidth,
    Rect bounds,
  ) {
    // Directly above the target, the lean says nothing about the pour, so it
    // might as well keep the bottle's body on screen.
    if ((targetCentreX - sourceCentreX).abs() < sourceWidth * 0.5) {
      final midX = (bounds.left + bounds.right) / 2;
      return targetCentreX >= midX ? 1.0 : -1.0;
    }
    return targetCentreX >= sourceCentreX ? 1.0 : -1.0;
  }

  static Offset _rotate(Offset point, double angle) {
    final cosine = math.cos(angle);
    final sine = math.sin(angle);
    return Offset(
      point.dx * cosine - point.dy * sine,
      point.dx * sine + point.dy * cosine,
    );
  }
}
