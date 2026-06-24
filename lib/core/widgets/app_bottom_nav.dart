import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'app_menu_sheet.dart';

/// Shared bottom navigation used on every screen (shell pages and pushed
/// full-screen pages). The trailing "Menu" item opens the app menu sheet.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  static const _items = [
    _NavItem(Icons.home_rounded,                   'Home',      '/home'),
    _NavItem(Icons.account_balance_outlined,       'Finance',   '/finance'),
    _NavItem(Icons.account_balance_wallet_rounded, 'Portfolio', '/portfolio'),
    _NavItem(Icons.newspaper_rounded,              'News',      '/news'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/us-macro')) return 1; // Finance tab
    final idx = _items.indexWhere((t) => location.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = _currentIndex(context);
    // Shrink the home-indicator gap that made the bar feel too tall.
    final inset = MediaQuery.of(context).padding.bottom;
    final bottomGap = inset > 0 ? (inset * 0.45).clamp(8.0, 18.0) : 6.0;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.surfaceAlt)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: List.generate(_items.length + 1, (i) {
                final isMenu = i == _items.length;
                final selected = !isMenu && i == current;
                final color = selected ? AppColors.emerald : c.textMuted;
                return Expanded(
                  child: InkWell(
                    onTap: () =>
                        isMenu ? showAppMenu(context) : context.go(_items[i].path),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isMenu ? Icons.menu_rounded : _items[i].icon,
                            size: 22, color: color),
                        const SizedBox(height: 2),
                        Text(
                          isMenu ? 'Menu' : _items[i].label,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: color,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: bottomGap),
        ],
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
