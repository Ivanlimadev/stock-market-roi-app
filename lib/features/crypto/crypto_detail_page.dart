import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class CryptoDetail {
  final String id;
  final String symbol;
  final String name;
  final String image;
  final String? description;
  final CryptoMarketData marketData;

  const CryptoDetail({
    required this.id, required this.symbol, required this.name,
    required this.image, this.description, required this.marketData,
  });

  factory CryptoDetail.fromJson(Map<String, dynamic> j) => CryptoDetail(
    id:          j['id']     as String? ?? '',
    symbol:      j['symbol'] as String? ?? '',
    name:        j['name']   as String? ?? '',
    image:       (j['image'] is Map
        ? (j['image'] as Map)['large'] as String? ?? ''
        : j['image'] as String? ?? ''),
    description: j['description'] as String?,
    marketData:  CryptoMarketData.fromJson(
        j['market_data'] as Map<String, dynamic>? ?? {}),
  );
}

class CryptoMarketData {
  final double currentPrice;
  final double? change24h;
  final double? change24hPct;
  final double? change7dPct;
  final double? change30dPct;
  final double? marketCap;
  final int? marketCapRank;
  final double? totalVolume;
  final double? high24h;
  final double? low24h;

  const CryptoMarketData({
    required this.currentPrice, this.change24h, this.change24hPct,
    this.change7dPct, this.change30dPct, this.marketCap, this.marketCapRank,
    this.totalVolume, this.high24h, this.low24h,
  });

  factory CryptoMarketData.fromJson(Map<String, dynamic> j) {
    double? n(String k) => (j[k] as num?)?.toDouble();
    return CryptoMarketData(
      currentPrice: n('current_price') ?? 0,
      change24h:    n('price_change_24h'),
      change24hPct: n('price_change_percentage_24h'),
      change7dPct:  n('price_change_percentage_7d'),
      change30dPct: n('price_change_percentage_30d'),
      marketCap:    n('market_cap'),
      marketCapRank:(j['market_cap_rank'] as num?)?.toInt(),
      totalVolume:  n('total_volume'),
      high24h:      n('high_24h'),
      low24h:       n('low_24h'),
    );
  }
}

class CryptoHistoryBar {
  final DateTime time;
  final double price;
  const CryptoHistoryBar({required this.time, required this.price});
}

// ── Providers ─────────────────────────────────────────────────────────────────

final cryptoDetailProvider = FutureProvider.autoDispose
    .family<CryptoDetail, String>((ref, id) async {
  final res = await ApiClient.dio.get('/crypto/$id');
  return CryptoDetail.fromJson(res.data as Map<String, dynamic>);
});

