import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';
import '../../core/providers/stock_detail_provider.dart';
import '../../core/providers/blog_provider.dart';
import '../../core/models/stock_detail_model.dart';
import '../../core/models/blog_post_model.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/formatters.dart';
import '../../core/ads/ad_manager.dart';
import '../../core/ads/collapsible_banner_ad.dart';
import '../../core/ads/rewarded_gate.dart';
import '../../core/ads/rewarded_unlocks.dart';
import '../../core/providers/watchlist_provider.dart';
import '../../core/providers/portfolio_provider.dart';
import '../portfolio/add_transaction_sheet.dart';
import '../../core/widgets/add_alert_dialog.dart';
import '../../core/providers/financials_provider.dart';
import '../../core/utils/share_utils.dart';
import '../../core/widgets/app_footer.dart';
import '../../core/widgets/comments_section.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/auth_prompt_sheet.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class StockDetailPage extends ConsumerWidget {
  final String symbol;
  const StockDetailPage({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym          = symbol.toUpperCase();
    final async        = ref.watch(stockDetailProvider(sym));
    final inWatchlist  = ref.watch(watchlistSymbolsProvider).contains(sym);
    final hasAlert     = ref.watch(alertSymbolsProvider).contains(sym);
    final isLoggedIn   = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(sym),
        actions: [
          MainShellMenu.searchButton(),
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
                await WatchlistService.removeStock(sym);
              } else {
                final name = async.asData?.value.name ?? sym;
                await WatchlistService.addStock(symbol: sym, name: name);
              }
            },
          ),
          // Price alert — always visible; yellow when active alert exists
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
              final price = async.asData?.value.currentPrice;
              if (price == null) return;
              final name = async.asData?.value.name ?? sym;
              showAddAlertDialog(
                context,
                symbol: sym,
                name: name,
                currentPrice: price,
                assetType: 'stock',
              );
            },
          ),

          Builder(
            builder: (btnCtx) => IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share',
              onPressed: () => shareWithImage(
                btnCtx: btnCtx,
                text: '$sym — ${async.asData?.value.name ?? sym}\nhttps://stockmarketroi.com/stocks/${sym.toLowerCase()}',
                imageUrl: 'https://assets.parqet.com/logos/symbol/$sym?format=png',
                filename: '$sym.png',
              ),
            ),
          ),
          MainShellMenu.avatarButton(),
          MainShellMenu.settingsButton(),
        ],
      ),
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CollapsibleBannerAd(),
          AppBottomNav(),
        ],
      ),
      body: async.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: context.colors.textMuted),
              SizedBox(height: 12),
              Text('Falha ao carregar $sym',
                  style: TextStyle(color: context.colors.textMuted)),
              SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(stockDetailProvider(sym)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emerald,
                  side: BorderSide(color: AppColors.emerald),
                ),
                child: Text('Try again'),
              ),
            ],
          ),
        ),
        data: (stock) => _Body(stock: stock, sym: sym),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends ConsumerStatefulWidget {
  final StockDetail stock;
  final String sym;
  const _Body({required this.stock, required this.sym});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  int _periodIdx = 2; // default 3M

  static const _periods = [
    (label: '1S',  take: 5),
    (label: '1M',  take: 21),
    (label: '3M',  take: 63),
    (label: '6M',  take: 126),
    (label: '1A',  take: 252),
  ];

  @override
  Widget build(BuildContext context) {
    final stock   = widget.stock;
    final sym     = widget.sym;
    final info    = stock.info;
    final up      = stock.changePct >= 0;
    final color   = up ? AppColors.emerald : AppColors.red;
    final history = ref.watch(stockHistoryProvider(sym));

    return ListView(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        _Header(stock: stock),

        // ── Price ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtStockPrice(stock.currentPrice),
                  style: TextStyle(fontSize: 36,
                      fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
              SizedBox(width: 10),
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
                    style: TextStyle(fontSize: 14, color: color,
                        fontWeight: FontWeight.w700)),
                ),
              ),
              SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _AddToPortfolioButton(sym: sym),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
          child: Text(
            '${up ? '+' : ''}${fmtStockPrice(stock.change.abs())} hoje',
            style: TextStyle(fontSize: 13, color: color)),
        ),

        // ── Period tabs ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: List.generate(_periods.length, (i) {
              final active = _periodIdx == i;
              return GestureDetector(
                onTap: () => setState(() => _periodIdx = i),
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
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.colors.surface, borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.emerald, strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (bars) {
            if (bars.length < 2) return const SizedBox.shrink();
            final take = _periods[_periodIdx].take;
            final slice = bars.length > take
                ? bars.sublist(bars.length - take)
                : bars;
            return _Chart(bars: slice, color: color);
          },
        ),

        SizedBox(height: 12),

        // ── Performance Strip ─────────────────────────────────────────────────
        _PerformanceStrip(history: history, currentPrice: stock.currentPrice, changePct1d: stock.changePct),

        SizedBox(height: 4),

        // ── AI Insight ───────────────────────────────────────────────────────
        _AIInsightCard(sym: sym),

        // ── Analyst Consensus ────────────────────────────────────────────────
        if (info?.recommendationKey != null)
          _AnalystCard(info: info!, price: stock.currentPrice),

        // ── Investment Simulator ─────────────────────────────────────────────
        _InvestmentSimulator(sym: sym, dividends: stock.dividends),

        // ── Earnings ────────────────────────────────────────────────────────
        if (info?.nextEarningsDate != null || info?.eps != null)
          _EarningsCard(info: info!),

        // ── Earnings History (quarterly EPS) ─────────────────────────────────
        _EarningsHistorySection(sym: sym),

        // ── Financial Charts (revenue / net income, rewarded-gated) ───────────
        RewardedGate(
          featureKey: RewardedUnlocks.financials,
          icon: Icons.bar_chart_rounded,
          title: 'Financials',
          description: 'Watch a short ad to unlock revenue & net income charts — '
              'stays unlocked for every stock this session.',
          child: _FinancialSection(sym: sym),
        ),

        // ── Key Statistics ───────────────────────────────────────────────────
        if (info != null) _KeyStats(info: info, stock: stock),

        // ── Dividends ────────────────────────────────────────────────────────
        if (stock.dividends.isNotEmpty)
          _DividendsCard(dividends: stock.dividends, info: info),

        // ── Magic Number ─────────────────────────────────────────────────────
        if (stock.dividends.isNotEmpty)
          _MagicNumber(dividends: stock.dividends, price: stock.currentPrice),

        // ── Buy & Hold Checklist ─────────────────────────────────────────────
        if (info != null) _BuyHoldChecklist(
            info: info, price: stock.currentPrice, dividends: stock.dividends),

        // ── Fair Value ───────────────────────────────────────────────────────
        if (info != null) _FairValueCard(info: info),

        // ── Company Info ─────────────────────────────────────────────────────
        if (info != null) _CompanyInfo(info: info, sym: sym),

        // ── About ────────────────────────────────────────────────────────────
        if (info?.description != null && info!.description!.isNotEmpty)
          _About(text: info.description!),

        // ── SEC Filings (rewarded-gated) ──────────────────────────────────────
        RewardedGate(
          featureKey: RewardedUnlocks.secFilings,
          icon: Icons.description_outlined,
          title: 'SEC Filings',
          description: 'Watch a short ad to unlock the latest SEC filings — '
              'stays unlocked for every stock this session.',
          child: _SecFilingsSection(sym: sym),
        ),

        // ── Insider Transactions (SEC Form 4, rewarded-gated) ─────────────────
        RewardedGate(
          featureKey: RewardedUnlocks.insiders,
          icon: Icons.badge_outlined,
          title: 'Insider Transactions',
          description: 'Watch a short ad to unlock insider (Form 4) trades — '
              'stays unlocked for every stock this session.',
          child: _InsiderSection(sym: sym),
        ),

        // ── Discussion ────────────────────────────────────────────────────────
        CommentsSection(target: (type: 'stock', id: sym)),

        // ── Related Articles ──────────────────────────────────────────────────
        _RelatedArticles(sym: sym),

        // ── Footer ────────────────────────────────────────────────────────────
        const AppFooter(),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final StockDetail stock;
  const _Header({required this.stock});

  @override
  Widget build(BuildContext context) {
    final info = stock.info;
    final breadcrumb = [info?.sector, info?.industry]
        .whereType<String>()
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              'https://assets.parqet.com/logos/symbol/${stock.symbol}?format=png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  stock.symbol.length >= 2 ? stock.symbol.substring(0, 2) : stock.symbol,
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 16, color: context.colors.textMuted)),
              ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stock.name,
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                if (stock.exchange != null)
                  Text(stock.exchange!,
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                if (breadcrumb.isNotEmpty)
                  Text(breadcrumb,
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              ],
            ),
          ),
        ],
      ),
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
    final spots = bars.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.close))
        .toList();
    final prices = bars.map((b) => b.close);
    final minY   = prices.reduce(math.min);
    final maxY   = prices.reduce(math.max);
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
                getTooltipColor: (_) => context.colors.surface,
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  fmtStockPrice(s.y),
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

