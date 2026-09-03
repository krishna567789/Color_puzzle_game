import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tube_model.dart';
import '../core/storage_service.dart';
import '../core/audio_service.dart';
import '../core/haptic_service.dart';
import '../core/review_service.dart';
import '../core/play_games_service.dart';
import '../core/analytics_service.dart';

enum GameMode { classic, challenge, timeAttack, daily }

class HintMove {
  const HintMove({required this.fromIndex, required this.toIndex});
  final int fromIndex;
  final int toIndex;
}

class GameController extends ChangeNotifier {
  List<Tube> tubes = [];
  int? selectedTubeIndex;
  int? wrongMoveIndex;

  // Player Stats
  int coins = 0;
  int gems = 0;
  int maxUnlockedLevel = 1;
  String selectedSkinId = 'default_tube';
  String selectedThemeId = 'default_theme';

  // Pouring animation states
  int? pouringFromIndex;
  int? pouringToIndex;
  double pourTiltAngle = 0.0;
  Offset pourOffset = Offset.zero;
  Color? pouringColor;
  bool isPouringLiquid = false;

  bool isLevelComplete = false;
  bool isGameOver = false;
  bool hasClaimedDailyReward = false;
  int currentLevel = 1;
  int movesCount = 0;

  // Mode specific logic
  GameMode activeMode = GameMode.classic;
  int? remainingTime; // for all modes (seconds)
  int? movesLimit; // for all modes
  int extraChancesUsed = 0;
  
  // Powerups / Tools (Using coins now, no hard limits)
  HintMove? activeHint;
  
  Timer? _timer;
  bool _isDisposed = false;

  final List<List<Tube>> _history = [];
  final List<Color> _availableColors = [
    const Color(0xFFFF2A2A), // Vivid Red
    const Color(0xFF1E88E5), // Vivid Blue
    const Color(0xFF2AFA2A), // Vivid Green
    const Color(0xFFFFD500), // Vivid Yellow
    const Color(0xFFFF7A00), // Vivid Orange
    const Color(0xFFA200FF), // Vivid Purple
    const Color(0xFF00E5FF), // Vivid Cyan
    const Color(0xFFFF0088), // Vivid Pink
    const Color(0xFF00FF88), // Vivid Teal
    const Color(0xFF5500FF), // Vivid Indigo
    const Color(0xFFFF4500), // Vivid Deep Orange
    const Color(0xFFA6FF00), // Vivid Lime
  ];

  GameController({GameMode mode = GameMode.classic, bool loadProgress = true, int? targetLevel}) {
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
    isGameOver = false;
    movesCount = 0;
    extraChancesUsed = 0;
    
    // Tools reset
    activeHint = null;
    
    _history.clear();
    
    AnalyticsService.logLevelStart(currentLevel, activeMode.name);

    _setupModeConstraints();
    _generateProceduralLevel();

    if (remainingTime != null) {
      _startTimer();
    }

    _notifySafely();
  }

  void _setupModeConstraints() {
    if (activeMode == GameMode.challenge) {
      remainingTime = null;
      movesLimit = 15 + (currentLevel * 2);
    } else if (activeMode == GameMode.timeAttack) {
      remainingTime = 60 + (currentLevel * 10);
      movesLimit = null;
    } else {
      remainingTime = null;
      movesLimit = null;
    }
  }

