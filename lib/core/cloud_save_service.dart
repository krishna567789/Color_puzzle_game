import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'analytics_service.dart';
import 'play_games_service.dart';
import 'storage_service.dart';

/// A device's progress, as it travels to and from Play Games.
///
/// Purchased cosmetics (owned skins, ads-removed) deliberately stay off the
/// cloud: they are backed by the store's own purchase history, and a blob that
/// could claim them would also be able to hand them out for free.
class CloudSave {
  const CloudSave({
    required this.savedAt,
    required this.level,
    required this.coins,
    required this.gems,
    required this.totalLevelsWon,
    required this.playerXp,
    required this.levelStars,
  });

  final DateTime savedAt;

  /// Highest level the player may enter.
  final int level;
  final int coins;
  final int gems;
  final int totalLevelsWon;

  /// Career XP, which is what the dashboard's player level is derived from.
  final int playerXp;

  /// Stars ever earned per level, the record that makes a replay honest.
  final Map<int, int> levelStars;

  /// 2 added `xp`. A 1 still decodes, with zero XP, so an install that synced
  /// before this build went out does not lose the rest of its save.
  static const int _version = 2;
  static const int _oldestReadableVersion = 1;

  static Future<CloudSave> capture() async {
    return CloudSave(
      savedAt: DateTime.now(),
      level: await StorageService.getLevel(),
      coins: await StorageService.getCoins(),
      gems: await StorageService.getGems(),
      totalLevelsWon: await StorageService.getTotalLevelsWon(),
      playerXp: await StorageService.getPlayerXp(),
      levelStars: await StorageService.getAllLevelStars(),
    );
  }

  String encode() => jsonEncode({
    'v': _version,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'level': level,
    'coins': coins,
    'gems': gems,
    'wins': totalLevelsWon,
    'xp': playerXp,
    'stars': {for (final e in levelStars.entries) e.key.toString(): e.value},
  });

  /// Null for anything that is not a save this build understands, including
  /// the `level:12,coins:340,gems:3` string earlier versions wrote.
  static CloudSave? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final version = (json['v'] as num? ?? 0).toInt();
      if (version < _oldestReadableVersion || version > _version) return null;
      final savedAt = DateTime.tryParse(json['savedAt'].toString());
      if (savedAt == null) return null;
      final stars = <int, int>{};
      final rawStars = json['stars'];
      if (rawStars is Map) {
        for (final entry in rawStars.entries) {
          final level = int.tryParse(entry.key.toString());
          final value = entry.value;
          if (level != null && value is num) stars[level] = value.toInt();
        }
      }
      return CloudSave(
        savedAt: savedAt.toLocal(),
        level: (json['level'] as num? ?? 1).toInt(),
        coins: (json['coins'] as num? ?? 0).toInt(),
        gems: (json['gems'] as num? ?? 0).toInt(),
        totalLevelsWon: (json['wins'] as num? ?? 0).toInt(),
        playerXp: (json['xp'] as num? ?? 0).toInt(),
        levelStars: stars,
      );
    } catch (e) {
      debugPrint('Cloud save unreadable: $e');
      return null;
    }
  }
}

/// Pushes and pulls that snapshot.
///
/// Restore is merge-only: a level, a win count or a star rating can go up but
/// never down, so a phone that was offline for a week cannot overwrite a
/// player's progress with an old copy. Currency follows the newest save, which
/// is the only field where a device can legitimately have less than another.
class CloudSaveService {
  /// Sends the whole snapshot; Play Games keeps one slot, so there is nothing
  /// to patch.
  static Future<void> upload() async {
    if (!PlayGamesService.isSignedIn) return;
    final snapshot = await CloudSave.capture();
    await PlayGamesService.saveGame(snapshot.encode());
    // Stamped with the snapshot's own time, so the next merge can tell a copy
    // written elsewhere from a round trip of this device's.
    await StorageService.setCloudUploadedAt(snapshot.savedAt);
  }

  /// Pulls the cloud copy and merges it. True when the device ended up holding
  /// something it did not have before.
  static Future<bool> restore() async {
    if (!PlayGamesService.isSignedIn) return false;
    final remote = CloudSave.decode(await PlayGamesService.loadGame());
    if (remote == null) return false;
    return merge(remote);
  }

  /// Raises what can only go up (levels, wins, XP, star ratings) and takes the
  /// currency from whichever copy was written last.
  static Future<bool> merge(CloudSave remote) async {
    final local = await CloudSave.capture();
    var changed = false;

    if (remote.level > local.level) {
      await StorageService.raiseLevel(remote.level);
      changed = true;
    }
    if (remote.totalLevelsWon > local.totalLevelsWon) {
      await StorageService.raiseTotalLevelsWon(remote.totalLevelsWon);
      changed = true;
    }
    if (remote.playerXp > local.playerXp) {
      await StorageService.raisePlayerXp(remote.playerXp);
      changed = true;
    }
    for (final entry in remote.levelStars.entries) {
      if (entry.value > (local.levelStars[entry.key] ?? 0)) {
        await StorageService.saveLevelStars(entry.key, entry.value);
        changed = true;
      }
    }

    // Compared with the last thing this device pushed, not with the local
    // snapshot's own stamp: that would always be "now", and a copy from another
    // phone would then always look stale.
    final lastUpload = await StorageService.getCloudUploadedAt();
    if (lastUpload == null || remote.savedAt.isAfter(lastUpload)) {
      if (remote.coins != local.coins) {
        await StorageService.saveCoins(remote.coins);
        changed = true;
      }
      if (remote.gems != local.gems) {
        await StorageService.saveGems(remote.gems);
        changed = true;
      }
    }

    if (changed) {
      debugPrint('Cloud save merged into local progress.');
      AnalyticsService.logEvent(
        'cloud_save_restored',
        parameters: {'level': remote.level},
      );
    }
    return changed;
  }
}
