import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'storage_service.dart';

class ReviewService {
  static final InAppReview _inAppReview = InAppReview.instance;

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
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.openStoreListing(appStoreId: '...', microsoftStoreId: '...');
        await StorageService.setHasReviewed(true);
      }
    } catch (e) {
      debugPrint("Error opening store listing: $e");
    }
  }
}
