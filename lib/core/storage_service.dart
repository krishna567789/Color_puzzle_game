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
  static const String _keyLoginStreak = 'login_streak';
  static const String _keyLastLoginDate = 'last_login_date';
  static const String _keyHasReviewed = 'has_reviewed';
  static const String _keyHasRemovedAds = 'has_removed_ads';
  static const String _keyDailyChallengeDate = 'daily_challenge_date';
  static const String _keyDeliveredPurchases = 'delivered_purchase_ids';
  static const String _keyLevelStars = 'level_stars';
  static const String _keyDailyCounters = 'daily_counters';
  static const String _keyStreakRewardDate = 'streak_reward_date';
  static const String _keyCloudUploadedAt = 'cloud_uploaded_at';
  static const String _keyPlayerXp = 'player_xp';

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

  static Future<void> resetAllSettings() async {
    final box = await _getBox();
    await box.clear();
  }

  // --- Review Tracking ---
  static Future<bool> getHasReviewed() async {
    final box = await _getBox();
    return box.get(_keyHasReviewed, defaultValue: false) as bool;
  }

  static Future<void> setHasReviewed(bool value) async {
    final box = await _getBox();
    await box.put(_keyHasReviewed, value);
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
    return List<String>.from(
      box.get(_keyOwnedItems, defaultValue: <String>['default_tube']) as List,
    );
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

  static Future<Map<String, dynamic>> getAchievementData(
    String achievementId,
  ) async {
    final box = await _getBox();
    Map<String, dynamic> data = Map<String, dynamic>.from(
      box.get(_keyAchievementProgress, defaultValue: <String, dynamic>{})
          as Map,
    );
    return data[achievementId] as Map<String, dynamic>? ??
        {'claimed': false, 'progress': 0};
  }

  /// True the first time an achievement is collected. Progress itself is never
  /// stored, only the claim, because every goal here is a read of a counter the
  /// game already keeps.
  static Future<bool> claimAchievement(String achievementId) async {
    final box = await _getBox();
    final data = Map<String, dynamic>.from(
      box.get(_keyAchievementProgress, defaultValue: <String, dynamic>{})
          as Map,
    );
    final entry = data[achievementId];
    if (entry is Map && entry['claimed'] == true) return false;
    data[achievementId] = {'claimed': true, 'progress': 0};
    await box.put(_keyAchievementProgress, data);
    return true;
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

  /// Raises a stored number without ever lowering it, which is the whole rule a
  /// cloud save has to follow: syncing can only give progress back.
  static Future<void> raiseTotalLevelsWon(int value) async {
    final box = await _getBox();
    if (value > (box.get(_keyTotalLevelsWon, defaultValue: 0) as int)) {
      await box.put(_keyTotalLevelsWon, value);
    }
  }

  static Future<void> raiseLevel(int value) async {
    final box = await _getBox();
    if (value > (box.get(_keyLevel, defaultValue: 1) as int)) {
      await box.put(_keyLevel, value);
    }
  }

  /// The career XP total. The dashboard's player level is derived from this by
  /// `PlayerLevel.fromXp`, so nothing else has to be stored to draw the bar.
  static Future<int> getPlayerXp() async {
    final box = await _getBox();
    return box.get(_keyPlayerXp, defaultValue: 0) as int;
  }

  static Future<void> addPlayerXp(int amount) async {
    if (amount <= 0) return;
    final box = await _getBox();
    final current = box.get(_keyPlayerXp, defaultValue: 0) as int;
    await box.put(_keyPlayerXp, current + amount);
  }

  static Future<void> raisePlayerXp(int value) async {
    final box = await _getBox();
    if (value > (box.get(_keyPlayerXp, defaultValue: 0) as int)) {
      await box.put(_keyPlayerXp, value);
    }
  }

  static String _eventKey(String eventId, String windowKey) =>
      '$eventId@$windowKey';

  /// Live-ops progress for one run of one event.
  ///
  /// The window is part of the key so a rolling calendar starts a fresh counter
  /// instead of inheriting last season's half-finished progress.
  static Map<String, dynamic> _readEventRuns(Box<dynamic> box) {
    final stored =
        box.get(_keyEventProgress, defaultValue: <String, dynamic>{}) as Map;
    return Map<String, dynamic>.from(stored);
  }

  static Future<({int progress, bool claimed})> getEventRun(
    String eventId,
    String windowKey,
  ) async {
    final box = await _getBox();
    final run = _readEventRuns(box)[_eventKey(eventId, windowKey)];
    if (run is! Map) return (progress: 0, claimed: false);
    return (
      progress: (run['progress'] as num? ?? 0).toInt(),
      claimed: run['claimed'] as bool? ?? false,
    );
  }

  static Future<int> bumpEventProgress(
    String eventId,
    String windowKey,
    int amount,
  ) async {
    final box = await _getBox();
    final runs = _readEventRuns(box);
    final key = _eventKey(eventId, windowKey);
    final run = runs[key];
    final current = run is Map ? (run['progress'] as num? ?? 0).toInt() : 0;
    final claimed = run is Map && run['claimed'] == true;
    final next = current + amount;
    runs[key] = {'progress': next, 'claimed': claimed};
    await box.put(_keyEventProgress, runs);
    return next;
  }

  /// True the first time a run is claimed and only that time.
  static Future<bool> claimEventRun(String eventId, String windowKey) async {
    final box = await _getBox();
    final runs = _readEventRuns(box);
    final key = _eventKey(eventId, windowKey);
    final run = runs[key];
    if (run is Map && run['claimed'] == true) return false;
    runs[key] = {
      'progress': run is Map ? (run['progress'] as num? ?? 0).toInt() : 0,
      'claimed': true,
    };
    await box.put(_keyEventProgress, runs);
    return true;
  }

  static Future<void> setTutorialCompleted(bool completed) async {
    final box = await _getBox();
    await box.put(_keyTutorialCompleted, completed);
  }

  static Future<bool> isTutorialCompleted() async {
    final box = await _getBox();
    return box.get(_keyTutorialCompleted, defaultValue: false) as bool;
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

  static Future<void> setHasRemovedAds(bool value) async {
    final box = await _getBox();
    await box.put(_keyHasRemovedAds, value);
  }

  static Future<bool> getHasRemovedAds() async {
    final box = await _getBox();
    return box.get(_keyHasRemovedAds, defaultValue: false) as bool;
  }

  static Future<bool> _purchaseLedgerTail = Future<bool>.value(true);

  /// First call for a purchase id returns true; replays of the same purchase
  /// from the store stream return false so coins are never credited twice.
  static Future<bool> markPurchaseDelivered(String purchaseId) {
    // Chained so two overlapping store callbacks cannot both read the ledger
    // before either writes it and credit the same purchase twice.
    final next = _purchaseLedgerTail.then((_) => _checkDelivery(purchaseId));
    _purchaseLedgerTail = next;
    return next;
  }

  static Future<bool> _checkDelivery(String purchaseId) async {
    if (purchaseId.isEmpty) return true;
    final box = await _getBox();
    final delivered = List<String>.from(
      box.get(_keyDeliveredPurchases, defaultValue: <String>[]) as List,
    );
    if (delivered.contains(purchaseId)) return false;
    delivered.add(purchaseId);
    if (delivered.length > 200)
      delivered.removeRange(0, delivered.length - 200);
    await box.put(_keyDeliveredPurchases, delivered);
    return true;
  }

  static Future<bool> isDailyChallengeCompleted(String dateStr) async {
    final box = await _getBox();
    return box.get(_keyDailyChallengeDate) == dateStr;
  }

  static Future<void> setDailyChallengeCompleted(String dateStr) async {
    final box = await _getBox();
    await box.put(_keyDailyChallengeDate, dateStr);
  }

  /// The one date format used for anything that resets daily: streaks, quests,
  /// spins and the daily challenge.
  /// When this device last pushed a cloud save, which is what decides whether a
  /// save found in the cloud is newer than the local one.
  static Future<DateTime?> getCloudUploadedAt() async {
    final box = await _getBox();
    final stored = box.get(_keyCloudUploadedAt);
    if (stored is! String) return null;
    return DateTime.tryParse(stored);
  }

  static Future<void> setCloudUploadedAt(DateTime at) async {
    final box = await _getBox();
    await box.put(_keyCloudUploadedAt, at.toUtc().toIso8601String());
  }

  static String dateKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static String get todayKey => dateKey(DateTime.now());

  // --- Per-level stars ---

  static Map<int, int> _readLevelStars(Box<dynamic> box) {
    final stored =
        box.get(_keyLevelStars, defaultValue: <String, dynamic>{}) as Map;
    return {
      for (final entry in stored.entries)
        (int.tryParse(entry.key.toString()) ?? 0): (entry.value as num).toInt(),
    };
  }

  /// Stars the player has ever earned on a level, so the map can show a real
  /// rating and a first three-star can pay a gem once.
  static Future<int> getLevelStars(int level) async {
    final box = await _getBox();
    return _readLevelStars(box)[level] ?? 0;
  }

  static Future<Map<int, int>> getAllLevelStars() async {
    final box = await _getBox();
    return _readLevelStars(box);
  }

  /// Keeps the better of the two ratings. Returns false when the new result did
  /// not beat what is already stored.
  static Future<bool> saveLevelStars(int level, int stars) async {
    final box = await _getBox();
    final stored = _readLevelStars(box);
    if ((stored[level] ?? 0) >= stars) return false;
    stored[level] = stars;
    await box.put(_keyLevelStars, {
      for (final entry in stored.entries) '${entry.key}': entry.value,
    });
    return true;
  }

  static Future<int> getTotalStars() async {
    final box = await _getBox();
    return _readLevelStars(
      box,
    ).values.fold<int>(0, (sum, stars) => sum + stars);
  }

  // --- Today's play ---

  static Map<String, int> _readDailyCounters(Box<dynamic> box) {
    final stored = box.get(_keyDailyCounters) as Map?;
    if (stored == null || stored['date'] != todayKey) return {};
    return {
      for (final entry in (stored['counters'] as Map? ?? {}).entries)
        entry.key.toString(): (entry.value as num).toInt(),
    };
  }

  /// Counters for quests, read fresh. Everything stored under an earlier date
  /// reads as zero, which is what makes the quests daily without a timer.
  static Future<Map<String, int>> getDailyCounters() async {
    final box = await _getBox();
    return _readDailyCounters(box);
  }

  static Future<int> getDailyCounter(String key) async {
    final box = await _getBox();
    return _readDailyCounters(box)[key] ?? 0;
  }

  static Future<void> bumpDailyCounters(Map<String, int> deltas) async {
    final box = await _getBox();
    final counters = _readDailyCounters(box);
    deltas.forEach((key, amount) {
      counters[key] = (counters[key] ?? 0) + amount;
    });
    await box.put(_keyDailyCounters, {
      'date': todayKey,
      'counters': counters,
      'claimedQuests': _readClaimedQuests(box),
    });
  }

  static List<String> _readClaimedQuests(Box<dynamic> box) {
    final stored = box.get(_keyDailyCounters) as Map?;
    if (stored == null || stored['date'] != todayKey) return [];
    return List<String>.from((stored['claimedQuests'] as List? ?? []));
  }

  static Future<List<String>> getClaimedQuestsToday() async {
    return _readClaimedQuests(await _getBox());
  }

  /// True the first time a quest is claimed today, false on every later tap and
  /// after the day rolls over into a fresh set.
  static Future<bool> claimQuestToday(String questId) async {
    final box = await _getBox();
    final claimed = _readClaimedQuests(box);
    if (claimed.contains(questId)) return false;
    claimed.add(questId);
    await box.put(_keyDailyCounters, {
      'date': todayKey,
      'counters': _readDailyCounters(box),
      'claimedQuests': claimed,
    });
    return true;
  }

  // --- Login streak ---

  /// The day the streak reward was already paid, so a relaunch on the same day
  /// cannot hand out the same coins twice.
  static Future<bool> claimStreakRewardToday() async {
    final box = await _getBox();
    final today = todayKey;
    if (box.get(_keyStreakRewardDate) == today) return false;
    await box.put(_keyStreakRewardDate, today);
    return true;
  }
}
