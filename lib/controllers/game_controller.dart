import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../content/content_repository.dart';
import '../content/content_types.dart';
import '../game/level_dealer.dart';
import '../game/level_design.dart';
import '../game/rewards.dart';
import '../game/water_sort_solver.dart';
import '../models/tube_model.dart';
import '../core/ad_manager.dart';
import '../core/achievement_service.dart';
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
  /// A power-up's shelf price, before this level's inflation is added. A HUD
  /// can quote these before a board exists.
  static int get undoCost => _baseCost('undo');
  static int get hintCost => _baseCost('hint');
  static int get shuffleCost => _baseCost('shuffle');
  static int get extraTubeCost => _baseCost('addTube');
  static int get extraChanceCost =>
      ContentRepository.content.rewards.extraChanceCost;
  static int get maxExtraChances =>
      ContentRepository.content.rewards.maxExtraChances;

  static int _baseCost(String key) =>
      ContentRepository.content.rewards.costOf(key, 0);

  /// The most bottles a board can ever carry, from `levels/curve.json`. A dealt
  /// board stops well under it; the room above is what the add-tube power-up
  /// sells, and past it the grid is more bottles than a phone can show.
  static int get maxBoardTubes =>
      ContentRepository.content.curve.maxBoardTubes;

  /// True once the board has as many bottles as the content contract allows.
  bool get isAtTubeCeiling => tubes.length >= maxBoardTubes;

  /// Ceiling for the solvability check at level start. Going higher only buys a
  /// more exact solution length on boards that are already winnable by
  /// construction, and that pause is visible on screen.
  static const int solveNodeBudget = 12000;

  /// Up to this many colours a breadth-first search answers inside the budget,
  /// so the level start can afford the proof and the exact par. Past it the
  /// search only burns the budget without ever concluding; the boards stay
  /// winnable either way, since they are built by undoing legal pours.
  static const int searchableColorCount = 9;

  /// What a power-up costs on this board. The base prices are the tutorial's;
  /// a board twelve colours deep replaces far more thinking than the first one,
  /// so the same aid is worth more there.
  int costOf(PowerUp power) {
    final key = switch (power) {
      PowerUp.undo => 'undo',
      PowerUp.hint => 'hint',
      PowerUp.shuffle => 'shuffle',
      PowerUp.addTube => 'addTube',
    };
    return ContentRepository.content.rewards.costOf(key, designLevel);
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

  /// Whether today's daily prize was already spent when this board was dealt.
  bool hasClaimedDailyReward = false;

  /// Set by a daily win that found the prize gone. The card says so instead of
  /// paying out a pair of zeroes, which a player reads as a broken reward.
  bool dailyPrizeAlreadyClaimed = false;
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

  /// Set when the board just cleared was the last one of a chapter, with what
  /// that chapter pays. The reward itself is already in the wallet and folded
  /// into [coinsEarned] and [gemsEarned]; this only says why the number is
  /// bigger than a normal win.
  ({String name, int coins, int gems})? chapterReward;

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

  GameController({
    GameMode mode = GameMode.classic,
    bool loadProgress = true,
    int? targetLevel,
  }) {
    activeMode = mode;
    if (targetLevel != null) {
      // On a mode's ladder a requested stage is a request, not a fact: a save
      // or a link written against a longer ladder can ask for a stage that no
      // longer exists, and that plays the last one it has.
      currentLevel = _requestedStage = _ladderId == null
          ? targetLevel
          : _clampStage(targetLevel);
    }
    if (loadProgress) {
      _loadProgress().then((_) {
        if (!_isDisposed) _initLevel();
      });
    } else {
      _initLevel();
    }
  }

  /// The stage the caller asked for, if any. A side mode opens here when the
  /// player taps a node on its map; otherwise it opens where its own ladder
  /// says they got to.
  int? _requestedStage;

  /// Which mode's ladder this run is playing, or null for a mode that has none.
  /// These are the ids content names in `assets/content/modes.json`.
  String? get _ladderId => switch (activeMode) {
    GameMode.challenge => 'challenge',
    GameMode.timeAttack => 'timeAttack',
    GameMode.classic => null,
    GameMode.daily => null,
  };

  /// How many stages this mode's ladder has, or 0 for a mode that has none.
  int get stageCount => _ladderId == null
      ? 0
      : ContentRepository.content.stageCountOf(_ladderId!);

  /// Keeps a stage request inside the ladder, so a save written against a
  /// longer ladder cannot ask for a board that does not exist.
  int _clampStage(int stage) {
    final last = stageCount;
    return last == 0 ? 1 : stage.clamp(1, last);
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
      // A node tapped on the map wins over the saved frontier; opening the
      // campaign with no request resumes it where it stopped.
      currentLevel = _requestedStage ?? maxUnlockedLevel;
    } else if (_ladderId != null) {
      // A side mode counts stages on its own ladder, and that ladder is what
      // remembers how far the player got, so reopening Challenge returns to
      // where they left it instead of to stage 1 - and a tap on a map node goes
      // to that node.
      currentLevel = _clampStage(
        _requestedStage ?? await StorageService.getModeProgress(_ladderId!),
      );
    } else {
      currentLevel = 1;
    }
    if (activeMode == GameMode.daily) {
      hasClaimedDailyReward = await StorageService.hasClaimedDailyReward(
        StorageService.todayKey,
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
    chapterReward = null;
    dailyPrizeAlreadyClaimed = false;
    _awardingWin = false;

    _history.clear();
    _levelStopwatch
      ..reset()
      ..start();

    AnalyticsService.logLevelStart(currentLevel, activeMode.name);

    // The board has to exist first, because the move and time budgets are
    // derived from the length of its reference solution.
    _buildLevel();
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

  /// Puts a board on screen.
  ///
  /// A level the content set authored is dealt out exactly as written, so every
  /// player meets the same first boards and a designer can read a board off the
  /// JSON. Past the authored packs the curve takes over and a board is built by
  /// undoing legal pours, which makes it winnable by construction. Narrow
  /// boards are searched as well, which proves that independently and hands back
  /// the shortest solution the budgets and star ratings key off. Wide boards
  /// blow the node budget without ever answering, so they skip the search and
  /// estimate par from the deal rather than freezing the screen for it.
  void _buildLevel() {
    final content = ContentRepository.content;
    final authored = activeMode == GameMode.classic
        ? content.levelFor(designLevel)
        : null;
    if (authored != null) {
      _useAuthoredBoard(authored);
      return;
    }

    final spec = LevelDesign.specFor(designLevel);
    final random = Random(
      activeMode == GameMode.daily ? _dailySeed() : _levelSeed(),
    );
    final worthProving = spec.colorCount <= searchableColorCount;

    var dealt = LevelDealer.deal(
      spec: spec,
      palette: content.paletteIds,
      random: random,
    );
    var board = _boardOf(dealt, spec.capacity);
    int? proved;
    for (var attempt = 0; attempt < 3; attempt++) {
      dealt = LevelDealer.deal(
        spec: spec,
        palette: content.paletteIds,
        random: random,
      );
      board = _boardOf(dealt, spec.capacity);
      if (!worthProving) break;
      final report = WaterSortSolver.solve(
        board,
        nodeBudget: solveNodeBudget,
      );
      if (report.outcome != SolveOutcome.unsolvable) {
        proved = report.pours;
        break;
      }
    }

    tubes = board;
    // Either the first deal held up, or the search ran out of budget on a board
    // that is still winnable by construction. Neither is a reason to leave the
    // player without a level.
    parMoves =
        proved ?? LevelDesign.estimatedPar(spec.toConfig(designLevel));
    tubesToSort = spec.colorCount;
    assert(
      LevelDealer.dealsWholeSegments(dealt, spec),
      'Malformed deal at level $designLevel',
    );
  }

  /// A board the content set wrote, with the par its generator proved.
  void _useAuthoredBoard(LevelSpec spec) {
    final content = ContentRepository.content;
    tubes = [
      for (var i = 0; i < spec.tubes.length; i++)
        Tube(
          capacity: spec.capacity,
          initialColors: [for (final id in spec.tubes[i]) content.colorById(id)],
          hiddenCount: i < spec.hidden.length ? spec.hidden[i] : 0,
        ),
    ];
    parMoves = spec.parMoves;
    tubesToSort = spec.colors.length;
  }

  List<Tube> _boardOf(DealtBoard dealt, int capacity) => dealt.toTubes(
    capacity: capacity,
    resolve: ContentRepository.content.colorById,
  );

  /// Which point on the difficulty curve this board should sit at.
  ///
  /// Classic tracks saved progress. A side mode asks its own ladder, so the
  /// stage a player is on says the same thing on every device and has nothing
  /// to do with how far the campaign got.
  int get designLevel {
    switch (activeMode) {
      case GameMode.classic:
        return currentLevel;
      case GameMode.challenge:
      case GameMode.timeAttack:
        // The fallback only answers for a build whose content set never loaded,
        // which is a build bug rather than a state a player can reach; a stage
        // still has to deal something, and it still has to climb.
        return ContentRepository.content.stageAnchor(
              _ladderId!,
              currentLevel,
            ) ??
            currentLevel * 4;
      case GameMode.daily:
        // Same day, same puzzle for everyone — derived from the date seed.
        return 24 + _dailySeed() % 26;
    }
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

  /// Whether pressing Next has a stage to take the player to.
  ///
  /// A ladder ends. Offering Next on a mode's last stage would deal the same
  /// board again and pay nothing for it, which reads as a broken button rather
  /// than a finished mode, so the win screen drops it instead.
  bool get hasNextStage {
    if (activeMode == GameMode.daily) return false;
    final last = stageCount;
    return last == 0 || currentLevel < last;
  }

  /// What the win card counts. A mode's ladder and the daily board are not
  /// campaign levels, and a card reading "LEVEL 1" under the fourth stage of a
  /// Challenge run tells the player the wrong thing.
  String get winRibbon => switch (activeMode) {
    GameMode.classic => 'LEVEL $currentLevel',
    GameMode.challenge => 'STAGE $currentLevel',
    GameMode.timeAttack => 'STAGE $currentLevel',
    GameMode.daily => 'DAILY PUZZLE',
  };

  /// Moves the player on. Payouts and the unlock happen the moment a board is
  /// finished, in [_awardWin], so walking back to the dashboard instead of
  /// pressing Next can never cost a player what they earned.
  Future<void> nextLevel() async {
    if (hasNextStage) currentLevel++;
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
        final today = StorageService.todayKey;
        hasClaimedDailyReward = await StorageService.claimDailyReward(today);
        dailyPrizeAlreadyClaimed = !hasClaimedDailyReward;
        if (hasClaimedDailyReward) {
          coinsWon = 100;
          gemsWon = 1;
          // Paid on the same first-claim gate as the coins, so replaying
          // today's board cannot level the player up a second time.
          xpWon = LevelReward.xpFor(stars: stars);
        }
      } else {
        // Both ladders keep a best rating per step, so a first three-star pays
        // its gem once on a Challenge stage exactly as it does on a campaign
        // level, and replaying a stage you already beat pays nothing extra.
        final ladder = _ladderId;
        final previousBest = classic
            ? await StorageService.getLevelStars(currentLevel)
            : await StorageService.getModeStars(ladder!, currentLevel);
        final reward = LevelReward.forWin(
          level: classic ? currentLevel : designLevel,
          moves: movesCount,
          par: parMoves,
          previousBestStars: previousBest,
          sideMode: !classic,
        );
        stars = reward.stars;
        coinsWon = reward.coins;
        gemsWon = reward.gems;
        xpWon = reward.xp;
        if (reward.isNewBest) {
          if (classic) {
            await StorageService.saveLevelStars(currentLevel, reward.stars);
          } else {
            await StorageService.saveModeStars(
              ladder!,
              currentLevel,
              reward.stars,
            );
          }
        }
        if (ladder != null) {
          // The ladder opens one stage further, forward only, so a stage can
          // never be locked again by losing the one after it.
          await StorageService.raiseModeProgress(ladder, currentLevel + 1);
        }
        if (classic) {
          // A chapter pays its purse on the board that closes it, through the
          // same first-time gate as everything else here, so replaying that
          // board cannot collect it twice.
          final bonus = await _chapterBonusFor(currentLevel);
          if (bonus != null) {
            coinsWon += bonus.coins;
            gemsWon += bonus.gems;
            chapterReward = bonus;
          }
        }
      }

      starsEarned = stars;
      coinsEarned = coinsWon;
      gemsEarned = gemsWon;
      // The balance moves inside storage. This copy is only what this screen
      // believes, and a quest claimed from another screen may have changed the
      // real number while this win was being tallied.
      coins = await StorageService.addCoins(coinsWon);
      if (gemsWon != 0) gems = await StorageService.addGems(gemsWon);
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
        if (stars == 3) DailyStat.threeStarWins: 1,
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

  /// What the chapter [level] belongs to pays for being closed, or null when
  /// this is not its last board, the content set has no chapter for it, or the
  /// purse has already been collected on this account.
  Future<({String name, int coins, int gems})?> _chapterBonusFor(
    int level,
  ) async {
    final content = ContentRepository.content;
    final chapter = content.chapterFor(level);
    if (chapter == null || content.lastLevelOf(chapter) != level) return null;
    if (!await StorageService.claimChapter(chapter.id)) return null;
    return (
      name: chapter.name,
      coins: chapter.rewardCoins,
      gems: chapter.rewardGems,
    );
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

    final config = LevelDesign.specFor(designLevel);
    final mixRounds = max(6, config.colorCount * 2);
    final random = Random();
    final stirred = tubes.map((tube) => tube.copyWith()).toList();
    final layers = [for (final tube in stirred) tube.colors];

    var applied = 0;
    for (var move = 0; move < mixRounds; move++) {
      if (LevelDealer.mixMove(layers, random, stirred.first.capacity)) {
        applied++;
      }
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
    // Checked before the till, not after: coins or a rewarded ad spent on a
    // bottle the board cannot take is a purchase the player has to notice.
    if (isAtTubeCeiling) return false;
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
        if (tubes.isEmpty) return false;
        final stirred = tubes.map((tube) => tube.copyWith()).toList();
        return LevelDealer.mixMove(
          [for (final tube in stirred) tube.colors],
          Random(),
          stirred.first.capacity,
        );
      case PowerUp.addTube:
        return !isAtTubeCeiling;
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
    // A delta, not the copy above: this screen's belief about the wallet is not
    // the wallet, and writing it back could erase money paid in elsewhere.
    StorageService.addCoins(-amount);
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

    // 2. Play Games achievements. Which ones exist, what unlocks each and the
    // id the SDK knows it by all come from the content set, so a goal is never
    // a number in two places. A row with no id yet is simply not mirrored.
    if (!PlayGamesService.isSignedIn) return;
    final counters = await AchievementService.readAll();
    for (final achievement in ContentRepository.content.achievements) {
      final id = achievement.playGamesId;
      if (id.isEmpty) continue;
      if (AchievementService.progressOf(counters, achievement.stat) <
          achievement.goal) {
        continue;
      }
      await PlayGamesService.unlockAchievement(id);
    }
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }
}
