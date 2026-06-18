import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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

  static const _tabs = [
    _Tab(icon: Icons.home_rounded,                    label: 'Home',     path: '/home'),
    _Tab(icon: Icons.account_balance_outlined,        label: 'Finance',  path: '/finance'),
    _Tab(icon: Icons.account_balance_wallet_rounded,  label: 'Portfolio', path: '/portfolio'),
    _Tab(icon: Icons.newspaper_rounded,               label: 'News',     path: '/news'),
    _Tab(icon: Icons.currency_bitcoin,                label: 'Crypto',   path: '/crypto'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => location.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  void _onTap(int index) => context.go(_tabs[index].path);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // ── End drawer = Perfil ──────────────────────────────────────────────
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

              // ── User info ─────────────────────────────────────────────────
              _DrawerUser(user: Supabase.instance.client.auth.currentUser),

              Divider(color: context.colors.surfaceAlt, height: 1),

              // ── Nav items ─────────────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _DrawerSection('Account'),
                    _DrawerItem(
                      icon: Icons.person_rounded,
                      label: 'My Account',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/perfil');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.notifications_rounded,
                      label: 'Notifications',
                      badge: 'Coming soon',
                      onTap: () {},
                    ),
                    _DrawerItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'My Portfolio',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go('/portfolio');
                      },
                    ),
                    const SizedBox(height: 8),
                    _DrawerSection('Tools'),
                    _DrawerItem(
                      icon: Icons.calculate_rounded,
                      label: 'Calculators',
                      badge: 'Coming soon',
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    _DrawerSection('Help'),
                    _DrawerItem(
                      icon: Icons.support_agent_rounded,
                      label: 'Support',
                      onTap: () {
                        Navigator.of(context).pop();
                        launchUrl(
                          Uri.parse('mailto:contato@stockmarketroi.com'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Sign out (logged in only) ──────────────────────────────────
              _DrawerSignOut(user: Supabase.instance.client.auth.currentUser),
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
          items: _tabs
              .map((t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.label))
              .toList(),
        ),
      ),
    );
  }
}

// ── Drawer: user info strip ───────────────────────────────────────────────────

class _DrawerUser extends StatelessWidget {
  final User? user;
  const _DrawerUser({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.person_outline_rounded,
                  size: 22, color: context.colors.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Visitante',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary)),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/login');
                    },
                    child: Text('Entrar ou criar conta',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.emerald,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final email    = user!.email ?? '';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(initials,
                  style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold, color: AppColors.emerald)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Minha Conta',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              ],
            ),
          ),
        ],
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
  final String? badge;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
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
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: context.colors.textMuted)),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Drawer: sign out (bottom) ─────────────────────────────────────────────────

class _DrawerSignOut extends StatefulWidget {
  final User? user;
  const _DrawerSignOut({required this.user});

  @override
  State<_DrawerSignOut> createState() => _DrawerSignOutState();
}

class _DrawerSignOutState extends State<_DrawerSignOut> {
  bool _loading = false;

  Future<void> _signOut() async {
    setState(() => _loading = true);
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      setState(() => _loading = false);
      Navigator.of(context).pop();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/register');
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Create free account',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _signOut,
        icon: _loading
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red))
            : Icon(Icons.logout_rounded, size: 16),
        label: Text('Sair da conta'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.red,
          side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
