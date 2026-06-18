import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';
import '../../core/models/portfolio_model.dart';
import '../../core/providers/portfolio_provider.dart';
import 'add_transaction_sheet.dart';

// ── Asset type meta ───────────────────────────────────────────────────────────

const _typeColors = {
  'stock':  Color(0xFF6366F1),
  'reit':   Color(0xFF10B981),
  'etf':    Color(0xFFF59E0B),
  'crypto': Color(0xFFF97316),
};

const _typeLabels = {
  'stock':  'Stocks',
  'reit':   'REITs',
  'etf':    'ETFs',
  'crypto': 'Crypto',
};

const _typeOrder = ['stock', 'reit', 'etf', 'crypto'];

IconData _typeIcon(String type) => switch (type) {
  'stock'  => Icons.show_chart_rounded,
  'reit'   => Icons.apartment_rounded,
  'etf'    => Icons.pie_chart_rounded,
  'crypto' => Icons.currency_bitcoin,
  _        => Icons.account_balance_rounded,
};

// ── Root page ─────────────────────────────────────────────────────────────────

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const _GuestPortfolio();
    return const _LoggedInPortfolio();
  }
}

// ── Logged-in portfolio ───────────────────────────────────────────────────────

class _LoggedInPortfolio extends ConsumerStatefulWidget {
  const _LoggedInPortfolio();

  @override
  ConsumerState<_LoggedInPortfolio> createState() => _LoggedInPortfolioState();
}

class _LoggedInPortfolioState extends ConsumerState<_LoggedInPortfolio>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(portfolioHoldingsProvider);
    ref.invalidate(portfolioEnrichedProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Portfolio'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          MainShellMenu.themeButton(),
          MainShellMenu.button(),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.emerald,
          labelColor: AppColors.emerald,
          unselectedLabelColor: context.colors.textMuted,
          dividerColor: context.colors.surfaceAlt,
          tabs: const [Tab(text: 'Resumo'), Tab(text: 'Dividendos'), Tab(text: 'Ativos')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddTransactionSheet(context),
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded),
        label:
            Text('Transaction', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_ResumoTab(), _DividendosTab(), _AtivosTab()],
      ),
    );
  }
}

// ── Resumo tab ─────────────────────────────────────────────────────────────────

class _ResumoTab extends ConsumerWidget {
  const _ResumoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(portfolioEnrichedProvider);

    return async.when(
      loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (e, _) => _ErrorState(
        onRetry: () => ref.invalidate(portfolioEnrichedProvider)),
      data: (holdings) => holdings.isEmpty
          ? const _EmptyState()
          : _ResumoContent(holdings: holdings),
    );
  }
}

class _ResumoContent extends StatelessWidget {
  final List<PortfolioHolding> holdings;
  const _ResumoContent({required this.holdings});

  double get _totalValue => holdings.fold(0, (s, h) => s + h.currentValue);
  double get _totalInvested => holdings.fold(0, (s, h) => s + h.costBasis);
  double get _totalGain => _totalValue - _totalInvested;
  double get _totalGainPct =>
      _totalInvested > 0 ? (_totalGain / _totalInvested) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final isPositive = _totalGain >= 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        // ── KPI cards ──────────────────────────────────────────────────────
        Row(children: [
          _KpiCard(
            label: 'Net Worth',
            value: fmt.format(_totalValue),
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.emerald,
          ),
          SizedBox(width: 12),
          _KpiCard(
            label: 'Investido',
            value: fmt.format(_totalInvested),
            icon: Icons.payments_rounded,
            color: const Color(0xFF6366F1),
          ),
        ]),
        SizedBox(height: 12),
        Row(children: [
          _KpiCard(
            label: 'Ganho/Perda',
            value: '${isPositive ? '+' : ''}${fmt.format(_totalGain)}',
            icon: isPositive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: isPositive ? AppColors.emerald : AppColors.red,
            valueColor: isPositive ? AppColors.emerald : AppColors.red,
          ),
          SizedBox(width: 12),
          _KpiCard(
            label: 'Rentabilidade',
            value:
                '${_totalGainPct >= 0 ? '+' : ''}${_totalGainPct.toStringAsFixed(2)}%',
            icon: Icons.percent_rounded,
            color: _totalGainPct >= 0 ? AppColors.emerald : AppColors.red,
            valueColor: _totalGainPct >= 0 ? AppColors.emerald : AppColors.red,
          ),
        ]),
        SizedBox(height: 24),

