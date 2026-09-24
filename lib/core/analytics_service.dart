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

  static Future<void> logPowerUpUsed(String powerUpType, {
    bool adFunded = false,
  }) async {
    await logEvent('power_up_used', parameters: {
      'type': powerUpType,
      'funded_by': adFunded ? 'rewarded_ad' : 'coins',
    });
  }

  static Future<void> logAdImpression(String adFormat) async {
    await logEvent('ad_impression', parameters: {'ad_format': adFormat});
  }

  static Future<void> logAdRewarded(String adFormat) async {
    await logEvent('ad_reward_earned', parameters: {'ad_format': adFormat});
  }

  static Future<void> logAdFailedToLoad(String adFormat) async {
    await logEvent('ad_failed_to_load', parameters: {'ad_format': adFormat});
  }

  static Future<void> logShopOpened() async {
    await logEvent('shop_open');
  }

  static Future<void> logPurchase({
    required String productId,
    required String source,
  }) async {
    await logEvent('iap_purchase', parameters: {
      'product_id': productId,
      'source': source,
    });
  }

  static Future<void> logPurchaseFailed(String reason) async {
    await logEvent('iap_purchase_failed', parameters: {'reason': reason});
  }

  static Future<void> logAdsRemoved() async {
    await logEvent('ads_removed');
  }
}
