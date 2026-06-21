import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/home/home_page.dart';
import '../../features/stocks/stock_detail_page.dart';
import '../../features/finance/finance_page.dart';
import '../../features/portfolio/portfolio_page.dart';
import '../../features/news/news_page.dart';
import '../../features/crypto/crypto_page.dart';
import '../../features/crypto/crypto_detail_page.dart';
import '../../features/perfil/perfil_page.dart';
import '../../features/blog/blog_post_page.dart';
import '../../core/models/blog_post_model.dart';
import '../shell/main_shell.dart';
import '../../features/calculators/calculators_hub_page.dart';
import '../../features/calculators/compound_interest_page.dart';
import '../../features/calculators/simple_interest_page.dart';
import '../../features/calculators/first_million_page.dart';
import '../../features/calculators/percentage_page.dart';
import '../../features/calculators/dca_page.dart';
import '../../features/calculators/roi_page.dart';
import '../../features/watchlist/watchlist_page.dart';
import '../../features/screener/screener_page.dart';
import '../../features/rankings/rankings_page.dart';
import '../../features/heatmap/heatmap_page.dart';
import '../../features/compare/compare_page.dart';
import '../../features/editorial/editorial_rankings_page.dart';
import '../../features/finance/us_macro_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/notifications_page.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/home',
  redirect: (context, state) {
    final session  = Supabase.instance.client.auth.currentSession;
    final isAuth   = session != null;
    final isOnAuth = state.matchedLocation.startsWith('/login') ||
        state.matchedLocation.startsWith('/register') ||
        state.matchedLocation.startsWith('/forgot-password');

    if (isAuth && isOnAuth) return '/home';
    return null;
  },
  routes: [
    // Auth (outside shell — no bottom nav)
    GoRoute(path: '/login',           builder: (_, $) => const LoginPage()),
    GoRoute(path: '/register',        builder: (_, $) => const RegisterPage()),
    GoRoute(path: '/forgot-password', builder: (_, $) => const ForgotPasswordPage()),

    // Settings — outside shell (full screen, back button)
    GoRoute(path: '/settings',  builder: (_, $) => const SettingsPage()),
    GoRoute(path: '/settings/notifications', builder: (_, $) => const NotificationsPage()),

    // My Account — outside shell (avoids a 2nd MainShell / duplicate scaffoldKey
    // when pushed on top of a shell route from Settings)
    GoRoute(path: '/perfil',    builder: (_, $) => const PerfilPage()),

    // Crypto — outside shell so it can be pushed from the Menu with a back button
    GoRoute(path: '/crypto',    builder: (_, $) => const CryptoPage()),

    // Watchlist — outside shell (full screen, back button)
    GoRoute(path: '/watchlist', builder: (_, $) => const WatchlistPage()),

    // Screener — outside shell
    GoRoute(path: '/screener',  builder: (_, $) => const ScreenerPage()),

    // Rankings — outside shell
    GoRoute(path: '/rankings',  builder: (_, $) => const RankingsPage()),

    // Heatmap — outside shell
    GoRoute(path: '/heatmap',   builder: (_, $) => const HeatmapPage()),

    // Compare — outside shell
    GoRoute(path: '/compare',   builder: (_, $) => const ComparePage()),

    // Editorial rankings — outside shell
    GoRoute(
      path: '/editorial',
      builder: (_, $) => const EditorialHubPage(),
      routes: [
        GoRoute(
          path: ':slug',
          builder: (_, state) => EditorialListPage(
              slug: state.pathParameters['slug'] ?? ''),
        ),
      ],
    ),

    // Calculators — outside shell (full screen, back button)
    GoRoute(
      path: '/calculators',
      builder: (_, $) => const CalculatorsHubPage(),
      routes: [
        GoRoute(path: 'compound-interest', builder: (_, $) => const CompoundInterestPage()),
        GoRoute(path: 'simple-interest',   builder: (_, $) => const SimpleInterestPage()),
        GoRoute(path: 'first-million',     builder: (_, $) => const FirstMillionPage()),
        GoRoute(path: 'percentage',        builder: (_, $) => const PercentagePage()),
        GoRoute(path: 'dca',               builder: (_, $) => const DCAPage()),
        GoRoute(path: 'roi',               builder: (_, $) => const ROIPage()),
      ],
    ),

    // Detail pages — outside shell (full screen, back button, no bottom nav)
    GoRoute(
      path: '/stocks/:symbol',
      builder: (_, state) =>
          StockDetailPage(symbol: state.pathParameters['symbol'] ?? ''),
    ),
    GoRoute(
      path: '/crypto/:id',
      builder: (_, state) =>
          CryptoDetailPage(coinId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/blog/:slug',
      builder: (_, state) {
        final slug = state.pathParameters['slug'] ?? '';
        final extra = state.extra;
        return BlogPostPage(
          slug: slug,
          post: extra is BlogPost ? extra : null,
        );
      },
    ),

    // Main shell with bottom nav
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home',      builder: (_, $) => const HomePage()),
        GoRoute(path: '/finance',   builder: (_, $) => const FinancePage()),
        GoRoute(path: '/portfolio', builder: (_, $) => const PortfolioPage()),
        GoRoute(path: '/news',      builder: (_, $) => const NewsPage()),
        GoRoute(path: '/us-macro',  builder: (_, $) => const UsMacroPage()),
      ],
    ),
  ],
);