        // ── Allocation donut ────────────────────────────────────────────────
        _AllocationSection(holdings: holdings),
        SizedBox(height: 24),

        // ── Top holdings ────────────────────────────────────────────────────
        Text('Top positions',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary)),
        SizedBox(height: 12),
        ...holdings
            .take(5)
            .map((h) => _HoldingTile(holding: h)),
      ],
    );
  }
}

// ── KPI card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? valueColor;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.surfaceAlt),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            SizedBox(height: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? context.colors.textPrimary,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Allocation donut ──────────────────────────────────────────────────────────

class _AllocationSection extends StatefulWidget {
  final List<PortfolioHolding> holdings;
  const _AllocationSection({required this.holdings});

  @override
  State<_AllocationSection> createState() => _AllocationSectionState();
}

class _AllocationSectionState extends State<_AllocationSection> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // Aggregate value by type
    final map = <String, double>{};
    for (final h in widget.holdings) {
      map[h.assetType] = (map[h.assetType] ?? 0) + h.currentValue;
    }
    final total = map.values.fold(0.0, (s, v) => s + v);
    if (total == 0) return const SizedBox.shrink();

    final entries = _typeOrder
        .where((t) => map.containsKey(t))
        .map((t) => MapEntry(t, map[t]!))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Allocation',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary)),
          SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: PieChart(PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        _touchedIndex = event is FlTapUpEvent
                            ? (response?.touchedSection
                                    ?.touchedSectionIndex ??
                                -1)
                            : _touchedIndex;
                      });
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 46,
                  sections: entries.asMap().entries.map((e) {
                    final i = e.key;
                    final type = e.value.key;
                    final value = e.value.value;
                    final pct = value / total * 100;
                    final isTouched = i == _touchedIndex;
                    return PieChartSectionData(
                      color: _typeColors[type] ?? AppColors.emerald,
                      value: value,
                      title: '${pct.toStringAsFixed(0)}%',
                      radius: isTouched ? 58 : 50,
                      titleStyle: TextStyle(
                        fontSize: isTouched ? 11 : 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                )),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.map((e) {
                    final pct = e.value / total * 100;
                    final color = _typeColors[e.key] ?? AppColors.emerald;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(_typeLabels[e.key] ?? e.key,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecond)),
                        ),
                        Text('${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Ativos tab ────────────────────────────────────────────────────────────────

class _AtivosTab extends ConsumerWidget {
  const _AtivosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(portfolioEnrichedProvider);

    return async.when(
      loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (e, _) =>
          _ErrorState(onRetry: () => ref.invalidate(portfolioEnrichedProvider)),
      data: (holdings) {
        if (holdings.isEmpty) return const _EmptyState();

        final grouped = <String, List<PortfolioHolding>>{};
        for (final type in _typeOrder) {
          final items = holdings.where((h) => h.assetType == type).toList();
          if (items.isNotEmpty) grouped[type] = items;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: grouped.entries.expand((entry) {
            return [
              _TypeHeader(type: entry.key, holdings: entry.value),
              SizedBox(height: 8),
              ...entry.value.map((h) => _HoldingTile(holding: h)),
              SizedBox(height: 12),
            ];
          }).toList(),
        );
      },
    );
  }
}

// ── Type header ───────────────────────────────────────────────────────────────

class _TypeHeader extends StatelessWidget {
  final String type;
  final List<PortfolioHolding> holdings;
  const _TypeHeader({required this.type, required this.holdings});

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[type] ?? AppColors.emerald;
    final totalValue = holdings.fold(0.0, (s, h) => s + h.currentValue);
    final totalInvested = holdings.fold(0.0, (s, h) => s + h.costBasis);
    final gain = totalValue - totalInvested;
    final pct = totalInvested > 0 ? (gain / totalInvested) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_typeIcon(type), size: 14, color: color),
        ),
        SizedBox(width: 10),
        Text(_typeLabels[type] ?? type,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(
            ' · ${holdings.length} ativo${holdings.length > 1 ? 's' : ''}',
            style:
                TextStyle(fontSize: 12, color: context.colors.textMuted)),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${totalValue.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary)),
          Text('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
              style: TextStyle(
                  fontSize: 11,
                  color: pct >= 0 ? AppColors.emerald : AppColors.red)),
        ]),
      ]),
    );
  }
}

