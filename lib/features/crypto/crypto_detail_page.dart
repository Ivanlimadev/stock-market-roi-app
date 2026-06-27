import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';
import '../../core/api/api_client.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/blog_provider.dart';
import '../../core/models/blog_post_model.dart';
import '../../core/utils/formatters.dart';
import '../../core/providers/realtime_price_provider.dart';
import '../../core/providers/watchlist_provider.dart';
import '../../core/widgets/add_alert_dialog.dart';
import '../../core/providers/financials_provider.dart';
import '../../core/widgets/app_footer.dart';
import '../../core/widgets/comments_section.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/auth_prompt_sheet.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class CryptoDetail {
  final String id, symbol, name, image;
  final String? description;
  final CryptoMarketData marketData;

  const CryptoDetail({
    required this.id, required this.symbol, required this.name,
    required this.image, this.description, required this.marketData,
  });

  factory CryptoDetail.fromJson(Map<String, dynamic> j) => CryptoDetail(
    id:         j['id']     as String? ?? '',
    symbol:     j['symbol'] as String? ?? '',
    name:       j['name']   as String? ?? '',
    image:      (j['image'] is Map
        ? (j['image'] as Map)['large'] as String? ?? ''
        : j['image'] as String? ?? ''),
    description: j['description'] as String?,
    marketData: CryptoMarketData.fromJson(
        j['market_data'] as Map<String, dynamic>? ?? {}),
  );
}

class CryptoMarketData {
  final double currentPrice;
  final double? change24h, change24hPct, change7dPct, change14dPct,
      change30dPct, change60dPct, change1yPct;
  final double? marketCap;
  final int? marketCapRank;
  final double? totalVolume, high24h, low24h;
  final double? circulatingSupply, totalSupply, maxSupply;
  final double? ath, athChangePct;
  final String? athDate;
  final double? atl, atlChangePct;
  final String? atlDate;

  const CryptoMarketData({
    required this.currentPrice,
    this.change24h, this.change24hPct, this.change7dPct, this.change14dPct,
    this.change30dPct, this.change60dPct, this.change1yPct,
    this.marketCap, this.marketCapRank, this.totalVolume,
    this.high24h, this.low24h, this.circulatingSupply, this.totalSupply,
    this.maxSupply, this.ath, this.athChangePct, this.athDate,
    this.atl, this.atlChangePct, this.atlDate,
  });

  factory CryptoMarketData.fromJson(Map<String, dynamic> j) {
    double? n(String k) => (j[k] as num?)?.toDouble();
    return CryptoMarketData(
      currentPrice:       n('current_price') ?? 0,
      change24h:          n('price_change_24h'),
      change24hPct:       n('price_change_percentage_24h'),
      change7dPct:        n('price_change_percentage_7d'),
      change14dPct:       n('price_change_percentage_14d'),
      change30dPct:       n('price_change_percentage_30d'),
      change60dPct:       n('price_change_percentage_60d'),
      change1yPct:        n('price_change_percentage_1y'),
      marketCap:          n('market_cap'),
      marketCapRank:      (j['market_cap_rank'] as num?)?.toInt(),
      totalVolume:        n('total_volume'),
      high24h:            n('high_24h'),
      low24h:             n('low_24h'),
      circulatingSupply:  n('circulating_supply'),
      totalSupply:        n('total_supply'),
      maxSupply:          n('max_supply'),
      ath:                n('ath'),
      athChangePct:       n('ath_change_percentage'),
      athDate:            j['ath_date'] as String?,
      atl:                n('atl'),
      atlChangePct:       n('atl_change_percentage'),
      atlDate:            j['atl_date'] as String?,
    );
  }
}

class CryptoHistoryBar {
  final DateTime time;
  final double price;
  const CryptoHistoryBar({required this.time, required this.price});
}

// ── Providers ─────────────────────────────────────────────────────────────────

// Auto-refreshes price every 30 s while page is open
final cryptoDetailProvider = FutureProvider.autoDispose
    .family<CryptoDetail, String>((ref, id) async {
  final res = await ApiClient.dio.get('/crypto/$id');
  final data = CryptoDetail.fromJson(res.data as Map<String, dynamic>);

  // Schedule next refresh; cancel on dispose
  final timer = Timer(const Duration(seconds: 15), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);

  return data;
});

