import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/screener_provider.dart';
import '../../core/models/market_model.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bottom_nav.dart';

// ── Editorial list definitions ────────────────────────────────────────────────

class _Editorial {
  final String path, title, subtitle;
  final IconData icon;
  final Color color;
  final List<StockQuote> Function(List<StockQuote>) filter;

  const _Editorial({
    required this.path,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.filter,
  });
}

final _editorials = [
  _Editorial(
    path:     'best-dividend-stocks',
    title:    'Best Dividend Stocks',
    subtitle: 'Highest yield + positive earnings',
    icon:     Icons.monetization_on_outlined,
    color:    const Color(0xFFF59E0B),
    filter: (all) => ([...all]
      ..removeWhere((q) =>
          (q.dividendYield ?? 0) == 0 || q.changePct < -20 || q.pe == null)
      ..sort((a, b) =>
          (b.dividendYield ?? 0).compareTo(a.dividendYield ?? 0)))
        .take(25).toList(),
  ),
  _Editorial(
    path:     'best-growth-stocks',
    title:    'Best Growth Stocks',
    subtitle: 'Strong momentum + revenue growth signals',
    icon:     Icons.trending_up_rounded,
    color:    AppColors.emerald,
    filter: (all) => ([...all]
      ..removeWhere((q) => q.changePct < 0 || (q.marketCap ?? 0) < 1e9)
      ..sort((a, b) => b.changePct.compareTo(a.changePct)))
        .take(25).toList(),
  ),
  _Editorial(
    path:     'undervalued-stocks',
    title:    'Undervalued Stocks',
    subtitle: 'Low P/E + positive earnings',
    icon:     Icons.local_offer_outlined,
    color:    const Color(0xFF3B82F6),
    filter: (all) => ([...all]
      ..removeWhere((q) =>
          q.pe == null || q.pe! <= 0 || q.pe! > 20 ||
          (q.marketCap ?? 0) < 500e6)
      ..sort((a, b) => (a.pe ?? 999).compareTo(b.pe ?? 999)))
        .take(25).toList(),
  ),
];

// ── Hub page ──────────────────────────────────────────────────────────────────

class EditorialHubPage extends StatelessWidget {
  const EditorialHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('Editorial Rankings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Curated lists based on real-time screener data.',
              style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.5),
            ),
            const SizedBox(height: 16),
            ..._editorials.map((ed) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => context.push('/editorial/${ed.path}'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: ed.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(ed.icon, size: 22, color: ed.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ed.title,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary)),
                            const SizedBox(height: 3),
                            Text(ed.subtitle,
                                style: TextStyle(
                                    fontSize: 12, color: c.textMuted)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: c.textMuted),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Detail list page ──────────────────────────────────────────────────────────

class EditorialListPage extends ConsumerWidget {
  final String slug;
  const EditorialListPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ed = _editorials.firstWhere(
      (e) => e.path == slug,
      orElse: () => _editorials.first,
    );
    final async = ref.watch(screenerProvider);
    final c = context.colors;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: Text(ed.title)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(screenerProvider),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emerald,
                    side: BorderSide(color: AppColors.emerald),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (all) {
            final items = ed.filter(all);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(ed.icon, size: 16, color: ed.color),
                      const SizedBox(width: 6),
                      Text(ed.subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: c.textMuted,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.emerald,
                    onRefresh: () async => ref.invalidate(screenerProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: c.surfaceAlt),
                      itemBuilder: (ctx, i) {
                        final q     = items[i];
                        final isPos = q.changePct >= 0;
                        final clr   = isPos ? AppColors.emerald : AppColors.red;

                        return InkWell(
                          onTap: () => context.push('/stocks/${q.symbol}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text('#${i + 1}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: i < 3
                                              ? ed.color
                                              : c.textMuted)),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(q.symbol,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: c.textPrimary)),
                                      Text(q.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                                // Primary metric
                                _EditorialMetric(quote: q, ed: ed, c: c),
                                const SizedBox(width: 12),
                                // Price + change
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(fmtStockPrice(q.price),
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: c.textPrimary)),
                                    Text(
                                      '${isPos ? '+' : ''}${q.changePct.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: clr,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EditorialMetric extends StatelessWidget {
  final StockQuote quote;
  final _Editorial ed;
  final AppThemeColors c;
  const _EditorialMetric({
    required this.quote,
    required this.ed,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    String value;
    if (ed.path == 'best-dividend-stocks') {
      final pct = (quote.dividendYield ?? 0) * 100;
      value = '${pct.toStringAsFixed(2)}% div';
    } else if (ed.path == 'best-growth-stocks') {
      value = fmtBigUsd(quote.marketCap);
    } else {
      value = 'P/E ${(quote.pe ?? 0).toStringAsFixed(1)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ed.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(value,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ed.color)),
    );
  }
}