// ── Holding tile ──────────────────────────────────────────────────────────────

class _HoldingTile extends StatelessWidget {
  final PortfolioHolding holding;
  const _HoldingTile({required this.holding});

  @override
  Widget build(BuildContext context) {
    final h = holding;
    final isCrypto = h.assetType == 'crypto';
    final isPositive = h.gainLoss >= 0;
    final nf = NumberFormat('0.########');

    return InkWell(
      onTap: () {
        if (isCrypto) {
          final coinId = kCryptoTickerToCoinId[h.symbol.toUpperCase()] ??
              h.symbol.toLowerCase();
          context.push('/crypto/$coinId');
        } else {
          context.push('/stocks/${h.symbol}');
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.surfaceAlt),
        ),
        child: Row(children: [
          // Logo
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: isCrypto
                ? Center(
                    child: Text(
                      h.symbol.length > 3
                          ? h.symbol.substring(0, 3)
                          : h.symbol,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textSecond),
                    ),
                  )
                : Image.network(
                    'https://assets.parqet.com/logos/symbol/${h.symbol}?format=png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        h.symbol.length >= 2
                            ? h.symbol.substring(0, 2)
                            : h.symbol,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textMuted),
                      ),
                    ),
                  ),
          ),
          SizedBox(width: 12),

          // Symbol + shares
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.symbol,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary)),
                SizedBox(height: 2),
                Text(
                  '${nf.format(h.netShares)} · PM \$${h.avgPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 11, color: context.colors.textMuted),
                ),
              ],
            ),
          ),

          // Value + return
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\$${h.currentValue.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary)),
            SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                isPositive
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                size: 16,
                color: isPositive ? AppColors.emerald : AppColors.red,
              ),
              Text(
                '${h.gainLossPct >= 0 ? '+' : ''}${h.gainLossPct.toStringAsFixed(2)}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? AppColors.emerald : AppColors.red),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: AppColors.emerald),
          ),
          SizedBox(height: 20),
          Text('Empty portfolio',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary)),
          SizedBox(height: 8),
          Text(
            'Tap "+ Transaction" to record your first purchase.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: context.colors.textSecond, height: 1.5),
          ),
        ]),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded,
            color: context.colors.textMuted, size: 48),
        SizedBox(height: 12),
        Text('Error loading portfolio',
            style: TextStyle(color: context.colors.textMuted)),
        SizedBox(height: 16),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.emerald,
            side: BorderSide(color: AppColors.emerald),
          ),
          child: Text('Try again'),
        ),
      ]),
    );
  }
}

// ── Dividendos tab ────────────────────────────────────────────────────────────

class _DividendosTab extends ConsumerWidget {
  const _DividendosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(portfolioDividendsProvider);

