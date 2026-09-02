import 'package:games_services/games_services.dart';
import 'package:flutter/foundation.dart';

class PlayGamesService {
  static bool _isSignedIn = false;

  static bool get isSignedIn => _isSignedIn;

  static Future<void> init() async {
    try {
      await GamesServices.signIn();
      _isSignedIn = await GamesServices.isSignedIn;
    } catch (e) {
      debugPrint("Play Games silent sign-in failed: $e");
    }
  }

  static Future<bool> signIn() async {
    try {
      await GamesServices.signIn();
      _isSignedIn = await GamesServices.isSignedIn;
      return _isSignedIn;
    } catch (e) {
      debugPrint("Play Games sign-in failed: $e");
      return false;
    }
  }

  static Future<void> showLeaderboards() async {
    if (!_isSignedIn) {
      bool success = await signIn();
      if (!success) return;
    }
    try {
      await GamesServices.showLeaderboards();
    } catch (e) {
      debugPrint("Failed to show leaderboards: $e");
    }
  }

  static Future<void> showAchievements() async {
    if (!_isSignedIn) {
      bool success = await signIn();
      if (!success) return;
    }
    try {
      await GamesServices.showAchievements();
    } catch (e) {
      debugPrint("Failed to show achievements: $e");
    }
  }
}
