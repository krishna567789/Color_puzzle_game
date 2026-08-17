import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyLevel = 'user_level';
  static const String _keyCoins = 'user_coins';
  static const String _keyGems = 'user_gems';
  static const String _keyFirstTime = 'first_time_user';
  static const String _keyVibration = 'vibration_enabled';

  static Future<void> saveLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLevel, level);
  }

  static Future<int> getLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLevel) ?? 1;
  }

  static Future<void> saveCoins(int coins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCoins, coins);
  }

  static Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCoins) ?? 500; // Starting coins
  }

  static Future<void> saveGems(int gems) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGems, gems);
  }

  static Future<int> getGems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyGems) ?? 10; // Starting gems
  }

  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    bool first = prefs.getBool(_keyFirstTime) ?? true;
    if (first) {
      await prefs.setBool(_keyFirstTime, false);
    }
    return first;
  }

  static Future<void> setVibration(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibration, enabled);
  }

  static Future<bool> getVibration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVibration) ?? true;
  }
}
