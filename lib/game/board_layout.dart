import 'dart:math';
import 'dart:ui' show Size;

/// The grid the bottles sit in, in unscaled units. A bottle renders at these
/// dimensions times the layout's scale, and the rows and columns are separated
/// by these gaps.
const double kTubeSlotWidth = 55;
const double kTubeSlotHeight = 160;
const double kTubeGap = 24;
const double kRowGap = 40;

/// The furniture the board has to leave room for: the bar across the top, and
/// the power-up strip below it with the badge that hangs over it.
const double kTopBarHeight = 100;
const double kToolsReserve = 40 + 56 + 16;

/// Air between the last row and the strip. Without it the bottles stop exactly
/// where the buttons start, which reads as an overlap even when nothing is
/// actually painted twice.
const double kBoardGutter = 16;

/// The page margin either side of the board.
const double kBoardMargin = 32;

/// The patch of screen a board may cover, and nothing in the app may push it.
Size boardViewport(Size screen) => Size(
      screen.width - kBoardMargin,
      screen.height - kTopBarHeight - kToolsReserve - kBoardGutter,
    );

/// How many bottles fit in a row, the scale that makes the whole grid fit the
/// screen between the top bar and the power-up strip, and the width to hand the
/// `Wrap` so it lays out exactly that shape.
///
/// A `Wrap` only knows its row count once the scale is known, and the scale
/// depends on the row count, so the grid shape is decided here and the `Wrap`
/// is then given a box to lay that shape into.
///
/// Every shape is tried and the one that needs the least shrinking wins. The
/// guess this replaces fixed a row width by bottle count, and a fuller board
/// then needed a smaller scale than the legibility floor allows - which is how a
/// bottle bought with coins ended up painted behind the power-ups.
({int columns, double scale, double rowWidth}) resolveBoardLayout(
  int tubeCount,
  Size screen,
) {
  final viewport = boardViewport(screen);
  // A phone never gets more than life size; a tablet can, because its points
  // are further apart to begin with.
  final tallest = screen.width > 600 ? 1.3 : 1.1;
  // `Wrap` sums its children one at a time, so a row exactly as wide as its box
  // can still break early. Half a pixel off the scale buys that back.
  final widthBudget = viewport.width - 0.5;

  var columns = 1;
  var best = 0.0;
  for (var tryColumns = 1; tryColumns <= max(1, tubeCount); tryColumns++) {
    // The controller fills its tubes a frame after the first build, so a board
    // of zero still has to answer with a grid.
    final rows = max(1, (tubeCount / tryColumns).ceil());
    final scale = min(
      widthBudget /
          (tryColumns * kTubeSlotWidth + (tryColumns - 1) * kTubeGap),
      viewport.height / (rows * kTubeSlotHeight + (rows - 1) * kRowGap),
    );
    // Ascending with a strict comparison, so of the shapes that tie the
    // narrowest row wins and 9 bottles stay a 3 x 3 board.
    if (scale > best) {
      best = scale;
      columns = tryColumns;
    }
  }
  final scale = best.clamp(0.5, tallest);
  final gridWidth =
      columns * kTubeSlotWidth * scale + (columns - 1) * kTubeGap * scale;
  return (
    columns: columns,
    scale: scale,
    // The slack from the budget, never wider than the page.
    rowWidth: min(viewport.width, gridWidth + 0.5),
  );
}
