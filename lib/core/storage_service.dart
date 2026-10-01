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
  static const String _keyColorblindPatterns = 'colorblind_patterns';
  static const String _keyLeftHanded = 'left_handed_layout';
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
  static const String _keyDeliveredPurchases = 'delivered_purchase_ids';
  static const String _keyLevelStars = 'level_stars';
  static const String _keyModeProgress = 'mode_progress';
  static const String _keyModeStars = 'mode_stars';
  static const String _keyDailyCounters = 'daily_counters';
  static const String _keyStreakRewardDate = 'streak_reward_date';
  static const String _keyCloudUploadedAt = 'cloud_uploaded_at';
  static const String _keyPlayerXp = 'player_xp';
  static const String _keyClaimedChapters = 'claimed_chapters';
  static const String _keySchemaVersion = 'schema_version';

  /// The shape of the data this build reads. Bump it and add a step in
  /// [_migrate] whenever a stored key changes meaning, so an old install is
  /// translated instead of being read with the wrong defaults.
  static const int _currentSchemaVersion = 1;

  static Future<Box<dynamic>>? _boxFuture;

  /// Initializes the local Hive box used for game progress and settings.
  static Future<void> init() async {
    await _getBox();
  }

  static Future<Box<dynamic>> _getBox() {
    return _boxFuture ??= _openBox().catchError((Object error) {
      // A rejected future left cached fails every read for the life of the
      // process. Dropping it lets the next screen try again, which is what a
      // full disk or a slow path_provider handshake needs.
      _boxFuture = null;
      throw error;
    });
  }

  /// Opens the box and stamps it with the schema this build reads.
  ///
  /// Deliberately never deletes or replaces the file. Hive turns a damaged tail
  /// into a shorter box rather than an error - verified against a garbage file
  /// and a truncated one - so a failed open means the device cannot be read at
  /// all, and wiping the only copy of the save would be the worse outcome.
  static Future<Box<dynamic>> _openBox() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>(_boxName);
    await _stampSchemaVersion(box);
    return box;
  }

  static Future<void> _stampSchemaVersion(Box<dynamic> box) async {
    final stored = box.get(_keySchemaVersion, defaultValue: 0) as int;
    if (stored < _currentSchemaVersion) {
      await _migrate(box, stored);
      await box.put(_keySchemaVersion, _currentSchemaVersion);
    }
  }

  /// Brings a box written by an older build up to [_currentSchemaVersion].
  ///
  /// Every step reads the version it is named for, and there are none yet: the
  /// first release that changes what a key means has to add one here.
  static Future<void> _migrate(Box<dynamic> box, int from) async {}

  static Future<void> resetAllSettings() async {
    final box = await _getBox();
    await box.clear();
  }

  /// What a deletion spares, because it is owed to the player rather than
  /// earned by playing: the ad-free licence, the receipts that stop a purchase
  /// paying out twice, and the schema stamp this build reads.
  static const List<String> _keysDeletionSpares = [
    _keyHasRemovedAds,
    _keyDeliveredPurchases,
    _keySchemaVersion,
  ];

  /// The account-deletion path Google asks for: every level, star, balance,
  /// owned item, streak and preference this device holds is wiped.
  ///
  /// It runs on the wallet chain so a payout already queued cannot land on top
  /// of the wipe, and it keeps what was paid for - a player who bought "no ads"
  /// and then reset their progress would otherwise lose a licence they own, and
  /// dropping the receipts would let the store hand those coins out again.
  static Future<void> deletePlayerData() => _onWallet(() async {
    final box = await _getBox();
    final kept = <String, dynamic>{
      for (final key in _keysDeletionSpares)
        if (box.containsKey(key)) key: box.get(key),
    };
    await box.clear();
    for (final entry in kept.entries) {
      await box.put(entry.key, entry.value);
    }
  });

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

  /// Every wallet write goes through this one chain.
  ///
  /// A win paying out and a store receipt crediting at the same moment both
  /// used to read the balance, add to their own copy and write it back, so
  /// whichever finished last silently discarded the other one's money.
  static Future<void> _walletTail = Future<void>.value();

  static Future<T> _onWallet<T>(Future<T> Function() write) {
    final next = _walletTail.then((_) => write());
    // One failed write must not poison every write queued behind it.
    _walletTail = next.then((_) {}, onError: (_) {});
    return next;
  }

  static const int _defaultCoins = 500;
  static const int _defaultGems = 10;

  static int _balanceOf(Box<dynamic> box, String key, int fallback) =>
      (box.get(key, defaultValue: fallback) as num).toInt();

  /// Adds to the balance without going through a copy the caller is holding,
  /// and returns what the wallet actually ended up at. Never goes below zero.
  static Future<int> addCoins(int delta) =>
      _addDelta(_keyCoins, _defaultCoins, delta);

  static Future<int> addGems(int delta) =>
      _addDelta(_keyGems, _defaultGems, delta);

  static Future<int> _addDelta(String key, int fallback, int delta) =>
      _onWallet(() async {
        final box = await _getBox();
        final next = _balanceOf(box, key, fallback) + delta;
        final paid = next < 0 ? 0 : next;
        await box.put(key, paid);
        return paid;
      });

  /// Checks the price and deducts it in a single step, so two purchases that
  /// each looked affordable when read separately cannot both be honoured.
  static Future<bool> trySpend({int coins = 0, int gems = 0}) {
    if (coins < 0 || gems < 0) return Future.value(false);
    return _onWallet(() async {
      final box = await _getBox();
      final walletCoins = _balanceOf(box, _keyCoins, _defaultCoins);
      final walletGems = _balanceOf(box, _keyGems, _defaultGems);
      if (walletCoins < coins || walletGems < gems) return false;
      await box.put(_keyCoins, walletCoins - coins);
      await box.put(_keyGems, walletGems - gems);
      return true;
    });
  }

  /// Sets a balance outright. Only for a restore, where the incoming number is
  /// the whole truth; anything that adds to what is stored goes through
  /// [addCoins] or [addGems].
  static Future<void> saveCoins(int coins) => _onWallet(() async {
    final box = await _getBox();
    await box.put(_keyCoins, coins);
  });

  static Future<int> getCoins() async {
    final box = await _getBox();
    return _balanceOf(box, _keyCoins, _defaultCoins);
  }

  static Future<void> saveGems(int gems) => _onWallet(() async {
    final box = await _getBox();
    await box.put(_keyGems, gems);
  });

  static Future<int> getGems() async {
    final box = await _getBox();
    return _balanceOf(box, _keyGems, _defaultGems);
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

  /// Whether every liquid layer wears a distinguishing mark as well as a hue.
  static Future<void> setColorblindPatterns(bool enabled) async {
    final box = await _getBox();
    await box.put(_keyColorblindPatterns, enabled);
  }

  static Future<bool> getColorblindPatterns() async {
    final box = await _getBox();
    return box.get(_keyColorblindPatterns, defaultValue: false) as bool;
  }

  /// Whether the controls sit along the left edge, for one-handed left use.
  static Future<void> setLeftHandedLayout(bool enabled) async {
    final box = await _getBox();
    await box.put(_keyLeftHanded, enabled);
  }

  static Future<bool> getLeftHandedLayout() async {
    final box = await _getBox();
    return box.get(_keyLeftHanded, defaultValue: false) as bool;
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

  // --- Chapters ---

  /// The chapters whose reward has already been paid.
  static Future<List<String>> getClaimedChapters() async {
    final box = await _getBox();
    return List<String>.from(
      box.get(_keyClaimedChapters, defaultValue: <String>[]) as List,
    );
  }

  static Future<void> raiseClaimedChapters(Iterable<String> ids) async {
    final box = await _getBox();
    final claimed = List<String>.from(
      box.get(_keyClaimedChapters, defaultValue: <String>[]) as List,
    );
    final added = ids.where((id) => !claimed.contains(id));
    if (added.isEmpty) return;
    await box.put(_keyClaimedChapters, [...claimed, ...added]);
  }

  /// True the first time a chapter pays out, and false every time after, so
  /// replaying a chapter's closing board cannot buy the same reward again.
  static Future<bool> claimChapter(String chapterId) async {
    final box = await _getBox();
    final claimed = List<String>.from(
      box.get(_keyClaimedChapters, defaultValue: <String>[]) as List,
    );
    if (claimed.contains(chapterId)) return false;
    await box.put(_keyClaimedChapters, [...claimed, chapterId]);
    return true;
  }

  // --- Side modes ---

  /// A side mode's stage, spelled the way every per-mode record is filed.
  ///
  /// The mode is part of the key because a stage number is not a level number:
  /// the per-level stars are keyed by a bare integer, and reading a Time Attack
  /// record out of that map would show a campaign three-star on a board nobody
  /// played.
  static String _modeKey(String modeId, int stage) => '$modeId@$stage';

  static Map<String, int> _readModeMap(Box<dynamic> box, String key) {
    final stored = box.get(key, defaultValue: <String, dynamic>{}) as Map;
    return {
      for (final entry in stored.entries)
        entry.key.toString(): (entry.value as num).toInt(),
    };
  }

  static Future<void> _writeModeMap(
    Box<dynamic> box,
    String key,
    Map<String, int> values,
  ) => box.put(key, {...values});

  /// The highest stage [modeId] may be entered from. One until its first stage
  /// is cleared, which is what a mode's own map draws its path from.
  static Future<int> getModeProgress(String modeId) async {
    final box = await _getBox();
    return _readModeMap(box, _keyModeProgress)[modeId] ?? 1;
  }

  /// Unlocks up to [stage] in [modeId] and never locks anything back. The only
  /// way a record can travel is forward, which is what lets a cloud merge hand
  /// the whole map over.
  static Future<void> raiseModeProgress(String modeId, int stage) async {
    final box = await _getBox();
    final progress = _readModeMap(box, _keyModeProgress);
    if ((progress[modeId] ?? 1) >= stage) return;
    progress[modeId] = stage;
    await _writeModeMap(box, _keyModeProgress, progress);
  }

  /// Every mode's unlock, for a snapshot that has to carry them all.
  static Future<Map<String, int>> getAllModeProgress() async {
    final box = await _getBox();
    return _readModeMap(box, _keyModeProgress);
  }

  static Future<void> raiseAllModeProgress(Map<String, int> stages) async {
    final box = await _getBox();
    final progress = _readModeMap(box, _keyModeProgress);
    var changed = false;
    for (final entry in stages.entries) {
      if (entry.value > (progress[entry.key] ?? 1)) {
        progress[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) await _writeModeMap(box, _keyModeProgress, progress);
  }

  /// Best rating ever earned on one stage of one mode.
  static Future<int> getModeStars(String modeId, int stage) async {
    final box = await _getBox();
    return _readModeMap(box, _keyModeStars)[_modeKey(modeId, stage)] ?? 0;
  }

  static Future<Map<String, int>> getAllModeStars() async {
    final box = await _getBox();
    return _readModeMap(box, _keyModeStars);
  }

  /// One mode's best rating per stage, keyed by the stage number, which is what
  /// a mode's own map draws under each node.
  static Future<Map<int, int>> getModeStarsByStage(String modeId) async {
    final box = await _getBox();
    final prefix = '$modeId@';
    return {
      for (final entry in _readModeMap(box, _keyModeStars).entries)
        if (entry.key.startsWith(prefix))
          (int.tryParse(entry.key.substring(prefix.length)) ?? 0): entry.value,
    };
  }

  /// Keeps the better of the two ratings. False when this run did not beat what
  /// the stage already remembers, which is what makes a replay honest rather
  /// than a farm.
  static Future<bool> saveModeStars(
    String modeId,
    int stage,
    int stars,
  ) async {
    final box = await _getBox();
    final key = _modeKey(modeId, stage);
    final records = _readModeMap(box, _keyModeStars);
    if ((records[key] ?? 0) >= stars) return false;
    records[key] = stars;
    await _writeModeMap(box, _keyModeStars, records);
    return true;
  }

  static Future<void> raiseAllModeStars(Map<String, int> records) async {
    final box = await _getBox();
    final stored = _readModeMap(box, _keyModeStars);
    var changed = false;
    for (final entry in records.entries) {
      if (entry.value > (stored[entry.key] ?? 0)) {
        stored[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) await _writeModeMap(box, _keyModeStars, stored);
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
    if (delivered.length > 200) {
      delivered.removeRange(0, delivered.length - 200);
    }
    await box.put(_keyDeliveredPurchases, delivered);
    return true;
  }

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

  /// The one date format used for anything that resets daily: streaks, quests,
  /// spins and today's daily prize.
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
