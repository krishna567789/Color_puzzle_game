import 'package:flutter/material.dart';
import '../models/tube_model.dart';

class GameController extends ChangeNotifier {
  List<Tube> tubes = [];
  int? selectedTubeIndex;
  bool isLevelComplete = false;

  GameController() {
    _initLevel();
  }

  void _initLevel() {
    // Generate a predefined level for testing
    tubes = [
      Tube(initialColors: [Colors.purple, Colors.orange, Colors.green, Colors.red]),
      Tube(initialColors: [Colors.orange, Colors.red, Colors.purple, Colors.green]),
      Tube(initialColors: [Colors.green, Colors.purple, Colors.red, Colors.orange]),
      Tube(initialColors: []),
      Tube(initialColors: []),
    ];
    selectedTubeIndex = null;
    isLevelComplete = false;
    notifyListeners();
  }

  void restartLevel() {
    _initLevel();
  }

  void selectTube(int index) {
    if (isLevelComplete) return;

    if (selectedTubeIndex == null) {
      // Cannot select an empty tube as the source
      if (tubes[index].isEmpty) return;
      selectedTubeIndex = index;
      notifyListeners();
    } else {
      if (selectedTubeIndex == index) {
        // Deselect
        selectedTubeIndex = null;
        notifyListeners();
      } else {
        // Attempt to pour
        _attemptPour(selectedTubeIndex!, index);
      }
    }
  }

  void _attemptPour(int fromIndex, int toIndex) {
    Tube fromTube = tubes[fromIndex];
    Tube toTube = tubes[toIndex];

    if (fromTube.isEmpty || toTube.isFull) {
      selectedTubeIndex = null;
      notifyListeners();
      return;
    }

    if (toTube.isEmpty || toTube.topColor == fromTube.topColor) {
      // Valid pour: pour as much as possible
      Color pouringColor = fromTube.topColor!;
      
      while (fromTube.colors.isNotEmpty && 
             fromTube.topColor == pouringColor && 
             !toTube.isFull) {
        Color removedColor = fromTube.colors.removeLast();
        toTube.colors.add(removedColor);
      }

      _checkWinCondition();
    }
    
    selectedTubeIndex = null;
    notifyListeners();
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
