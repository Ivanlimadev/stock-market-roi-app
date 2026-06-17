import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/stock_detail_provider.dart';
import '../../core/providers/blog_provider.dart';
import '../../core/models/stock_detail_model.dart';
import '../../core/models/blog_post_model.dart';
import '../../core/widgets/blog_post_sheet.dart';

class StockDetailPage extends ConsumerWidget {
  final String symbol;
  const StockDetailPage({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym   = symbol.toUpperCase();
    final async = ref.watch(stockDetailProvider(sym));

    return Scaffold(
      appBar: AppBar(
        title: Text(sym),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(stockDetailProvider(sym));
              ref.invalidate(stockHistoryProvider(sym));
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(
              Uri.parse('https://stockmarketroi.com/stocks/${sym.toLowerCase()}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('Failed to load $sym',
                style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(stockDetailProvider(sym)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emerald,
                  side: const BorderSide(color: AppColors.emerald),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stock) => _Body(stock: stock, sym: sym),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final StockDetail stock;
  final String sym;
  const _Body({required this.stock, required this.sym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final up      = stock.changePct >= 0;
    final color   = up ? AppColors.emerald : AppColors.red;
    final history = ref.watch(stockHistoryProvider(sym));

    return ListView(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  'https://assets.parqet.com/logos/symbol/$sym?format=png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(sym.length >= 2 ? sym.substring(0, 2) : sym,
                      style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 16, color: AppColors.textMuted)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stock.name,
                      style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (stock.exchange != null)
                      Text(stock.exchange!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    if (stock.info?.sector != null)
                      Text(stock.info!.sector!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Price ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${stock.currentPrice.toStringAsFixed(2)}',
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
                    '${up ? '+' : ''}${stock.changePct.toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
          child: Text(
            '${up ? '+' : ''}\$${stock.change.abs().toStringAsFixed(2)} today',
            style: TextStyle(fontSize: 13, color: color)),
        ),

        // ── Chart (3 months) ──────────────────────────────────────────────
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
              : _Chart(bars: bars, color: color),
        ),

        const SizedBox(height: 8),

        // ── Key Statistics ────────────────────────────────────────────────
        if (stock.info != null) _KeyStats(info: stock.info!, stock: stock),

        // ── About ─────────────────────────────────────────────────────────
        if (stock.info?.description != null && stock.info!.description!.isNotEmpty)
          _About(text: stock.info!.description!),

        // ── Related Articles ──────────────────────────────────────────────
        _RelatedArticles(sym: sym),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Chart ─────────────────────────────────────────────────────────────────────

class _Chart extends StatelessWidget {
  final List<HistoryBar> bars;
  final Color color;
  const _Chart({required this.bars, required this.color});

  @override
  Widget build(BuildContext context) {
    // bars come newest-first from the endpoint, reverse for chronological
    final sorted = bars.reversed.toList();
    final spots  = sorted.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.close))
        .toList();

    final prices = sorted.map((b) => b.close);
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
                  '\$${s.y.toStringAsFixed(2)}',
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

// ── Key Statistics ────────────────────────────────────────────────────────────

class _KeyStats extends StatelessWidget {
  final StockInfo info;
  final StockDetail stock;
  const _KeyStats({required this.info, required this.stock});

  @override
  Widget build(BuildContext context) {
    String fmtBig(double? v) {
      if (v == null || v == 0) return '—';
      if (v >= 1e12) return '\$${(v / 1e12).toStringAsFixed(2)}T';
      if (v >= 1e9)  return '\$${(v / 1e9).toStringAsFixed(2)}B';
      if (v >= 1e6)  return '\$${(v / 1e6).toStringAsFixed(2)}M';
      return '\$${v.toStringAsFixed(0)}';
    }
    String fmtVol(double? v) {
      if (v == null || v == 0) return '—';
      if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
      if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
      return v.toStringAsFixed(0);
    }
    String fmtN(double? v, {int d = 2}) => v == null || v == 0 ? '—' : v.toStringAsFixed(d);

    // Analyst consensus chip
    String? consensus;
    Color? consensusColor;
    if (info.recommendationKey != null) {
      final r = info.recommendationKey!.toLowerCase();
      if (r.contains('strong_buy') || r.contains('strongbuy')) {
        consensus = 'Strong Buy'; consensusColor = AppColors.emerald;
      } else if (r == 'buy') {
        consensus = 'Buy'; consensusColor = AppColors.emerald;
      } else if (r == 'hold') {
        consensus = 'Hold'; consensusColor = const Color(0xFFF59E0B);
      } else if (r.contains('sell')) {
        consensus = 'Sell'; consensusColor = AppColors.red;
      }
    }

    final rows = <(String, String)>[
      ('Previous Close', '\$${stock.prevClose.toStringAsFixed(2)}'),
      if (info.pe != null && info.pe! > 0)    ('P/E Ratio', fmtN(info.pe)),
      if (info.forwardPE != null && info.forwardPE! > 0) ('Forward P/E', fmtN(info.forwardPE)),
      if (info.eps != null)                   ('EPS', '\$${fmtN(info.eps)}'),
      if (info.marketCap != null)             ('Market Cap', fmtBig(info.marketCap)),
      if (info.dividendYield != null && info.dividendYield! > 0)
        ('Dividend Yield', '${(info.dividendYield! * 100).toStringAsFixed(2)}%'),
      if (info.beta != null)                  ('Beta', fmtN(info.beta, d: 2)),
      if (info.week52High != null)            ('52W High', '\$${fmtN(info.week52High)}'),
      if (info.week52Low != null)             ('52W Low',  '\$${fmtN(info.week52Low)}'),
      if (info.avgVolume10d != null)          ('Avg Volume (10d)', fmtVol(info.avgVolume10d)),
      if (info.targetMeanPrice != null)       ('Analyst Target', '\$${fmtN(info.targetMeanPrice)}'),
      if (info.sector != null)                ('Sector',   info.sector!),
      if (info.industry != null)              ('Industry', info.industry!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(
            children: [
              const Text('Key Statistics',
                style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (consensus != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: consensusColor!.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(consensus,
                    style: TextStyle(fontSize: 12,
                      color: consensusColor, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                    Flexible(
                      child: Text(value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
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

// ── About ─────────────────────────────────────────────────────────────────────

class _About extends StatefulWidget {
  final String text;
  const _About({required this.text});
  @override
  State<_About> createState() => _AboutState();
}

class _AboutState extends State<_About> {
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

// ── Related Articles ──────────────────────────────────────────────────────────

class _RelatedArticles extends ConsumerWidget {
  final String sym;
  const _RelatedArticles({required this.sym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(relatedPostsProvider(sym));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                'Related Articles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ...posts.map((post) => _RelatedPostTile(post: post)),
          ],
        );
      },
    );
  }
}

const _categoryColors = {
  'Markets':    Color(0xFF6366F1),
  'Stocks':     Color(0xFF10B981),
  'Investing':  Color(0xFFF59E0B),
  'Economics':  Color(0xFFEF4444),
  'Crypto':     Color(0xFFF97316),
  'Technology': Color(0xFF3B82F6),
};

class _RelatedPostTile extends StatelessWidget {
  final BlogPost post;
  const _RelatedPostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColors[post.category] ?? AppColors.emerald;

    return InkWell(
      onTap: () => showBlogPostSheet(context, post),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  width: 72, height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholder(catColor),
                ),
              )
            else
              _placeholder(catColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      post.category,
                      style: TextStyle(
                        fontSize: 10,
                        color: catColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    post.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Color color) => Container(
    width: 72, height: 72,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(Icons.article_rounded,
        color: color.withValues(alpha: 0.4), size: 28),
  );
}
