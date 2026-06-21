import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_colors.dart';
import '../providers/theme_provider.dart';

/// Provides static access to the main shell's end drawer from any page.
class MainShellMenu {
  static final scaffoldKey = GlobalKey<ScaffoldState>();
  static void open() => scaffoldKey.currentState?.openEndDrawer();

  /// Botão padrão para colocar no AppBar de cada página.
  static Widget button() => IconButton(
    icon: Icon(Icons.menu_rounded),
    tooltip: 'Menu',
    onPressed: open,
  );

  /// Botão de configurações (conta, notificações, suporte, sair, encerrar).
  static Widget settingsButton() => Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.settings_rounded),
      tooltip: 'Settings',
      onPressed: () => context.push('/settings'),
    ),
  );

  /// Botão de alternar tema dark/light — coloque no AppBar antes de button().
  static Widget themeButton() => Consumer(
    builder: (context, ref, _) {
      final isDark = ref.watch(themeProvider) == ThemeMode.dark;
      return IconButton(
        icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
        tooltip: isDark ? 'Tema claro' : 'Tema escuro',
        onPressed: () => ref.read(themeProvider.notifier).state =
            isDark ? ThemeMode.light : ThemeMode.dark,
      );
    },
  );
}

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = MainShellMenu.scaffoldKey;

  // Real navigation destinations. The bottom bar appends a "Menu" launcher
  // after these that opens the end drawer instead of navigating.
  static const _tabs = [
    _Tab(icon: Icons.home_rounded,                    label: 'Home',      path: '/home'),
    _Tab(icon: Icons.account_balance_outlined,        label: 'Finance',   path: '/finance'),
    _Tab(icon: Icons.account_balance_wallet_rounded,  label: 'Portfolio', path: '/portfolio'),
    _Tab(icon: Icons.newspaper_rounded,               label: 'News',      path: '/news'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/us-macro')) return 1; // Finance tab
    final idx = _tabs.indexWhere((t) => location.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  void _onTap(int index) {
    // The trailing item is the Menu launcher → open the end drawer.
    if (index >= _tabs.length) {
      MainShellMenu.open();
      return;
    }
    context.go(_tabs[index].path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // ── End drawer = Tools only (account lives in Settings) ──────────────
      endDrawer: Drawer(
        backgroundColor: context.colors.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                child: Row(
                  children: [
                    Text('Menu',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: context.colors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              Divider(color: context.colors.surfaceAlt, height: 1),

              // ── Tools & markets ───────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _DrawerSection('Markets'),
                    _DrawerItem(
                      icon: Icons.currency_bitcoin,
                      label: 'Crypto',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go('/crypto');
                      },
                    ),
                    const SizedBox(height: 8),
                    _DrawerSection('Tools'),
                    _DrawerItem(
                      icon: Icons.star_rounded,
                      label: 'Watchlist',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/watchlist');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.manage_search_rounded,
                      label: 'Stock Screener',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/screener');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Rankings',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/rankings');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.grid_view_rounded,
                      label: 'Market Heatmap',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/heatmap');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.compare_arrows_rounded,
                      label: 'Compare Stocks',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/compare');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Editorial Rankings',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/editorial');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.calculate_rounded,
                      label: 'Calculators',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/calculators');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: widget.child,
      // ── Bottom nav ────────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.surfaceAlt)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex(context),
          onTap: _onTap,
          items: [
            ..._tabs.map((t) =>
                BottomNavigationBarItem(icon: Icon(t.icon), label: t.label)),
            const BottomNavigationBarItem(
                icon: Icon(Icons.menu_rounded), label: 'Menu'),
          ],
        ),
      ),
    );
  }
}

// ── Drawer: section header ────────────────────────────────────────────────────

class _DrawerSection extends StatelessWidget {
  final String title;
  const _DrawerSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: context.colors.textMuted, letterSpacing: 0.8)),
    );
  }
}

// ── Drawer: nav item ──────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: context.colors.textSecond),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final String path;
  const _Tab({required this.icon, required this.label, required this.path});
}
