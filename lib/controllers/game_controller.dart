import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../game/level_design.dart';
import '../game/liquid_patterns.dart';
import '../game/rewards.dart';
import '../game/water_sort_solver.dart';
import '../models/tube_model.dart';
import '../core/ad_manager.dart';
import '../core/event_service.dart';
import '../core/progress_service.dart';
import '../core/storage_service.dart';
import '../core/audio_service.dart';
import '../core/cloud_save_service.dart';
import '../core/haptic_service.dart';
import '../core/review_service.dart';
import '../core/play_games_service.dart';
import '../core/analytics_service.dart';

enum GameMode { classic, challenge, timeAttack, daily }

enum PowerUp { undo, hint, shuffle, addTube }

class HintMove {
  const HintMove({required this.fromIndex, required this.toIndex});
  final int fromIndex;
  final int toIndex;
}

class GameController extends ChangeNotifier {
  static const int undoCost = 50;
  static const int hintCost = 50;
  static const int shuffleCost = 50;
  static const int extraTubeCost = 100;
  static const int extraChanceCost = 50;
  static const int maxExtraChances = 3;

  /// Ceiling for the solvability check at level start. Going higher only buys a
  /// more exact solution length on boards that are already winnable by
  /// construction, and that pause is visible on screen.
  static const int solveNodeBudget = 12000;

  /// Up to this many colours a breadth-first search answers inside the budget,
  /// so the level start can afford the proof and the exact par. Past it the
  /// search only burns the budget without ever concluding; the boards stay
  /// winnable either way, since they are built by undoing legal pours.
  static const int searchableColorCount = 9;

  /// What a power-up costs right now. The base prices are the tutorial's; a
  /// board twelve colours deep replaces far more thinking than the first one,
  /// so the same aid is worth more there.
  int costOf(PowerUp power) {
    final base = switch (power) {
      PowerUp.undo => undoCost,
      PowerUp.hint => hintCost,
      PowerUp.shuffle => shuffleCost,
      PowerUp.addTube => extraTubeCost,
    };
    return base + (designLevel ~/ 10).clamp(0, 10) * 5;
  }

  List<Tube> tubes = [];
  int? selectedTubeIndex;
  int? wrongMoveIndex;

  // Player Stats
  int coins = 0;
  int gems = 0;
  int maxUnlockedLevel = 1;
  String selectedSkinId = 'default_tube';
  String selectedThemeId = 'default_theme';

  /// Accessibility, read once with the rest of the player's settings: every
  /// layer can wear a shape as well as a hue, and the controls can sit along
  /// the left edge for one-handed use.
  bool showColorblindPatterns = false;
  bool leftHandedLayout = false;

  // Pouring animation states
  int? pouringFromIndex;
  int? pouringToIndex;
  double pourTiltAngle = 0.0;
  Offset pourOffset = Offset.zero;
  Color? pouringColor;
  bool isPouringLiquid = false;

  bool isLevelComplete = false;

  /// The tube whose last layer sorted the board, so the celebration can burst
  /// where the win landed rather than at some generic point on screen.
  int? victoryTubeIndex;
  bool isGameOver = false;
  bool hasClaimedDailyReward = false;
  int currentLevel = 1;
  int movesCount = 0;

  /// Set when no pour is left, so the game-over dialog can say that the player
  /// is stuck rather than pretending they ran out of moves.
  bool isStuck = false;

  /// Length of the shortest solution the solver proved for the current board,
  /// or an estimate when the search ran out of budget.
  int parMoves = 0;

  /// How many bottles this level needs finished - one per colour - so the HUD
  /// can count down a goal that does not move when a spare bottle is emptied.
  int tubesToSort = 0;

  /// Bottles that are full and holding a single colour.
  int get sortedTubes => tubes.where((tube) => tube.isComplete).length;

  /// Why the last tap did not pour, shown beside the shake. A bottle that
  /// refuses a move should say so rather than only wobble.
  String? moveFeedback;
  int _feedbackToken = 0;

  /// The win's grading and payout, filled in once [_awardWin] has written them
  /// to storage. The end-of-level screen shows these rather than inventing its
  /// own numbers, so a promise and a grant cannot disagree.
  int starsEarned = 0;
  int coinsEarned = 0;
  int gemsEarned = 0;

