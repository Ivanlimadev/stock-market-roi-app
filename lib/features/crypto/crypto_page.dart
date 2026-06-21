import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/crypto_provider.dart';
import '../../core/providers/financials_provider.dart';
import '../../core/models/crypto_model.dart';
import '../../core/utils/formatters.dart';
import '../../core/providers/realtime_price_provider.dart';
import '../../core/shell/main_shell.dart';

class CryptoPage extends ConsumerStatefulWidget {
  const CryptoPage({super.key});

  @override
  ConsumerState<CryptoPage> createState() => _CryptoPageState();
}

class _CryptoPageState extends ConsumerState<CryptoPage>
    with SingleTickerProviderStateMixin {
  int _heatmapTab = 1; // 0=1h 1=24h 2=7d 3=30d 4=1y
  int _rankingTab = 0; // 0=Trending 1=Gainers 2=Losers
  bool _showAllCoins = false;

  void _refresh() {
    ref.invalidate(cryptoMarketsProvider);
    ref.invalidate(cryptoGlobalProvider);
    ref.invalidate(cryptoTrendingProvider);
    ref.invalidate(cryptoFearGreedProvider);
    ref.invalidate(cryptoFundingProvider);
    ref.invalidate(cryptoLongShortProvider);
    ref.invalidate(defiTvlProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.emerald,
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text('Crypto Market'),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh_rounded),
                  onPressed: _refresh,
                ),
                MainShellMenu.themeButton(),
                MainShellMenu.settingsButton(),
              ],
            ),

            // ── Global Stats ─────────────────────────────────────────────
            SliverToBoxAdapter(child: _GlobalStats()),

            // ── Fear & Greed + Market Dominance ──────────────────────────
            SliverToBoxAdapter(child: _FearDominanceRow()),

            // ── Trending / Gainers / Losers ───────────────────────────────
            SliverToBoxAdapter(
              child: _RankingSection(
                tab: _rankingTab,
                onTabChange: (i) => setState(() => _rankingTab = i),
              ),
            ),

            // ── Heatmap ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _HeatmapSection(
                tab: _heatmapTab,
                onTabChange: (i) => setState(() => _heatmapTab = i),
              ),
            ),

            // ── Funding Rates ────────────────────────────────────────────
            const SliverToBoxAdapter(child: _FundingSection()),

            // ── Long / Short Ratio ────────────────────────────────────────
            const SliverToBoxAdapter(child: _LongShortSection()),

            // ── DeFi TVL ─────────────────────────────────────────────────
            const SliverToBoxAdapter(child: _DefiSection()),

            // ── Top 100 list ─────────────────────────────────────────────
            const SliverToBoxAdapter(child: _SectionHeader('Top Cryptocurrencies')),
            _CryptoList(
              showAll: _showAllCoins,
              onShowMore: () => setState(() => _showAllCoins = true),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Global Stats
// ══════════════════════════════════════════════════════════════════════════════

class _GlobalStats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async      = ref.watch(cryptoGlobalProvider);
    final liveCount  = ref.watch(realtimePriceProvider).length;
    final isLive     = liveCount > 0;

    return async.when(
      loading: () => SizedBox(
        height: 130,
        child: Center(child: CircularProgressIndicator(color: AppColors.emerald, strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (g) {
        final up = g.marketCapChange24h >= 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cryptocurrency Market',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary)),
              SizedBox(height: 4),
              Row(
                children: [
                  if (isLive) ...[
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'LIVE · $liveCount coins in real time',
                      style: TextStyle(fontSize: 11, color: AppColors.emerald,
                          fontWeight: FontWeight.w600),
                    ),
                  ] else
                    Text('Connecting live prices…',
                        style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                ],
              ),
              SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Market Cap',
                    value: _fmtBig(g.totalMarketCapUsd),
                    sub: '${up ? '+' : ''}${g.marketCapChange24h.toStringAsFixed(2)}% 24h',
                    subUp: up,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: '24h Volume',
                    value: _fmtBig(g.totalVolumeUsd),
                  ),
                ),
              ]),
              SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _StatCard(
                    label: 'BTC Dominance',
                    value: '${g.btcDominance.toStringAsFixed(1)}%',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Active Cryptos',
                    value: _fmtCount(g.activeCryptocurrencies),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  String _fmtBig(double v) => fmtBigUsd(v);
  String _fmtCount(int v) => fmtCount(v);
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final String? sub;
  final bool? subUp;
  const _StatCard({required this.label, required this.value, this.sub, this.subUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          SizedBox(height: 4),
          Text(value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                color: context.colors.textPrimary)),
          if (sub != null) ...[
            SizedBox(height: 2),
            Text(sub!,
              style: TextStyle(
                fontSize: 11,
                color: (subUp ?? true) ? AppColors.emerald : AppColors.red,
                fontWeight: FontWeight.w600,
              )),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Fear & Greed + Market Dominance
// ══════════════════════════════════════════════════════════════════════════════

class _FearDominanceRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fgAsync = ref.watch(cryptoFearGreedProvider);
    final glAsync = ref.watch(cryptoGlobalProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fear & Greed
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.surfaceAlt),
              ),
              child: Column(
                children: [
                  Text('Fear & Greed',
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                  SizedBox(height: 10),
                  fgAsync.when(
                    loading: () => SizedBox(height: 80,
                        child: Center(child: CircularProgressIndicator(
                            color: AppColors.emerald, strokeWidth: 2))),
                    error: (_, __) => SizedBox(height: 80),
                    data: (fg) => _FearGauge(value: fg.value, label: fg.classification),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10),

          // Market Dominance
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.surfaceAlt),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Market Dominance',
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                  SizedBox(height: 10),
                  glAsync.when(
                    loading: () => SizedBox(height: 80,
                        child: Center(child: CircularProgressIndicator(
                            color: AppColors.emerald, strokeWidth: 2))),
                    error: (_, __) => SizedBox(height: 80),
                    data: (g) => _DominanceBars(entries: g.topDominances),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FearGauge extends StatelessWidget {
  final int value;
  final String label;
  const _FearGauge({required this.value, required this.label});

  Color get _color {
    if (value <= 20) return const Color(0xFFEF4444);
    if (value <= 40) return const Color(0xFFF97316);
    if (value <= 60) return const Color(0xFFEAB308);
    if (value <= 80) return const Color(0xFF22C55E);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 80, height: 48,
          child: CustomPaint(painter: _GaugePainter(value: value, color: _color, bgColor: context.colors.surfaceAlt)),
        ),
        SizedBox(height: 4),
        Text('$value',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _color)),
        SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int value;
  final Color color;
  final Color bgColor;
  const _GaugePainter({required this.value, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final r  = size.width / 2 - 4;
    final strokeW = 8.0;

    final bg = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    const start = math.pi;
    const sweep = math.pi;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start, sweep, false, bg);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start,
        sweep * (value / 100), false, fg);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}

const _domColors = [
  Color(0xFFF97316),
  Color(0xFF6366F1),
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF52525B), // "Other" — neutral zinc
];

class _DominanceBars extends StatelessWidget {
  final List<DominanceEntry> entries;
  const _DominanceBars({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: entries.asMap().entries.map((e) {
                final color = _domColors[e.key % _domColors.length];
                return Expanded(
                  flex: (e.value.pct * 100).round(),
                  child: Container(color: color),
                );
              }).toList(),
            ),
          ),
        ),
        SizedBox(height: 10),
        ...entries.take(5).toList().asMap().entries.map((e) {
          final color = _domColors[e.key % _domColors.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: color,
                        borderRadius: BorderRadius.circular(2))),
                SizedBox(width: 6),
                Text(e.value.symbol,
                    style: TextStyle(fontSize: 11, color: context.colors.textSecond,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${e.value.pct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Trending / Gainers / Losers
// ══════════════════════════════════════════════════════════════════════════════

class _RankingSection extends ConsumerWidget {
  final int tab;
  final ValueChanged<int> onTabChange;
  const _RankingSection({required this.tab, required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(cryptoTrendingProvider);
    final marketsAsync  = ref.watch(cryptoMarketsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTab(context, 0, 'Trending', Icons.local_fire_department_rounded),
                SizedBox(width: 8),
                _buildTab(context, 1, 'Gainers', Icons.trending_up_rounded),
                SizedBox(width: 8),
                _buildTab(context, 2, 'Losers', Icons.trending_down_rounded),
              ],
            ),
          ),
          SizedBox(height: 12),

          if (tab == 0)
            trendingAsync.when(
              loading: () => const _LoadingBox(),
              error: (_, __) => const _ErrorBox(),
              data: (coins) => _coinRowList(context, coins.map((c) => (
                id: c.id, name: c.name, symbol: c.symbol, image: c.image,
                price: c.price, change: c.priceChange24h, rank: c.marketCapRank,
              )).toList()),
            )
          else
            marketsAsync.when(
              loading: () => const _LoadingBox(),
              error: (_, __) => const _ErrorBox(),
              data: (coins) {
                final sorted = [...coins];
                if (tab == 1) {
                  sorted.sort((a, b) =>
                      b.priceChangePercentage24h.compareTo(a.priceChangePercentage24h));
                } else {
                  sorted.sort((a, b) =>
                      a.priceChangePercentage24h.compareTo(b.priceChangePercentage24h));
                }
                return _coinRowList(context, sorted.take(10).map((c) => (
                  id: c.id, name: c.name, symbol: c.symbol, image: c.image,
                  price: c.currentPrice, change: c.priceChangePercentage24h,
                  rank: c.marketCapRank ?? 0,
                )).toList());
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, int idx, String label, IconData icon) {
    final active = tab == idx;
    return GestureDetector(
      onTap: () => onTabChange(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.emerald : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.emerald : context.colors.surfaceAlt),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: active ? Colors.white : context.colors.textMuted),
            SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : context.colors.textMuted,
                )),
          ],
        ),
      ),
    );
  }

  Widget _coinRowList(BuildContext context,
      List<({String id, String name, String symbol, String image, double price, double change, int rank})> coins) {
    return Column(
      children: coins.map((c) {
        final up = c.change >= 0;
        return InkWell(
          onTap: () => context.push('/crypto/${c.id}'),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text('#${c.rank}',
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                ),
                SizedBox(width: 8),
                ClipOval(
                  child: Image.network(c.image, width: 32, height: 32,
                    errorBuilder: (_, __, ___) => _CoinFallback(symbol: c.symbol)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary)),
                      Text(c.symbol,
                          style: TextStyle(fontSize: 11,
                              color: context.colors.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Consumer(builder: (_, ref, __) {
                      final live  = ref.watch(realtimePriceProvider)[c.id];
                      final price = live ?? c.price;
                      return Text('\$${_fmtPrice(price)}',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary));
                    }),
                    SizedBox(height: 2),
                    _ChangeBadge(change: c.change),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Heatmap
// ══════════════════════════════════════════════════════════════════════════════

class _HeatmapSection extends ConsumerWidget {
  final int tab;
  final ValueChanged<int> onTabChange;
  static const _periods = ['1h', '24h', '7d', '30d', '1y'];

  const _HeatmapSection({required this.tab, required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cryptoMarketsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Heatmap',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary)),
              const Spacer(),
              ...List.generate(_periods.length, (i) {
                final active = tab == i;
                return GestureDetector(
                  onTap: () => onTabChange(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? AppColors.emerald : context.colors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: active ? AppColors.emerald : context.colors.surfaceAlt),
                    ),
                    child: Text(_periods[i],
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: active ? Colors.white : context.colors.textMuted,
                        )),
                  ),
                );
              }),
            ],
          ),
          SizedBox(height: 12),
          async.when(
            loading: () => const _LoadingBox(),
            error: (_, __) => const _ErrorBox(),
            data: (coins) {
              final top20 = coins.take(20).toList();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.1,
                ),
                itemCount: top20.length,
                itemBuilder: (_, i) {
                  final coin = top20[i];
                  final change = _getChange(coin, tab);
                  return _HeatTile(coin: coin, change: change);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  double? _getChange(CryptoMarket c, int tab) {
    switch (tab) {
      case 0: return c.priceChange1h;
      case 1: return c.priceChangePercentage24h;
      case 2: return c.priceChange7d;
      case 3: return c.priceChange30d;
      case 4: return c.priceChange1y;
      default: return c.priceChangePercentage24h;
    }
  }
}

class _HeatTile extends StatelessWidget {
  final CryptoMarket coin;
  final double? change;
  const _HeatTile({required this.coin, required this.change});

  Color get _bg {
    final v = change ?? 0;
    if (v >  5) return const Color(0xFF065F46);
    if (v >  2) return const Color(0xFF047857);
    if (v >  0) return const Color(0xFF059669);
    if (v > -2) return const Color(0xFF991B1B);
    if (v > -5) return const Color(0xFFB91C1C);
    return const Color(0xFF7F1D1D);
  }

  @override
  Widget build(BuildContext context) {
    final v = change ?? 0;
    return InkWell(
      onTap: () => context.push('/crypto/${coin.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.network(coin.image, width: 22, height: 22,
                errorBuilder: (_, __, ___) => _CoinFallback(symbol: coin.symbol, size: 22)),
            ),
            SizedBox(height: 4),
            Text(coin.symbol.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text('${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Full Crypto List
// ══════════════════════════════════════════════════════════════════════════════

class _CryptoList extends ConsumerWidget {
  final bool showAll;
  final VoidCallback onShowMore;
  const _CryptoList({required this.showAll, required this.onShowMore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cryptoMarketsProvider);
    return async.when(
      loading: () => const SliverToBoxAdapter(child: _LoadingBox()),
      error: (e, _) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.cloud_off_rounded, color: context.colors.textMuted, size: 44),
                SizedBox(height: 12),
                Text('$e', style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
      data: (coins) {
        if (!showAll) {
          // Show top 5 + "Ver mais" button
          final top5 = coins.take(5).toList();
          return SliverToBoxAdapter(
            child: Column(
              children: [
                _CoinTableHeader(),
                ...top5.asMap().entries.map(
                  (e) => _CoinTableRow(coin: e.value, rank: e.key + 1),
                ),
                // Ver mais button
                InkWell(
                  onTap: onShowMore,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.colors.surfaceAlt),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'See ${coins.length - 5} more coins',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.emerald,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: AppColors.emerald),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Show all
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              if (i == 0) return _CoinTableHeader();
              final coin = coins[i - 1];
              return _CoinTableRow(coin: coin, rank: i);
            },
            childCount: coins.length + 1,
          ),
        );
      },
    );
  }
}

class _CoinTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text('#', style: TextStyle(fontSize: 11, color: context.colors.textMuted))),
          SizedBox(width: 10),
          Expanded(child: Text('Coin', style: TextStyle(fontSize: 11, color: context.colors.textMuted))),
          SizedBox(width: 80, child: Text('Price', textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: context.colors.textMuted))),
          SizedBox(width: 60, child: Text('24h', textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: context.colors.textMuted))),
          SizedBox(width: 60, child: Text('7d', textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: context.colors.textMuted))),
        ],
      ),
    );
  }
}

class _CoinTableRow extends ConsumerWidget {
  final CryptoMarket coin;
  final int rank;
  const _CoinTableRow({required this.coin, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final livePrice  = ref.watch(realtimePriceProvider)[coin.id];
    final price      = livePrice ?? coin.currentPrice;

    return InkWell(
      onTap: () => context.push('/crypto/${coin.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.surfaceAlt, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text('$rank',
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
            ),
            SizedBox(width: 10),
            ClipOval(
              child: Image.network(coin.image, width: 28, height: 28,
                errorBuilder: (_, __, ___) => _CoinFallback(symbol: coin.symbol, size: 28)),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coin.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary)),
                  Text(coin.symbol.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: Text('\$${_fmtPrice(price)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary)),
            ),
            SizedBox(
              width: 60,
              child: Align(
                alignment: Alignment.centerRight,
                child: _ChangeBadge(change: coin.priceChangePercentage24h, small: true),
              ),
            ),
            SizedBox(
              width: 60,
              child: coin.priceChange7d != null
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: _ChangeBadge(change: coin.priceChange7d!, small: true),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
            color: context.colors.textPrimary)),
  );
}

class _ChangeBadge extends StatelessWidget {
  final double change;
  final bool small;
  const _ChangeBadge({required this.change, this.small = false});

  @override
  Widget build(BuildContext context) {
    final up    = change >= 0;
    final color = up ? AppColors.emerald : AppColors.red;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 5 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '${up ? '+' : ''}${change.toStringAsFixed(2)}%',
        style: TextStyle(
            fontSize: small ? 10 : 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CoinFallback extends StatelessWidget {
  final String symbol;
  final double size;
  const _CoinFallback({required this.symbol, this.size = 32});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    color: context.colors.surfaceAlt,
    child: Center(
      child: Text(
        symbol.isNotEmpty ? symbol[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: context.colors.textMuted,
        ),
      ),
    ),
  );
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 80,
    child: Center(child: CircularProgressIndicator(
        color: AppColors.emerald, strokeWidth: 2)),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: Center(child: Text('Error loading',
        style: TextStyle(color: context.colors.textMuted))),
  );
}

// Uses fmtCryptoPrice from formatters.dart — keeps $ prefix stripped for inline use
String _fmtPrice(double price) => fmtCryptoPrice(price).replaceFirst('\$', '');

// ══════════════════════════════════════════════════════════════════════════════
// Funding Rates
// ══════════════════════════════════════════════════════════════════════════════

class _FundingSection extends ConsumerWidget {
  const _FundingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cryptoFundingProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (rates) {
        if (rates.isEmpty) return const SizedBox.shrink();
        final c = context.colors;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader2('Funding Rates', 'Perpetual futures — refreshed every 5 min'),
              SizedBox(height: 10),
              // 2-column grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.3,
                ),
                itemCount: rates.length,
                itemBuilder: (_, i) {
                  final r      = rates[i];
                  final isPos  = r.ratePct >= 0;
                  final color  = isPos ? AppColors.emerald : AppColors.red;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.surfaceAlt),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(r.symbol,
                                  style: TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w700, color: c.textPrimary)),
                              Text('${r.annualPct.toStringAsFixed(1)}% ann.',
                                  style: TextStyle(fontSize: 10, color: c.textMuted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${isPos ? '+' : ''}${r.ratePct.toStringAsFixed(4)}%',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w700, color: color),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Long / Short Ratio
// ══════════════════════════════════════════════════════════════════════════════

class _LongShortSection extends ConsumerWidget {
  const _LongShortSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cryptoLongShortProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final c = context.colors;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader2('Long / Short Ratio', 'Account sentiment — perpetual contracts'),
              SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.surfaceAlt),
                ),
                child: Column(
                  children: items.asMap().entries.map((e) {
                    final isLast = e.key == items.length - 1;
                    final item   = e.value;
                    final longW  = item.longPct / 100;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: isLast ? null : Border(
                          bottom: BorderSide(color: c.surfaceAlt, width: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(item.symbol,
                                  style: TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w700, color: c.textPrimary)),
                              const Spacer(),
                              Text(
                                '${item.longPct.toStringAsFixed(1)}% L',
                                style: TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w600, color: AppColors.emerald),
                              ),
                              Text(' / ', style: TextStyle(fontSize: 11, color: c.textMuted)),
                              Text(
                                '${item.shortPct.toStringAsFixed(1)}% S',
                                style: TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w600, color: AppColors.red),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 5,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: (longW * 1000).round(),
                                    child: Container(color: AppColors.emerald),
                                  ),
                                  Expanded(
                                    flex: ((1 - longW) * 1000).round(),
                                    child: Container(color: AppColors.red),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DeFi TVL
// ══════════════════════════════════════════════════════════════════════════════

class _DefiSection extends ConsumerWidget {
  const _DefiSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(defiTvlProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (data) {
        final c = context.colors;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SectionHeader2('DeFi TVL', 'Total Value Locked — top protocols'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (data.change1d >= 0 ? AppColors.emerald : AppColors.red)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${data.change1d >= 0 ? '+' : ''}${data.change1d.toStringAsFixed(2)}% 24h',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: data.change1d >= 0 ? AppColors.emerald : AppColors.red,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 10),
                child: Text(
                  'Total: ${fmtBigUsd(data.totalTvl)}',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ),
              // Protocol list
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.surfaceAlt),
                ),
                child: Column(
                  children: data.protocols.asMap().entries.map((e) {
                    final isLast = e.key == data.protocols.length - 1;
                    final p      = e.value;
                    final isPos  = p.change1d >= 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        border: isLast ? null : Border(
                          bottom: BorderSide(color: c.surfaceAlt, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: TextStyle(fontSize: 13,
                                        fontWeight: FontWeight.w600, color: c.textPrimary)),
                                Text(p.category,
                                    style: TextStyle(fontSize: 11, color: c.textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(fmtBigUsd(p.tvl),
                                  style: TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w700, color: c.textPrimary)),
                              Text(
                                '${isPos ? '+' : ''}${p.change1d.toStringAsFixed(2)}%',
                                style: TextStyle(fontSize: 11,
                                    color: isPos ? AppColors.emerald : AppColors.red,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 6),
              // Chain bars
              Text('By Chain', style: TextStyle(fontSize: 12, color: c.textMuted,
                  fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              ...data.chains.map((ch) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    SizedBox(width: 56,
                        child: Text(ch.name, style: TextStyle(fontSize: 11, color: c.textSecond))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ch.share / 100,
                          minHeight: 5,
                          backgroundColor: c.surfaceAlt,
                          valueColor: const AlwaysStoppedAnimation(AppColors.emerald),
                        ),
                      ),
                    ),
                    SizedBox(width: 60,
                        child: Text(fmtBigUsd(ch.tvl),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10, color: c.textMuted))),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader2 extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader2(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
              color: context.colors.textPrimary)),
      Text(subtitle,
          style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
    ],
  );
}
