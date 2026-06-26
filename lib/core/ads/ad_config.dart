import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Central AdMob configuration.
///
/// In **debug** builds the app always serves Google's official *test* ad units
/// — using real ad unit IDs during development can get the AdMob account
/// suspended. In **release** builds the real production IDs are used.
///
/// Android IDs are still test placeholders until the Android app + ad units
/// are created in the AdMob console. Swap [_androidInterstitialReal] /
/// [_androidRewardedReal] (and the Android App ID in AndroidManifest.xml)
/// once they exist.
class AdConfig {
  AdConfig._();

  // ── Real production IDs ───────────────────────────────────────────────────
  // iOS — created in the AdMob console (app ca-app-pub-7113858977365190~6934968222)
  static const _iosInterstitialReal = 'ca-app-pub-7113858977365190/6788618243';
  static const _iosRewardedReal     = 'ca-app-pub-7113858977365190/2849373232';

  // Android — TODO: replace with real IDs once the Android app is created.
  static const _androidInterstitialReal = 'ca-app-pub-3940256099942544/1033173712';
  static const _androidRewardedReal     = 'ca-app-pub-3940256099942544/5224354917';

  // Native — iOS real (created in console). Android still a test placeholder
  // until the Android app + native unit are created.
  static const _iosNativeReal     = 'ca-app-pub-7113858977365190/9172073158';
  static const _androidNativeReal = 'ca-app-pub-3940256099942544/2247696110';

  // App Open — TODO: create the App Open ad unit in the AdMob console and
  // replace _iosAppOpenReal. Until then it falls back to Google's test unit so
  // release builds won't crash (but earn nothing from App Open).
  static const _iosAppOpenReal     = 'ca-app-pub-3940256099942544/5575463023';
  static const _androidAppOpenReal = 'ca-app-pub-3940256099942544/9257395921';

  // Banner (collapsible) — TODO: create the Banner ad unit in the AdMob console
  // and replace _iosBannerReal. Falls back to the test unit until then.
  static const _iosBannerReal     = 'ca-app-pub-3940256099942544/2934735716';
  static const _androidBannerReal = 'ca-app-pub-3940256099942544/6300978111';

  // ── Google official TEST IDs (safe for development) ───────────────────────
  static const _iosInterstitialTest     = 'ca-app-pub-3940256099942544/4411468910';
  static const _iosRewardedTest         = 'ca-app-pub-3940256099942544/1712485313';
  static const _iosNativeTest           = 'ca-app-pub-3940256099942544/3986624511';
  static const _iosAppOpenTest          = 'ca-app-pub-3940256099942544/5575463023';
  static const _iosBannerTest           = 'ca-app-pub-3940256099942544/2934735716';
  static const _androidInterstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const _androidRewardedTest     = 'ca-app-pub-3940256099942544/5224354917';
  static const _androidNativeTest       = 'ca-app-pub-3940256099942544/2247696110';
  static const _androidAppOpenTest      = 'ca-app-pub-3940256099942544/9257395921';
  static const _androidBannerTest       = 'ca-app-pub-3940256099942544/6300978111';

  static bool get _isIOS => Platform.isIOS;

  /// Interstitial ad unit for the current platform/build mode.
  static String get interstitialUnitId {
    if (kDebugMode) {
      return _isIOS ? _iosInterstitialTest : _androidInterstitialTest;
    }
    return _isIOS ? _iosInterstitialReal : _androidInterstitialReal;
  }

  /// Rewarded ad unit for the current platform/build mode.
  static String get rewardedUnitId {
    if (kDebugMode) {
      return _isIOS ? _iosRewardedTest : _androidRewardedTest;
    }
    return _isIOS ? _iosRewardedReal : _androidRewardedReal;
  }

  /// Native ad unit for the current platform/build mode.
  static String get nativeUnitId {
    if (kDebugMode) {
      return _isIOS ? _iosNativeTest : _androidNativeTest;
    }
    return _isIOS ? _iosNativeReal : _androidNativeReal;
  }

  /// App Open ad unit for the current platform/build mode.
  static String get appOpenUnitId {
    if (kDebugMode) {
      return _isIOS ? _iosAppOpenTest : _androidAppOpenTest;
    }
    return _isIOS ? _iosAppOpenReal : _androidAppOpenReal;
  }

  /// Banner (collapsible) ad unit for the current platform/build mode.
  static String get bannerUnitId {
    if (kDebugMode) {
      return _isIOS ? _iosBannerTest : _androidBannerTest;
    }
    return _isIOS ? _iosBannerReal : _androidBannerReal;
  }
}
