import 'dart:io';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';
import 'storage_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static bool _hasRemovedAds = false;

  /// AdMob penalises interstitials that interrupt the player too often, so they
  /// are rate limited on both level completions and wall-clock time.
  static const int _interstitialMinLevelsApart = 3;
  static const Duration _interstitialMinGap = Duration(minutes: 1);
  static int _levelsSinceInterstitial = 0;
  static DateTime? _lastInterstitialAt;

  static Future<void> init() async {
    if (kIsWeb) return;
    _hasRemovedAds = await StorageService.getHasRemovedAds();
    await MobileAds.instance.initialize();
    loadRewardedAd();
    if (!_hasRemovedAds) loadInterstitialAd();
  }

  static void updateHasRemovedAds(bool value) {
    _hasRemovedAds = value;
    if (_hasRemovedAds) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
    } else {
      loadInterstitialAd();
    }
  }

  // iOS unit IDs are still Google's public test IDs; swap in the real AdMob iOS
  // IDs before shipping an iOS build.
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-1221200396997472/9869856353'; // Real Banner ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-1221200396997472/7359563889'; // Real Interstitial ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-1221200396997472/4203801983'; // Real Rewarded ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return '';
  }

  static InterstitialAd? _interstitialAd;

  static void loadInterstitialAd() {
    if (kIsWeb || _hasRemovedAds || _interstitialAd != null) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Called once per cleared level so interstitials can be spaced out.
  static void notifyLevelCompleted() {
    _levelsSinceInterstitial++;
  }

  static bool get _interstitialDue {
    if (_levelsSinceInterstitial < _interstitialMinLevelsApart) return false;
    final last = _lastInterstitialAt;
    if (last != null && DateTime.now().difference(last) < _interstitialMinGap) {
      return false;
    }
    return true;
  }

  static void showInterstitialAd() {
    if (_hasRemovedAds || !_interstitialDue) return;

    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _levelsSinceInterstitial = 0;
      _lastInterstitialAt = DateTime.now();
    } else {
      loadInterstitialAd(); // Ensure we try loading again if not available
    }
  }

  static RewardedAd? _rewardedAd;
  static bool _rewardedAdLoading = false;

  static bool get isRewardedAdReady => _rewardedAd != null;

  static void loadRewardedAd() {
    if (kIsWeb || _rewardedAdLoading || _rewardedAd != null) return;
    _rewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAdLoading = false;
          _rewardedAd = ad;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAdLoading = false;
          _rewardedAd = null;
          debugPrint('RewardedAd failed to load: $error');
          AnalyticsService.logAdFailedToLoad('rewarded');
        },
      ),
    );
  }

  static void showRewardedAd(Function onRewardEarned, Function onAdFailed) {
    final ad = _rewardedAd;
    if (ad == null) {
      loadRewardedAd();
      onAdFailed();
      return;
    }
    _rewardedAd = null;
    var rewarded = false;
    ad.show(
      onUserEarnedReward: (AdWithoutView _, RewardItem _) {
        // AdMob can fire this more than once on some devices; pay out once.
        if (rewarded) return;
        rewarded = true;
        AnalyticsService.logAdRewarded('rewarded');
        onRewardEarned();
      },
    );
    AnalyticsService.logAdImpression('rewarded');
  }
}
