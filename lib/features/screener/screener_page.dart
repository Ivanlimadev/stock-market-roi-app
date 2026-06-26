import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';
import '../../core/providers/screener_provider.dart';
import '../../core/models/market_model.dart';
import '../../core/utils/formatters.dart';
import '../../core/ads/ad_manager.dart';
import '../../core/widgets/app_bottom_nav.dart';

// ── Sort column enum ──────────────────────────────────────────────────────────

enum _SortCol { name, price, change, marketCap, pe, pb, divYield, roe, beta }

extension _SortColLabel on _SortCol {
  String get label => switch (this) {
        _SortCol.name      => 'Name',
        _SortCol.price     => 'Price',
        _SortCol.change    => '24h%',
        _SortCol.marketCap => 'Mkt Cap',
        _SortCol.pe        => 'P/E',
        _SortCol.pb        => 'P/B',
        _SortCol.divYield  => 'Div%',
        _SortCol.roe       => 'ROE',
        _SortCol.beta      => 'Beta',
      };
}

// ── Sectors ───────────────────────────────────────────────────────────────────

const _sectors = [
  'All',
  'Technology',
  'Healthcare',
  'Financial Services',
  'Consumer Cyclical',
  'Consumer Defensive',
  'Industrials',
  'Energy',
  'Utilities',
  'Real Estate',
  'Basic Materials',
  'Communication Services',
];

// ── Page ──────────────────────────────────────────────────────────────────────

class ScreenerPage extends ConsumerStatefulWidget {
  const ScreenerPage({super.key});

  @override
  ConsumerState<ScreenerPage> createState() => _ScreenerPageState();
}

class _ScreenerPageState extends ConsumerState<ScreenerPage> {
  final _searchCtrl = TextEditingController();
  String _query     = '';
  String _sector    = 'All';
  _SortCol _sortCol = _SortCol.marketCap;
  bool _sortAsc     = false;

  // Rewarded gate: show the first [_freeRows] matches free, the rest after an ad.
  static const int _freeRows = 12;
  bool _resultsUnlocked = false;
  bool _loadingAd       = false;

