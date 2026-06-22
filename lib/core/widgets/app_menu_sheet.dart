import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// App-wide menu (tools + markets) shown as a modal bottom sheet so it works
/// from any screen — shell pages and pushed full-screen pages alike.
Future<void> showAppMenu(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: context.colors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AppMenu(parentContext: context),
  );
}

class _AppMenu extends StatelessWidget {
  /// The pushing page's context — used for navigation after the sheet closes.
  final BuildContext parentContext;
  const _AppMenu({required this.parentContext});

  void _go(BuildContext sheetCtx, String path) {
    Navigator.of(sheetCtx).pop();
    parentContext.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              Text('Menu',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, color: c.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          Divider(color: c.surfaceAlt, height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const _MenuSection('Markets'),
                _MenuItem(
                  icon: Icons.currency_bitcoin,
                  label: 'Crypto',
                  onTap: () => _go(context, '/crypto'),
                ),
                _MenuItem(
                  icon: Icons.event_rounded,
                  label: 'Calendar',
                  onTap: () => _go(context, '/calendar'),
                ),
                const SizedBox(height: 8),
                const _MenuSection('Tools'),
                _MenuItem(
                  icon: Icons.star_rounded,
                  label: 'Watchlist',
                  onTap: () => _go(context, '/watchlist'),
                ),
                _MenuItem(
                  icon: Icons.manage_search_rounded,
                  label: 'Stock Screener',
                  onTap: () => _go(context, '/screener'),
                ),
                _MenuItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Rankings',
                  onTap: () => _go(context, '/rankings'),
                ),
                _MenuItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Market Heatmap',
                  onTap: () => _go(context, '/heatmap'),
                ),
                _MenuItem(
                  icon: Icons.compare_arrows_rounded,
                  label: 'Compare Stocks',
                  onTap: () => _go(context, '/compare'),
                ),
                _MenuItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Editorial Rankings',
                  onTap: () => _go(context, '/editorial'),
                ),
                _MenuItem(
                  icon: Icons.calculate_rounded,
                  label: 'Calculators',
                  onTap: () => _go(context, '/calculators'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  const _MenuSection(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.colors.textMuted,
                letterSpacing: 0.8)),
      );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: c.textSecond),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary)),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
        ]),
      ),
    );
  }
}
