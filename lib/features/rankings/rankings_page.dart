import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';
import '../../core/providers/screener_provider.dart';
import '../../core/models/market_model.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bottom_nav.dart';

// ── Derived providers for top 20 ──────────────────────────────────────────────

final _top20GainersProvider =
    Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) =>
        ref.watch(screenerProvider).whenData((s) => ([...s]
          ..removeWhere((q) => q.changePct <= 0)
          ..sort((a, b) => b.changePct.compareTo(a.changePct)))
            .take(20).toList()));

final _top20LosersProvider =
    Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) =>
        ref.watch(screenerProvider).whenData((s) => ([...s]
          ..removeWhere((q) => q.changePct >= 0)
          ..sort((a, b) => a.changePct.compareTo(b.changePct)))
            .take(20).toList()));

final _top20VolumeProvider =
    Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) =>
        ref.watch(screenerProvider).whenData((s) => ([...s]
          ..removeWhere((q) => (q.volume ?? 0) == 0)
          ..sort((a, b) => (b.volume ?? 0).compareTo(a.volume ?? 0)))
            .take(20).toList()));

final _top20MarketCapProvider =
    Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) =>
        ref.watch(screenerProvider).whenData((s) => ([...s]
          ..removeWhere((q) => (q.marketCap ?? 0) == 0)
          ..sort((a, b) => (b.marketCap ?? 0).compareTo(a.marketCap ?? 0)))
            .take(20).toList()));

final _top20DividendProvider =
    Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) =>
        ref.watch(screenerProvider).whenData((s) => ([...s]
          ..removeWhere((q) => (q.dividendYield ?? 0) == 0)
          ..sort((a, b) =>
              (b.dividendYield ?? 0).compareTo(a.dividendYield ?? 0)))
            .take(20).toList()));

// ── Page ──────────────────────────────────────────────────────────────────────

class RankingsPage extends ConsumerWidget {
  const RankingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        bottomNavigationBar: const AppBottomNav(),
        appBar: AppBar(
          title: const Text('Rankings'),
          actions: MainShellMenu.actions(),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.emerald,
            indicatorColor: AppColors.emerald,
            unselectedLabelColor: context.colors.textMuted,
            tabs: const [
              Tab(text: 'Top Gainers'),
              Tab(text: 'Top Losers'),
              Tab(text: 'Volume'),
              Tab(text: 'Market Cap'),
              Tab(text: 'Dividends'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RankList(
              provider: _top20GainersProvider,
              valueLabel: '24h%',
              valueFor: (q) =>
                  '${q.changePct >= 0 ? '+' : ''}${q.changePct.toStringAsFixed(2)}%',
              colorFor: (q) =>
                  q.changePct >= 0 ? AppColors.emerald : AppColors.red,
              emptyMsg: 'No gainers today',
            ),
            _RankList(
              provider: _top20LosersProvider,
              valueLabel: '24h%',
              valueFor: (q) =>
                  '${q.changePct >= 0 ? '+' : ''}${q.changePct.toStringAsFixed(2)}%',
              colorFor: (q) => AppColors.red,
              emptyMsg: 'No losers today',
            ),
            _RankList(
              provider: _top20VolumeProvider,
              valueLabel: 'Volume',
              valueFor: (q) => fmtBigUsd(q.volume),
              colorFor: (_) => const Color(0xFF3B82F6),
              emptyMsg: 'No data',
            ),
            _RankList(
              provider: _top20MarketCapProvider,
              valueLabel: 'Mkt Cap',
              valueFor: (q) => fmtBigUsd(q.marketCap),
              colorFor: (_) => const Color(0xFF8B5CF6),
              emptyMsg: 'No data',
            ),
            _RankList(
              provider: _top20DividendProvider,
              valueLabel: 'Div Yield',
              valueFor: (q) {
                final pct = (q.dividendYield ?? 0) * 100;
                return '${pct.toStringAsFixed(2)}%';
              },
              colorFor: (_) => const Color(0xFFF59E0B),
              emptyMsg: 'No dividend payers',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ranked list ───────────────────────────────────────────────────────────────

class _RankList extends ConsumerWidget {
  final ProviderListenable<AsyncValue<List<StockQuote>>> provider;
  final String valueLabel;
  final String Function(StockQuote) valueFor;
  final Color Function(StockQuote) colorFor;
  final String emptyMsg;

  const _RankList({
    required this.provider,
    required this.valueLabel,
    required this.valueFor,
    required this.colorFor,
    required this.emptyMsg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c     = context.colors;
    final async = ref.watch(provider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error loading rankings',
            style: TextStyle(color: c.textMuted)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
              child: Text(emptyMsg, style: TextStyle(color: c.textMuted)));
        }
        return RefreshIndicator(
          color: AppColors.emerald,
          onRefresh: () async => ref.invalidate(screenerProvider),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: c.surfaceAlt),
            itemBuilder: (ctx, i) {
              final q     = items[i];
              final color = colorFor(q);
              return InkWell(
                onTap: () => context.push('/stocks/${q.symbol}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Rank
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: i < 3 ? AppColors.emerald : c.textMuted,
                          ),
                        ),
                      ),
                      // Symbol + name + sector
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(q.symbol,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary)),
                            const SizedBox(height: 1),
                            Text(q.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: c.textMuted)),
                          ],
                        ),
                      ),
                      // Price + value
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(fmtStockPrice(q.price),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              valueFor(q),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
