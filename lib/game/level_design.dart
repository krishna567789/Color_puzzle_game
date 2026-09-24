import 'dart:math' as math;

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

/// The difficulty curve.
///
/// A level number maps to exactly one recipe, so L1..L999 stay interesting
/// after the colour count saturates: the tube count stops growing and free
/// space, capacity and entangling take over as the pressure.
class LevelDesign {
  static const int levelsPerChapter = 20;
  static const int maxColorCount = 12;
  static const int minFreeTubes = 2;

  static LevelConfig forLevel(int level) {
    final clamped = math.max(1, level);

    // 3 colours at L1, one more every 6 levels, capped at 12 around L54.
    final colorCount = math.min(2 + (clamped + 5) ~/ 6, maxColorCount);

    // Onboarding boards get an extra workspace tube; it is taken away once the
    // player is expected to plan several moves ahead.
    final freeTubes = colorCount <= 6 ? 3 : minFreeTubes;

    final capacity = clamped >= 70 ? 5 : 4;

    // First hidden tube at L16, three from L46 but never before L16.
    final mysteryTubes = ((clamped - 10) ~/ 12).clamp(0, 3);

    // Enough rounds to fully entangle the board, not a raw level multiplier —
    // past L16 a level-number term only adds wasted work, not difficulty.
    final mixRounds = colorCount * (capacity + 2) + clamped ~/ 10;

    return LevelConfig(
      level: clamped,
      colorCount: colorCount,
      capacity: capacity,
      freeTubes: freeTubes,
      mysteryTubes: mysteryTubes,
      mixRounds: mixRounds,
    );
  }

  static int chapterIndex(int level) => (math.max(1, level) - 1) ~/ levelsPerChapter;

  static const List<String> _chapterNames = [
    'First Pours',
    'Mixed Signals',
    'Narrow Shelf',
    'Layered Colors',
    'Deep Tubes',
    'Mystery Row',
    'Tight Space',
    'Color Storm',
    'The Alchemist',
    'Master Bench',
  ];

  static String chapterName(int level) {
    final index = chapterIndex(level);
    final named = index < _chapterNames.length
        ? _chapterNames[index]
        : 'Chapter ${index + 1}';
    return 'Chapter ${index + 1} · $named';
  }

  static int firstLevelOfChapter(int chapterIndex) =>
      chapterIndex * levelsPerChapter + 1;

  /// Reference solution length used for star ratings and move budgets. A real
  /// solver result is preferred; this is the fallback when the search gives up.
  static int estimatedPar(LevelConfig config) =>
      config.colorCount * 2 + config.mysteryTubes;
}