  void _startTimer() {
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

  void _generateProceduralLevel() {
    final random = activeMode == GameMode.daily
        ? Random(_dailySeed())
        : Random();

    int baseDifficulty = (currentLevel ~/ 2) + 4;
    if (activeMode == GameMode.challenge || activeMode == GameMode.timeAttack) baseDifficulty += 2;
    if (activeMode == GameMode.daily) baseDifficulty = 8;

    int numColors = min(baseDifficulty, _availableColors.length);
    int numEmptyTubes = 2;
    List<Color> levelColors = List.from(_availableColors)..shuffle(random);
    levelColors = levelColors.take(numColors).toList();
    for (var attempt = 0; attempt < 8; attempt++) {
      tubes = [
        ...levelColors.map(
          (color) =>
              Tube(initialColors: List<Color>.filled(4, color, growable: true)),
        ),
        ...List.generate(numEmptyTubes, (_) => Tube()),
      ];

      final mixMoves = min(80, numColors * 6 + currentLevel * 2);
      for (var move = 0; move < mixMoves; move++) {
        _applyReversibleMixMove(random);
      }

      if (!_isAlreadySolved() && tubes.any(_hasMixedColors)) {
        // Apply Mystery Mode logic (e.g. 1 mystery tube at lvl 4, max 3)
        if (currentLevel >= 4) {
          int numMysteryTubes = min(3, (currentLevel ~/ 4));
          List<int> validIndexes = [];
          for (int i = 0; i < tubes.length; i++) {
            if (tubes[i].colors.length >= 3) validIndexes.add(i);
          }
          validIndexes.shuffle(random);
          for (int i = 0; i < min(numMysteryTubes, validIndexes.length); i++) {
            int idx = validIndexes[i];
            tubes[idx].hiddenCount = max(0, tubes[idx].colors.length - 1);
          }
        }
        return;
      }
    }
  }

  bool _applyReversibleMixMove(Random random) {
    final sourceIndexes = <int>[];
    for (var index = 0; index < tubes.length; index++) {
      final tube = tubes[index];
      if (tube.isEmpty) continue;

      final runLength = _topColorRunLength(tube);
      if (tube.colors.length == runLength || runLength > 1) {
        sourceIndexes.add(index);
      }
    }
    if (sourceIndexes.isEmpty) return false;

    sourceIndexes.shuffle(random);
    for (final sourceIndex in sourceIndexes) {
      final source = tubes[sourceIndex];
      final color = source.topColor!;
      final runLength = _topColorRunLength(source);
      final maxTransfer = source.colors.length == runLength
          ? runLength
          : runLength - 1;

      final targetIndexes = <int>[];
      for (var index = 0; index < tubes.length; index++) {
        final target = tubes[index];
        if (index != sourceIndex &&
            !target.isFull &&
            (target.isEmpty || target.topColor != color)) {
          targetIndexes.add(index);
        }
      }
      if (targetIndexes.isEmpty) continue;

      final target = tubes[targetIndexes[random.nextInt(targetIndexes.length)]];
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

  bool _isAlreadySolved() {
    for (var tube in tubes) {
      if (tube.isEmpty) continue;
      if (!tube.isFull) return false;
      Color first = tube.colors.first;
      if (tube.colors.any((c) => c != first)) return false;
    }
    return true;
  }

  String get dailyChallengeId {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  int _dailySeed() {
    final today = DateTime.now();
    return today.year * 10000 + today.month * 100 + today.day;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }

  void restartLevel() {
    _initLevel();
  }

  Future<void> nextLevel() async {
    if (activeMode != GameMode.daily) {
      // Reward and progression
      coins += (activeMode == GameMode.classic) ? 50 : 75;
      await StorageService.saveCoins(coins);
      await StorageService.incrementTotalLevelsWon();
      
      // Update event progress logic
      await _updateEventProgress();

      if (currentLevel == maxUnlockedLevel) {
        maxUnlockedLevel++;
        await StorageService.saveLevel(maxUnlockedLevel);
        await PlayGamesService.submitScore(maxUnlockedLevel);
      }
    } else if (activeMode == GameMode.daily && !hasClaimedDailyReward) {
      if (await StorageService.claimDailyReward(dailyChallengeId)) {
        coins += 100;
        gems += 1;
        hasClaimedDailyReward = true;
        await StorageService.saveCoins(coins);
        await StorageService.saveGems(gems);
      }
    }
    if (activeMode != GameMode.daily) currentLevel++;
    _initLevel();
  }

  Future<void> _updateEventProgress() async {
    final eventIds = ['summer_season_2026', 'weekend_warrior'];
    for (var id in eventIds) {
      final data = await StorageService.getEventData(id);
      if (!(data['claimed'] ?? false)) {
        int currentProgress = data['progress'] ?? 0;
        await StorageService.saveEventProgress(id, false, currentProgress + 1);
      }
    }
  }

  void undo() {
    if (isGameOver || isLevelComplete || pouringFromIndex != null) return;
    if (coins < 50) return; // Not enough coins
    if (_history.isNotEmpty) {
      coins -= 50;
      StorageService.saveCoins(coins);
      
      AnalyticsService.logPowerUpUsed('undo');
      tubes = _history.removeLast();
      selectedTubeIndex = null;
      activeHint = null;
      movesCount = max(0, movesCount - 1);
      _notifySafely();
      HapticService.mediumImpact();
    }
  }

  void selectTube(int index) {
    if (isLevelComplete || isGameOver || pouringFromIndex != null) return;

    activeHint = null; // Clear hint on interaction

    if (selectedTubeIndex == null) {
      if (tubes[index].isEmpty) {
        triggerWrongMove(index);
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

  void shuffleTubes() {
    if (isGameOver || isLevelComplete || coins < 50) return;
    
    coins -= 50;
    StorageService.saveCoins(coins);

    List<Color> topColors = [];
    List<int> validIndices = [];

    for (int i = 0; i < tubes.length; i++) {
      if (tubes[i].isNotEmpty && !tubes[i].isComplete) {
        topColors.add(tubes[i].topColor!);
        validIndices.add(i);
      }
    }

    if (topColors.length > 1) {
      _history.add(tubes.map((t) => t.copyWith()).toList());
      movesCount++;
      
      topColors.shuffle(Random());
      for (int i = 0; i < validIndices.length; i++) {
        int tubeIndex = validIndices[i];
        tubes[tubeIndex].colors.removeLast();
        tubes[tubeIndex].colors.add(topColors[i]);
      }
      
      AudioService.playPourSfx();
      
      // Check win condition right after shuffle
      _checkWinCondition();
      if (isLevelComplete) {
        _timer?.cancel();
      } else if (movesLimit != null && movesCount >= movesLimit!) {
        _timer?.cancel();
        _handleGameOver();
      }
      
      // Note: Shuffle uses coins now, if we want to keep it. 
      // But the plan replaced Shuffle with Hint. We can leave it for now.
      _notifySafely();
    }
  }
  
  void addExtraTube() {
    if (isGameOver || isLevelComplete) return;
    if (coins < 100) return;
    
    coins -= 100;
    StorageService.saveCoins(coins);
    
    AnalyticsService.logPowerUpUsed('add_tube');
    // Add an empty tube with standard capacity
    tubes.add(Tube(capacity: 4));
    
    AudioService.playPourSfx();
    _notifySafely();
  }

  void useExtraChance(bool isTime, {bool isAd = false}) {
    if (extraChancesUsed >= 3) return;
    
    // Deduct coins if not an Ad
    if (!isAd) {
      if (coins >= 50) {
        coins -= 50;
        StorageService.saveCoins(coins);
      } else {
        return; // Prevent using chance if they somehow bypass the UI check
      }
    }
    
    extraChancesUsed++;
    isGameOver = false;

    if (isTime) {
      remainingTime = (remainingTime ?? 0) + 30;
      _startTimer();
    } else {
      movesLimit = (movesLimit ?? 0) + 5;
    }
    _notifySafely();
  }

  void requestHint() {
    if (isLevelComplete || isGameOver || pouringFromIndex != null) return;
    if (coins < 50) return; // Not enough coins
    
    for (var fromIndex = 0; fromIndex < tubes.length; fromIndex++) {
      final source = tubes[fromIndex];
      final isSolved =
          source.isFull &&
          source.isNotEmpty &&
          source.colors.every((color) => color == source.colors.first);
      if (source.isEmpty || isSolved) continue;
      for (var toIndex = 0; toIndex < tubes.length; toIndex++) {
        if (canPour(fromIndex, toIndex)) {
          coins -= 50;
          StorageService.saveCoins(coins);
          activeHint = HintMove(fromIndex: fromIndex, toIndex: toIndex);
          _notifySafely();
          return;
        }
      }
    }
  }

  Future<void> _startPouring(int fromIndex, int toIndex) async {
    if (isGameOver || (movesLimit != null && movesCount >= movesLimit!)) {
      triggerWrongMove(fromIndex);
      return;
    }

    if (!canPour(fromIndex, toIndex)) {
      triggerWrongMove(toIndex);
      selectedTubeIndex = null;
      _notifySafely();
      return;
    }

    Tube fromTube = tubes[fromIndex];
    Tube toTube = tubes[toIndex];

    _history.add(tubes.map((t) => t.copyWith()).toList());
    movesCount++;

    pouringFromIndex = fromIndex;
    pouringToIndex = toIndex;
    pouringColor = fromTube.topColor;
    selectedTubeIndex = null;

    double tiltDirection = (toIndex > fromIndex) ? 1.5 : -1.5;
    pourTiltAngle = tiltDirection;
    AudioService.playPourSfx();
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

    pourTiltAngle = 0.0;
    isPouringLiquid = false;
    _notifySafely();
    await Future.delayed(const Duration(milliseconds: 400));

    if (_isDisposed) return;
    pouringFromIndex = null;
    pouringToIndex = null;

    _checkWinCondition();

    if (isLevelComplete) {
      _timer?.cancel();
    } else if (movesLimit != null && movesCount >= movesLimit!) {
      _timer?.cancel();
      _handleGameOver();
    }

    _notifySafely();
  }

  void triggerWrongMove(int index) {
    wrongMoveIndex = index;
    HapticService.vibrate();
    AudioService.playErrorSfx();
    _notifySafely();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isDisposed) return;
      wrongMoveIndex = null;
      _notifySafely();
    });
  }

  void _checkWinCondition() {
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
      AudioService.playWinSfx();
      AnalyticsService.logLevelComplete(currentLevel, movesCount, 0);
      
      // Production Integrations
      if (activeMode != GameMode.daily) {
        _handleProductionIntegrations();
      }
    }
  }

  Future<void> _handleProductionIntegrations() async {
    // 1. In-App Review
    await ReviewService.requestReviewIfEligible(currentLevel);

    // 2. Play Games Achievements & Leaderboard
    if (PlayGamesService.isSignedIn) {
      // Submit score (e.g. current level reached)
      await PlayGamesService.submitScore(currentLevel);
      
      // Unlock achievements based on level
      if (currentLevel >= 1) {
        await PlayGamesService.unlockAchievement(PlayGamesService.achievementBeginnerId);
      }
      if (currentLevel >= 10) {
        await PlayGamesService.unlockAchievement(PlayGamesService.achievementMasterId);
      }
      if (currentLevel >= 100) {
        await PlayGamesService.unlockAchievement(PlayGamesService.achievementHundredId);
      }

      // 3. Cloud Save
      // Create a simple string representation of the cloud data
      String cloudData = "level:$currentLevel,coins:$coins,gems:$gems";
      await PlayGamesService.saveGame(cloudData);
    }
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }
}
