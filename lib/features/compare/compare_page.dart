import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/screener_provider.dart';
import '../../core/models/market_model.dart';
import '../../core/utils/formatters.dart';

// ── Row definitions ───────────────────────────────────────────────────────────

class _MetricRow {
  final String label;
  final String Function(StockQuote) value;
  final double? Function(StockQuote) numValue; // for highlighting best/worst
  final bool higherIsBetter;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.numValue,
    this.higherIsBetter = true,
  });
}

final _metrics = [
  _MetricRow(
    label: 'Price',
    value: (q) => fmtStockPrice(q.price),
    numValue: (q) => q.price,
    higherIsBetter: false,
  ),
  _MetricRow(
    label: '24h Change',
    value: (q) =>
        '${q.changePct >= 0 ? '+' : ''}${q.changePct.toStringAsFixed(2)}%',
    numValue: (q) => q.changePct,
    higherIsBetter: true,
  ),
  _MetricRow(
    label: 'Market Cap',
    value: (q) => fmtBigUsd(q.marketCap),
    numValue: (q) => q.marketCap,
    higherIsBetter: true,
  ),
  _MetricRow(
    label: 'P/E Ratio',
    value: (q) => q.pe != null ? q.pe!.toStringAsFixed(1) : '—',
    numValue: (q) => q.pe,
    higherIsBetter: false,
  ),
  _MetricRow(
    label: 'P/B Ratio',
    value: (q) => q.pb != null ? q.pb!.toStringAsFixed(2) : '—',
    numValue: (q) => q.pb,
    higherIsBetter: false,
  ),
  _MetricRow(
    label: 'Div Yield',
    value: (q) {
      if (q.dividendYield == null) return '—';
      return '${(q.dividendYield! * 100).toStringAsFixed(2)}%';
    },
    numValue: (q) => q.dividendYield,
    higherIsBetter: true,
  ),
  _MetricRow(
    label: 'ROE',
    value: (q) {
      if (q.roe == null) return '—';
      return '${(q.roe! * 100).toStringAsFixed(2)}%';
    },
    numValue: (q) => q.roe,
    higherIsBetter: true,
  ),
  _MetricRow(
    label: 'Beta',
    value: (q) => q.beta != null ? q.beta!.toStringAsFixed(2) : '—',
    numValue: (q) => q.beta,
    higherIsBetter: false,
  ),
  _MetricRow(
    label: 'EPS',
    value: (q) => q.eps != null ? '\$${q.eps!.toStringAsFixed(2)}' : '—',
    numValue: (q) => q.eps,
    higherIsBetter: true,
  ),
  _MetricRow(
    label: 'Volume',
    value: (q) => fmtBigUsd(q.volume),
    numValue: (q) => q.volume,
    higherIsBetter: true,
  ),
];

// ── Page ──────────────────────────────────────────────────────────────────────