// Family key: (coinId, days)
final cryptoHistoryProvider = FutureProvider.autoDispose
    .family<List<CryptoHistoryBar>, ({String id, int days})>((ref, args) async {
  final res = await ApiClient.dio.get(
    '/crypto/${args.id}/history',
    queryParameters: {'days': '${args.days}'},
  );
  final list = res.data as List? ?? [];
  return list.map((e) {
    final m = e as Map<String, dynamic>;
    return CryptoHistoryBar(
      time:  DateTime.fromMillisecondsSinceEpoch(
          ((m['time'] as num) * 1000).toInt()),
      price: (m['price'] as num).toDouble(),
    );
  }).toList();
});

// ── Page ──────────────────────────────────────────────────────────────────────

const _periods = [
  (label: '1D',  days: 1),
  (label: '7D',  days: 7),
  (label: '30D', days: 30),
  (label: '1A',  days: 365),
];

class CryptoDetailPage extends ConsumerStatefulWidget {
  final String coinId;
  const CryptoDetailPage({super.key, required this.coinId});

  @override
  ConsumerState<CryptoDetailPage> createState() => _CryptoDetailPageState();
}

class _CryptoDetailPageState extends ConsumerState<CryptoDetailPage> {
  int _periodIdx = 1; // default 7D

  int get _days => _periods[_periodIdx].days;

  void _refresh() {
    ref.invalidate(cryptoDetailProvider(widget.coinId));
    ref.invalidate(cryptoHistoryProvider((id: widget.coinId, days: _days)));
  }

  @override
  Widget build(BuildContext context) {
    final async       = ref.watch(cryptoDetailProvider(widget.coinId));
    final inWatchlist = ref.watch(watchlistCryptoIdsProvider).contains(widget.coinId);
    final cryptoSym   = async.asData?.value.symbol.toUpperCase() ?? '';
    final hasAlert    = ref.watch(alertSymbolsProvider).contains(cryptoSym);
    final isLoggedIn  = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.coinId[0].toUpperCase() + widget.coinId.substring(1),
        ),
        actions: [
          ...MainShellMenu.actions(),
          // Favorite — always visible; prompts auth if not logged in
          IconButton(
            icon: Icon(
              inWatchlist ? Icons.star_rounded : Icons.star_border_rounded,
              color: inWatchlist ? AppColors.emerald : null,
            ),
            tooltip: inWatchlist ? 'Remove from watchlist' : 'Add to watchlist',
            onPressed: () async {
              if (!isLoggedIn) {
                showAuthPromptSheet(context, action: 'favorite this asset');
                return;
              }
              if (inWatchlist) {
                await WatchlistService.removeCrypto(widget.coinId);
              } else {
                final detail = async.asData?.value;
                await WatchlistService.addCrypto(
                  coinId: widget.coinId,
                  symbol: detail?.symbol.toUpperCase() ?? widget.coinId.toUpperCase(),
                  name:   detail?.name ?? widget.coinId,
                  image:  detail?.image,
                );
              }
            },
          ),
          // Price alert — yellow when active alert exists
          IconButton(
            icon: Icon(
              hasAlert ? Icons.notifications_rounded : Icons.notifications_none_rounded,
              color: hasAlert ? const Color(0xFFF59E0B) : null,
            ),
            tooltip: 'Set price alert',
            onPressed: () {
              if (!isLoggedIn) {
                showAuthPromptSheet(context, action: 'set price alerts');
                return;
              }
              final detail = async.asData?.value;
              if (detail == null) return;
              showAddAlertDialog(
                context,
                symbol:      detail.symbol.toUpperCase(),
                name:        detail.name,
                currentPrice: detail.marketData.currentPrice,
                assetType:   'crypto',
                coingeckoId: widget.coinId,
                image:       detail.image,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(
              Uri.parse('https://stockmarketroi.com/crypto/${widget.coinId}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: async.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: context.colors.textMuted),
              SizedBox(height: 12),
              Text('Falha ao carregar ${widget.coinId}',
                  style: TextStyle(color: context.colors.textMuted)),
              SizedBox(height: 16),
              OutlinedButton(
                onPressed: _refresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emerald,
                  side: BorderSide(color: AppColors.emerald),
                ),
                child: Text('Try again'),
              ),
            ],
          ),
        ),
        data: (coin) => _CryptoBody(
          coin: coin,
          coinId: widget.coinId,
          periodIdx: _periodIdx,
          onPeriodChange: (i) => setState(() => _periodIdx = i),
          days: _days,
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CryptoBody extends ConsumerWidget {
  final CryptoDetail coin;
  final String coinId;
  final int periodIdx;
  final ValueChanged<int> onPeriodChange;
  final int days;

  const _CryptoBody({
    required this.coin, required this.coinId, required this.periodIdx,
    required this.onPeriodChange, required this.days,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final md         = coin.marketData;
    final livePrice  = ref.watch(realtimePriceProvider)[coinId];
    final isLive     = livePrice != null;
    final price      = livePrice ?? md.currentPrice;
    final up         = (md.change24hPct ?? 0) >= 0;
    final color      = up ? AppColors.emerald : AppColors.red;
    final history    = ref.watch(cryptoHistoryProvider((id: coinId, days: days)));

    return ListView(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              ClipOval(
                child: Image.network(
                  coin.image, width: 52, height: 52,
                  errorBuilder: (_, __, ___) => _CoinFallback(
                      symbol: coin.symbol, size: 52),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coin.name,
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary)),
                    Text(coin.symbol.toUpperCase(),
                        style: TextStyle(fontSize: 13,
                            color: context.colors.textMuted)),
                  ],
                ),
              ),
              if (md.marketCapRank != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('#${md.marketCapRank}',
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textMuted)),
                ),
            ],
          ),
        ),

