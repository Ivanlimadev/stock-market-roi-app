# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`stock_market_roi_app` — the Flutter (iOS-first) mobile app for **Stock Market ROI**
(stockmarketroi.com). It is a thin client: it renders data but owns almost no
market data itself.

- **Market data** (quotes, screener, crypto, calendar, macro, blog) comes from the
  **backend** at `https://stockmarketroi.com/api`. That backend is a separate repo:
  **`us-market-hub`** (Next.js 15, hosted on a VPS). If a `/api/...` response looks
  wrong, the fix is almost always in `us-market-hub`, not here.
- **User data** (auth, portfolio, watchlist, price alerts, finance, FCM tokens,
  notification prefs) lives in **Supabase** (project `ogbramvzqmbkizspeccg`) and is
  read/written directly from the app via `supabase_flutter`.
- **Realtime crypto prices** come straight from **Kraken** over WebSocket
  (`lib/core/providers/realtime_price_provider.dart`), not the backend.

## Commands

```bash
flutter pub get                      # install deps
flutter run -d <device-id>           # run (use `flutter devices` / a simulator UDID)
flutter analyze                      # lint/static analysis (flutter_lints)
flutter test                         # tests (only the default test/widget_test.dart exists)
flutter build ipa                    # iOS release build
```

`flutter run` defaults to debug mode, which matters for ads (see below). After
editing native deps (`pubspec.yaml` plugins), `flutter run` re-runs `pod install`
automatically.

### Environment / secrets

Supabase URL + anon key are read via `String.fromEnvironment` in `lib/main.dart`
with **hardcoded fallback defaults**, so the app runs without flags. Override with:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Architecture

- **State**: Riverpod. Data sources are `FutureProvider`/`StateNotifier` in
  `lib/core/providers/`. UI screens live in `lib/features/<feature>/`; shared
  building blocks in `lib/core/{widgets,models,theme,utils}`.
- **Networking**: `lib/core/api/api_client.dart` — a single `dio` client pointed at
  `https://stockmarketroi.com/api`. All backend calls go through `ApiClient.get`.
- **Routing**: `lib/core/router/app_router.dart` (go_router). A `redirect` gate forces
  `/login` when there is no Supabase session (only `/login`, `/register`,
  `/forgot-password`, `/privacy`, `/terms` are public). Most screens live inside a
  shell with the bottom nav (`lib/core/shell/`); detail/tool pages are pushed
  full-screen. `rootNavigatorKey` is exported so non-widget code (ATT priming) can
  show dialogs.
- **Startup** (`lib/main.dart`): `Supabase.initialize` and `Firebase.initializeApp`
  run before `runApp`; notifications and ads initialize *after* `runApp` so their
  permission prompts don't block the first frame.

### Ads (`lib/core/ads/`) — revenue-critical, handle carefully

- `AdConfig` returns **Google test ad unit IDs in `kDebugMode`** and real IDs in
  release. **Ads basically never serve on the iOS simulator** (network errors) — the
  widgets render `SizedBox.shrink` and gates fall through, so test real ads on a
  physical device registered as an AdMob test device.
- `AdManager` (singleton): UMP/GDPR consent → **ATT priming dialog**
  (`att_priming.dart`, iOS only, lifts opt-in) → `requestTrackingAuthorization` →
  init Mobile Ads. Owns interstitial (rate-limited, fired only when *leaving* a
  `/stocks/`, `/crypto/`, `/calculators/` page) and rewarded. `isShowingFullScreenAd`
  coordinates so formats never stack.
- `AppOpenAdManager`: shows on warm resume only (lifecycle observer), with a
  cold-start grace, 4 h expiry, and frequency cap.
- `RewardedGate` + `RewardedUnlocks`: reusable "watch a short ad to unlock"
  wrapper. Unlocks are **global per feature for the session** (one ad unlocks e.g.
  SEC filings for every stock). Used for AI Insight, SEC Filings, Insiders,
  Financials, and the Compare table. **Don't stack many gates on one screen** —
  spread them across screens to protect retention.
- `NativeAdTile` (News list + in-article in long blog posts) and
  `CollapsibleBannerAd` (anchored above the bottom nav on the stock detail).
- **TODO carried in `AdConfig`**: the real iOS **App Open** and **Banner** ad units
  are still test-ID placeholders — create them in the AdMob console and swap
  `_iosAppOpenReal` / `_iosBannerReal` before release.

### Push notifications

`lib/core/services/notification_service.dart` handles FCM on the client (permission,
token → `user_fcm_tokens`, foreground/tap, deep-link via `_navigateFromData`). The
**sending** side is **Supabase Edge Functions + pg_cron**, not the app: market-close
(personalized portfolio/movers recap), market-open (earnings heads-up for held/
watched stocks), price alerts, dividends, blog posts. Each respects a column in
`notification_preferences` (toggled in `lib/features/settings/notifications_page.dart`
via `notification_prefs_provider.dart`). Push does not serve on the simulator.

## Gotchas

- **Supabase: new tables need GRANTs, not just RLS.** This project's tables had RLS
  enabled but the `authenticated`/`service_role` roles were missing table GRANTs,
  so every insert failed with Postgres error `42501` and tables stayed empty. When
  adding a table/feature, `GRANT SELECT, INSERT, UPDATE, DELETE ... TO authenticated`
  (and `service_role` for anything an Edge Function touches) in addition to the RLS
  policy — an RLS policy with no table grant blocks everything.
- The app shows **only the project's own blog**, never external news sources.
- `flutter analyze` carries many pre-existing `info`-level lints; only new
  `error`/`warning` matter.