  /// False until the payout has been stored, which is what the win dialog waits
  /// for. Replaying a level cannot collect twice.
  bool winRewarded = false;
  bool _awardingWin = false;

  // Mode specific logic
  GameMode activeMode = GameMode.classic;
  int? remainingTime; // for all modes (seconds)
  int? movesLimit; // for all modes
  int extraChancesUsed = 0;

  // Powerups / Tools (Using coins now, no hard limits)
  HintMove? activeHint;

  Timer? _timer;
  bool _isDisposed = false;

  final Stopwatch _levelStopwatch = Stopwatch();

  /// How long the level that just finished took, for analytics and records.
  int lastLevelDurationSeconds = 0;

  final List<List<Tube>> _history = [];
  final List<Color> _availableColors = List<Color>.from(kLiquidPalette);

  GameController({
    GameMode mode = GameMode.classic,
    bool loadProgress = true,
    int? targetLevel,
  }) {
    activeMode = mode;
    if (targetLevel != null) {
      currentLevel = targetLevel;
    }
    if (loadProgress) {
      _loadProgress().then((_) {
        if (!_isDisposed) _initLevel();
      });
    } else {
      _initLevel();
    }
  }

  Future<void> _loadProgress() async {
    maxUnlockedLevel = await StorageService.getLevel();
    coins = await StorageService.getCoins();
    gems = await StorageService.getGems();
    selectedSkinId = await StorageService.getSelectedSkin();
    selectedThemeId = await StorageService.getSelectedTheme();
    showColorblindPatterns = await StorageService.getColorblindPatterns();
    leftHandedLayout = await StorageService.getLeftHandedLayout();
    if (activeMode == GameMode.classic) {
      // Keep currentLevel if targetLevel was passed via constructor, else use maxUnlockedLevel
      currentLevel = (currentLevel > 0) ? currentLevel : maxUnlockedLevel;
    } else {
      currentLevel = 1;
    }
    if (activeMode == GameMode.daily) {
      hasClaimedDailyReward = await StorageService.hasClaimedDailyReward(
        dailyChallengeId,
      );
    }
    _notifySafely();
  }

  void _initLevel() {
    _timer?.cancel();
    pouringFromIndex = null;
    pouringToIndex = null;
    pourTiltAngle = 0.0;
    pourOffset = Offset.zero;
    isPouringLiquid = false;
    selectedTubeIndex = null;
    wrongMoveIndex = null;
    activeHint = null;
    isLevelComplete = false;
    victoryTubeIndex = null;
    isGameOver = false;
    isStuck = false;
    movesCount = 0;
    extraChancesUsed = 0;
    remainingTime = null;
    movesLimit = null;
    starsEarned = 0;
    coinsEarned = 0;
    gemsEarned = 0;
    winRewarded = false;
    _awardingWin = false;

    _history.clear();
    _levelStopwatch
      ..reset()
      ..start();

    AnalyticsService.logLevelStart(currentLevel, activeMode.name);

    // The board has to exist first, because the move and time budgets are
    // derived from the length of its reference solution.
    _generateProceduralLevel();
    _setupModeConstraints();

    if (remainingTime != null) {
      _startTimer();
    }

    _notifySafely();
  }

