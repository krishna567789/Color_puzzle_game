import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';
import 'storage_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static bool _hasRemovedAds = false;

  /// Google's answer to "may this device be asked for ads". False for an EEA
  /// player who has not consented yet, true everywhere no form is needed.
  static bool _consentAllowsAds = true;

  /// AdMob penalises interstitials that interrupt the player too often, so they
  /// are rate limited on both level completions and wall-clock time.
  static const int _interstitialMinLevelsApart = 3;
  static const Duration _interstitialMinGap = Duration(minutes: 1);
  static int _levelsSinceInterstitial = 0;
  static DateTime? _lastInterstitialAt;

  static Future<void> init() async {
    if (kIsWeb) return;
    _hasRemovedAds = await StorageService.getHasRemovedAds();
    await _collectConsent();
    await MobileAds.instance.initialize();
    loadRewardedAd();
    if (!_hasRemovedAds) loadInterstitialAd();
  }

  /// Google requires the EEA consent dialog in front of the first ad request,
  /// and the same User Messaging Platform form is what says whether this device
  /// may be asked at all. Where no form is needed it stays silent.
  static Future<void> _collectConsent() async {
    final info = ConsentInformation.instance;
    try {
      // The SDK reports completion through callbacks, so the wait is bounded by
      // hand: with no network the app must not sit at the launch screen forever.
      await _requestConsentUpdate(info).timeout(const Duration(seconds: 10));
      await ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) debugPrint('Consent form did not show: $error');
      });
      _consentAllowsAds = await info.canRequestAds();
    } catch (error) {
      // Only Google's own "no" switches the ads off. A handshake that failed for
      // no network should not cost a player their rewarded ads all session, and
      // must not hold the game up either - the next launch asks again.
      debugPrint('Consent could not be gathered: $error');
    }
  }

  /// The SDK hands back completion callbacks, so the await has to be built by
  /// hand rather than chained off a future that does not exist.
  static Future<void> _requestConsentUpdate(ConsentInformation info) {
    final done = Completer<void>();
    info.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => done.complete(),
      (error) => done.completeError(error),
    );
    return done.future;
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

  /// The iOS half of this account exists in AdMob - the app ID is already in
  /// `ios/Runner/Info.plist` - but these three unit numbers were never filled
  /// in, and the build used to fall back to Google's demo IDs, which AdMob
  /// counts as invalid traffic on a live app.
  ///
  /// Paste the `ca-app-pub-1221200396997472/nnnnnnnnnn` strings from the AdMob
  /// iOS app here, one per line. While any of them is empty, that format asks
  /// for nothing on iPhone and iPad: a quiet, playable game beats a suspended
  /// account, and the Android IDs are untouched.
  static const String _iosBannerUnitId = '';
  static const String _iosInterstitialUnitId = '';
  static const String _iosRewardedUnitId = '';

  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-1221200396997472/9869856353'; // Real Banner ID
    } else if (Platform.isIOS) {
      return _iosBannerUnitId;
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-1221200396997472/7359563889'; // Real Interstitial ID
    } else if (Platform.isIOS) {
      return _iosInterstitialUnitId;
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-1221200396997472/4203801983'; // Real Rewarded ID
    } else if (Platform.isIOS) {
      return _iosRewardedUnitId;
    }
    return '';
  }

  /// An empty unit ID (iOS, until its real IDs land) or a withheld consent both
  /// mean the same thing to a caller: there is nothing to ask Google for.
  static bool get canRequestBannerAds => _adRequestable(bannerAdUnitId);

  static bool _adRequestable(String unitId) =>
      _consentAllowsAds && unitId.isNotEmpty;

  static InterstitialAd? _interstitialAd;

  static void loadInterstitialAd() {
    if (kIsWeb ||
        _hasRemovedAds ||
        _interstitialAd != null ||
        !_adRequestable(interstitialAdUnitId)) {
      return;
    }
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
    if (kIsWeb ||
        _rewardedAdLoading ||
        _rewardedAd != null ||
        !_adRequestable(rewardedAdUnitId)) {
      return;
    }
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
