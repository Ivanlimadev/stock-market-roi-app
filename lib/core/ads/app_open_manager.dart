import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../router/app_router.dart';
import 'ad_config.dart';
import 'ad_manager.dart';

/// Shows an App Open ad when the user brings the app back from the background
/// (warm resume) — the highest-eCPM placement after rewarded.
///
/// Deliberately conservative so it stays policy-compliant and doesn't hurt
/// retention:
/// - Never on cold start (collides with consent/ATT/notification prompts).
/// - Never over another full-screen ad (coordinates via [AdManager]).
/// - Never on auth/onboarding/legal screens.
/// - Rate-limited so quick app-switching doesn't spam it.
/// - Cached ads expire after 4h (AdMob requirement) and are reloaded.
class AppOpenAdManager with WidgetsBindingObserver {
  AppOpenAdManager._();
  static final AppOpenAdManager instance = AppOpenAdManager._();

  static const Duration _expiry = Duration(hours: 4);
  static const Duration _minInterval = Duration(minutes: 4);
  // Grace window after launch so the first (cold-start) resume is skipped.
  static const Duration _coldStartGrace = Duration(seconds: 10);

  // Screens that must never be interrupted by an App Open ad.
  static const List<String> _noAdPrefixes = [
    '/login', '/register', '/forgot-password',
    '/onboarding', '/privacy', '/terms', '/about',
  ];

  final DateTime _appStart = DateTime.now();
  AppOpenAd? _ad;
  DateTime? _loadTime;
  DateTime? _lastShown;
  bool _showing = false;
  bool _started = false;

  /// Registers the lifecycle observer and preloads the first ad. Safe to call
  /// more than once. Call only after ads consent allows requests.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _load() {
    AppOpenAd.load(
      adUnitId: AdConfig.appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadTime = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ads] appOpen failed: ${error.message}');
        },
      ),
    );
  }

  bool get _isExpired =>
      _loadTime == null || DateTime.now().difference(_loadTime!) > _expiry;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _showIfEligible();
  }

  void _showIfEligible() {
    final now = DateTime.now();

    // Skip the cold-start resume (consent/ATT/notification prompts run there).
    if (now.difference(_appStart) < _coldStartGrace) return;
    // Don't stack on top of an interstitial/rewarded that's already showing.
    if (_showing || AdManager.instance.isShowingFullScreenAd) return;
    // Frequency cap.
    if (_lastShown != null && now.difference(_lastShown!) < _minInterval) return;
    // Not on auth/onboarding/legal screens.
    final loc = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (_noAdPrefixes.any(loc.startsWith)) return;

    final ad = _ad;
    if (ad == null || _isExpired) {
      _ad?.dispose();
      _ad = null;
      _load(); // preload for next time
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _showing = true;
        AdManager.instance.isShowingFullScreenAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _showing = false;
        _lastShown = DateTime.now();
        AdManager.instance.isShowingFullScreenAd = false;
        ad.dispose();
        _ad = null;
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _showing = false;
        AdManager.instance.isShowingFullScreenAd = false;
        ad.dispose();
        _ad = null;
        _load();
      },
    );
    ad.show();
  }
}
