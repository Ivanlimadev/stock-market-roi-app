import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';
import '../../core/providers/watchlist_provider.dart';
import '../../core/providers/screener_provider.dart';
import '../../core/models/market_model.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bottom_nav.dart';

class WatchlistPage extends ConsumerWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return Scaffold(
        bottomNavigationBar: const AppBottomNav(),
        appBar: AppBar(
          title: const Text('Watchlist'),
          actions: MainShellMenu.actions(),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_border_rounded, size: 64, color: context.colors.textMuted),
              const SizedBox(height: 16),
              Text('Sign in to manage your watchlist',
                  style: TextStyle(color: context.colors.textMuted, fontSize: 15)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/login'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Watchlist'),
          actions: MainShellMenu.actions(),
          bottom: TabBar(
            labelColor: AppColors.emerald,
            indicatorColor: AppColors.emerald,
            unselectedLabelColor: context.colors.textMuted,
            tabs: const [
              Tab(text: 'Watchlist'),
              Tab(text: 'Alerts'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _WatchlistTab(),
            _AlertsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Watchlist tab ─────────────────────────────────────────────────────────────

class _WatchlistTab extends ConsumerWidget {
  const _WatchlistTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wlAsync      = ref.watch(watchlistProvider);
    final screenerAsync = ref.watch(screenerProvider);

    return wlAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error loading watchlist',
            style: TextStyle(color: context.colors.textMuted)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.star_border_rounded,
            title: 'No stocks on your watchlist',
            subtitle:
                'Tap the ★ on any stock or crypto detail page to add it here.',
          );
        }

        final stockMap = screenerAsync.maybeWhen(
          data: (quotes) => {for (final q in quotes) q.symbol: q},
          orElse: () => <String, StockQuote>{},
        );

        return RefreshIndicator(
          color: AppColors.emerald,
          onRefresh: () async {
            ref.invalidate(watchlistProvider);
            ref.invalidate(screenerProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: context.colors.surfaceAlt),
            itemBuilder: (ctx, i) {
              final item = items[i];
              final quote = stockMap[item.symbol];
              return _WatchlistTile(
                item: item,
                quote: quote,
                onTap: () {
                  if (item.assetType == 'crypto') {
                    final coinId = item.coingeckoId ?? item.symbol.toLowerCase();
                    context.push('/crypto/$coinId');
                  } else {
                    context.push('/stocks/${item.symbol}');
                  }
                },
                onRemove: () async {
                  if (item.assetType == 'crypto') {
                    await WatchlistService.removeCrypto(
                        item.coingeckoId ?? item.symbol.toLowerCase());
                  } else {
                    await WatchlistService.removeStock(item.symbol);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _WatchlistTile extends StatelessWidget {
  final WatchlistItem item;
  final StockQuote? quote;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _WatchlistTile({
    required this.item,
    required this.quote,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final price     = quote?.price;
    final changePct = quote?.changePct;
    final isPos     = (changePct ?? 0) >= 0;
    final priceColor = changePct == null
        ? c.textMuted
        : (isPos ? AppColors.emerald : AppColors.red);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Leading icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: item.assetType == 'crypto'
                    ? const Color(0xFFF97316).withValues(alpha: 0.12)
                    : AppColors.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: item.image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(item.image!, width: 28, height: 28,
                            errorBuilder: (_, __, ___) =>
                                _SymbolIcon(item.symbol, item.assetType)),
                      )
                    : _SymbolIcon(item.symbol, item.assetType),
              ),
            ),
            const SizedBox(width: 12),
            // Symbol + name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.symbol,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(item.name,
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Price + change
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price != null
                      ? (item.assetType == 'crypto'
                          ? fmtCryptoPrice(price)
                          : fmtStockPrice(price))
                      : '—',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  changePct != null
                      ? '${isPos ? '+' : ''}${changePct.toStringAsFixed(2)}%'
                      : '—',
                  style: TextStyle(fontSize: 12, color: priceColor,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Remove button
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18,
                  color: c.textMuted),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _SymbolIcon extends StatelessWidget {
  final String symbol, assetType;
  const _SymbolIcon(this.symbol, this.assetType);

  @override
  Widget build(BuildContext context) {
    final color = assetType == 'crypto'
        ? const Color(0xFFF97316)
        : AppColors.emerald;
    return Text(
      symbol.length >= 2 ? symbol.substring(0, 2) : symbol,
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: color),
    );
  }
}

// ── Alerts tab ────────────────────────────────────────────────────────────────

class _AlertsTab extends ConsumerWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(alertsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error loading alerts',
            style: TextStyle(color: context.colors.textMuted)),
      ),
      data: (alerts) {
        if (alerts.isEmpty) {
          return _EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No price alerts set',
            subtitle:
                'Tap the 🔔 on any stock or crypto detail page to set an alert.',
          );
        }

        return RefreshIndicator(
          color: AppColors.emerald,
          onRefresh: () async => ref.invalidate(alertsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: alerts.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: context.colors.surfaceAlt),
            itemBuilder: (ctx, i) => _AlertTile(
              alert: alerts[i],
              onDelete: () => WatchlistService.deleteAlert(alerts[i].id),
            ),
          ),
        );
      },
    );
  }
}

class _AlertTile extends StatelessWidget {
  final PriceAlert alert;
  final VoidCallback onDelete;
  const _AlertTile({required this.alert, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c         = context.colors;
    final isAbove   = alert.condition == 'above';
    final triggered = alert.triggered;
    final condColor = triggered
        ? AppColors.emerald
        : (isAbove ? const Color(0xFF3B82F6) : AppColors.red);

    final priceFmt = alert.assetType == 'crypto'
        ? fmtCryptoPrice(alert.targetPrice)
        : fmtStockPrice(alert.targetPrice);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Leading icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: condColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              triggered
                  ? Icons.check_circle_outline_rounded
                  : (isAbove
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded),
              size: 18, color: condColor,
            ),
          ),
          const SizedBox(width: 12),
          // Symbol + condition
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(alert.symbol,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary)),
                    const SizedBox(width: 6),
                    if (triggered)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('Triggered',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emerald)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${isAbove ? 'Above' : 'Below'} $priceFmt',
                  style: TextStyle(
                      fontSize: 12,
                      color: condColor,
                      fontWeight: FontWeight.w600),
                ),
                if (alert.referencePrice != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Set at ${alert.assetType == 'crypto' ? fmtCryptoPrice(alert.referencePrice!) : fmtStockPrice(alert.referencePrice!)}',
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                  ),
                ],
              ],
            ),
          ),
          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 18,
                color: c.textMuted),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: c.textMuted),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: c.textMuted, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
