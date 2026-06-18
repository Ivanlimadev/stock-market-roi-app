import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/screener_provider.dart';
import '../../core/models/market_model.dart';

// ── Color scale ───────────────────────────────────────────────────────────────

Color _heatColor(double pct) {
  if (pct >= 5)   return const Color(0xFF065F46); // dark green
  if (pct >= 2)   return const Color(0xFF059669); // green
  if (pct >= 0.5) return const Color(0xFF34D399); // light green
  if (pct >= 0)   return const Color(0xFF6EE7B7); // pale green
  if (pct >= -0.5) return const Color(0xFFFCA5A5); // pale red
  if (pct >= -2)  return const Color(0xFFEF4444); // red
  if (pct >= -5)  return const Color(0xFFB91C1C); // dark red
  return const Color(0xFF7F1D1D); // very dark red
}

Color _textColorFor(double pct) {
  if (pct.abs() < 0.5) return Colors.black87;
  return Colors.white;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class HeatmapPage extends ConsumerStatefulWidget {
  const HeatmapPage({super.key});

  @override
  ConsumerState<HeatmapPage> createState() => _HeatmapPageState();
}

class _HeatmapPageState extends ConsumerState<HeatmapPage> {
  String _sector = 'All';

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final async = ref.watch(screenerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Heatmap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(screenerProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
                const SizedBox(height: 12),
                Text('Failed to load heatmap',
                    style: TextStyle(color: c.textMuted)),
                const SizedBox(height: 16),
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
            // Collect distinct sectors
            final sectors = ['All', ...{
              for (final q in all)
                if (q.sector != null) q.sector!
            }.toList()..sort()];

            final filtered = _sector == 'All'
                ? all
                : all.where((q) => q.sector == _sector).toList();

            // Sort by market cap descending so biggest squares first
            final sorted = [...filtered]
              ..sort((a, b) =>
                  (b.marketCap ?? 0).compareTo(a.marketCap ?? 0));

            return Column(
              children: [
                // Legend
                _Legend(),
                // Sector filter
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    itemCount: sectors.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final s      = sectors[i];
                      final active = _sector == s;
                      return GestureDetector(
                        onTap: () => setState(() => _sector = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.emerald.withValues(alpha: 0.12)
                                : c.surface,
                            border: Border.all(
                              color: active
                                  ? AppColors.emerald.withValues(alpha: 0.5)
                                  : c.border,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active ? AppColors.emerald : c.textMuted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Heatmap grid
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.emerald,
                    onRefresh: () async => ref.invalidate(screenerProvider),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(4),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 3,
                        crossAxisSpacing: 3,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: sorted.length,
                      itemBuilder: (ctx, i) => _HeatCell(
                        quote: sorted[i],
                        onTap: () =>
                            context.push('/stocks/${sorted[i].symbol}'),
                      ),
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

// ── Heat cell ─────────────────────────────────────────────────────────────────

class _HeatCell extends StatelessWidget {
  final StockQuote quote;
  final VoidCallback onTap;
  const _HeatCell({required this.quote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg  = _heatColor(quote.changePct);
    final txt = _textColorFor(quote.changePct);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              quote.symbol,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: txt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${quote.changePct >= 0 ? '+' : ''}${quote.changePct.toStringAsFixed(2)}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: txt.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Color legend ──────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const stops = [
      (-5.0, '>−5%'),
      (-2.0, '>−2%'),
      (-0.5, '>−0.5%'),
      (0.0, '0%'),
      (0.5, '>0.5%'),
      (2.0, '>2%'),
      (5.0, '>5%'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: stops.map((s) {
          return Expanded(
            child: Container(
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: _heatColor(s.$1),
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.center,
              child: Text(
                s.$2,
                style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: _textColorFor(s.$1)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