    return async.when(
      loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(portfolioDividendsProvider)),
      data: (list) {
        final payers = list.where((d) => d.paysDividends).toList()
          ..sort((a, b) => b.annualTotal.compareTo(a.annualTotal));

        if (list.isEmpty) return const _EmptyState();

        final totalAnual = payers.fold(0.0, (s, d) => s + d.annualTotal);
        final totalInvested = payers.fold(
            0.0, (s, d) => s + d.netShares * 0); // placeholder
        final avgYield = payers.isEmpty
            ? 0.0
            : payers.fold(0.0, (s, d) => s + d.yieldPct) / payers.length;

        // Próximo ex-date
        final withDate = payers
            .where((d) => d.exDividendDate != null)
            .toList()
          ..sort((a, b) => a.exDividendDate!.compareTo(b.exDividendDate!));
        final nextExDate = withDate.isNotEmpty ? withDate.first.exDividendDate : null;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            // KPIs
            Row(children: [
              _KpiCard(
                label: 'Anual estimado',
                value: '\$${totalAnual.toStringAsFixed(2)}',
                icon: Icons.savings_rounded,
                color: AppColors.emerald,
              ),
              SizedBox(width: 12),
              _KpiCard(
                label: 'Avg Yield',
                value: '${avgYield.toStringAsFixed(2)}%',
                icon: Icons.percent_rounded,
                color: const Color(0xFF6366F1),
              ),
            ]),
            SizedBox(height: 12),
            if (nextExDate != null)
              _KpiCard(
                label: 'Next ex-dividend',
                value: _fmtDate(nextExDate),
                icon: Icons.event_rounded,
                color: const Color(0xFFF59E0B),
              ),
            SizedBox(height: 24),

            // Dividend payers
            if (payers.isNotEmpty) ...[
              Text('Pagadores de dividendos',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary)),
              SizedBox(height: 12),
              ...payers.map((d) => _DividendTile(info: d)),
            ],

            // Non-payers
            if (payers.length < list.length) ...[
              SizedBox(height: 20),
              Text(
                'Sem dividendos (${list.length - payers.length})',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textMuted),
              ),
              SizedBox(height: 8),
              ...list
                  .where((d) => !d.paysDividends)
                  .map((d) => _DividendTileEmpty(symbol: d.symbol, assetType: d.assetType)),
            ],
          ],
        );
      },
    );
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = ['Jan','Fev','Mar','Abr','Mai','Jun',
                      'Jul','Ago','Set','Out','Nov','Dez'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _DividendTile extends StatelessWidget {
  final DividendInfo info;
  const _DividendTile({required this.info});

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[info.assetType] ?? AppColors.emerald;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.surfaceAlt),
      ),
      child: Row(children: [
        // Logo
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            'https://assets.parqet.com/logos/symbol/${info.symbol}?format=png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                info.symbol.length >= 2 ? info.symbol.substring(0, 2) : info.symbol,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textMuted),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),

        // Symbol + ex-date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(info.symbol,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary)),
                SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _typeLabels[info.assetType] ?? info.assetType,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ]),
              SizedBox(height: 2),
              if (info.exDividendDate != null)
                Text('Ex-div: ${_fmtShort(info.exDividendDate!)}',
                    style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
            ],
          ),
        ),

        // Div/share + Annual + Yield
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${info.annualTotal.toStringAsFixed(2)}/ano',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.emerald)),
          SizedBox(height: 2),
          Text(
            '\$${(info.dividendRate ?? 0).toStringAsFixed(4)}/share · ${info.yieldPct.toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 10, color: context.colors.textMuted),
          ),
        ]),
      ]),
    );
  }

  String _fmtShort(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return iso; }
  }
}

class _DividendTileEmpty extends StatelessWidget {
  final String symbol;
  final String assetType;
  const _DividendTileEmpty({required this.symbol, required this.assetType});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.surfaceAlt),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            'https://assets.parqet.com/logos/symbol/$symbol?format=png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                symbol.length >= 2 ? symbol.substring(0, 2) : symbol,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                    color: context.colors.textMuted),
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
        Text(symbol,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecond)),
        const Spacer(),
        Text('No dividends',
            style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
      ]),
    );
  }
}

// ── Guest portfolio ───────────────────────────────────────────────────────────

class _GuestPortfolio extends StatelessWidget {
  const _GuestPortfolio();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Portfolio'),
          actions: [MainShellMenu.button()]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(44),
                ),
                child: Icon(Icons.account_balance_wallet_rounded,
                    size: 44, color: AppColors.emerald),
              ),
              SizedBox(height: 24),
              Text('Build your portfolio',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary),
                  textAlign: TextAlign.center),
              SizedBox(height: 12),
              Text(
                'Track your investments, monitor each asset\'s performance and keep your portfolio organized.',
                style: TextStyle(
                    fontSize: 14, color: context.colors.textSecond, height: 1.55),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/register'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Create free account',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/login'),
                child: Text('I already have an account — Log in',
                    style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
