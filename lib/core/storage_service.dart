import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String _boxName = 'game_settings';
  static const String _keyLevel = 'user_level';
  static const String _keyCoins = 'user_coins';
  static const String _keyGems = 'user_gems';
  static const String _keyFirstTime = 'first_time_user';
  static const String _keyVibration = 'vibration_enabled';
  static const String _keyMusic = 'music_enabled';
  static const String _keySfx = 'sfx_enabled';
  static const String _keyDailyRewardDate = 'daily_reward_date';
  static const String _keyOwnedItems = 'owned_items';
  static const String _keySelectedSkin = 'selected_skin';
  static const String _keySelectedTheme = 'selected_theme';
  static const String _keyLastSpinDate = 'last_spin_date';
  static const String _keyAchievementProgress = 'achievement_progress';
  static const String _keyTotalLevelsWon = 'total_levels_won';
  static const String _keyEventProgress = 'event_progress';
  static const String _keyTutorialCompleted = 'tutorial_completed';
  static const String _keyQuestProgress = 'quest_progress';
  static const String _keyLoginStreak = 'login_streak';
  static const String _keyLastLoginDate = 'last_login_date';

  static Future<Box<dynamic>>? _boxFuture;

  /// Initializes the local Hive box used for game progress and settings.
  static Future<void> init() async {
    await _getBox();
  }

  static Future<Box<dynamic>> _getBox() {
    return _boxFuture ??= _openBox();
  }

  static Future<Box<dynamic>> _openBox() async {
    await Hive.initFlutter();
    return Hive.openBox<dynamic>(_boxName);
  }

  static Future<void> saveLevel(int level) async {
    final box = await _getBox();
    await box.put(_keyLevel, level);
  }

  static Future<int> getLevel() async {
    final box = await _getBox();
    return box.get(_keyLevel, defaultValue: 1) as int;
  }

  static Future<void> saveCoins(int coins) async {
    final box = await _getBox();
    await box.put(_keyCoins, coins);
  }

  static Future<int> getCoins() async {
    final box = await _getBox();
    return box.get(_keyCoins, defaultValue: 500) as int;
  }

  static Future<void> saveGems(int gems) async {
    final box = await _getBox();
    await box.put(_keyGems, gems);
  }

  static Future<int> getGems() async {
    final box = await _getBox();
    return box.get(_keyGems, defaultValue: 10) as int;
  }

  static Future<bool> isFirstTime() async {
    final box = await _getBox();
    final first = box.get(_keyFirstTime, defaultValue: true) as bool;
    if (first) {
      await box.put(_keyFirstTime, false);
    }
    return first;
  }

  static Future<void> setVibration(bool enabled) async {
    final box = await _getBox();
    await box.put(_keyVibration, enabled);
  }

  static Future<bool> getVibration() async {
    final box = await _getBox();
    return box.get(_keyVibration, defaultValue: true) as bool;
  }

  static Future<void> setMusic(bool enabled) async {
    final box = await _getBox();
    await box.put(_keyMusic, enabled);
  }

  static Future<bool> getMusic() async {
    final box = await _getBox();
    return box.get(_keyMusic, defaultValue: true) as bool;
  }

  static Future<void> setSfx(bool enabled) async {
    final box = await _getBox();
    await box.put(_keySfx, enabled);
  }

  static Future<bool> getSfx() async {
    final box = await _getBox();
    return box.get(_keySfx, defaultValue: true) as bool;
  }

  static Future<bool> hasClaimedDailyReward(String challengeId) async {
    final box = await _getBox();
    return box.get(_keyDailyRewardDate) == challengeId;
  }

  /// Claims a daily reward once for the supplied date-based challenge id.
  static Future<bool> claimDailyReward(String challengeId) async {
    final box = await _getBox();
    if (box.get(_keyDailyRewardDate) == challengeId) return false;
    await box.put(_keyDailyRewardDate, challengeId);
    return true;
  }

  static Future<void> saveOwnedItems(List<String> itemIds) async {
    final box = await _getBox();
    await box.put(_keyOwnedItems, itemIds);
  }

  static Future<List<String>> getOwnedItems() async {
    final box = await _getBox();
    return List<String>.from(box.get(_keyOwnedItems, defaultValue: <String>['default_tube']) as List);
  }

  static Future<void> setSelectedSkin(String skinId) async {
    final box = await _getBox();
    await box.put(_keySelectedSkin, skinId);
  }

  static Future<String> getSelectedSkin() async {
    final box = await _getBox();
    return box.get(_keySelectedSkin, defaultValue: 'default_tube') as String;
  }

  static Future<void> setSelectedTheme(String themeId) async {
    final box = await _getBox();
    await box.put(_keySelectedTheme, themeId);
  }

  static Future<String> getSelectedTheme() async {
    final box = await _getBox();
    return box.get(_keySelectedTheme, defaultValue: 'default_theme') as String;
  }

  static Future<void> setLastSpinDate(String date) async {
    final box = await _getBox();
    await box.put(_keyLastSpinDate, date);
  }

  static Future<String?> getLastSpinDate() async {
    final box = await _getBox();
    return box.get(_keyLastSpinDate) as String?;
  }

  static Future<void> saveAchievementProgress(String achievementId, bool claimed, int progress) async {
    final box = await _getBox();
    Map<String, dynamic> data = Map<String, dynamic>.from(box.get(_keyAchievementProgress, defaultValue: <String, dynamic>{}) as Map);
    data[achievementId] = {'claimed': claimed, 'progress': progress};
    await box.put(_keyAchievementProgress, data);
  }

  static Future<Map<String, dynamic>> getAchievementData(String achievementId) async {
    final box = await _getBox();
    Map<String, dynamic> data = Map<String, dynamic>.from(box.get(_keyAchievementProgress, defaultValue: <String, dynamic>{}) as Map);
    return data[achievementId] as Map<String, dynamic>? ?? {'claimed': false, 'progress': 0};
  }
  
  static Future<void> incrementTotalLevelsWon() async {
    final box = await _getBox();
    int total = box.get(_keyTotalLevelsWon, defaultValue: 0) as int;
    await box.put(_keyTotalLevelsWon, total + 1);
  }

  static Future<int> getTotalLevelsWon() async {
    final box = await _getBox();
    return box.get(_keyTotalLevelsWon, defaultValue: 0) as int;
  }

  static Future<void> saveEventProgress(String eventId, bool claimed, int progress) async {
    final box = await _getBox();
    Map<String, dynamic> data = Map<String, dynamic>.from(box.get(_keyEventProgress, defaultValue: <String, dynamic>{}) as Map);
    data[eventId] = {'claimed': claimed, 'progress': progress};
    await box.put(_keyEventProgress, data);
  }

  static Future<Map<String, dynamic>> getEventData(String eventId) async {
    final box = await _getBox();
    Map<String, dynamic> data = Map<String, dynamic>.from(box.get(_keyEventProgress, defaultValue: <String, dynamic>{}) as Map);
    return Map<String, dynamic>.from(data[eventId] as Map? ?? {'claimed': false, 'progress': 0});
  }

  static Future<void> setTutorialCompleted(bool completed) async {
    final box = await _getBox();
    await box.put(_keyTutorialCompleted, completed);
  }

  static Future<bool> isTutorialCompleted() async {
    final box = await _getBox();
    return box.get(_keyTutorialCompleted, defaultValue: false) as bool;
  }

  static Future<void> saveQuestProgress(String questId, bool claimed, int progress) async {
    final box = await _getBox();
    Map<String, dynamic> data = Map<String, dynamic>.from(box.get(_keyQuestProgress, defaultValue: <String, dynamic>{}) as Map);
    data[questId] = {'claimed': claimed, 'progress': progress};
    await box.put(_keyQuestProgress, data);
  }

  static Future<Map<String, dynamic>> getQuestData(String questId) async {
    final box = await _getBox();
    Map<String, dynamic> data = Map<String, dynamic>.from(box.get(_keyQuestProgress, defaultValue: <String, dynamic>{}) as Map);
    return Map<String, dynamic>.from(data[questId] as Map? ?? {'claimed': false, 'progress': 0});
  }

  static Future<void> setLoginStreak(int streak) async {
    final box = await _getBox();
    await box.put(_keyLoginStreak, streak);
  }

  static Future<int> getLoginStreak() async {
    final box = await _getBox();
    return box.get(_keyLoginStreak, defaultValue: 0) as int;
  }

  static Future<void> setLastLoginDate(String date) async {
    final box = await _getBox();
    await box.put(_keyLastLoginDate, date);
  }

  static Future<String?> getLastLoginDate() async {
    final box = await _getBox();
    return box.get(_keyLastLoginDate) as String?;
  }
}
