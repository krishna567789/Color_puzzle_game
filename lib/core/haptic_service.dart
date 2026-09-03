import 'package:flutter/services.dart';
import 'storage_service.dart';

class HapticService {
  static bool _vibrationEnabled = true;

  static Future<void> init() async {
    _vibrationEnabled = await StorageService.getVibration();
  }

  static void toggleVibration(bool enabled) {
    _vibrationEnabled = enabled;
    StorageService.setVibration(enabled);
  }

  static Future<void> lightImpact() async {
    if (_vibrationEnabled) {
      await HapticFeedback.lightImpact();
    }
  }

  static Future<void> mediumImpact() async {
    if (_vibrationEnabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> heavyImpact() async {
    if (_vibrationEnabled) {
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> selectionClick() async {
    if (_vibrationEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  static Future<void> vibrate() async {
    if (_vibrationEnabled) {
      await HapticFeedback.vibrate();
    }
  }
}
