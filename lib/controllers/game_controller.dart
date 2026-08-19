import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tube_model.dart';
import '../core/storage_service.dart';

enum GameMode { classic, challenge, daily }

class GameController extends ChangeNotifier {
  List<Tube> tubes = [];
  int? selectedTubeIndex;
  int? wrongMoveIndex;
  
  // Player Stats
  int coins = 0;
  int gems = 0;
  int maxUnlockedLevel = 1;

  // Pouring animation states
  int? pouringFromIndex;
  int? pouringToIndex;
  double pourTiltAngle = 0.0;
  Offset pourOffset = Offset.zero;
  Color? pouringColor;

  bool isLevelComplete = false;
  int currentLevel = 1;
  int movesCount = 0;
  
  // Mode specific logic
  GameMode activeMode = GameMode.classic;
  int? remainingTime; // for Challenge Mode (seconds)
  int? movesLimit;    // for Challenge Mode
  Timer? _timer;

  final List<List<Tube>> _history = [];

  // Available colors for level generation (vivid, high-contrast flat colors)
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

  GameController({GameMode mode = GameMode.classic}) {
    activeMode = mode;
    _loadProgress().then((_) => _initLevel());
  }

  Future<void> _loadProgress() async {
    maxUnlockedLevel = await StorageService.getLevel();
    coins = await StorageService.getCoins();
    gems = await StorageService.getGems();
    currentLevel = (activeMode == GameMode.classic) ? maxUnlockedLevel : 1;
    notifyListeners();
  }

  void _initLevel() {
    _timer?.cancel();
    pouringFromIndex = null;
    pouringToIndex = null;
    pourTiltAngle = 0.0;
    pourOffset = Offset.zero;
    selectedTubeIndex = null;
    wrongMoveIndex = null;
    isLevelComplete = false;
    movesCount = 0;
    _history.clear();

    _setupModeConstraints();
    _generateProceduralLevel();
    
    if (activeMode == GameMode.challenge) {
      _startTimer();
    }
    
    notifyListeners();
  }

  void _setupModeConstraints() {
    if (activeMode == GameMode.challenge) {
      remainingTime = 120; // 2 minutes
      movesLimit = 30;     // 30 moves
    } else {
      remainingTime = null;
      movesLimit = null;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime != null && remainingTime! > 0) {
        remainingTime = remainingTime! - 1;
        notifyListeners();
      } else {
        _timer?.cancel();
        _handleGameOver();
      }
    });
  }

  void _handleGameOver() {
    notifyListeners();
  }

  void _generateProceduralLevel() {
    final Random random = Random();
    
    int baseDifficulty = (currentLevel ~/ 2) + 4;
    if (activeMode == GameMode.challenge) baseDifficulty += 2;
    if (activeMode == GameMode.daily) baseDifficulty = 8;
    
    int numColors = min(baseDifficulty, _availableColors.length);
    int numEmptyTubes = 2;
    int totalTubes = numColors + numEmptyTubes;
    
    List<Color> levelColors = List.from(_availableColors)..shuffle(random);
    levelColors = levelColors.take(numColors).toList();
    
    List<Color> allUnits = [];
    for (var color in levelColors) {
      for (int i = 0; i < 4; i++) {
        allUnits.add(color);
      }
    }
    
    allUnits.shuffle(random);
    
    tubes = List.generate(totalTubes, (index) {
      if (index < numColors) {
        List<Color> tubeColors = [];
        for (int i = 0; i < 4; i++) {
          tubeColors.add(allUnits.removeLast());
        }
        return Tube(initialColors: tubeColors);
      } else {
        return Tube(initialColors: []); 
      }
    });

    bool hasAlreadySortedTube = tubes.any((t) => t.isFull && t.colors.every((c) => c == t.colors.first));
    if (hasAlreadySortedTube || _isAlreadySolved()) {
      _generateProceduralLevel();
    }
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void restartLevel() {
    _initLevel();
  }

  void nextLevel() {
    if (activeMode == GameMode.classic) {
      // Reward and progression
      coins += 50;
      StorageService.saveCoins(coins);
      if (currentLevel == maxUnlockedLevel) {
        maxUnlockedLevel++;
        StorageService.saveLevel(maxUnlockedLevel);
      }
    }
    currentLevel++;
    _initLevel();
  }

  void undo() {
    if (_history.isNotEmpty) {
      tubes = _history.removeLast();
      selectedTubeIndex = null;
      notifyListeners();
      HapticFeedback.mediumImpact();
    }
  }

  void selectTube(int index) {
    if (isLevelComplete || pouringFromIndex != null) return;

    if (selectedTubeIndex == null) {
      if (tubes[index].isEmpty) {
        _triggerWrongMove(index);
        return;
      }
      selectedTubeIndex = index;
      HapticFeedback.selectionClick();
      notifyListeners();
    } else {
      if (selectedTubeIndex == index) {
        selectedTubeIndex = null;
        notifyListeners();
      } else {
        _startPouring(selectedTubeIndex!, index);
      }
    }
  }

  Future<void> _startPouring(int fromIndex, int toIndex) async {
    if (movesLimit != null && movesCount >= movesLimit!) {
      _triggerWrongMove(fromIndex);
      return;
    }

    Tube fromTube = tubes[fromIndex];
    Tube toTube = tubes[toIndex];

    if (toTube.isFull) {
      _triggerWrongMove(toIndex);
      selectedTubeIndex = null;
      notifyListeners();
      return;
    }

    _history.add(tubes.map((t) => t.copyWith()).toList());
    movesCount++;

    pouringFromIndex = fromIndex;
    pouringToIndex = toIndex;
    pouringColor = fromTube.topColor;
    selectedTubeIndex = null;
    
    double tiltDirection = (toIndex > fromIndex) ? 1.5 : -1.5;
    pourTiltAngle = tiltDirection; 
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 400));
    
    Color pColor = fromTube.topColor!;
    while (fromTube.colors.isNotEmpty && 
           fromTube.topColor == pColor && 
           !toTube.isFull) {
      Color removedColor = fromTube.colors.removeLast();
      toTube.colors.add(removedColor);
      notifyListeners();
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    pourTiltAngle = 0.0;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));

    pouringFromIndex = null;
    pouringToIndex = null;
    
    _checkWinCondition();
    
    if (isLevelComplete) {
      _timer?.cancel();
    } else if (movesLimit != null && movesCount >= movesLimit!) {
      _timer?.cancel();
      _handleGameOver();
    }
    
    notifyListeners();
  }

  void _triggerWrongMove(int index) {
    wrongMoveIndex = index;
    HapticFeedback.vibrate();
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 500), () {
      wrongMoveIndex = null;
      notifyListeners();
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
    }
  }
}