  void _unlockResults() {
    setState(() => _loadingAd = true);
    AdManager.instance.showRewarded(
      onReward: () {
        if (mounted) setState(() => _resultsUnlocked = true);
      },
      onUnavailable: () {
        if (!mounted) return;
        setState(() {
          _loadingAd = false;
          _resultsUnlocked = true; // don't block the user if no ad is available
        });
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<StockQuote> _filter(List<StockQuote> all) {
    var list = all.where((q) {
      final q2 = _query.toLowerCase();
      if (q2.isNotEmpty &&
          !q.symbol.toLowerCase().contains(q2) &&
          !q.name.toLowerCase().contains(q2)) {
        return false;
      }
      if (_sector != 'All' && (q.sector ?? '') != _sector) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case _SortCol.name:
          cmp = a.name.compareTo(b.name);
        case _SortCol.price:
          cmp = a.price.compareTo(b.price);
        case _SortCol.change:
          cmp = a.changePct.compareTo(b.changePct);
        case _SortCol.marketCap:
          cmp = (a.marketCap ?? 0).compareTo(b.marketCap ?? 0);
        case _SortCol.pe:
          cmp = (a.pe ?? double.infinity)
              .compareTo(b.pe ?? double.infinity);
        case _SortCol.pb:
          cmp = (a.pb ?? double.infinity)
              .compareTo(b.pb ?? double.infinity);
        case _SortCol.divYield:
          cmp = (a.dividendYield ?? 0).compareTo(b.dividendYield ?? 0);
        case _SortCol.roe:
          cmp = (a.roe ?? -double.infinity)
              .compareTo(b.roe ?? -double.infinity);
        case _SortCol.beta:
          cmp = (a.beta ?? 0).compareTo(b.beta ?? 0);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _setSort(_SortCol col) {
    setState(() {
      if (_sortCol == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCol = col;
        _sortAsc = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final async = ref.watch(screenerProvider);

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Stock Screener'),
        actions: MainShellMenu.actions(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by symbol or name…',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: c.textMuted, size: 20),
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
                ),
              ),
            ),

            // ── Sector filter ───────────────────────────────────────────────
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _sectors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s      = _sectors[i];
                  final active = _sector == s;
                  return GestureDetector(
                    onTap: () => setState(() => _sector = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
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
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color:
                              active ? AppColors.emerald : c.textMuted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Table header ────────────────────────────────────────────────
            _TableHeader(
              sortCol: _sortCol,
              sortAsc: _sortAsc,
              onSort: _setSort,
              c: c,
            ),

            Divider(height: 1, color: c.surfaceAlt),

            // ── Rows ────────────────────────────────────────────────────────
            Expanded(
              child: async.when(
                loading: () => Center(
                    child:
                        CircularProgressIndicator(color: AppColors.emerald)),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 48, color: c.textMuted),
                      const SizedBox(height: 12),
                      Text('Failed to load screener',
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
                  final rows = _filter(all);
                  if (rows.isEmpty) {
                    return Center(
                      child: Text('No results',
                          style: TextStyle(color: c.textMuted)),
                    );
                  }
                  final gated = !_resultsUnlocked && rows.length > _freeRows;
                  final visible = gated ? _freeRows : rows.length;
                  return RefreshIndicator(
                    color: AppColors.emerald,
                    onRefresh: () async =>
                        ref.invalidate(screenerProvider),
                    child: ListView.separated(
                      // +1 slot for the unlock card when results are gated.
                      itemCount: visible + (gated ? 1 : 0),
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: c.surfaceAlt),
                      itemBuilder: (ctx, i) {
                        if (gated && i == visible) {
                          return _UnlockResultsCard(
                            hidden: rows.length - _freeRows,
                            loading: _loadingAd,
                            onUnlock: _unlockResults,
                          );
                        }
                        return _ScreenerRow(
                          quote: rows[i],
                          sortCol: _sortCol,
                          onTap: () =>
                              context.push('/stocks/${rows[i].symbol}'),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rewarded unlock card ──────────────────────────────────────────────────────

class _UnlockResultsCard extends StatelessWidget {
  final int hidden;
  final bool loading;
  final VoidCallback onUnlock;
  const _UnlockResultsCard({
    required this.hidden,
    required this.loading,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded, size: 26, color: c.textMuted),
          const SizedBox(height: 10),
          Text('+$hidden more matches',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          const SizedBox(height: 4),
          Text('Watch a short ad to unlock the full screener results.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: c.textSecond)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : onUnlock,
              icon: loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: Text(loading ? 'Loading…' : 'Watch ad to unlock all results'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final _SortCol sortCol;
  final bool sortAsc;
  final void Function(_SortCol) onSort;
  final AppThemeColors c;

  const _TableHeader({
    required this.sortCol,
    required this.sortAsc,
    required this.onSort,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    Widget hdr(_SortCol col, {double width = 64, TextAlign align = TextAlign.right}) {
      final active = sortCol == col;
      return GestureDetector(
        onTap: () => onSort(col),
        child: SizedBox(
          width: width,
          child: Row(
            mainAxisAlignment: align == TextAlign.right
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Text(
                col.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.emerald : c.textMuted,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 2),
                Icon(
                  sortAsc
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 10,
                  color: AppColors.emerald,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      color: c.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            hdr(_SortCol.name, width: 150, align: TextAlign.left),
            const SizedBox(width: 8),
            hdr(_SortCol.price, width: 72),
            const SizedBox(width: 8),
            hdr(_SortCol.change, width: 60),
            const SizedBox(width: 8),
            hdr(_SortCol.marketCap, width: 72),
            const SizedBox(width: 8),
            hdr(_SortCol.pe, width: 52),
            const SizedBox(width: 8),
            hdr(_SortCol.pb, width: 52),
            const SizedBox(width: 8),
            hdr(_SortCol.divYield, width: 52),
            const SizedBox(width: 8),
            hdr(_SortCol.roe, width: 52),
            const SizedBox(width: 8),
            hdr(_SortCol.beta, width: 48),
          ],
        ),
      ),
    );
  }
}

// ── Table row ─────────────────────────────────────────────────────────────────

class _ScreenerRow extends StatelessWidget {
  final StockQuote quote;
  final _SortCol sortCol;
  final VoidCallback onTap;

  const _ScreenerRow({
    required this.quote,
    required this.sortCol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final isPos = quote.changePct >= 0;
    final clr   = isPos ? AppColors.emerald : AppColors.red;

    String fmt(double? v, {String prefix = '', String suffix = '', int dec = 2}) {
      if (v == null) return '—';
      return '$prefix${v.toStringAsFixed(dec)}$suffix';
    }

    String fmtPct(double? v) {
      if (v == null) return '—';
      final pct = v * 100;
      return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';
    }

    // Highlighted cell color for the active sort column
    Color? highlightFor(_SortCol col) {
      if (sortCol != col) return null;
      return AppColors.emerald.withValues(alpha: 0.05);
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Symbol + name
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quote.symbol,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary)),
                    Text(quote.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: c.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Cell(fmtStockPrice(quote.price), width: 72,
                  bold: sortCol == _SortCol.price,
                  bg: highlightFor(_SortCol.price), c: c),
              const SizedBox(width: 8),
              _Cell(
                '${isPos ? '+' : ''}${quote.changePct.toStringAsFixed(2)}%',
                width: 60,
                color: clr,
                bold: sortCol == _SortCol.change,
                bg: highlightFor(_SortCol.change),
                c: c,
              ),
              const SizedBox(width: 8),
              _Cell(fmtBigUsd(quote.marketCap), width: 72,
                  bold: sortCol == _SortCol.marketCap,
                  bg: highlightFor(_SortCol.marketCap), c: c),
              const SizedBox(width: 8),
              _Cell(fmt(quote.pe), width: 52,
                  bold: sortCol == _SortCol.pe,
                  bg: highlightFor(_SortCol.pe), c: c),
              const SizedBox(width: 8),
              _Cell(fmt(quote.pb), width: 52,
                  bold: sortCol == _SortCol.pb,
                  bg: highlightFor(_SortCol.pb), c: c),
              const SizedBox(width: 8),
              _Cell(fmtPct(quote.dividendYield), width: 52,
                  bold: sortCol == _SortCol.divYield,
                  bg: highlightFor(_SortCol.divYield), c: c),
              const SizedBox(width: 8),
              _Cell(fmtPct(quote.roe), width: 52,
                  bold: sortCol == _SortCol.roe,
                  bg: highlightFor(_SortCol.roe), c: c),
              const SizedBox(width: 8),
              _Cell(fmt(quote.beta), width: 48,
                  bold: sortCol == _SortCol.beta,
                  bg: highlightFor(_SortCol.beta), c: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final double width;
  final Color? color;
  final Color? bg;
  final bool bold;
  final AppThemeColors c;

  const _Cell(this.text, {
    required this.width,
    this.color,
    this.bg,
    this.bold = false,
    required this.c,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        alignment: Alignment.centerRight,
        decoration: bg != null
            ? BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4))
            : null,
        padding: bg != null
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
            : null,
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? c.textPrimary,
          ),
        ),
      );
}
