import 'dart:math' show Random;
import 'dart:ui' show Color;

import '../content/content_types.dart';
import '../models/tube_model.dart';

/// A board in the spelling the content set uses: colour ids, layer by layer.
///
/// The dealer works in ids rather than in painted colours so the same code can
/// write a level file and build a board from one, and so a board can be read
/// back off disk without any generator at all.
class DealtBoard {
  const DealtBoard({
    required this.colors,
    required this.tubes,
    required this.hidden,
  });

  /// The colours in play, each sitting on the board `capacity` times.
  final List<String> colors;
  final List<List<String>> tubes;

  /// How many layers of each bottle start face down.
  final List<int> hidden;

  List<Tube> toTubes({
    required int capacity,
    required Color Function(String id) resolve,
  }) => [
    for (var i = 0; i < tubes.length; i++)
      Tube(
        capacity: capacity,
        initialColors: [for (final id in tubes[i]) resolve(id)],
        hiddenCount: i < hidden.length ? hidden[i] : 0,
      ),
  ];
}

/// Deals water-sort boards.
///
/// A board is built by undoing legal pours from a solved one, which is what
/// makes it winnable without a search having to prove it. The same scramble is
/// what `tools/content` writes into a level pack, so an authored board and a
/// procedural one are the same kind of object with the same texture.
class LevelDealer {
  /// How many layers of one colour sit on top of a bottle, which is how many a
  /// single pour takes.
  static int topRunLength<T>(List<T> tube) {
    if (tube.isEmpty) return 0;
    final top = tube.last;
    var run = 0;
    for (var i = tube.length - 1; i >= 0 && tube[i] == top; i--) {
      run++;
    }
    return run;
  }

  /// Colours this board will use, drawn from the palette without repeats.
  static List<String> coloursFor(
    int count,
    List<String> palette,
    Random random,
  ) {
    final shuffled = List<String>.from(palette)..shuffle(random);
    return shuffled.take(count).toList();
  }

  /// A scrambled board of [spec]'s making, or the last candidate if none of the
  /// six dealt ones met the texture target.
  static DealtBoard deal({
    required LevelConfigSpec spec,
    required List<String> palette,
    required Random random,
  }) {
    final colors = coloursFor(spec.colorCount, palette, random);
    List<List<String>> board = const [];
    var poured = 0;

    for (var attempt = 0; attempt < 6; attempt++) {
      board = [
        // Growable, because the scramble lifts layers out of a bottle and the
        // fixed-length list `filled` hands back cannot give one up.
        for (final color in colors)
          List<String>.filled(spec.capacity, color, growable: true),
        for (var i = 0; i < spec.freeTubes; i++) <String>[],
      ];

      poured = 0;
      for (var move = 0; move < spec.mixRounds; move++) {
        if (mixMove(board, random, spec.capacity)) poured++;
      }

      if (poured >= spec.colorCount &&
          board.any(_hasMixedColors) &&
          board.every((tube) => !_isComplete(tube, spec.capacity)) &&
          !_isAlreadySolved(board, spec.capacity)) {
        return DealtBoard(
          colors: colors,
          tubes: board,
          hidden: _hideLayers(board, spec, random),
        );
      }
    }

    return DealtBoard(
      colors: colors,
      tubes: board,
      hidden: _hideLayers(board, spec, random),
    );
  }

  /// A deal is sound if every colour sits on the board in one whole segment and
  /// no bottle overflowed. Cheap enough to run in debug on every board.
  static bool dealsWholeSegments(DealtBoard board, LevelConfigSpec spec) {
    final counts = <String, int>{};
    for (final tube in board.tubes) {
      if (tube.length > spec.capacity) return false;
      for (final color in tube) {
        counts[color] = (counts[color] ?? 0) + 1;
      }
    }
    return counts.length == spec.colorCount &&
        counts.values.every((count) => count == spec.capacity);
  }

  /// Which bottles start face down. Only bottles that already hold several
  /// layers are worth hiding, and a free workspace bottle must stay readable or
  /// the board becomes a guess.
  static List<int> _hideLayers(
    List<List<String>> board,
    LevelConfigSpec spec,
    Random random,
  ) {
    final hidden = List<int>.filled(board.length, 0);
    if (spec.mysteryTubes == 0) return hidden;
    final candidates = <int>[];
    for (var i = 0; i < board.length; i++) {
      if (board[i].length >= 3) candidates.add(i);
    }
    candidates.shuffle(random);
    for (final index in candidates.take(spec.mysteryTubes)) {
      hidden[index] = board[index].length - 1;
    }
    return hidden;
  }

