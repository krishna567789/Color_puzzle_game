import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      debugPrint("Analytics Event Logged: $name $parameters");
    } catch (e) {
      debugPrint("Failed to log analytics event: $e");
    }
  }

  static Future<void> logLevelStart(int level, String mode) async {
    await logEvent('level_start', parameters: {
      'level': level,
      'mode': mode,
    });
  }

  static Future<void> logLevelComplete(int level, int moves, int durationSeconds) async {
    await logEvent('level_complete', parameters: {
      'level': level,
      'moves': moves,
      'duration_seconds': durationSeconds,
    });
  }

  static Future<void> logPowerUpUsed(String powerUpType) async {
    await logEvent('power_up_used', parameters: {
      'type': powerUpType,
    });
  }
}