        // ── Price ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${_fmtPrice(price)}',
                style: TextStyle(fontSize: 36,
                    fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ),
              SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _ChangeBadge(value: md.change24hPct ?? 0, fontSize: 14),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Row(
            children: [
              if (isLive) ...[
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.emerald, shape: BoxShape.circle),
                ),
                SizedBox(width: 5),
                Text('LIVE',
                    style: TextStyle(fontSize: 11, color: AppColors.emerald,
                        fontWeight: FontWeight.w700)),
                SizedBox(width: 10),
              ],
              Text(
                md.change24h != null
                    ? '${(md.change24h! >= 0 ? '+' : '')}\$${_fmtPrice(md.change24h!.abs())} today'
                    : '24h Change',
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
            ],
          ),
        ),

        // ── Period tabs ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: List.generate(_periods.length, (i) {
              final active = periodIdx == i;
              return GestureDetector(
                onTap: () => onPeriodChange(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? AppColors.emerald : context.colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: active ? AppColors.emerald : context.colors.surfaceAlt),
                  ),
                  child: Text(_periods[i].label,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: active ? Colors.white : context.colors.textMuted,
                      )),
                ),
              );
            }),
          ),
        ),

        // ── Chart ───────────────────────────────────────────────────────────
        history.when(
          loading: () => Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: CircularProgressIndicator(
                color: AppColors.emerald, strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (bars) => bars.length < 2
              ? const SizedBox.shrink()
              : _PriceChart(bars: bars, color: color),
        ),

        // ── Period returns ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (md.change24hPct  != null) _PeriodChip('24h', md.change24hPct!),
              if (md.change7dPct   != null) _PeriodChip('7d',  md.change7dPct!),
              if (md.change30dPct  != null) _PeriodChip('30d', md.change30dPct!),
              if (md.change1yPct   != null) _PeriodChip('1a',  md.change1yPct!),
            ],
          ),
        ),

        // ── Market Stats ─────────────────────────────────────────────────────
        _MarketStats(md: md),

        // ── ATH / ATL ────────────────────────────────────────────────────────
        _AthAtlSection(md: md),

        // ── Supply ────────────────────────────────────────────────────────────
        _SupplySection(md: md, symbol: coin.symbol),

        // ── Exchange Listings ─────────────────────────────────────────────────
        _ExchangeListings(coinId: coinId),

        // ── About ─────────────────────────────────────────────────────────────
        if (coin.description != null && coin.description!.isNotEmpty)
          _AboutSection(text: coin.description!),

        // ── ROI Calculator ────────────────────────────────────────────────────
        _RoiCalcBanner(coinId: coinId, price: coin.marketData.currentPrice),

        // ── Related articles ──────────────────────────────────────────────────
        _RelatedArticles(coinId: coinId),

        // ── Discussion ────────────────────────────────────────────────────────
        CommentsSection(target: (type: 'crypto', id: coinId)),

        // ── Footer ────────────────────────────────────────────────────────────
        const AppFooter(),
      ],
    );
  }
}