  /// How many bottles a player can empty in one pour.
  static int _chunkyCount<T>(List<List<T>> board) {
    var chunky = 0;
    for (final tube in board) {
      if (topRunLength(tube) >= 2) chunky++;
    }
    return chunky;
  }

  /// The texture a dealt board should end up with.
  ///
  /// A top run of one means a pour is a single tick of animation and a single
  /// layer of thought, and a board made of nothing but those is pure shuffling.
  /// About a third of the bottles holding two or more is how the good manual
  /// levels feel; past that the colours sit in piles big enough to announce the
  /// solution.
  static int _chunkTarget<T>(List<List<T>> board) {
    final filled = board.where((tube) => tube.isNotEmpty).length;
    return (filled ~/ 3) < 1 ? 1 : filled ~/ 3;
  }

  static int _textureGap<T>(List<List<T>> board) =>
      (_chunkyCount(board) - _chunkTarget(board)).abs();

  /// One step of the reverse scramble. Every move here is the exact undo of a
  /// legal pour, which is what keeps the resulting board winnable.
  ///
  /// A move that takes the board further from the texture target is thrown back.
  /// The scramble can only pour from bottles that have a run on top, so left to
  /// itself it grinds every run down to a single layer, and that is what made
  /// one tick long.
  ///
  /// It works over any layer type: the dealer scrambles colour ids, and the
  /// controller scrambles the colours already on the board it is playing.
  static bool mixMove<T>(
    List<List<T>> board,
    Random random,
    int capacity,
  ) {
    final sources = <int>[];
    for (var index = 0; index < board.length; index++) {
      final tube = board[index];
      if (tube.isEmpty) continue;
      final run = topRunLength(tube);
      if (tube.length == run || run > 1) sources.add(index);
    }
    if (sources.isEmpty) return false;

    sources.shuffle(random);
    for (final sourceIndex in sources) {
      final source = board[sourceIndex];
      final run = topRunLength(source);
      final maxTransfer = source.length == run ? run : run - 1;

      final targets = _targets(board, sourceIndex, maxTransfer, capacity);
      if (targets.isEmpty) continue;

      final targetIndex = targets[random.nextInt(targets.length)];
      final target = board[targetIndex];
      final room = capacity - target.length;
      // Half the moves give up the whole run they are allowed to move, so a
      // chunk lands somewhere instead of being shaved one layer at a time.
      final wanted = random.nextBool()
          ? maxTransfer
          : 1 + random.nextInt(maxTransfer);
      final amount = room < wanted ? room : wanted;

      final gapBefore = _textureGap(board);
      final color = source.removeLast();
      for (var i = 1; i < amount; i++) {
        source.removeLast();
      }

      for (var i = 0; i < amount; i++) {
        target.add(color);
      }

      // A whole colour gathered into one bottle is not a scramble step, it is
      // the answer already sitting on the board, so the move that parks it
      // there is thrown back along with the ones that ruin the texture.
      if (_isComplete(target, capacity) || _textureGap(board) > gapBefore) {
        for (var i = 0; i < amount; i++) {
          source.add(target.removeLast());
        }
        return false;
      }
      return true;
    }
    return false;
  }

  /// Bottles a reverse pour may land in.
  ///
  /// A fresh chunk has to sit on a different colour, or the two runs would merge
  /// and the greedy forward pour could not put them back apart. When the move is
  /// meant to relocate a whole run, a bottle with room for all of it is worth
  /// more than one that only takes a bite.
  static List<int> _targets<T>(
    List<List<T>> board,
    int sourceIndex,
    int maxTransfer,
    int capacity,
  ) {
    final color = board[sourceIndex].isEmpty ? null : board[sourceIndex].last;
    final any = <int>[];
    final roomy = <int>[];
    for (var index = 0; index < board.length; index++) {
      if (index == sourceIndex) continue;
      final tube = board[index];
      if (tube.length >= capacity) continue;
      if (tube.isNotEmpty && tube.last == color) continue;
      any.add(index);
      if (capacity - tube.length >= maxTransfer) roomy.add(index);
    }
    return roomy.isNotEmpty ? roomy : any;
  }

  static bool _hasMixedColors<T>(List<T> tube) =>
      tube.isNotEmpty && tube.any((color) => color != tube.first);

  static bool _isComplete<T>(List<T> tube, int capacity) =>
      tube.length == capacity && tube.every((color) => color == tube.first);

  static bool _isAlreadySolved(List<List<String>> board, int capacity) {
    for (final tube in board) {
      if (tube.isEmpty) continue;
      if (tube.length != capacity) return false;
      if (tube.any((color) => color != tube.first)) return false;
    }
    return true;
  }
}