// ── Analyst Consensus ─────────────────────────────────────────────────────────

class _AnalystCard extends StatelessWidget {
  final StockInfo info;
  final double price;
  const _AnalystCard({required this.info, required this.price});

  ({String label, Color color}) get _verdict {
    final r = (info.recommendationKey ?? '').toLowerCase();
    if (r.contains('strong_buy') || r.contains('strongbuy'))
      return (label: 'Strong Buy', color: AppColors.emerald);
    if (r == 'buy')
      return (label: 'Buy', color: AppColors.emerald);
    if (r == 'hold' || r == 'neutral')
      return (label: 'Neutral', color: const Color(0xFFF59E0B));
    if (r.contains('underperform') || r == 'sell')
      return (label: 'Sell', color: AppColors.red);
    return (label: r, color: AppColors.textMuted);
  }

  @override
  Widget build(BuildContext context) {
    final v = _verdict;
    return _Section(
      title: 'Consenso Analistas',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: v.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(v.label,
                      style: TextStyle(fontSize: 15, color: v.color,
                          fontWeight: FontWeight.w800)),
                ),
                if (info.numberOfAnalystOpinions != null) ...[
                  SizedBox(width: 10),
                  Text('${info.numberOfAnalystOpinions} analistas',
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                ],
              ],
            ),
            if (info.targetMeanPrice != null) ...[
              SizedBox(height: 14),
              Row(
                children: [
                  _TargetChip('Low',     info.targetLowPrice,  price),
                  SizedBox(width: 8),
                  _TargetChip('Avg',     info.targetMeanPrice, price, highlight: true),
                  SizedBox(width: 8),
                  _TargetChip('High',    info.targetHighPrice, price),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final double? target;
  final double price;
  final bool highlight;
  const _TargetChip(this.label, this.target, this.price, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    if (target == null) return const SizedBox.shrink();
    final pct = ((target! - price) / price * 100);
    final up  = pct >= 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlight ? AppColors.emerald.withValues(alpha: 0.08) : context.colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: highlight ? AppColors.emerald.withValues(alpha: 0.3) : context.colors.surfaceAlt),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
            SizedBox(height: 4),
            Text(fmtStockPrice(target!),
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: highlight ? AppColors.emerald : context.colors.textPrimary)),
            Text('${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 10,
                    color: up ? AppColors.emerald : AppColors.red,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Earnings ──────────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  final StockInfo info;
  const _EarningsCard({required this.info});

  @override
  Widget build(BuildContext context) {
    int? daysUntil;
    String? formattedDate;
    if (info.nextEarningsDate != null) {
      try {
        final dt   = DateTime.parse(info.nextEarningsDate!);
        final diff = dt.difference(DateTime.now());
        daysUntil  = diff.inDays;
        formattedDate =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {}
    }

    final rows = <(String, String)>[
      if (formattedDate != null)
        ('Next earnings', formattedDate),
      if (daysUntil != null && daysUntil >= 0)
        ('Days remaining', '$daysUntil days'),
      if (info.eps != null && info.eps! != 0)
        ('EPS (TTM)', '\$${info.eps!.toStringAsFixed(2)}'),
      if (info.pe != null && info.pe! > 0)
        ('P/E (TTM)', info.pe!.toStringAsFixed(1)),
      if (info.forwardPE != null && info.forwardPE! > 0)
        ('Forward P/E', info.forwardPE!.toStringAsFixed(1)),
      if (info.pegRatio != null && info.pegRatio! > 0)
        ('PEG Ratio', info.pegRatio!.toStringAsFixed(2)),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Resultados',
      child: _RowList(rows: rows),
    );
  }
}

// ── Key Statistics ────────────────────────────────────────────────────────────

class _KeyStats extends StatefulWidget {
  final StockInfo info;
  final StockDetail stock;
  const _KeyStats({required this.info, required this.stock});

  @override
  State<_KeyStats> createState() => _KeyStatsState();
}

class _KeyStatsState extends State<_KeyStats> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final stock = widget.stock;
    String fmtN(double? v, {int d = 2}) =>
        v == null || v == 0 ? '—' : v.toStringAsFixed(d);
    String fmtVol(double? v) {
      if (v == null || v == 0) return '—';
      if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
      if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
      if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
      return v.toStringAsFixed(0);
    }
    String fmtPct(double? v) =>
        v == null ? '—' : '${(v * 100).toStringAsFixed(2)}%';

    // Build all sections, keeping only rows that have data.
    final sections = <(String, List<(String, String)>)>[
      ('Valuation', [
        ('Market Cap',    fmtBigUsd(info.marketCap)),
        ('P/E (TTM)',     info.pe != null && info.pe! > 0 ? fmtN(info.pe) : '—'),
        ('Forward P/E',   info.forwardPE != null && info.forwardPE! > 0 ? fmtN(info.forwardPE) : '—'),
        ('PEG Ratio',     info.pegRatio != null && info.pegRatio! > 0 ? fmtN(info.pegRatio) : '—'),
        ('EPS',           info.eps != null ? '\$${fmtN(info.eps)}' : '—'),
        ('P/B Ratio',     info.priceToBook != null && info.priceToBook! > 0 ? fmtN(info.priceToBook) : '—'),
      ].where((r) => r.$2 != '—').toList()),
      ('Trading', [
        ('Prev. Close',   fmtStockPrice(stock.prevClose)),
        ('52W High',      info.week52High != null ? fmtStockPrice(info.week52High!) : '—'),
        ('52W Low',       info.week52Low  != null ? fmtStockPrice(info.week52Low!)  : '—'),
        ('Avg Vol 3M',    fmtVol(info.avgVolume3m)),
        ('Avg Vol 10D',   fmtVol(info.avgVolume10d)),
        ('Beta',          fmtN(info.beta)),
        ('Analyst Target',info.targetMeanPrice != null ? fmtStockPrice(info.targetMeanPrice!) : '—'),
      ].where((r) => r.$2 != '—').toList()),
      if ((info.dividendYield ?? 0) > 0)
        ('Dividends', [
          ('Dividend Yield',  fmtPct(info.dividendYield)),
          ('Annual Dividend', info.dividendRate != null ? '\$${fmtN(info.dividendRate)}' : '—'),
          ('Ex-Dividend',     info.exDividendDate ?? '—'),
          ('Payout Ratio',    info.payoutRatio != null ? '${(info.payoutRatio! * 100).toStringAsFixed(1)}%' : '—'),
        ].where((r) => r.$2 != '—').toList()),
      if (info.profitMargin != null || info.roe != null)
        ('Return', [
          ('Net Margin',      info.profitMargin   != null ? '${(info.profitMargin! * 100).toStringAsFixed(1)}%' : '—'),
          ('Op. Margin',      info.operatingMargin != null ? '${(info.operatingMargin! * 100).toStringAsFixed(1)}%' : '—'),
          ('ROE',             info.roe != null ? '${(info.roe! * 100).toStringAsFixed(1)}%' : '—'),
          ('ROA',             info.roa != null ? '${(info.roa! * 100).toStringAsFixed(1)}%' : '—'),
          ('Rev. Growth',     info.revenueGrowth  != null ? '${(info.revenueGrowth! * 100).toStringAsFixed(1)}%' : '—'),
          ('EPS Growth',      info.earningsGrowth != null ? '${(info.earningsGrowth! * 100).toStringAsFixed(1)}%' : '—'),
        ].where((r) => r.$2 != '—').toList()),
      if (info.totalRevenue != null || info.freeCashflow != null)
        ('Balance Sheet', [
          ('Total Revenue',  fmtBigUsd(info.totalRevenue)),
          ('Total Debt',     fmtBigUsd(info.totalDebt)),
          ('Debt/Equity',    info.debtToEquity   != null ? fmtN(info.debtToEquity, d: 2) : '—'),
          ('Current Ratio',  info.currentRatio    != null ? fmtN(info.currentRatio,  d: 2) : '—'),
          ('Free Cash Flow', fmtBigUsd(info.freeCashflow)),
        ].where((r) => r.$2 != '—' && r.$2 != '\$—').toList()),
    ].where((s) => s.$2.isNotEmpty).toList();

    final allRows = sections.expand((s) => s.$2).toList();
    final total = allRows.length;

    return _Section(
      title: 'Statistics',
      child: Column(
        children: [
          if (_showAll)
            for (final s in sections) ...[
              _SubHeader(s.$1),
              _RowList(rows: s.$2),
            ]
          else
            _RowList(rows: allRows.take(5).toList()),

          if (total > 5)
            InkWell(
              onTap: () => setState(() => _showAll = !_showAll),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: context.colors.surfaceAlt, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_showAll ? 'Show less' : 'See all $total statistics',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.emerald)),
                    const SizedBox(width: 4),
                    Icon(
                        _showAll
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: context.colors.emerald),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String title;
  const _SubHeader(this.title);

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: context.colors.surfaceAlt.withValues(alpha: 0.5),
    child: Text(title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: context.colors.textMuted, letterSpacing: 0.5)),
  );
}

// ── Dividends Card ────────────────────────────────────────────────────────────

class _DividendsCard extends StatelessWidget {
  final List<DividendPayment> dividends;
  final StockInfo? info;
  const _DividendsCard({required this.dividends, this.info});

  @override
  Widget build(BuildContext context) {
    final recent = dividends.take(8).toList();
    final lastPay = dividends.isNotEmpty ? dividends.first.amount : null;

    return _Section(
      title: 'Dividends',
      child: Column(
        children: [
          if (info?.dividendYield != null || lastPay != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  if (info?.dividendYield != null)
                    _DivChip('Yield',
                        '${(info!.dividendYield! * 100).toStringAsFixed(2)}%'),
                  if (lastPay != null) ...[
                    SizedBox(width: 10),
                    _DivChip('Last pay.', '\$${lastPay.toStringAsFixed(4)}'),
                  ],
                  if (info?.dividendRate != null) ...[
                    SizedBox(width: 10),
                    _DivChip('Annual', '\$${info!.dividendRate!.toStringAsFixed(2)}'),
                  ],
                ],
              ),
            ),
          ...recent.asMap().entries.map((e) {
            final isLast = e.key == recent.length - 1;
            final d = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: isLast ? null : Border(
                    bottom: BorderSide(color: context.colors.surfaceAlt, width: 0.5)),
              ),
              child: Row(
                children: [
                  Text(d.date,
                      style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
                  const Spacer(),
                  Text('\$${d.amount.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: AppColors.emerald)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DivChip extends StatelessWidget {
  final String label, value;
  const _DivChip(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: context.colors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.colors.surfaceAlt),
    ),
    child: Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
        SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.emerald)),
      ],
    ),
  );
}

// ── Buy & Hold Checklist ──────────────────────────────────────────────────────

class _BuyHoldChecklist extends StatelessWidget {
  final StockInfo info;
  final double price;
  final List<DividendPayment> dividends;
  const _BuyHoldChecklist({required this.info, required this.price, required this.dividends});

  @override
  Widget build(BuildContext context) {
    // Dividend history years
    final divYears = dividends.isNotEmpty
        ? DateTime.now().year -
          DateTime.tryParse(dividends.last.date)!.year
        : 0;
    final paysDivs = dividends.isNotEmpty;

    // Liquidity
    final liquidity = info.avgVolume3m != null && price > 0
        ? info.avgVolume3m! * price : null;
    String? liquidityVal;
    if (liquidity != null) {
      liquidityVal = liquidity >= 1e9
          ? '\$${(liquidity / 1e9).toStringAsFixed(1)}B/d'
          : '\$${(liquidity / 1e6).toStringAsFixed(0)}M/d';
    }

    final items = <(String, String, bool?, String?)>[
      // (label, detail, pass?, value)
      ('Pays dividends',            'Dividend history found',
          paysDivs ? true : false,
          paysDivs ? '${divYears}Y hist.' : null),
      ('Consistent dividend (5Y+)', 'Uninterrupted payments for ≥ 5 years',
          paysDivs ? (divYears >= 5 ? true : false) : null,
          divYears > 0 ? '$divYears yrs' : null),
      ('ROE > 10%',                 'Return on equity — efficient use of capital',
          info.roe != null ? (info.roe! * 100) > 10 : null,
          info.roe != null ? '${(info.roe! * 100).toStringAsFixed(1)}%' : null),
      ('Positive net margin',       'Company earns more than it spends',
          info.profitMargin != null ? info.profitMargin! > 0 : null,
          info.profitMargin != null ? '${(info.profitMargin! * 100).toStringAsFixed(1)}%' : null),
      ('Revenue growth',            'Annual revenue growing vs. prior year',
          info.revenueGrowth != null ? info.revenueGrowth! > 0 : null,
          info.revenueGrowth != null
              ? '${info.revenueGrowth! >= 0 ? '+' : ''}${(info.revenueGrowth! * 100).toStringAsFixed(1)}%'
              : null),
      ('Earnings growth',           'Annual earnings growing vs. prior year',
          info.earningsGrowth != null ? info.earningsGrowth! > 0 : null,
          info.earningsGrowth != null
              ? '${info.earningsGrowth! >= 0 ? '+' : ''}${(info.earningsGrowth! * 100).toStringAsFixed(1)}%'
              : null),
      ('Debt/Equity < 2×',          'Low leverage reduces financial risk',
          info.debtToEquity != null ? info.debtToEquity! < 2 : null,
          info.debtToEquity != null ? '${info.debtToEquity!.toStringAsFixed(2)}×' : null),
      ('Current ratio > 1',         'Short-term assets cover liabilities',
          info.currentRatio != null ? info.currentRatio! > 1 : null,
          info.currentRatio != null ? '${info.currentRatio!.toStringAsFixed(2)}×' : null),
      ('Daily volume > \$5M',       'High liquidity ensures easy entry and exit',
          liquidity != null ? liquidity > 5e6 : null,
          liquidityVal),
      ('Dividend yield > 0%',       'Returns income to shareholders',
          info.dividendYield != null ? info.dividendYield! > 0 : null,
          info.dividendYield != null ? '${(info.dividendYield! * 100).toStringAsFixed(2)}%' : null),
    ];

    final passed = items.where((i) => i.$3 == true).length;
    final applicable = items.where((i) => i.$3 != null).length;
    final total = items.length;
    final pct = applicable > 0 ? passed / applicable : 0.0;
    final scoreColor = pct >= 0.7 ? AppColors.emerald
        : pct >= 0.4 ? const Color(0xFFF59E0B)
        : AppColors.red;

    return _Section(
      title: 'Buy & Hold Checklist',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header: score + progress bar
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$passed/$total',
                        style: TextStyle(fontSize: 26,
                            fontWeight: FontWeight.w800, color: scoreColor)),
                    Text('${(pct * 100).toStringAsFixed(0)}% score',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: scoreColor)),
                  ],
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: context.colors.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...items.map((item) {
              final pass = item.$3;
              final value = item.$4;
              final color = pass == null ? context.colors.textMuted
                  : pass ? AppColors.emerald : AppColors.red;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      pass == null ? Icons.remove_circle_outline_rounded
                          : pass ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 17, color: color,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1,
                              style: TextStyle(fontSize: 13,
                                  color: pass == null
                                      ? context.colors.textMuted
                                      : context.colors.textPrimary)),
                          Text(item.$2,
                              style: TextStyle(
                                  fontSize: 11, color: context.colors.textMuted)),
                        ],
                      ),
                    ),
                    if (value != null) ...[
                      SizedBox(width: 8),
                      Text(value,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: color, fontFamily: 'monospace')),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Fair Value ────────────────────────────────────────────────────────────────

class _FairValueCard extends StatelessWidget {
  final StockInfo info;
  const _FairValueCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final eps  = info.eps;
    final bv   = info.bookValue;
    if (eps == null || eps <= 0 || bv == null || bv <= 0) return const SizedBox.shrink();

    final graham = math.sqrt(22.5 * eps * bv);

    return _Section(
      title: 'Fair Value',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.colors.surfaceAlt),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Graham Number',
                            style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                        SizedBox(height: 6),
                        Text(fmtStockPrice(graham),
                            style: TextStyle(fontSize: 17,
                                fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                        SizedBox(height: 4),
                        Text('√(22.5 × EPS × Book Value)',
                            style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'Simplified estimate based on Benjamin Graham\'s formula. Not an investment recommendation.',
              style: TextStyle(fontSize: 11, color: context.colors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Company Info ──────────────────────────────────────────────────────────────

class _CompanyInfo extends StatelessWidget {
  final StockInfo info;
  final String sym;
  const _CompanyInfo({required this.info, required this.sym});

  @override
  Widget build(BuildContext context) {
    final location = [info.city, info.country].whereType<String>().join(', ');
    final rows = <(String, String, bool)>[
      if (info.sector   != null) ('Sector',      info.sector!,   false),
      if (info.industry != null) ('Industry',    info.industry!, false),
      if (location.isNotEmpty)   ('Location',    location,       false),
      if (info.employees != null)
        ('Employees', _fmtEmployees(info.employees!), false),
      if (info.website  != null) ('Website',     info.website!,  true),
    ];

    return _Section(
      title: 'Company Info',
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          final label  = e.value.$1;
          final value  = e.value.$2;
          final isLink = e.value.$3;
          return InkWell(
            onTap: isLink
                ? () => launchUrl(Uri.parse(value),
                    mode: LaunchMode.externalApplication)
                : null,
            child: Container(
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
                  Flexible(
                    child: Text(value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLink ? AppColors.emerald : context.colors.textPrimary,
                        )),
                  ),
                  if (isLink) ...[
                    SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 14, color: AppColors.emerald),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _fmtEmployees(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
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
    return _Section(
      title: 'About',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(widget.text,
                maxLines: _expanded ? null : 4,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13,
                    color: context.colors.textSecond, height: 1.6)),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_expanded ? 'Show less' : 'Read more',
                  style: TextStyle(color: AppColors.emerald, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Related Articles ──────────────────────────────────────────────────────────

class _RelatedArticles extends ConsumerWidget {
  final String sym;
  const _RelatedArticles({required this.sym});

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
    final async = ref.watch(relatedPostsProvider(sym));
    return async.when(
      loading: () => _Section(
        title: 'Artigos Relacionados',
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(
              color: AppColors.emerald, strokeWidth: 2)),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();
        return _Section(
          title: 'Artigos Relacionados',
          child: Column(
            children: [
              // Destaque: primeiro post com excerpt
              _ArticleFeatured(post: posts.first, catColors: _catColors),
              // Demais posts como lista simples
              ...posts.skip(1).map(
                (p) => _ArticleTile(post: p, catColors: _catColors)),
            ],
          ),
        );
      },
    );
  }
}

class _ArticleFeatured extends StatelessWidget {
  final BlogPost post;
  final Map<String, Color> catColors;
  const _ArticleFeatured({required this.post, required this.catColors});

  @override
  Widget build(BuildContext context) {
    final color = catColors[post.category] ?? AppColors.emerald;
    return InkWell(
      onTap: () => context.push('/blog/${post.slug}', extra: post),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity, height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (post.imageUrl != null) SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(post.category,
                    style: TextStyle(fontSize: 10, color: color,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            SizedBox(height: 8),
            Text(post.title,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary, height: 1.35)),
            if (post.excerpt != null && post.excerpt!.isNotEmpty) ...[
              SizedBox(height: 6),
              Text(post.excerpt!,
                  maxLines: 4, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: context.colors.textMuted,
                      height: 1.5)),
            ],
            SizedBox(height: 10),
            Row(children: [
              Text('Read full article',
                  style: TextStyle(fontSize: 12, color: AppColors.emerald,
                      fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.emerald),
            ]),
          ],
        ),
      ),
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
          border: Border(top: BorderSide(color: context.colors.surfaceAlt, width: 0.5)),
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

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

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

// ── Add to portfolio button ───────────────────────────────────────────────────

class _AddToPortfolioButton extends ConsumerWidget {
  final String sym;
  const _AddToPortfolioButton({required this.sym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inPortfolio = ref.watch(portfolioSymbolsProvider).contains(sym);
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final accent = inPortfolio ? AppColors.emerald : context.colors.textSecond;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        if (!isLoggedIn) {
          showAuthPromptSheet(context, action: 'add to your portfolio');
          return;
        }
        showAddTransactionSheet(context, initialSymbol: sym);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            inPortfolio
                ? Icons.account_balance_wallet_rounded
                : Icons.account_balance_wallet_outlined,
            size: 16, color: accent,
          ),
          if (!inPortfolio) ...[
            SizedBox(width: 1),
            Icon(Icons.add_rounded, size: 14, color: accent),
          ],
        ]),
      ),
    );
  }
}

// ── AI Insight ────────────────────────────────────────────────────────────────

class _AIInsightCard extends ConsumerStatefulWidget {
  final String sym;
  const _AIInsightCard({required this.sym});

  @override
  ConsumerState<_AIInsightCard> createState() => _AIInsightCardState();
}

class _AIInsightCardState extends ConsumerState<_AIInsightCard> {
  bool _unlocked = false;
  bool _loadingAd = false;

  String get sym => widget.sym;

  void _unlock() {
    setState(() => _loadingAd = true);
    AdManager.instance.showRewarded(
      onReward: () {
        if (mounted) setState(() => _unlocked = true);
      },
      onUnavailable: () {
        if (!mounted) return;
        setState(() {
          _loadingAd = false;
          _unlocked = true; // don't punish the user if no ad is available
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Teaser uses a reduced payload (no bull/bear); the full analysis is only
    // fetched once the rewarded ad has unlocked it.
    final async = _unlocked
        ? ref.watch(stockAIInsightProvider(sym))
        : ref.watch(stockAIInsightTeaserProvider(sym));

    return _Section(
      title: 'AI Insight',
      child: async.when(
        loading: () => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: const Color(0xFF8B5CF6)),
                SizedBox(width: 6),
                Text('Powered by Claude',
                    style: TextStyle(fontSize: 11, color: const Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w600)),
              ]),
              SizedBox(height: 12),
              _shimmer(context, 80, double.infinity),
              SizedBox(height: 8),
              _shimmer(context, 60, 220),
              SizedBox(height: 8),
              _shimmer(context, 60, 180),
            ],
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (insight) {
          if (!_unlocked) return _teaser(context, insight);
          final cfg = _verdictCfg(insight.verdict);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: const Color(0xFF8B5CF6)),
                  SizedBox(width: 6),
                  Text('Powered by Claude',
                      style: TextStyle(fontSize: 11, color: const Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w600)),
                ]),
                SizedBox(height: 14),
                // Verdict badge + confidence
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: cfg.$1.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cfg.$1.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(cfg.$2, size: 16, color: cfg.$1),
                      SizedBox(width: 6),
                      Text(insight.verdict,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                              color: cfg.$1, letterSpacing: 0.5)),
                    ]),
                  ),
                  SizedBox(width: 12),
                  Text('Confidence: ',
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                  Text(insight.confidence,
                      style: TextStyle(fontSize: 12, color: context.colors.textSecond,
                          fontWeight: FontWeight.w600)),
                ]),
                SizedBox(height: 14),
                // Summary
                Text(insight.summary,
                    style: TextStyle(fontSize: 13, color: context.colors.textSecond,
                        height: 1.55)),
                if (insight.bull != null || insight.bear != null) ...[
                  SizedBox(height: 14),
                  Row(children: [
                    if (insight.bull != null)
                      Expanded(child: _CaseCard(
                        label: 'Bull Case', text: insight.bull!,
                        color: AppColors.emerald,
                      )),
                    if (insight.bull != null && insight.bear != null)
                      SizedBox(width: 10),
                    if (insight.bear != null)
                      Expanded(child: _CaseCard(
                        label: 'Bear Case', text: insight.bear!,
                        color: AppColors.red,
                      )),
                  ]),
                ],
                SizedBox(height: 12),
                Text('AI-generated analysis for informational purposes only. Not financial advice.',
                    style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Free teaser: real verdict + confidence + a clipped summary, with the full
  /// bull/bear analysis blurred behind a rewarded-ad gate.
  Widget _teaser(BuildContext context, AIInsight insight) {
    final c = context.colors;
    final cfg = _verdictCfg(insight.verdict);
    final summary = insight.summary;
    final teaser = summary.length > 130
        ? '${summary.substring(0, 130).trimRight()}…'
        : summary;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: const Color(0xFF8B5CF6)),
            SizedBox(width: 6),
            Text('Powered by Claude',
                style: TextStyle(fontSize: 11, color: const Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w600)),
          ]),
          SizedBox(height: 14),
          // Verdict + confidence (shown free — the hook)
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cfg.$1.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cfg.$1.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(cfg.$2, size: 16, color: cfg.$1),
                SizedBox(width: 6),
                Text(insight.verdict,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                        color: cfg.$1, letterSpacing: 0.5)),
              ]),
            ),
            SizedBox(width: 12),
            Text('Confidence: ',
                style: TextStyle(fontSize: 12, color: c.textMuted)),
            Text(insight.confidence,
                style: TextStyle(fontSize: 12, color: c.textSecond,
                    fontWeight: FontWeight.w600)),
          ]),
          SizedBox(height: 14),
          // Clipped summary with a fade-out at the bottom
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.textSecond, c.textSecond.withValues(alpha: 0.15)],
            ).createShader(rect),
            blendMode: BlendMode.srcIn,
            child: Text(teaser,
                style: TextStyle(fontSize: 13, color: c.textSecond, height: 1.55)),
          ),
          SizedBox(height: 16),
          // Locked full analysis
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
            decoration: BoxDecoration(
              color: c.surfaceAlt.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.surfaceAlt),
            ),
            child: Column(children: [
              Icon(Icons.lock_outline_rounded, size: 22, color: c.textMuted),
              SizedBox(height: 8),
              Text('Bull case, bear case & full analysis',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: c.textSecond,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loadingAd ? null : _unlock,
                  icon: _loadingAd
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: Text(_loadingAd
                      ? 'Loading…'
                      : 'Watch ad to reveal full analysis'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _shimmer(BuildContext context, double h, double w) => Container(
    height: h, width: w,
    decoration: BoxDecoration(
      color: context.colors.surfaceAlt,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  // (color, icon)
  (Color, IconData) _verdictCfg(String v) => switch (v) {
    'BUY'  => (AppColors.emerald, Icons.trending_up_rounded),
    'SELL' => (AppColors.red,     Icons.trending_down_rounded),
    _      => (const Color(0xFFF59E0B), Icons.remove_rounded),
  };
}

class _CaseCard extends StatelessWidget {
  final String label, text;
  final Color color;
  const _CaseCard({required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: color, letterSpacing: 0.8)),
          SizedBox(height: 5),
          Text(text, style: TextStyle(fontSize: 11, color: context.colors.textSecond,
              height: 1.45)),
        ],
      ),
    );
  }
}

// ── Investment Simulator ──────────────────────────────────────────────────────

class _InvestmentSimulator extends ConsumerStatefulWidget {
  final String sym;
  final List<DividendPayment> dividends;
  const _InvestmentSimulator({required this.sym, required this.dividends});

  @override
  ConsumerState<_InvestmentSimulator> createState() => _InvestmentSimulatorState();
}

class _InvestmentSimulatorState extends ConsumerState<_InvestmentSimulator> {
  final _ctrl = TextEditingController(text: '1000');
  String _period = '1A';

  static const _periods = [
    ('7D', 7), ('1M', 30), ('6M', 182), ('YTD', -1),
    ('1A', 365), ('2A', 730), ('5A', 1825), ('10A', 3650),
  ];

  int get _days {
    if (_period == 'YTD') {
      final now = DateTime.now();
      return now.difference(DateTime(now.year)).inDays;
    }
    return _periods.firstWhere((p) => p.$1 == _period).$2;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ({double? priceOnly, double? withDiv}) _calc(List<HistoryBar> bars) {
    final amount = double.tryParse(_ctrl.text) ?? 1000;
    if (amount <= 0 || bars.isEmpty) return (priceOnly: null, withDiv: null);

    final cutoff = DateTime.now().subtract(Duration(days: _days));
    final slice  = bars.where((b) {
      final d = DateTime.tryParse(b.date);
      return d != null && d.isAfter(cutoff);
    }).toList();

    if (slice.isEmpty) return (priceOnly: null, withDiv: null);
    final startPrice = slice.first.close;
    final endPrice   = slice.last.close;
    if (startPrice <= 0) return (priceOnly: null, withDiv: null);

    final shares     = amount / startPrice;
    final priceOnly  = shares * endPrice;

    // Dividend reinvestment
    double totalShares = shares;
    final cutoffDate = cutoff;
    for (final d in widget.dividends) {
      final dt = DateTime.tryParse(d.date);
      if (dt == null || dt.isBefore(cutoffDate)) continue;
      // Find closest bar price on/after ex-date
      final bar = bars.firstWhere(
        (b) {
          final bd = DateTime.tryParse(b.date);
          return bd != null && !bd.isBefore(dt);
        },
        orElse: () => slice.last,
      );
      if (bar.close > 0) {
        totalShares += (totalShares * d.amount) / bar.close;
      }
    }
    final withDiv = totalShares * endPrice;

    return (priceOnly: priceOnly, withDiv: withDiv);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stockLongHistoryProvider(widget.sym));

    return _Section(
      title: 'If You Had Invested…',
      child: Column(
        children: [
          // Amount input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              Text('Amount invested',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted,
                      fontWeight: FontWeight.w600)),
              Spacer(),
              Container(
                width: 130,
                decoration: BoxDecoration(
                  color: context.colors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('\$', style: TextStyle(color: context.colors.textMuted,
                        fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none, isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          // Period chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: _periods.map((p) {
                final active = _period == p.$1;
                return GestureDetector(
                  onTap: () => setState(() => _period = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? AppColors.emerald : context.colors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: active ? AppColors.emerald : context.colors.border),
                    ),
                    child: Text(p.$1,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: active ? Colors.white : context.colors.textMuted)),
                  ),
                );
              }).toList(),
            ),
          ),
          // Results
          Padding(
            padding: const EdgeInsets.all(16),
            child: async.when(
              loading: () => Row(children: [
                Expanded(child: _SimCard(label: 'Price', value: null, pct: null)),
                SizedBox(width: 10),
                Expanded(child: _SimCard(label: '+ Dividends', value: null, pct: null)),
              ]),
              error: (_, __) => Text('Historical data unavailable',
                  style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
              data: (bars) {
                final result = _calc(bars);
                final amount = double.tryParse(_ctrl.text) ?? 1000;
                final pctPrice = result.priceOnly != null
                    ? ((result.priceOnly! - amount) / amount) * 100 : null;
                final pctDiv = result.withDiv != null
                    ? ((result.withDiv! - amount) / amount) * 100 : null;
                return Row(children: [
                  Expanded(child: _SimCard(
                      label: 'Price',
                      value: result.priceOnly,
                      pct: pctPrice)),
                  SizedBox(width: 10),
                  Expanded(child: _SimCard(
                      label: '+ Dividends',
                      value: result.withDiv,
                      pct: pctDiv,
                      highlight: result.withDiv != null)),
                ]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '* Reinvestment calculated at the ex-dividend date price. For informational purposes only.',
              style: TextStyle(fontSize: 10, color: context.colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimCard extends StatelessWidget {
  final String label;
  final double? value;
  final double? pct;
  final bool highlight;
  const _SimCard({required this.label, required this.value, required this.pct,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = pct == null ? context.colors.textPrimary
        : pct! >= 0 ? AppColors.emerald : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.emerald.withValues(alpha: 0.06)
            : context.colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? AppColors.emerald.withValues(alpha: 0.3)
              : context.colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: context.colors.textMuted, letterSpacing: 0.5)),
          SizedBox(height: 8),
          value == null
              ? Container(height: 22, width: 80,
                  decoration: BoxDecoration(color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(4)))
              : Text('\$${value!.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary)),
          if (pct != null) ...[
            SizedBox(height: 4),
            Text('${pct! >= 0 ? '+' : ''}${pct!.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ],
      ),
    );
  }
}

// ── Performance Strip ─────────────────────────────────────────────────────────

class _PerformanceStrip extends StatelessWidget {
  final AsyncValue<List<HistoryBar>> history;
  final double currentPrice;
  final double changePct1d;
  const _PerformanceStrip({required this.history, required this.currentPrice, required this.changePct1d});

  @override
  Widget build(BuildContext context) {
    return history.maybeWhen(
      data: (bars) {
        if (bars.length < 2) return const SizedBox.shrink();

        double? _ret(int n) {
          if (bars.length <= n) return null;
          final base = bars[bars.length - 1 - n].close;
          if (base <= 0) return null;
          return (currentPrice / base - 1) * 100;
        }

        final periods = [
          ('1D',  changePct1d),   // YF real-time — mais preciso que EOD
          ('5D',  _ret(5)),
          ('1M',  _ret(21)),
          ('3M',  _ret(63)),
          ('6M',  _ret(126)),
          ('1Y',  _ret(bars.length - 1)),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(color: context.colors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: periods.map((p) {
                final pct   = p.$2;
                final isPos = (pct ?? 0) >= 0;
                final color = pct == null
                    ? context.colors.textMuted
                    : (isPos ? AppColors.emerald : AppColors.red);
                return Expanded(
                  child: Column(
                    children: [
                      Text(p.$1,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textMuted)),
                      const SizedBox(height: 3),
                      Text(
                        pct == null
                            ? '—'
                            : '${isPos ? '+' : ''}${pct.toStringAsFixed(2)}%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _RowList extends StatelessWidget {
  final List<(String, String)> rows;
  const _RowList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows.asMap().entries.map((e) {
        final isLast = e.key == rows.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: isLast ? null : Border(
                bottom: BorderSide(color: context.colors.surfaceAlt, width: 0.5)),
          ),
          child: Row(
            children: [
              Text(e.value.$1,
                  style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
              const Spacer(),
              Flexible(
                child: Text(e.value.$2,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Earnings History Section ──────────────────────────────────────────────────

class _EarningsHistorySection extends ConsumerWidget {
  final String sym;
  const _EarningsHistorySection({required this.sym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stockFinancialsProvider(sym));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (fin) {
        final quarters = fin.quarterly.where((q) => q.eps != null).take(8).toList();
        if (quarters.isEmpty) return const SizedBox.shrink();
        final c = context.colors;
        return _Section(
          title: 'Quarterly Earnings (EPS)',
          child: Column(
            children: quarters.asMap().entries.map((e) {
              final isLast = e.key == quarters.length - 1;
              final q      = e.value;
              final eps    = q.eps!;
              final isPos  = eps >= 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: isLast ? null : Border(
                    bottom: BorderSide(color: c.surfaceAlt, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Text(q.date.length >= 7 ? q.date.substring(0, 7) : q.date,
                        style: TextStyle(fontSize: 13, color: c.textMuted)),
                    const Spacer(),
                    if (q.revenue != null)
                      Text(fmtBigUsd(q.revenue!),
                          style: TextStyle(fontSize: 12, color: c.textSecond)),
                    SizedBox(width: 16),
                    Container(
                      width: 72,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'EPS \$${eps.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isPos ? AppColors.emerald : AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Financial Charts Section ──────────────────────────────────────────────────

class _FinancialSection extends ConsumerStatefulWidget {
  final String sym;
  const _FinancialSection({required this.sym});

  @override
  ConsumerState<_FinancialSection> createState() => _FinancialSectionState();
}

class _FinancialSectionState extends ConsumerState<_FinancialSection> {
  bool _quarterly = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stockFinancialsProvider(widget.sym));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (fin) {
        final periods = _quarterly ? fin.quarterly.take(8).toList() : fin.annual;
        final filtered = periods
            .where((p) => p.revenue != null || p.netIncome != null)
            .toList();
        if (filtered.isEmpty) return const SizedBox.shrink();

        return _Section(
          title: 'Financial Charts',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── CAGR chips + tab toggle ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    if (!_quarterly && fin.cagr5yRevenue != null)
                      _FinChip(
                        'Rev. CAGR 5Y',
                        '${((fin.cagr5yRevenue! - 1) * 100).toStringAsFixed(1)}%',
                        fin.cagr5yRevenue! >= 1,
                      ),
                    if (!_quarterly && fin.cagr5yNetIncome != null) ...[
                      SizedBox(width: 8),
                      _FinChip(
                        'NI CAGR 5Y',
                        '${((fin.cagr5yNetIncome! - 1) * 100).toStringAsFixed(1)}%',
                        fin.cagr5yNetIncome! >= 1,
                      ),
                    ],
                    const Spacer(),
                    _PillToggle(
                      options: const ['Annual', 'Quarterly'],
                      selected: _quarterly ? 1 : 0,
                      onTap: (i) => setState(() => _quarterly = i == 1),
                    ),
                  ],
                ),
              ),

              // ── Legend ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _LegendDot(color: AppColors.emerald, label: 'Revenue'),
                    SizedBox(width: 16),
                    _LegendDot(color: const Color(0xFF6366F1), label: 'Net Income'),
                  ],
                ),
              ),

              // ── Bar chart ───────────────────────────────────────────────
              SizedBox(
                height: 160,
                child: _FinBarChart(periods: filtered),
              ),
              SizedBox(height: 12),

              // ── Margins (latest period) ─────────────────────────────────
              Builder(builder: (_) {
                final withRev = filtered.where((p) => p.revenue != null && p.revenue != 0).toList();
                if (withRev.isEmpty) return const SizedBox.shrink();
                final m = withRev.reduce((a, b) => a.date.compareTo(b.date) >= 0 ? a : b);
                final rev = m.revenue!;
                if (m.grossProfit == null && m.operatingIncome == null && m.netIncome == null) {
                  return const SizedBox.shrink();
                }
                String pct(double? v) => v == null ? '—' : '${(v / rev * 100).toStringAsFixed(1)}%';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    Expanded(child: _MiniMargin('Gross Margin', pct(m.grossProfit), AppColors.emerald)),
                    Expanded(child: _MiniMargin('Op. Margin', pct(m.operatingIncome), const Color(0xFF8B5CF6))),
                    Expanded(child: _MiniMargin('Net Margin', pct(m.netIncome), const Color(0xFF6366F1))),
                  ]),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _MiniMargin extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniMargin(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    ],
  );
}

class _FinBarChart extends StatelessWidget {
  final List<FinancialPeriod> periods;
  const _FinBarChart({required this.periods});

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) return const SizedBox.shrink();
    final c = context.colors;

    double maxVal = 0;
    for (final p in periods) {
      if ((p.revenue ?? 0) > maxVal) maxVal = p.revenue!;
      if ((p.netIncome ?? 0).abs() > maxVal) maxVal = p.netIncome!.abs();
    }
    if (maxVal == 0) return const SizedBox.shrink();

    String _shortDate(String d) =>
        d.length >= 7 ? d.substring(2, 7) : d;

    String _fmtY(double v) {
      if (v.abs() >= 1e9) return '\$${(v / 1e9).toStringAsFixed(0)}B';
      if (v.abs() >= 1e6) return '\$${(v / 1e6).toStringAsFixed(0)}M';
      return '\$${v.toStringAsFixed(0)}';
    }

    return BarChart(
      BarChartData(
        maxY: maxVal * 1.15,
        minY: 0,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => c.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'Rev' : 'NI';
              return BarTooltipItem(
                '$label ${_fmtY(rod.toY)}',
                TextStyle(
                  color: rodIndex == 0 ? AppColors.emerald : const Color(0xFF6366F1),
                  fontSize: 11, fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
              color: c.surfaceAlt.withValues(alpha: 0.6), strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= periods.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_shortDate(periods[i].date),
                      style: TextStyle(fontSize: 9, color: c.textMuted)),
                );
              },
            ),
          ),
        ),
        barGroups: periods.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          return BarChartGroupData(
            x: i,
            groupVertically: false,
            barRods: [
              BarChartRodData(
                toY: (p.revenue ?? 0).clamp(0, double.infinity).toDouble(),
                color: AppColors.emerald.withValues(alpha: 0.85),
                width: 7,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              BarChartRodData(
                toY: (p.netIncome ?? 0).clamp(0, double.infinity).toDouble(),
                color: const Color(0xFF6366F1).withValues(alpha: 0.85),
                width: 7,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _FinChip extends StatelessWidget {
  final String label, value;
  final bool positive;
  const _FinChip(this.label, this.value, this.positive);

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.emerald : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: context.colors.textMuted)),
          SizedBox(height: 1),
          Text(value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _PillToggle extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onTap;
  const _PillToggle({required this.options, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.asMap().entries.map((e) {
          final active = e.key == selected;
          return GestureDetector(
            onTap: () => onTap(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.emerald : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(e.value,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: active ? Colors.white : c.textMuted,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
    ],
  );
}

// ── Magic Number ──────────────────────────────────────────────────────────────

class _MagicNumber extends StatelessWidget {
  final List<DividendPayment> dividends;
  final double price;
  const _MagicNumber({required this.dividends, required this.price});

  int? _detectFrequencyPerYear() {
    if (dividends.length < 2) return 4;
    final sorted = dividends
        .take(8)
        .map((d) => DateTime.tryParse(d.date)?.millisecondsSinceEpoch ?? 0)
        .where((t) => t > 0)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (sorted.length < 2) return 4;
    double total = 0;
    for (int i = 0; i < sorted.length - 1; i++) {
      total += (sorted[i] - sorted[i + 1]) / 86400000.0;
    }
    final avg = total / (sorted.length - 1);
    if (avg <= 35)  return 12;
    if (avg <= 100) return 4;
    if (avg <= 200) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final lastDiv = dividends.first.amount;
    if (lastDiv <= 0 || price <= 0) return const SizedBox.shrink();

    final perYear    = _detectFrequencyPerYear() ?? 4;
    final label      = perYear == 12 ? 'month' : perYear == 4 ? 'quarter'
                     : perYear == 2 ? 'semester' : 'year';
    final magic      = (price / lastDiv).ceil();
    final invested   = magic * price;

    final c = context.colors;
    return _Section(
      title: 'Magic Number',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shares needed so each ${label}ly dividend pays for 1 new share.',
                style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.4)),
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MagicPill(label: 'Price', value: fmtStockPrice(price)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('÷', style: TextStyle(fontSize: 22, color: c.textMuted)),
                ),
                _MagicPill(label: 'Last div. ($label)',
                    value: '\$${lastDiv.toStringAsFixed(4)}'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('=', style: TextStyle(fontSize: 22, color: c.textMuted)),
                ),
                Column(
                  children: [
                    Text('$magic',
                        style: TextStyle(fontSize: 30,
                            fontWeight: FontWeight.w900, color: AppColors.emerald)),
                    Text('shares',
                        style: TextStyle(fontSize: 10, color: c.textMuted)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MagicStat('Investment target', fmtStockPrice(invested)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MagicStat('New shares / year', '+$perYear shares',
                      green: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MagicPill extends StatelessWidget {
  final String label, value;
  const _MagicPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: context.colors.textPrimary)),
      SizedBox(height: 2),
      Text(label.toUpperCase(),
          style: TextStyle(fontSize: 9, color: context.colors.textMuted,
              letterSpacing: 0.5)),
    ],
  );
}

class _MagicStat extends StatelessWidget {
  final String label, value;
  final bool green;
  const _MagicStat(this.label, this.value, {this.green = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.colors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.colors.surfaceAlt),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
        SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: green ? AppColors.emerald : context.colors.textPrimary)),
      ],
    ),
  );
}

// ── SEC Filings Section ───────────────────────────────────────────────────────

class _SecFilingsSection extends ConsumerWidget {
  final String sym;
  const _SecFilingsSection({required this.sym});

  Color _formColor(String form) {
    if (form == '10-K') return const Color(0xFF6366F1);
    if (form == '10-Q') return AppColors.emerald;
    if (form == '8-K')  return AppColors.orange;
    return const Color(0xFF6B7280);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stockFilingsProvider(sym));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (filings) {
        if (filings.isEmpty) return const SizedBox.shrink();
        final c = context.colors;
        return _Section(
          title: 'SEC Filings',
          child: Column(
            children: filings.take(8).toList().asMap().entries.map((e) {
              final isLast = e.key == filings.take(8).length - 1;
              final f      = e.value;
              final color  = _formColor(f.form);
              return InkWell(
                onTap: f.url.isNotEmpty
                    ? () => launchUrl(Uri.parse(f.url),
                          mode: LaunchMode.externalApplication)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(
                      bottom: BorderSide(color: c.surfaceAlt, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(f.form,
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w800, color: color)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.description.isNotEmpty ? f.description : f.form,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: c.textPrimary,
                                    fontWeight: FontWeight.w500)),
                            Text(f.filingDate,
                                style: TextStyle(fontSize: 11, color: c.textMuted)),
                          ],
                        ),
                      ),
                      if (f.url.isNotEmpty) ...[
                        SizedBox(width: 8),
                        Icon(Icons.open_in_new_rounded, size: 14, color: c.textMuted),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Insider Transactions (SEC Form 4) ───────────────────────────────────────────

class _InsiderSection extends ConsumerWidget {
  final String sym;
  const _InsiderSection({required this.sym});

  String _usd(double n) {
    final abs = n.abs();
    final sign = n < 0 ? '-' : '';
    if (abs >= 1e9) return '$sign\$${(abs / 1e9).toStringAsFixed(1)}B';
    if (abs >= 1e6) return '$sign\$${(abs / 1e6).toStringAsFixed(1)}M';
    if (abs >= 1e3) return '$sign\$${(abs / 1e3).toStringAsFixed(0)}K';
    return '$sign\$${abs.toStringAsFixed(0)}';
  }

  String _sh(double? n) {
    if (n == null) return '—';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(2)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  String _date(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year % 100}';
  }

  (String, Color) _typeChip(String t, BuildContext ctx) {
    switch (t) {
      case 'buy':  return ('Buy', AppColors.emerald);
      case 'sell': return ('Sell', AppColors.red);
      case 'award':  return ('Grant', ctx.colors.textMuted);
      case 'option': return ('Option', ctx.colors.textMuted);
      case 'tax':    return ('Tax', ctx.colors.textMuted);
      case 'gift':   return ('Gift', ctx.colors.textMuted);
      default:       return ('Other', ctx.colors.textMuted);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stockInsidersProvider(sym));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (d) {
        if (d.transactions.isEmpty) return const SizedBox.shrink();
        final c = context.colors;
        final hasSignal = d.buys > 0 || d.sells > 0;
        final netBuying = d.netValue > 0;
        final txs = d.transactions.take(12).toList();
        return _Section(
          title: 'Insider Transactions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasSignal)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (netBuying ? AppColors.emerald : AppColors.red).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(netBuying ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              size: 14, color: netBuying ? AppColors.emerald : AppColors.red),
                          const SizedBox(width: 4),
                          Text(netBuying ? 'Net buying' : 'Net selling',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: netBuying ? AppColors.emerald : AppColors.red)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text('${d.months}mo', style: TextStyle(fontSize: 11, color: c.textMuted)),
                      const Spacer(),
                      Text('${d.buys} buys', style: TextStyle(fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Text('${d.sells} sells', style: TextStyle(fontSize: 11, color: AppColors.red, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ...txs.asMap().entries.map((e) {
                final isLast = e.key == txs.length - 1;
                final t = e.value;
                final (label, color) = _typeChip(t.type, context);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: isLast ? null : Border(bottom: BorderSide(color: c.surfaceAlt, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.owner, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                            Text('${_date(t.date)} · ${t.role}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: c.textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 66,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_sh(t.shares), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
                            Text(t.value != null ? _usd(t.value!) : '—', style: TextStyle(fontSize: 11, color: c.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text('SEC Form 4 · officers, directors & 10% owners',
                    style: TextStyle(fontSize: 10, color: c.textMuted)),
              ),
            ],
          ),
        );
      },
    );
  }
}