// ── Chart ─────────────────────────────────────────────────────────────────────

class _PriceChart extends StatelessWidget {
  final List<CryptoHistoryBar> bars;
  final Color color;
  const _PriceChart({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    final spots = bars.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.price))
        .toList();
    final prices = bars.map((b) => b.price);
    final minY   = prices.reduce((a, b) => a < b ? a : b);
    final maxY   = prices.reduce((a, b) => a > b ? a : b);
    final pad    = (maxY - minY) * 0.12;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: minY - pad,
            maxY: maxY + pad,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => context.colors.surface,
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  '\$${_fmtPrice(s.y)}',
                  TextStyle(color: color, fontWeight: FontWeight.w600),
                )).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                    show: true, color: color.withValues(alpha: 0.1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Period chips ──────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final String label;
  final double value;
  const _PeriodChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final up    = value >= 0;
    final color = up ? AppColors.emerald : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.surfaceAlt),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          SizedBox(height: 2),
          Text('${up ? '+' : ''}${value.toStringAsFixed(2)}%',
              style: TextStyle(fontSize: 12, color: color,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Market Stats ──────────────────────────────────────────────────────────────

class _MarketStats extends StatelessWidget {
  final CryptoMarketData md;
  const _MarketStats({required this.md});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (md.marketCap   != null) ('Market Cap',   _fmtBig(md.marketCap)),
      if (md.totalVolume != null) ('Volume 24h',   _fmtBig(md.totalVolume)),
      if (md.high24h     != null) ('24h High', '\$${_fmtPrice(md.high24h!)}'),
      if (md.low24h      != null) ('24h Low',  '\$${_fmtPrice(md.low24h!)}'),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return _CardSection(
      title: 'Market Data',
      child: _RowList(rows: rows),
    );
  }
}

// ── ATH / ATL ─────────────────────────────────────────────────────────────────

class _AthAtlSection extends StatelessWidget {
  final CryptoMarketData md;
  const _AthAtlSection({required this.md});

  @override
  Widget build(BuildContext context) {
    if (md.ath == null && md.atl == null) return const SizedBox.shrink();

    final rows = <(String, String)>[
      if (md.ath != null) ...[
        ('ATH', '\$${_fmtPrice(md.ath!)}'),
        if (md.athChangePct != null)
          ('Dist. do ATH',
           '${md.athChangePct! >= 0 ? '+' : ''}${md.athChangePct!.toStringAsFixed(2)}%'),
        if (md.athDate != null)
          ('Data ATH', _fmtDate(md.athDate!)),
      ],
      if (md.atl != null) ...[
        ('ATL', '\$${_fmtPrice(md.atl!)}'),
        if (md.atlChangePct != null)
          ('Dist. do ATL',
           '${md.atlChangePct! >= 0 ? '+' : ''}${md.atlChangePct!.toStringAsFixed(2)}%'),
        if (md.atlDate != null)
          ('Data ATL', _fmtDate(md.atlDate!)),
      ],
    ];

    return _CardSection(
      title: 'ATH / ATL',
      child: _RowList(rows: rows, athAtl: true, md: md),
    );
  }
}

// ── Supply ────────────────────────────────────────────────────────────────────

class _SupplySection extends StatelessWidget {
  final CryptoMarketData md;
  final String symbol;
  const _SupplySection({required this.md, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final sym = symbol.toUpperCase();
    final rows = <(String, String)>[
      if (md.circulatingSupply != null)
        ('Circulante', '${_fmtSupply(md.circulatingSupply!)} $sym'),
      if (md.totalSupply != null)
        ('Total Supply', '${_fmtSupply(md.totalSupply!)} $sym'),
      if (md.maxSupply != null)
        ('Max Supply', '${_fmtSupply(md.maxSupply!)} $sym'),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return _CardSection(
      title: 'Supply',
      child: Column(
        children: [
          if (md.circulatingSupply != null && md.maxSupply != null)
            _SupplyBar(
              circulating: md.circulatingSupply!,
              max: md.maxSupply!,
            ),
          _RowList(rows: rows),
        ],
      ),
    );
  }
}

class _SupplyBar extends StatelessWidget {
  final double circulating, max;
  const _SupplyBar({required this.circulating, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = (circulating / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Circulante / Max',
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
              Text('${(pct * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600, color: AppColors.emerald)),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: context.colors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(AppColors.emerald),
            ),
          ),
        ],
      ),
    );
  }
}

// ── About ─────────────────────────────────────────────────────────────────────

class _AboutSection extends StatefulWidget {
  final String text;
  const _AboutSection({required this.text});
  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'About',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.text,
              maxLines: _expanded ? null : 5,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13,
                  color: context.colors.textSecond, height: 1.65)),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(_expanded ? 'Show less' : 'Read more',
                  style: TextStyle(color: AppColors.emerald, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Related Articles ─────────────────────────────────────────────────────────

class _RelatedArticles extends ConsumerWidget {
  final String coinId;
  const _RelatedArticles({required this.coinId});

  static const _catColors = {
    'Markets':    Color(0xFF6366F1),
    'Stocks':     Color(0xFF10B981),
    'Investing':  Color(0xFFF59E0B),
    'Economics':  Color(0xFFEF4444),
    'Crypto':     Color(0xFFF97316),
    'Technology': Color(0xFF3B82F6),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = coinId.toUpperCase();
    final async = ref.watch(relatedPostsProvider(sym));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();
        return _CardSection(
          title: 'Artigos Relacionados',
          child: Column(
            children: posts
                .map((p) => _ArticleTile(post: p, catColors: _catColors))
                .toList(),
          ),
        );
      },
    );
  }
}

