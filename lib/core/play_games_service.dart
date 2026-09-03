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

  // --- NEW: Production Level Integrations ---

  // REPLACE THESE WITH REAL IDs FROM PLAY CONSOLE LATER
  static const String achievementBeginnerId = "CgkIuO_IqdMbEAIQAQ";
  static const String achievementMasterId = "PLACEHOLDER_ACHIEVEMENT_MASTER";
  static const String achievementHundredId = "PLACEHOLDER_ACHIEVEMENT_HUNDRED";
  static const String leaderboardHighScoreId = "CgkIuO_IqdMbEAIQAw";

  static Future<void> unlockAchievement(String achievementId) async {
    if (!_isSignedIn) return;
    if (achievementId.startsWith("PLACEHOLDER")) return;
    try {
      await GamesServices.unlock(
        achievement: Achievement(androidID: achievementId),
      );
      debugPrint("Achievement unlocked: $achievementId");
    } catch (e) {
      debugPrint("Failed to unlock achievement: $e");
    }
  }

  static Future<void> submitScore(int score) async {
    if (!_isSignedIn) return;
    try {
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: leaderboardHighScoreId,
          value: score,
        ),
      );
      debugPrint("Score submitted: $score");
    } catch (e) {
      debugPrint("Failed to submit score: $e");
    }
  }

  static Future<List<LeaderboardScoreData>?> loadFriendsScores() async {
    if (!_isSignedIn) return null;
    try {
      return await GamesServices.loadLeaderboardScores(
        androidLeaderboardID: leaderboardHighScoreId,
        scope: PlayerScope.friendsOnly,
        timeScope: TimeScope.allTime,
        maxResults: 20, // Load up to 20 friends
      );
    } catch (e) {
      debugPrint("Failed to load friends scores: $e");
      return null;
    }
  }

  // --- Cloud Save functionality ---

  static Future<void> saveGame(String dataStr) async {
    if (!_isSignedIn) return;
    try {
      await GamesServices.saveGame(data: dataStr, name: "slot1");
      debugPrint("Game saved to cloud.");
    } catch (e) {
      debugPrint("Failed to save game to cloud: $e");
    }
  }

  static Future<String?> loadGame() async {
    if (!_isSignedIn) return null;
    try {
      final data = await GamesServices.loadGame(name: "slot1");
      debugPrint("Game loaded from cloud.");
      return data;
    } catch (e) {
      debugPrint("Failed to load game from cloud: $e");
      return null;
    }
  }

  static Future<String?> getPlayerIconImage() async {
    if (!_isSignedIn) return null;
    try {
      // Returns base64 encoded image string
      return await GamesServices.getPlayerIconImage();
    } catch (e) {
      debugPrint("Failed to get player image: $e");
      return null;
    }
  }
}
