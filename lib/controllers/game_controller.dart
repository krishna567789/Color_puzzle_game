import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tube_model.dart';

class GameController extends ChangeNotifier {
  List<Tube> tubes = [];
  int? selectedTubeIndex;
  int? wrongMoveIndex;
  
  // Pouring animation states
  int? pouringFromIndex;
  int? pouringToIndex;
  double pourTiltAngle = 0.0;
  Offset pourOffset = Offset.zero;
  Color? pouringColor;

  bool isLevelComplete = false;
  int currentLevel = 1;
  int movesCount = 0;

  final List<List<Tube>> _history = [];

  // Available colors for level generation
  final List<Color> _availableColors = [
    Colors.red, Colors.blue, Colors.green, Colors.yellow,
    Colors.orange, Colors.purple, Colors.cyan, Colors.pink,
    Colors.teal, Colors.indigo, Colors.brown, Colors.lime,
  ];

  GameController() {
    _initLevel();
  }

  void _initLevel() {
    pouringFromIndex = null;
    pouringToIndex = null;
    pourTiltAngle = 0.0;
    pourOffset = Offset.zero;
    selectedTubeIndex = null;
    wrongMoveIndex = null;
    isLevelComplete = false;
    movesCount = 0;
    _history.clear();

    _generateProceduralLevel();
    notifyListeners();
  }

  void _generateProceduralLevel() {
    final Random random = Random();
    
    // Determine number of colors based on level (more aggressive progression)
    // Starting with 4 colors at level 1, increasing every 2 levels
    int numColors = min((currentLevel ~/ 2) + 4, _availableColors.length);
    
    // Number of empty tubes can also vary (2 or 3)
    int numEmptyTubes = (currentLevel > 10 && random.nextBool()) ? 3 : 2;
    
    int totalTubes = numColors + numEmptyTubes;
    
    // 1. Pick colors
    List<Color> levelColors = List.from(_availableColors)..shuffle(random);
    levelColors = levelColors.take(numColors).toList();
    
    // 2. Create all liquid units (4 per color)
    List<Color> allUnits = [];
    for (var color in levelColors) {
      for (int i = 0; i < 4; i++) {
        allUnits.add(color);
      }
    }
    
    // 3. Shuffle units thoroughly
    allUnits.shuffle(random);
    
    // 4. Distribute into tubes
    tubes = List.generate(totalTubes, (index) {
      if (index < numColors) {
        List<Color> tubeColors = [];
        // Ensure no tube starts already completed (4 of same color)
        for (int i = 0; i < 4; i++) {
          tubeColors.add(allUnits.removeLast());
        }
        return Tube(initialColors: tubeColors);
      } else {
        return Tube(initialColors: []); // Empty tubes
      }
    });

    // Final check: if a tube happens to be already sorted by chance, reshuffle
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

  void restartLevel() {
    _initLevel();
  }

  void nextLevel() {
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
    Tube fromTube = tubes[fromIndex];
    Tube toTube = tubes[toIndex];

    // New Logic: Anyone's color can be filled in anyone, just need space.
    if (toTube.isFull) {
      _triggerWrongMove(toIndex);
      selectedTubeIndex = null;
      notifyListeners();
      return;
    }

    // Save history
    _history.add(tubes.map((t) => t.copyWith()).toList());
    movesCount++;

    pouringFromIndex = fromIndex;
    pouringToIndex = toIndex;
    pouringColor = fromTube.topColor;
    selectedTubeIndex = null;
    
    // Calculate tilt direction
    double tiltDirection = (toIndex > fromIndex) ? 1.2 : -1.2;
    pourTiltAngle = tiltDirection; 
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 400));
    
    // Transfer colors: Even if they are different, we allow it.
    // We transfer the entire top block of the same color.
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

    // Tilt back
    pourTiltAngle = 0.0;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));

    // Reset pouring state
    pouringFromIndex = null;
    pouringToIndex = null;
    _checkWinCondition();
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
