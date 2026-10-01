import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'storage_service.dart';

class ReviewService {
  static final InAppReview _inAppReview = InAppReview.instance;

  /// Apple only hands out the numeric App Store id once the listing exists, and
  /// this build does not have one yet. Android needs no id at all: the plugin
  /// builds the Play URL from the package name.
  static const String _iosAppStoreId = '';

  /// Call this when a level completes to conditionally ask for a review
  static Future<void> requestReviewIfEligible(int currentLevel) async {
    if (kIsWeb) return; // In-app review is only for Android/iOS

    // Only prompt at "delightful" moments (e.g. after Level 3, 10, 25, 50)
    final triggerLevels = [3, 10, 25, 50, 100];
    
    if (triggerLevels.contains(currentLevel)) {
      bool hasReviewed = await StorageService.getHasReviewed();
      if (!hasReviewed) {
        try {
          if (await _inAppReview.isAvailable()) {
            await _inAppReview.requestReview();
            await StorageService.setHasReviewed(true);
          }
        } catch (e) {
          debugPrint("Error requesting in-app review: $e");
        }
      }
    }
  }

  /// Call this when the user manually taps "Rate Us" in settings
  static Future<void> openStoreListing() async {
    if (kIsWeb) return;
    try {
      if (Platform.isIOS && _iosAppStoreId.isEmpty) {
        // There is no store page to open yet. The system review sheet is the
        // one path that works without one, and it is the same ask.
        if (await _inAppReview.isAvailable()) {
          await _inAppReview.requestReview();
          await StorageService.setHasReviewed(true);
        }
        return;
      }
      await _inAppReview.openStoreListing(
        appStoreId: _iosAppStoreId.isEmpty ? null : _iosAppStoreId,
      );
      await StorageService.setHasReviewed(true);
    } catch (e) {
      debugPrint("Error opening store listing: $e");
    }
  }
}
