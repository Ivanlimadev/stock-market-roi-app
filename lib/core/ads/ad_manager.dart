import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../router/app_router.dart';
import 'ad_config.dart';
import 'app_open_manager.dart';
import 'att_priming.dart';

/// Centralised ad lifecycle + frequency control.
///
/// Strategy: few, high-value ads.
/// - **Interstitial** is rate-limited (min interval + 1 every N navigations)
///   and never shown during onboarding/auth.
/// - **Rewarded** is fully opt-in (user taps to unlock the AI analysis).
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  // ── Frequency rules (tune freely) ─────────────────────────────────────────
  static const Duration _minInterval = Duration(seconds: 90);
  static const int _navigationsPerInterstitial = 2;

  /// "Logical content breaks" — full-screen pages a user finishes and leaves.
  /// AdMob only allows interstitials *between* content, so we fire one when the
  /// user is LEAVING one of these (e.g. closing a calculator or a detail page),
  /// never when opening one.
  static const List<String> _breakpointPrefixes = [
    '/calculators/', // a specific calculator (not the hub)
    '/stocks/',      // stock detail
    '/crypto/',      // crypto detail
  ];

  static bool _isBreakpoint(String loc) =>
      _breakpointPrefixes.any(loc.startsWith);

  /// Screens that must NEVER trigger an interstitial (auth, onboarding, legal,
  /// settings). Refine this list when defining exact ad placements.
  static const List<String> _noAdPrefixes = [
    '/login', '/register', '/forgot-password',
    '/onboarding', '/privacy', '/terms', '/about', '/settings',
  ];

  bool _initialized = false;
  DateTime? _lastInterstitialShown;
  int _navCount = 0;
  String? _lastLocation;

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  /// Call once at startup (after WidgetsFlutterBinding.ensureInitialized).
  ///
  /// Order matters for GDPR: gather UMP consent first, then initialise the Ads
  /// SDK, then only request ads if consent allows it.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _gatherConsent();
    await _requestTrackingAuthorization();
    await MobileAds.instance.initialize();

    if (await ConsentInformation.instance.canRequestAds()) {
      _loadInterstitial();
      if (AdConfig.enableAppOpen) AppOpenAdManager.instance.start();
    }
  }

  /// True while any full-screen ad (interstitial, rewarded or App Open) is on
  /// screen — used so the formats never stack on top of each other.
  bool isShowingFullScreenAd = false;

  /// iOS App Tracking Transparency. Apple requires the ATT prompt before the
  /// app accesses the IDFA for personalized ads; without it Apple may reject
  /// the build and AdMob can only serve non-personalized ads. No-op on Android
  /// and when the status was already determined.
  Future<void> _requestTrackingAuthorization() async {
    if (!Platform.isIOS) return;
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;

      // Show a custom value explainer first — lifts the ATT opt-in rate, and
      // personalized ads earn materially more. The system prompt follows.
      final ctx = await _waitForContext();
      if (ctx != null && ctx.mounted) {
        await showAttPriming(ctx);
      }

      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (e) {
      debugPrint('[Ads] ATT request error: $e');
    }
  }

  /// Waits briefly for the root navigator to be mounted so we have a context to
  /// show the priming dialog (initialize() runs right after runApp).
  Future<BuildContext?> _waitForContext() async {
    for (var i = 0; i < 50; i++) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) return ctx;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return rootNavigatorKey.currentContext;
  }

  /// Runs the Google User Messaging Platform (UMP) flow: updates consent info
  /// and shows the consent form when required (e.g. EEA/UK users). Completes
  /// once the user has dismissed the form or no form is needed.
  Future<void> _gatherConsent() {
    final completer = Completer<void>();

    final params = ConsentRequestParameters(
      // In debug, force the EEA geography so the consent form can be verified
      // on the simulator. Has no effect in release builds.
      consentDebugSettings: kDebugMode
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea)
          : null,
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) {
            debugPrint('[Ads] consent form error: ${formError.message}');
          }
          if (!completer.isCompleted) completer.complete();
        });
      },
      (error) {
        debugPrint('[Ads] consent info error: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  /// Re-opens the privacy options form so users can change their choice later.
  /// Wire this to a "Privacy options" row in Settings (GDPR requires it).
  void showPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null) {
        debugPrint('[Ads] privacy options error: ${formError.message}');
      }
    });
  }

  /// Whether a "Privacy options" entry must be shown in the UI.
  Future<bool> get privacyOptionsRequired async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  /// Hook for the router: called on every location change. Fires an
  /// interstitial only when the user LEAVES a logical content break (closing a
  /// calculator or a detail page) and lands somewhere that allows ads — i.e.
  /// only at policy-compliant "between content" moments.
  void onNavigation(String location) {
    final prev = _lastLocation;
    if (location == prev) return;
    _lastLocation = location;
    if (prev == null) return; // first load — never an ad

    final leavingBreakpoint = _isBreakpoint(prev) && !_isBreakpoint(location);
    if (!leavingBreakpoint) return;
    if (_noAdPrefixes.any(location.startsWith)) return;

    maybeShowInterstitialOnNavigation();
  }

  // ── Interstitial ──────────────────────────────────────────────────────────

  void _loadInterstitial() {
    if (_loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          _loadingInterstitial = false;
          debugPrint('[Ads] interstitial failed: ${error.message}');
        },
      ),
    );
  }

  /// Register a navigation/transition. Shows an interstitial only when the
  /// frequency rules allow it. Returns true if an ad was shown.
  bool maybeShowInterstitialOnNavigation() {
    _navCount++;
    if (_navCount < _navigationsPerInterstitial) return false;

    final now = DateTime.now();
    if (_lastInterstitialShown != null &&
        now.difference(_lastInterstitialShown!) < _minInterval) {
      return false;
    }

    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial(); // not ready yet — preload for next time
      return false;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => isShowingFullScreenAd = true,
      onAdDismissedFullScreenContent: (ad) {
        isShowingFullScreenAd = false;
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        isShowingFullScreenAd = false;
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
      },
    );

    ad.show();
    _interstitial = null;
    _lastInterstitialShown = now;
    _navCount = 0;
    return true;
  }

  // ── Rewarded (opt-in) ─────────────────────────────────────────────────────

  /// Loads and shows a rewarded ad. [onReward] fires only if the user watches
  /// it to completion (e.g. unlock the AI analysis). [onUnavailable] fires when
  /// no ad could be loaded/shown.
  void showRewarded({
    required VoidCallback onReward,
    VoidCallback? onUnavailable,
  }) {
    RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) => isShowingFullScreenAd = true,
            onAdDismissedFullScreenContent: (ad) {
              isShowingFullScreenAd = false;
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              isShowingFullScreenAd = false;
              ad.dispose();
              onUnavailable?.call();
            },
          );
          ad.show(onUserEarnedReward: (ad, reward) => onReward());
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ads] rewarded failed: ${error.message}');
          onUnavailable?.call();
        },
      ),
    );
  }
}
