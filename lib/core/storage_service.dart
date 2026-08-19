import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String _boxName = 'game_settings';
  static const String _keyLevel = 'user_level';
  static const String _keyCoins = 'user_coins';
  static const String _keyGems = 'user_gems';
  static const String _keyFirstTime = 'first_time_user';
  static const String _keyVibration = 'vibration_enabled';

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
}