class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key});

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  final List<StockQuote> _selected = [];
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _maxStocks = 5;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _add(StockQuote q) {
    if (_selected.any((s) => s.symbol == q.symbol)) return;
    if (_selected.length >= _maxStocks) return;
    setState(() { _selected.add(q); _query = ''; _searchCtrl.clear(); });
  }

  void _remove(String symbol) =>
      setState(() => _selected.removeWhere((s) => s.symbol == symbol));

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final async = ref.watch(screenerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Stocks')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search + add ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                enabled: _selected.length < _maxStocks,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _selected.length >= _maxStocks
                      ? 'Max $_maxStocks stocks'
                      : 'Add stock by symbol or name…',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.add_rounded, color: c.textMuted, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: c.textMuted, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.emerald, width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                ),
              ),
            ),

            // ── Search results dropdown ────────────────────────────────────
            if (_query.length >= 1)
              async.maybeWhen(
                data: (all) {
                  final q = _query.toLowerCase();
                  final results = all
                      .where((s) =>
                          s.symbol.toLowerCase().contains(q) ||
                          s.name.toLowerCase().contains(q))
                      .take(6)
                      .toList();
                  if (results.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: results.map((s) {
                        final already = _selected.any((x) => x.symbol == s.symbol);
                        return InkWell(
                          onTap: already ? null : () => _add(s),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(s.symbol,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: c.textPrimary)),
                                      Text(s.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: c.textMuted)),
                                    ],
                                  ),
                                ),
                                if (already)
                                  Text('Added',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.emerald,
                                          fontWeight: FontWeight.w600))
                                else
                                  Icon(Icons.add_circle_outline_rounded,
                                      size: 18, color: AppColors.emerald),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),

            const SizedBox(height: 12),

            // ── Selected chips ─────────────────────────────────────────────
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _selected.map((q) {
                    return Chip(
                      label: Text(q.symbol,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.emerald)),
                      backgroundColor:
                          AppColors.emerald.withValues(alpha: 0.1),
                      side: BorderSide(
                          color: AppColors.emerald.withValues(alpha: 0.3)),
                      deleteIcon: Icon(Icons.close_rounded,
                          size: 14, color: AppColors.emerald),
                      onDeleted: () => _remove(q.symbol),
                    );
                  }).toList(),
                ),
              ),

            if (_selected.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.compare_arrows_rounded,
                            size: 56, color: c.textMuted),
                        const SizedBox(height: 16),
                        Text('Compare up to 5 stocks',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                        const SizedBox(height: 8),
                        Text(
                          'Search and add stocks above to compare metrics side by side.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: c.textMuted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // ── Comparison table ─────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _CompareTable(
                        selected: _selected, metrics: _metrics),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Comparison table ──────────────────────────────────────────────────────────

class _CompareTable extends StatelessWidget {
  final List<StockQuote> selected;
  final List<_MetricRow> metrics;
  const _CompareTable({required this.selected, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Column widths
    const labelW = 100.0;
    const colW   = 90.0;

    return Table(
      columnWidths: {
        0: const FixedColumnWidth(labelW),
        for (var i = 0; i < selected.length; i++)
          (i + 1): const FixedColumnWidth(colW),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: c.surfaceAlt, width: 0.5),
        bottom: BorderSide(color: c.surfaceAlt, width: 0.5),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(color: c.surface),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Text('Metric',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted)),
            ),
            ...selected.map((q) => GestureDetector(
              onTap: () => context.push('/stocks/${q.symbol}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 12),
                child: Column(
                  children: [
                    Text(q.symbol,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.emerald)),
                    const SizedBox(height: 2),
                    Text(q.name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style:
                            TextStyle(fontSize: 9.5, color: c.textMuted)),
                  ],
                ),
              ),
            )),
          ],
        ),
        // Metric rows
        ...metrics.map((m) {
          // Find best/worst numeric value
          final nums = selected
              .map(m.numValue)
              .whereType<double>()
              .toList();
          final best  = nums.isEmpty
              ? null
              : (m.higherIsBetter
                  ? nums.reduce((a, b) => a > b ? a : b)
                  : nums.reduce((a, b) => a < b ? a : b));
          final worst = nums.isEmpty
              ? null
              : (m.higherIsBetter
                  ? nums.reduce((a, b) => a < b ? a : b)
                  : nums.reduce((a, b) => a > b ? a : b));

          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Text(m.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textSecond)),
              ),
              ...selected.map((q) {
                final num  = m.numValue(q);
                final isBest  = num != null && best  != null && num == best  && nums.length > 1;
                final isWorst = num != null && worst != null && num == worst && nums.length > 1 && best != worst;

                Color? bg;
                Color  textColor = c.textPrimary;
                if (isBest) {
                  bg = AppColors.emerald.withValues(alpha: 0.12);
                  textColor = AppColors.emerald;
                } else if (isWorst) {
                  bg = AppColors.red.withValues(alpha: 0.08);
                  textColor = AppColors.red;
                }

                return Container(
                  color: bg,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
                  child: Text(
                    m.value(q),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isBest
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}