  void _setupModeConstraints() {
    if (activeMode == GameMode.challenge) {
      // A small allowance over the shortest known solution, so the mode tests
      // planning rather than luck.
      movesLimit = parMoves + 6;
    } else if (activeMode == GameMode.timeAttack) {
      remainingTime = 20 + parMoves * 6;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || isLevelComplete || isGameOver) {
        timer.cancel();
        return;
      }

      remainingTime = (remainingTime ?? 0) - 1;
      if (remainingTime! <= 0) {
        remainingTime = 0;
        _handleGameOver();
        return;
      }
      _notifySafely();
    });
  }

  void _handleGameOver() {
    if (isGameOver || isLevelComplete) return;
    isGameOver = true;
    selectedTubeIndex = null;
    _timer?.cancel();
    _notifySafely();
  }

  /// Undoes the game-over state that a deadlock caused, and picks the clock back
  /// up where it stopped.
  void _reviveFromDeadlock() {
    if (!isStuck) return;
    isStuck = false;
    isGameOver = false;
    if (remainingTime != null && remainingTime! > 0) _startTimer();
  }

  /// A board is built by undoing legal pours, so it is winnable by construction.
  /// Narrow boards are still searched, which proves that independently and hands
  /// back the shortest solution the budgets and star ratings key off. Wide
  /// boards blow the node budget without ever answering, so they skip the search
  /// and estimate par from the deal rather than freezing the screen for it.
  void _generateProceduralLevel() {
    final random = Random(
      activeMode == GameMode.daily ? _dailySeed() : _levelSeed(),
    );
    final config = LevelDesign.forLevel(designLevel);
    final worthProving = config.colorCount <= searchableColorCount;

    List<Tube>? board;
    int? par;

    for (var attempt = 0; attempt < 3 && board == null; attempt++) {
      final candidate = _dealBoard(config, random);
      if (!worthProving) {
        board = candidate;
        break;
      }
      final report = WaterSortSolver.solve(
        candidate,
        nodeBudget: solveNodeBudget,
      );
      if (report.outcome == SolveOutcome.unsolvable) continue;
      board = candidate;
      par = report.pours;
    }

    // Either the first deal held up, or the search ran out of budget on a
    // board that is still winnable by construction. Neither is a reason to
    // leave the player without a level.
    tubes = board ?? _dealBoard(config, random);
    parMoves = par ?? LevelDesign.estimatedPar(config);
    // One bottle per colour is what "sorted" means here, so the goal the HUD
    // shows cannot move when the player empties a spare bottle.
    tubesToSort = config.colorCount;
    assert(_dealsWholeSegments(config), 'Malformed deal at level $designLevel');
    _hideMysterySegments(config, random);
  }

  /// Cheap stand-in for the search on wide boards, and only run in debug: a deal
  /// is sound if every colour sits on the board in one whole segment and no tube
  /// overflowed. Builds ship without it.
  bool _dealsWholeSegments(LevelConfig config) {
    final counts = <int, int>{};
    for (final tube in tubes) {
      if (tube.colors.length > tube.capacity) return false;
      for (final color in tube.colors) {
        counts[color.toARGB32()] = (counts[color.toARGB32()] ?? 0) + 1;
      }
    }
    return counts.length == config.colorCount &&
        counts.values.every((count) => count == config.capacity);
  }

  List<Tube> _dealBoard(LevelConfig config, Random random) {
    final palette = List<Color>.from(_availableColors)..shuffle(random);
    final levelColors = palette.take(config.colorCount).toList();

    List<Tube> board = const [];
    for (var attempt = 0; attempt < 6; attempt++) {
      board = [
        ...levelColors.map(
          (color) => Tube(
            capacity: config.capacity,
            initialColors: List<Color>.filled(
              config.capacity,
              color,
              growable: true,
            ),
          ),
        ),
        ...List.generate(
          config.freeTubes,
          (_) => Tube(capacity: config.capacity),
        ),
      ];

      var pouredSegments = 0;
      for (var move = 0; move < config.mixRounds; move++) {
        if (_applyReversibleMixMove(board, random)) pouredSegments++;
      }

      if (pouredSegments >= config.colorCount &&
          board.any(_hasMixedColors) &&
          !_isAlreadySolved(board)) {
        return board;
      }
    }
    return board;
  }

  void _hideMysterySegments(LevelConfig config, Random random) {
    if (config.mysteryTubes == 0) return;

    // Only tubes that already hold several layers are worth hiding, and the
    // free workspace tubes must stay readable or the board becomes a guess.
    final candidates = <int>[];
    for (var i = 0; i < tubes.length; i++) {
      if (tubes[i].colors.length >= 3) candidates.add(i);
    }
    candidates.shuffle(random);

    for (final index in candidates.take(config.mysteryTubes)) {
      tubes[index].hiddenCount = tubes[index].colors.length - 1;
    }
  }

  /// One step of the reverse scramble. Every move here is the exact undo of a
  /// legal pour, which is what keeps the resulting board winnable.
  bool _applyReversibleMixMove(List<Tube> board, Random random) {
    final sourceIndexes = <int>[];
    for (var index = 0; index < board.length; index++) {
      final tube = board[index];
      if (tube.isEmpty) continue;

      final runLength = _topColorRunLength(tube);
      if (tube.colors.length == runLength || runLength > 1) {
        sourceIndexes.add(index);
      }
    }
    if (sourceIndexes.isEmpty) return false;

    sourceIndexes.shuffle(random);
    for (final sourceIndex in sourceIndexes) {
      final source = board[sourceIndex];
      final color = source.topColor!;
      final runLength = _topColorRunLength(source);
      final maxTransfer = source.colors.length == runLength
          ? runLength
          : runLength - 1;

      final targetIndexes = <int>[];
      for (var index = 0; index < board.length; index++) {
        final target = board[index];
        if (index != sourceIndex &&
            !target.isFull &&
            (target.isEmpty || target.topColor != color)) {
          targetIndexes.add(index);
        }
      }
      if (targetIndexes.isEmpty) continue;

      final target = board[targetIndexes[random.nextInt(targetIndexes.length)]];
      final amount = min(
        maxTransfer,
        min(
          target.capacity - target.colors.length,
          1 + random.nextInt(maxTransfer),
        ),
      );
      for (var count = 0; count < amount; count++) {
        target.colors.add(source.colors.removeLast());
      }
      return true;
    }
    return false;
  }

  int _topColorRunLength(Tube tube) {
    if (tube.isEmpty) return 0;
    final color = tube.topColor;
    var length = 0;
    for (
      var index = tube.colors.length - 1;
      index >= 0 && tube.colors[index] == color;
      index--
    ) {
      length++;
    }
    return length;
  }

  bool _hasMixedColors(Tube tube) {
    return tube.colors.isNotEmpty &&
        tube.colors.any((color) => color != tube.colors.first);
  }

  bool _isAlreadySolved(List<Tube> board) {
    for (var tube in board) {
      if (tube.isEmpty) continue;
      if (!tube.isFull) return false;
      Color first = tube.colors.first;
      if (tube.colors.any((c) => c != first)) return false;
    }
    return true;
  }

  /// Which point on the difficulty curve this board should sit at.
  ///
  /// Classic tracks saved progress. The side modes restart `currentLevel` at 1
  /// every session, so without this they would all play the tutorial board and
  /// never deepen.
  int get designLevel {
    switch (activeMode) {
      case GameMode.classic:
        return currentLevel;
      case GameMode.challenge:
      case GameMode.timeAttack:
        return maxUnlockedLevel + (currentLevel - 1) * 3;
      case GameMode.daily:
        // Same day, same puzzle for everyone — derived from the date seed.
        return 24 + _dailySeed() % 26;
    }
  }

  String get dailyChallengeId {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  int _dailySeed() {
    final today = DateTime.now();
    return today.year * 10000 + today.month * 100 + today.day;
  }

  /// A level number always deals the same board. Without that, restarting a
  /// level the player failed hands them a different - and possibly far easier
  /// - puzzle, and no two players can compare the same "hard level".
  int _levelSeed() => designLevel * 31 + activeMode.index * 7919;

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }

  void restartLevel() {
    _initLevel();
  }

  /// Moves the player on. Payouts and the unlock happen the moment a board is
  /// finished, in [_awardWin], so walking back to the dashboard instead of
  /// pressing Next can never cost a player what they earned.
  Future<void> nextLevel() async {
    if (activeMode != GameMode.daily) currentLevel++;
    _initLevel();
  }

  /// Grades and pays a finished board, then moves today's counters.
  ///
  /// Gems are deliberately rare: one per level, only the first time it is
  /// three-starred, which keeps them a multi-day goal rather than a spare
  /// balance. The daily challenge pays a fixed prize once a day however often
  /// the board is replayed.
  Future<void> _awardWin() async {
    if (_awardingWin || winRewarded) return;
    _awardingWin = true;
    try {
      final classic = activeMode == GameMode.classic;
      var coinsWon = 0;
      var gemsWon = 0;
      var xpWon = 0;
      var stars = LevelReward.starsFor(moves: movesCount, par: parMoves);

      if (activeMode == GameMode.daily) {
        hasClaimedDailyReward = await StorageService.claimDailyReward(
          dailyChallengeId,
        );
        if (hasClaimedDailyReward) {
          coinsWon = 100;
          gemsWon = 1;
          // Paid on the same first-claim gate as the coins, so replaying
          // today's board cannot level the player up a second time.
          xpWon = LevelReward.xpFor(stars: stars);
        }
      } else {
        final previousBest = classic
            ? await StorageService.getLevelStars(currentLevel)
            : 0;
        final reward = LevelReward.forWin(
          level: classic ? currentLevel : designLevel,
          moves: movesCount,
          par: parMoves,
          previousBestStars: previousBest,
          trackBest: classic,
          sideMode: !classic,
        );
        stars = reward.stars;
        coinsWon = reward.coins;
        gemsWon = reward.gems;
        xpWon = reward.xp;
        if (classic && reward.isNewBest) {
          await StorageService.saveLevelStars(currentLevel, reward.stars);
        }
      }

      starsEarned = stars;
      coinsEarned = coinsWon;
      gemsEarned = gemsWon;
      coins += coinsWon;
      gems += gemsWon;
      await StorageService.saveCoins(coins);
      if (gemsWon != 0) await StorageService.saveGems(gems);
      await StorageService.addPlayerXp(xpWon);
      await StorageService.incrementTotalLevelsWon();
      if (classic && currentLevel >= maxUnlockedLevel) {
        // Unlocked on the win itself, not when Next is pressed, so a player who
        // finishes a level and leaves cannot find it locked again.
        maxUnlockedLevel = currentLevel + 1;
        await StorageService.saveLevel(maxUnlockedLevel);
        await PlayGamesService.submitScore(maxUnlockedLevel);
      }
      await EventService.recordWin(stars: stars);
      await ProgressService.recordDaily({
        DailyStat.wins: 1,
        DailyStat.stars: stars,
        if (!classic) DailyStat.sideModeWins: 1,
      });
      winRewarded = true;
      // Both of these round-trip to Play Games. Neither may sit between a
      // finished board and the screen that pays for it.
      unawaited(CloudSaveService.upload());
      if (activeMode != GameMode.daily) {
        unawaited(_handleProductionIntegrations());
      }
    } finally {
      _awardingWin = false;
      _notifySafely();
    }
  }

  bool undo({bool adFunded = false}) {
    if (!_canAct) return false;
    if (_history.isEmpty) return false;
    if (!_payForPowerUp(PowerUp.undo, adFunded: adFunded)) return false;

    AnalyticsService.logPowerUpUsed('undo', adFunded: adFunded);
    tubes = _history.removeLast();
    selectedTubeIndex = null;
    activeHint = null;
    movesCount = max(0, movesCount - 1);
    _reviveFromDeadlock();
    _notifySafely();
    HapticService.mediumImpact();
    return true;
  }

  void selectTube(int index) {
    if (isLevelComplete || isGameOver || pouringFromIndex != null) return;

    activeHint = null; // Clear hint on interaction

    if (selectedTubeIndex == null) {
      if (tubes[index].isEmpty) {
        triggerWrongMove(index, reason: 'Nothing to pick up here');
        return;
      }
      selectedTubeIndex = index;
      HapticService.selectionClick();
      AudioService.playClickSfx();
      _notifySafely();
    } else {
      if (selectedTubeIndex == index) {
        selectedTubeIndex = null;
        _notifySafely();
      } else {
        _startPouring(selectedTubeIndex!, index);
      }
    }
  }

  /// Whether the bottle the player has held up would pour into [index]. The
  /// board marks the ones that answer yes, so choosing where to tap next is a
  /// decision rather than a guess that costs a shake.
  bool acceptsFromSelected(int index) {
    final from = selectedTubeIndex;
    return from != null && canPour(from, index);
  }

  /// The one line explaining a tap that looked legal and was not.
  String blockReason(int fromIndex, int toIndex) {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= tubes.length ||
        toIndex >= tubes.length) {
      return 'Pick a second bottle';
    }
    final from = tubes[fromIndex];
    final to = tubes[toIndex];
    if (from.isEmpty) return 'This bottle is empty';
    if (to.isFull) return 'That bottle is full';
    return 'The colours do not match';
  }

  bool canPour(int fromIndex, int toIndex) {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= tubes.length ||
        toIndex >= tubes.length) {
      return false;
    }

    final fromTube = tubes[fromIndex];
    final toTube = tubes[toIndex];
    return fromTube.isNotEmpty &&
        !toTube.isFull &&
        (toTube.isEmpty || toTube.topColor == fromTube.topColor);
  }

  /// Re-scrambles the board with the generator's own reversible pour, which is
  /// what keeps the level winnable afterwards. Permuting the top colours
  /// randomly, as this used to, broke the construction invariant and could hand
  /// the player a board that cannot be finished at any price.
  bool shuffleTubes({bool adFunded = false}) {
    if (!_canAct) return false;

    final config = LevelDesign.forLevel(designLevel);
    final mixRounds = max(6, config.colorCount * 2);
    final random = Random();
    final stirred = tubes.map((tube) => tube.copyWith()).toList();

    var applied = 0;
    for (var move = 0; move < mixRounds; move++) {
      if (_applyReversibleMixMove(stirred, random)) applied++;
    }
    if (applied == 0) return false;
    if (!_payForPowerUp(PowerUp.shuffle, adFunded: adFunded)) return false;

    AnalyticsService.logPowerUpUsed('shuffle', adFunded: adFunded);
    _history.add(tubes.map((tube) => tube.copyWith()).toList());
    tubes = stirred;
    selectedTubeIndex = null;
    activeHint = null;
    _reviveFromDeadlock();
    // A stir's inverse is always a legal pour, so the board cannot end up
    // dead; it can, however, land on the last few segments of a solve.
    _checkWinCondition();
    AudioService.playPourSfx();
    _notifySafely();
    return true;
  }

  bool addExtraTube({bool adFunded = false}) {
    if (!_canAct) return false;
    if (!_payForPowerUp(PowerUp.addTube, adFunded: adFunded)) return false;

    AnalyticsService.logPowerUpUsed('add_tube', adFunded: adFunded);
    // Same capacity as the rest of the board: a short tube on a five-layer
    // level cannot hold a colour to itself, so it is workspace that does not
    // work.
    tubes.add(Tube(capacity: tubes.isEmpty ? 4 : tubes.first.capacity));

    AudioService.playPourSfx();
    _notifySafely();
    return true;
  }

  bool useExtraChance(bool isTime, {bool isAd = false}) {
    // Deliberately does not reject `isGameOver`: this is the revive action.
    if (isLevelComplete || pouringFromIndex != null) return false;
    if (extraChancesUsed >= maxExtraChances) return false;
    if (!isAd && !_spendCoins(extraChanceCost)) return false;

    extraChancesUsed++;
    isGameOver = false;
    AnalyticsService.logPowerUpUsed(
      isTime ? 'extra_time' : 'extra_moves',
      adFunded: isAd,
    );

    if (isTime) {
      remainingTime = (remainingTime ?? 0) + 30;
      _startTimer();
    } else {
      movesLimit = (movesLimit ?? 0) + 5;
    }
    _notifySafely();
    return true;
  }

  /// The most useful pour available right now.
  ///
  /// Returning the first legal one would charge a player for a move that undoes
  /// their own progress, so each pour is scored by how much it actually
  /// accomplishes. It still answers whenever any legal pour exists, because a
  /// null result is read as a dead board by the move bookkeeping.
  HintMove? findHintMove() {
    HintMove? best;
    var bestScore = 0;

    for (var fromIndex = 0; fromIndex < tubes.length; fromIndex++) {
      final source = tubes[fromIndex];
      if (source.isEmpty || source.isComplete) continue;
      final run = _topRun(source);

      for (var toIndex = 0; toIndex < tubes.length; toIndex++) {
        if (toIndex == fromIndex || !canPour(fromIndex, toIndex)) continue;
        final target = tubes[toIndex];
        final moved = min(run, target.capacity - target.colors.length);
        final score = target.isEmpty
            // Only a whole tube moving into a spare frees something; a partial
            // one just relocates the problem.
            ? (source.colors.length == run ? 30 : 2)
            // Merging same-coloured layers is progress, and finishing a tube is
            // the best move on the board.
            : 10 +
                  moved * 2 +
                  (target.colors.length + moved == target.capacity &&
                          target.colors.every((c) => c == source.topColor)
                      ? 50
                      : 0);

        if (score > bestScore) {
          bestScore = score;
          best = HintMove(fromIndex: fromIndex, toIndex: toIndex);
        }
      }
    }
    return best;
  }

  /// How many top segments of a tube share the colour that would pour next.
  int _topRun(Tube tube) {
    final color = tube.topColor;
    var run = 0;
    for (
      var i = tube.colors.length - 1;
      i >= 0 && tube.colors[i] == color;
      i--
    ) {
      run++;
    }
    return run;
  }

  bool requestHint({bool adFunded = false}) {
    if (!_canAct) return false;
    final move = findHintMove();
    if (move == null) return false;
    if (!_payForPowerUp(PowerUp.hint, adFunded: adFunded)) return false;

    AnalyticsService.logPowerUpUsed('hint', adFunded: adFunded);
    activeHint = move;
    _notifySafely();
    return true;
  }

  /// Takes payment for a power-up that has already been shown to apply. An
  /// ad-funded use costs no coins but still counts as using the tool, which is
  /// what the daily quest for power-ups is really measuring.
  bool _payForPowerUp(PowerUp power, {required bool adFunded}) {
    if (!adFunded && !_spendCoins(costOf(power))) return false;
    unawaited(ProgressService.recordDaily({DailyStat.powerUps: 1}));
    return true;
  }

  /// Whether a power-up can currently take effect, so a rewarded ad is never
  /// shown for a move that would be rejected.
  bool canUsePowerUp(PowerUp power) {
    if (!_canAct) return false;
    switch (power) {
      case PowerUp.undo:
        return _history.isNotEmpty;
      case PowerUp.hint:
        return findHintMove() != null;
      case PowerUp.shuffle:
        // Probed on a copy, because a stir both needs and changes the board.
        return _applyReversibleMixMove(
          tubes.map((t) => t.copyWith()).toList(),
          Random(),
        );
      case PowerUp.addTube:
        return true;
    }
  }

  /// Being out of moves ends the level, but a deadlock is still recoverable —
  /// rewinding or re-scrambling is exactly what the player should reach for.
  bool get _canAct {
    if (isLevelComplete || pouringFromIndex != null) return false;
    return !isGameOver || isStuck;
  }

  void _afterMoveBookkeeping({int? winnerIndex}) {
    _checkWinCondition(winnerIndex: winnerIndex);
    if (isLevelComplete) {
      _timer?.cancel();
      return;
    }
    isStuck = findHintMove() == null;
    final outOfMoves = movesLimit != null && movesCount >= movesLimit!;
    if (isStuck || outOfMoves) {
      _timer?.cancel();
      _handleGameOver();
    }
  }

  /// Deducts a price, returning false when the player cannot pay. Never lets
  /// the balance go negative and never charges for a move that is not applied.
  bool _spendCoins(int amount) {
    if (coins < amount) return false;
    coins -= amount;
    StorageService.saveCoins(coins);
    return true;
  }

  Future<void> _startPouring(int fromIndex, int toIndex) async {
    if (isGameOver || (movesLimit != null && movesCount >= movesLimit!)) {
      triggerWrongMove(fromIndex, reason: 'No moves left');
      return;
    }

    if (!canPour(fromIndex, toIndex)) {
      triggerWrongMove(toIndex, reason: blockReason(fromIndex, toIndex));
      selectedTubeIndex = null;
      _notifySafely();
      return;
    }

    Tube fromTube = tubes[fromIndex];
    Tube toTube = tubes[toIndex];
    // A move that worked ends the conversation about the one that did not.
    moveFeedback = null;
    _feedbackToken++;

    _history.add(tubes.map((t) => t.copyWith()).toList());
    movesCount++;

    pouringFromIndex = fromIndex;
    pouringToIndex = toIndex;
    pouringColor = fromTube.topColor;
    selectedTubeIndex = null;

    // Dead level: the bottle rotates around its own neck, so anything past
    // horizontal lifts the body up and off the top of the board, and anything
    // short of it lays the body across the tubes below.
    double tiltDirection = (toIndex > fromIndex) ? pi / 2 : -pi / 2;
    pourTiltAngle = tiltDirection;
    _notifySafely();

    await Future.delayed(const Duration(milliseconds: 400));

    if (_isDisposed) return;
    if (isGameOver) {
      pouringFromIndex = null;
      pouringToIndex = null;
      pourTiltAngle = 0.0;
      isPouringLiquid = false;
      _notifySafely();
      return;
    }

    isPouringLiquid = true;
    _notifySafely();

    // The gurgle runs only while liquid is actually in the air: the clip is
    // longer than a one-layer pour, so it has to be cut when the stream breaks.
    AudioService.startPourSfx();
    try {
      Color pColor = fromTube.topColor!;
      while (fromTube.colors.isNotEmpty &&
          fromTube.topColor == pColor &&
          !toTube.isFull) {
        Color removedColor = fromTube.colors.removeLast();
        toTube.colors.add(removedColor);

        // Update hidden status
        if (fromTube.colors.length <= fromTube.hiddenCount) {
          fromTube.hiddenCount = max(0, fromTube.colors.length - 1);
        }

        HapticService.lightImpact();
        _notifySafely();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      isPouringLiquid = false;
      _notifySafely();
      // The jet needs a beat to break apart before the bottle leaves, otherwise
      // the liquid is left hanging in mid air over the target tube.
      await Future.delayed(const Duration(milliseconds: 200));
    } finally {
      await AudioService.stopPourSfx();
    }

    if (_isDisposed) return;
    pourTiltAngle = 0.0;
    _notifySafely();
    await Future.delayed(const Duration(milliseconds: 400));

    if (_isDisposed) return;
    pouringFromIndex = null;
    pouringToIndex = null;

    _afterMoveBookkeeping(winnerIndex: toIndex);
    _notifySafely();
  }

  void triggerWrongMove(int index, {String? reason}) {
    wrongMoveIndex = index;
    moveFeedback = reason;
    HapticService.vibrate();
    AudioService.playErrorSfx();
    _notifySafely();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isDisposed) return;
      wrongMoveIndex = null;
      _notifySafely();
    });
    // The line stays up long enough to read, which a shake is not.
    final token = ++_feedbackToken;
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (_isDisposed || token != _feedbackToken) return;
      moveFeedback = null;
      _notifySafely();
    });
  }

  void _checkWinCondition({int? winnerIndex}) {
    bool allSorted = true;
    for (var tube in tubes) {
      if (tube.isEmpty) continue;
      if (!tube.isFull) {
        allSorted = false;
        break;
      }
      Color firstColor = tube.colors.first;
      if (tube.colors.any((color) => color != firstColor)) {
        allSorted = false;
        break;
      }
    }

    if (allSorted) {
      isLevelComplete = true;
      victoryTubeIndex = winnerIndex;
      _levelStopwatch.stop();
      lastLevelDurationSeconds = _levelStopwatch.elapsed.inSeconds;
      AudioService.playWinSfx();
      HapticService.mediumImpact();
      AnalyticsService.logLevelComplete(
        currentLevel,
        movesCount,
        lastLevelDurationSeconds,
      );
      AdManager.notifyLevelCompleted();
      unawaited(_awardWin());
    }
  }

  Future<void> _handleProductionIntegrations() async {
    // 1. In-App Review
    await ReviewService.requestReviewIfEligible(currentLevel);

    // 2. Play Games achievements. The leaderboard score goes up with
    // [nextLevel], where the level reached has actually changed.
    if (!PlayGamesService.isSignedIn) return;
    if (currentLevel >= 1) {
      await PlayGamesService.unlockAchievement(
        PlayGamesService.achievementBeginnerId,
      );
    }
    if (currentLevel >= 10) {
      await PlayGamesService.unlockAchievement(
        PlayGamesService.achievementMasterId,
      );
    }
    if (currentLevel >= 100) {
      await PlayGamesService.unlockAchievement(
        PlayGamesService.achievementHundredId,
      );
    }
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }
}
