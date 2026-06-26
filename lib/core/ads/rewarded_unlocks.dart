import 'package:flutter/foundation.dart';

/// Session-scoped registry of features the user unlocked by watching a rewarded
/// ad.
///
/// Unlocks are **global per feature** — watching one ad to see SEC filings
/// unlocks them for every stock for the rest of the session. That earns a
/// high-eCPM rewarded impression without nagging the user on every screen.
/// Cleared when the app process restarts.
class RewardedUnlocks {
  RewardedUnlocks._();

  // Feature keys.
  static const secFilings = 'sec_filings';
  static const insiders = 'insiders';
  static const financials = 'financials';
  static const compare = 'compare';

  static final ValueNotifier<Set<String>> _unlocked =
      ValueNotifier<Set<String>>(<String>{});

  static ValueListenable<Set<String>> get listenable => _unlocked;

  static bool isUnlocked(String key) => _unlocked.value.contains(key);

  static void unlock(String key) {
    if (_unlocked.value.contains(key)) return;
    _unlocked.value = {..._unlocked.value, key};
  }
}
