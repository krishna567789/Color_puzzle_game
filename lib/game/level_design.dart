import 'dart:math' as math;

import '../content/content_repository.dart';
import '../content/content_types.dart';

/// A board recipe. Everything the generator needs, with no randomness, so the
/// difficulty curve can be reasoned about and tested on its own.
class LevelConfig {
  const LevelConfig({
    required this.level,
    required this.colorCount,
    required this.capacity,
    required this.freeTubes,
    required this.mysteryTubes,
    required this.mixRounds,
  });

  final int level;

  /// How many colours must end up sorted. The real difficulty knob.
  final int colorCount;

  /// Segments per tube. Bigger tubes mean longer pours and deeper entangling.
  final int capacity;

  /// Empty tubes the player can work with. Fewer of these is what makes late
  /// levels brutal rather than merely long.
  final int freeTubes;

  /// Tubes that start face-down. Purely cosmetic pressure, capped low because
  /// a hidden bottom segment is guesswork, not puzzle.
  final int mysteryTubes;

  /// How many reversible pours scramble the solved board.
  final int mixRounds;

  int get tubeCount => colorCount + freeTubes;

  @override
  String toString() =>
      'LevelConfig(L$level, colors: $colorCount, cap: $capacity, '
      'free: $freeTubes, mystery: $mysteryTubes, mix: $mixRounds)';
}

/// The difficulty curve, read from the shipped content set.
///
/// A level number maps to exactly one recipe, so levels past the authored packs
/// stay interesting after the colour count saturates: the tube count stops
/// growing and free space, capacity and entangling take over as the pressure.
/// Every number here lives in `assets/content/levels/curve.json`, which is why
/// a rebalance is a data change rather than a release.
class LevelDesign {
  static CurveSpec get _curve => ContentRepository.content.curve;

  static int get levelsPerChapter =>
      ContentRepository.content.levelsPerChapter;

  static int get maxColorCount => _curve.maxColorCount;

  /// The most bottles the curve ever deals to a board.
  static int get maxTubeCount => _curve.maxTubeCount;

  /// The recipe for a level, in the content set's own spelling.
  static LevelConfigSpec specFor(int level) => _curve.configFor(level);

  static LevelConfig forLevel(int level) =>
      specFor(level).toConfig(math.max(1, level));

  static int chapterIndex(int level) =>
      (math.max(1, level) - 1) ~/ levelsPerChapter;

  static String chapterName(int level) {
    final index = chapterIndex(level);
    final number = index + 1;
    final start = firstLevelOfChapter(index);
    for (final chapter in ContentRepository.content.chapters) {
      if (chapter.startsAtLevel == start) {
        return 'Chapter $number · ${chapter.name}';
      }
    }
    return 'Chapter $number';
  }

  static int firstLevelOfChapter(int chapterIndex) =>
      chapterIndex * levelsPerChapter + 1;

  /// Reference solution length used for star ratings and move budgets. A real
  /// solver result is preferred; this is the fallback when the search gives up.
  static int estimatedPar(LevelConfig config) =>
      config.colorCount * 2 + config.mysteryTubes;
}
