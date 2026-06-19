import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  static const _items = [
    _NavItem(Icons.home_rounded,                   'Home',      '/home'),
    _NavItem(Icons.account_balance_outlined,       'Finance',   '/finance'),
    _NavItem(Icons.account_balance_wallet_rounded, 'Portfolio', '/portfolio'),
    _NavItem(Icons.newspaper_rounded,              'News',      '/news'),
    _NavItem(Icons.currency_bitcoin,               'Crypto',    '/crypto'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _items.indexWhere((t) => location.startsWith(t.path));

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.surfaceAlt)),
      ),
      child: BottomNavigationBar(
        currentIndex: idx < 0 ? 0 : idx,
        onTap: (i) => context.go(_items[i].path),
        items: _items
            .map((t) => BottomNavigationBarItem(icon: Icon(t.icon), label: t.label))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem(this.icon, this.label, this.path);
}