class _ArticleTile extends StatelessWidget {
  final BlogPost post;
  final Map<String, Color> catColors;
  const _ArticleTile({required this.post, required this.catColors});

  @override
  Widget build(BuildContext context) {
    final color = catColors[post.category] ?? AppColors.emerald;
    return InkWell(
      onTap: () => context.push('/blog/${post.slug}', extra: post),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.surfaceAlt, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(post.category,
                        style: TextStyle(fontSize: 10, color: color,
                            fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(height: 6),
                  Text(post.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary)),
                ],
              ),
            ),
            SizedBox(width: 12),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Shared UI ─────────────────────────────────────────────────────────────────

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Text(title,
            style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.surfaceAlt),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      ),
    ],
  );
}

class _RowList extends StatelessWidget {
  final List<(String, String)> rows;
  final bool athAtl;
  final CryptoMarketData? md;
  const _RowList({required this.rows, this.athAtl = false, this.md});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows.asMap().entries.map((entry) {
        final i     = entry.key;
        final label = entry.value.$1;
        final value = entry.value.$2;
        final isLast = i == rows.length - 1;

        Color? valueColor;
        if (athAtl && label.startsWith('Dist.')) {
          final num = double.tryParse(value.replaceAll('%', '').replaceAll('+', ''));
          if (num != null) valueColor = num >= 0 ? AppColors.emerald : AppColors.red;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: isLast ? null : Border(
                bottom: BorderSide(color: context.colors.surfaceAlt, width: 0.5)),
          ),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(fontSize: 13,
                      color: context.colors.textMuted)),
              const Spacer(),
              Text(value,
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? context.colors.textPrimary)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final double value;
  final double fontSize;
  const _ChangeBadge({required this.value, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final up    = value >= 0;
    final color = up ? AppColors.emerald : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(
        '${up ? '+' : ''}${value.toStringAsFixed(2)}%',
        style: TextStyle(fontSize: fontSize, color: color,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CoinFallback extends StatelessWidget {
  final String symbol;
  final double size;
  const _CoinFallback({required this.symbol, this.size = 36});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size, color: context.colors.surfaceAlt,
    child: Center(
      child: Text(
        symbol.isNotEmpty ? symbol[0].toUpperCase() : '?',
        style: TextStyle(fontSize: size * 0.4,
            fontWeight: FontWeight.bold, color: context.colors.textMuted),
      ),
    ),
  );
}

// ── Formatters ────────────────────────────────────────────────────────────────

// Strips leading $ since callers prepend it where needed
String _fmtPrice(double price) => fmtCryptoPrice(price).replaceFirst('\$', '');

String _fmtBig(double? v) => fmtBigUsd(v);

String _fmtSupply(double v) => fmtSupply(v);

String _fmtDate(String iso) {
  try {
    final dt = DateTime.parse(iso);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return iso.substring(0, 10);
  }
}

// ── ROI Calculator Banner ─────────────────────────────────────────────────────

class _RoiCalcBanner extends StatelessWidget {
  final String coinId;
  final double price;
  const _RoiCalcBanner({required this.coinId, required this.price});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => context.push('/calculators/roi'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withValues(alpha: 0.08),
            border: Border.all(
                color: const Color(0xFFF97316).withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_upward_rounded,
                    size: 20, color: const Color(0xFFF97316)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ROI Calculator',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Calculate returns on your ${coinId[0].toUpperCase()}${coinId.substring(1)} investment',
                        style: TextStyle(fontSize: 12, color: c.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Exchange Listings ─────────────────────────────────────────────────────────

class _ExchangeListings extends ConsumerWidget {
  final String coinId;
  const _ExchangeListings({required this.coinId});

  Color _trustColor(String? score) {
    if (score == 'green')  return AppColors.emerald;
    if (score == 'yellow') return const Color(0xFFF59E0B);
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cryptoTickersProvider(coinId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (tickers) {
        if (tickers.isEmpty) return const SizedBox.shrink();
        final c = context.colors;
        return _CardSection(
          title: 'Exchange Listings',
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Expanded(child: Text('Exchange',
                        style: TextStyle(fontSize: 11, color: c.textMuted,
                            fontWeight: FontWeight.w600))),
                    SizedBox(width: 60,
                        child: Text('Price', textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 11, color: c.textMuted,
                                fontWeight: FontWeight.w600))),
                    SizedBox(width: 70,
                        child: Text('Vol 24h', textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 11, color: c.textMuted,
                                fontWeight: FontWeight.w600))),
                    SizedBox(width: 14),
                  ],
                ),
              ),
              Divider(height: 1, color: c.surfaceAlt),
              ...tickers.asMap().entries.map((e) {
                final isLast = e.key == tickers.length - 1;
                final t      = e.value;
                return InkWell(
                  onTap: t.tradeUrl != null && t.tradeUrl!.isNotEmpty
                      ? () => launchUrl(Uri.parse(t.tradeUrl!),
                            mode: LaunchMode.externalApplication)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      border: isLast ? null : Border(
                        bottom: BorderSide(color: c.surfaceAlt, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: _trustColor(t.trustScore),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.exchange,
                                  style: TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary)),
                              Text(t.target,
                                  style: TextStyle(fontSize: 11, color: c.textMuted)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            t.price >= 1000
                                ? '\$${t.price.toStringAsFixed(0)}'
                                : '\$${t.price.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600, color: c.textPrimary),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            fmtBigUsd(t.volume24h),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12, color: c.textSecond),
                          ),
                        ),
                        SizedBox(width: 4),
                        if (t.tradeUrl != null && t.tradeUrl!.isNotEmpty)
                          Icon(Icons.open_in_new_rounded, size: 12, color: c.textMuted)
                        else
                          SizedBox(width: 12),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
