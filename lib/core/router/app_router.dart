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
import '../shell/main_shell.dart';

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

    // Main shell with bottom nav
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home',      builder: (_, $) => const HomePage()),
        GoRoute(path: '/finance',   builder: (_, $) => const FinancePage()),
        GoRoute(path: '/portfolio', builder: (_, $) => const PortfolioPage()),
        GoRoute(path: '/news',      builder: (_, $) => const NewsPage()),
        GoRoute(path: '/crypto',    builder: (_, $) => const CryptoPage()),
        GoRoute(path: '/perfil',    builder: (_, $) => const PerfilPage()),
      ],
    ),
  ],
);