final cryptoHistoryProvider = FutureProvider.autoDispose
    .family<List<CryptoHistoryBar>, String>((ref, id) async {
  final res = await ApiClient.dio.get('/crypto/$id/history',
      queryParameters: {'days': '30'});
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

class CryptoDetailPage extends ConsumerWidget {
  final String coinId;
  const CryptoDetailPage({super.key, required this.coinId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cryptoDetailProvider(coinId));

    return Scaffold(
      appBar: AppBar(
        title: Text(coinId[0].toUpperCase() + coinId.substring(1)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(cryptoDetailProvider(coinId));
              ref.invalidate(cryptoHistoryProvider(coinId));
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(
              Uri.parse('https://stockmarketroi.com/crypto/$coinId'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('Failed to load $coinId',
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(cryptoDetailProvider(coinId)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emerald,
                  side: const BorderSide(color: AppColors.emerald),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (coin) => _CryptoBody(coin: coin, coinId: coinId),
      ),
    );
  }
}

class _CryptoBody extends ConsumerWidget {
  final CryptoDetail coin;
  final String coinId;
  const _CryptoBody({required this.coin, required this.coinId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final md      = coin.marketData;
    final up      = (md.change24hPct ?? 0) >= 0;
    final color   = up ? AppColors.emerald : AppColors.red;
    final history = ref.watch(cryptoHistoryProvider(coinId));

    return ListView(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.network(
                  coin.image,
                  width: 52, height: 52,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 52, height: 52,
                    color: AppColors.surfaceAlt,
                    child: Center(
                      child: Text(coin.symbol.toUpperCase().substring(0, 1),
                        style: const TextStyle(fontSize: 20,
                          fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coin.name,
                    style: const TextStyle(fontSize: 17,
                      fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text(coin.symbol.toUpperCase(),
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
              if (md.marketCapRank != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('#${md.marketCapRank}',
                    style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                ),
              ],
            ],
          ),
        ),

        // ── Price ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${_fmtPrice(md.currentPrice)}',
                style: const TextStyle(fontSize: 36,
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${up ? '+' : ''}${(md.change24hPct ?? 0).toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 14,
                      color: color, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
          child: Text('24h change', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),

        // ── Chart ─────────────────────────────────────────────────────────
        history.when(
          loading: () => Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.emerald, strokeWidth: 2)),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (bars) => bars.length < 2
              ? const SizedBox.shrink()
              : _CryptoChart(bars: bars, color: color),
        ),

        // ── Period returns ────────────────────────────────────────────────
        if (md.change7dPct != null || md.change30dPct != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                if (md.change24hPct != null)
                  _PeriodChip(label: '24h', value: md.change24hPct!),
                const SizedBox(width: 8),
                if (md.change7dPct != null)
                  _PeriodChip(label: '7d', value: md.change7dPct!),
                const SizedBox(width: 8),
                if (md.change30dPct != null)
                  _PeriodChip(label: '30d', value: md.change30dPct!),
              ],
            ),
          ),

        // ── Market data ───────────────────────────────────────────────────
        _MarketStats(md: md),

        // ── About ─────────────────────────────────────────────────────────
        if (coin.description != null && coin.description!.isNotEmpty)
          _CryptoAbout(text: coin.description!),

        const SizedBox(height: 32),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final double value;
  const _PeriodChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final up    = value >= 0;
    final color = up ? AppColors.emerald : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(
        children: [
          Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text('${up ? '+' : ''}${value.toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MarketStats extends StatelessWidget {
  final CryptoMarketData md;
  const _MarketStats({required this.md});

  @override
  Widget build(BuildContext context) {
    String fmtBig(double? v) {
      if (v == null || v == 0) return '—';
      if (v >= 1e12) return '\$${(v / 1e12).toStringAsFixed(2)}T';
      if (v >= 1e9)  return '\$${(v / 1e9).toStringAsFixed(2)}B';
      if (v >= 1e6)  return '\$${(v / 1e6).toStringAsFixed(2)}M';
      return '\$${v.toStringAsFixed(0)}';
    }

    final rows = <(String, String)>[
      if (md.marketCap != null)    ('Market Cap', fmtBig(md.marketCap)),
      if (md.totalVolume != null)  ('24h Volume', fmtBig(md.totalVolume)),
      if (md.high24h != null)      ('24h High', '\$${_fmtPrice(md.high24h!)}'),
      if (md.low24h != null)       ('24h Low',  '\$${_fmtPrice(md.low24h!)}'),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text('Market Data',
            style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceAlt),
          ),
          child: Column(
            children: rows.asMap().entries.map((entry) {
              final isLast = entry.key == rows.length - 1;
              final label  = entry.value.$1;
              final value  = entry.value.$2;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  border: isLast ? null : const Border(
                    bottom: BorderSide(color: AppColors.surfaceAlt)),
                ),
                child: Row(
                  children: [
                    Text(label,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    const Spacer(),
                    Text(value,
                      style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _CryptoChart extends StatelessWidget {
  final List<CryptoHistoryBar> bars;
  final Color color;
  const _CryptoChart({required this.bars, required this.color});

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
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
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
                getTooltipColor: (_) => AppColors.surface,
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

class _CryptoAbout extends StatefulWidget {
  final String text;
  const _CryptoAbout({required this.text});
  @override
  State<_CryptoAbout> createState() => _CryptoAboutState();
}

class _CryptoAboutState extends State<_CryptoAbout> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About',
            style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(widget.text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13,
              color: AppColors.textSecond, height: 1.6)),
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(_expanded ? 'Show less' : 'Read more',
              style: const TextStyle(color: AppColors.emerald, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtPrice(double price) {
  if (price >= 10000) return price.toStringAsFixed(0);
  if (price >= 1)     return price.toStringAsFixed(2);
  if (price >= 0.01)  return price.toStringAsFixed(4);
  return price.toStringAsFixed(8);
}
