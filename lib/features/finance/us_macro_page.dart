import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/macro_model.dart';
import '../../core/providers/macro_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class UsMacroPage extends ConsumerWidget {
  const UsMacroPage({super.key});

  Future<void> _refreshAll(WidgetRef ref) async {
    // Invalidate every detail card (whole family) plus the overview, then
    // await the overview so the refresh spinner reflects real reload work.
    ref.invalidate(macroDetailProvider);
    ref.invalidate(macroUsProvider);
    await ref.read(macroUsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(macroUsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('US Economy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _refreshAll(ref),
          ),
          MainShellMenu.themeButton(),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => _ErrorRetry(
          message: 'Macro data unavailable',
          onRetry: () => ref.invalidate(macroUsProvider),
        ),
        data: (indicators) => _MacroBody(
          indicators: indicators,
          onRefresh: () => _refreshAll(ref),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _MacroBody extends StatelessWidget {
  final List<MacroIndicator> indicators;
  final Future<void> Function() onRefresh;
  const _MacroBody({required this.indicators, required this.onRefresh});

  static const _order = [
    'fed', 'labor', 'inflation', 'growth', 'consumer',
    'bonds', 'markets', 'commodities', 'leading', 'fiscal', 'housing', 'money',
  ];
  static const _labels = {
    'fed':         'Federal Reserve',
    'labor':       'Labor Market',
    'inflation':   'Inflation',
    'growth':      'Economic Growth',
    'consumer':    'Consumer',
    'bonds':       'Fixed Income',
    'markets':     'Financial Markets',
    'commodities': 'Commodities',
    'leading':     'Leading Indicators',
    'fiscal':      'Fiscal Policy',
    'housing':     'Housing',
    'money':       'Money Supply',
  };

  MacroIndicator? _find(String id) =>
      indicators.where((i) => i.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final bySection = <String, List<MacroIndicator>>{};
    for (final ind in indicators) {
      bySection.putIfAbsent(ind.section, () => []).add(ind);
    }
    final fed = _find('FEDFUNDS');

    // Flat list so ListView.builder only builds visible items,
    // preventing all 37 macroDetailProvider requests firing at once.
    final items = <dynamic>['_scorecard', '_fomc'];
    for (final sec in _order) {
      if (bySection.containsKey(sec)) {
        items.add(sec);
        items.addAll(bySection[sec]!);
      }
    }
    items.addAll(['_credit', '_spacer']);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.emerald,
      child: ListView.builder(
        // AlwaysScrollable so pull-to-refresh works even when content is short.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          if (item == '_scorecard') return _MacroScorecard(indicators: indicators);
          if (item == '_fomc')      return _FomcCalendar(fedFunds: fed);
          if (item == '_credit')    return const _FredCredit();
          if (item == '_spacer')    return const SizedBox(height: 32);
          if (item is String)       return _SectionHeader(label: _labels[item] ?? item.toUpperCase());
          return _FullIndicatorCard(indicator: item as MacroIndicator);
        },
      ),
    );
  }
}

// ── Macro Scorecard ───────────────────────────────────────────────────────────

class _MacroScorecard extends StatelessWidget {
  final List<MacroIndicator> indicators;
  const _MacroScorecard({required this.indicators});

  MacroIndicator? _find(String id) =>
      indicators.where((i) => i.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _fedTile(_find('FEDFUNDS')),
      _growthTile(_find('GDPC1')),
      _inflationTile(_find('PCEPILFE')),
      _laborTile(_find('UNRATE')),
      _curveTile(_find('T10Y2Y')),
      _recessionTile(_find('RECPROUSM156N')),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.analytics_rounded, size: 14, color: AppColors.emerald),
          const SizedBox(width: 6),
          Text('MACRO SNAPSHOT', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            letterSpacing: 1.1, color: context.colors.textMuted)),
          const Spacer(),
          Text(DateFormat('MMM yyyy').format(DateTime.now()),
            style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
        ]),
        const SizedBox(height: 12),
        Row(children: tiles.take(3).map((t) =>
            Expanded(child: _ScoreTile(tile: t))).toList()),
        const SizedBox(height: 6),
        Row(children: tiles.skip(3).map((t) =>
            Expanded(child: _ScoreTile(tile: t))).toList()),
      ]),
    );
  }

  static _TileData _fedTile(MacroIndicator? ind) {
    if (ind == null) return const _TileData('FED', '—', '—', _Regime.neutral);
    final v = ind.value; final c = ind.change;
    if (v > 4.5)  return _TileData('FED', 'Restritivo',      '${v.toStringAsFixed(2)}%', _Regime.negative);
    if (c < -0.1) return _TileData('FED', 'Ciclo de Cortes', '${v.toStringAsFixed(2)}%', _Regime.caution);
    if (v < 2.0)  return _TileData('FED', 'Acomodatício',    '${v.toStringAsFixed(2)}%', _Regime.positive);
    return               _TileData('FED', 'Neutro',           '${v.toStringAsFixed(2)}%', _Regime.caution);
  }

  static _TileData _growthTile(MacroIndicator? ind) {
    if (ind == null) return const _TileData('GDP', '—', '—', _Regime.neutral);
    final v = ind.value;
    if (v >= 2.5) return _TileData('GDP', 'Expansão',      '${v.toStringAsFixed(1)}% YoY', _Regime.positive);
    if (v >= 0)   return _TileData('GDP', 'Desaceleração', '${v.toStringAsFixed(1)}% YoY', _Regime.caution);
    return               _TileData('GDP', 'Contração',     '${v.toStringAsFixed(1)}% YoY', _Regime.negative);
  }

  static _TileData _inflationTile(MacroIndicator? ind) {
    if (ind == null) return const _TileData('PCE', '—', '—', _Regime.neutral);
    final v = ind.value; final c = ind.change;
    if (v > 3.5) { return _TileData('PCE', 'Elevada', '${v.toStringAsFixed(2)}%', _Regime.negative); }
    if (v > 2.5) {
      return _TileData('PCE',
        c <= 0 ? 'Em queda' : 'Acelerando', '${v.toStringAsFixed(2)}%',
        c <= 0 ? _Regime.caution : _Regime.negative);
    }
    return _TileData('PCE', 'Controlada', '${v.toStringAsFixed(2)}%', _Regime.positive);
  }

  static _TileData _laborTile(MacroIndicator? ind) {
    if (ind == null) return const _TileData('EMPREGO', '—', '—', _Regime.neutral);
    final v = ind.value;
    if (v < 4.0) return _TileData('EMPREGO', 'Aquecido',  '${v.toStringAsFixed(1)}%', _Regime.positive);
    if (v < 5.0) return _TileData('EMPREGO', 'Esfriando', '${v.toStringAsFixed(1)}%', _Regime.caution);
    return              _TileData('EMPREGO', 'Fraco',      '${v.toStringAsFixed(1)}%', _Regime.negative);
  }

  static _TileData _curveTile(MacroIndicator? ind) {
    if (ind == null) return const _TileData('CURVA', '—', '—', _Regime.neutral);
    final v = ind.value;
    final vs = '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';
    if (v < -0.25) return _TileData('CURVA', 'Invertida', vs, _Regime.negative);
    if (v <  0.5)  return _TileData('CURVA', 'Flat',      vs, _Regime.caution);
    return                _TileData('CURVA', 'Normal',     vs, _Regime.positive);
  }

  static _TileData _recessionTile(MacroIndicator? ind) {
    if (ind == null) return const _TileData('RECESSÃO', '—', '—', _Regime.neutral);
    final v = ind.value;
    if (v < 10) return _TileData('RECESSÃO', 'Baixo',   '${v.toStringAsFixed(0)}%', _Regime.positive);
    if (v < 30) return _TileData('RECESSÃO', 'Elevado', '${v.toStringAsFixed(0)}%', _Regime.caution);
    return             _TileData('RECESSÃO', 'Alto',     '${v.toStringAsFixed(0)}%', _Regime.negative);
  }
}

enum _Regime { positive, caution, negative, neutral }

class _TileData {
  final String title;
  final String status;
  final String value;
  final _Regime regime;
  const _TileData(this.title, this.status, this.value, this.regime);
}

class _ScoreTile extends StatelessWidget {
  final _TileData tile;
  const _ScoreTile({required this.tile});

  Color _bg(BuildContext context) => switch (tile.regime) {
    _Regime.positive => AppColors.emerald.withValues(alpha: 0.13),
    _Regime.negative => AppColors.red.withValues(alpha: 0.13),
    _Regime.caution  => AppColors.orange.withValues(alpha: 0.13),
    _Regime.neutral  => context.colors.surfaceAlt,
  };

  Color _fg() => switch (tile.regime) {
    _Regime.positive => AppColors.emerald,
    _Regime.negative => AppColors.red,
    _Regime.caution  => AppColors.orange,
    _Regime.neutral  => const Color(0xFF71717A),
  };

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
    decoration: BoxDecoration(
      color: _bg(context), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tile.title, style: TextStyle(
        fontSize: 8, fontWeight: FontWeight.w700,
        letterSpacing: 0.8, color: context.colors.textMuted)),
      const SizedBox(height: 3),
      Text(tile.status,
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _fg())),
      const SizedBox(height: 2),
      Text(tile.value,
        style: TextStyle(fontSize: 9, color: context.colors.textMuted)),
    ]),
  );
}

// ── FOMC Calendar ─────────────────────────────────────────────────────────────

class _FomcCalendar extends StatelessWidget {
  final MacroIndicator? fedFunds;
  const _FomcCalendar({this.fedFunds});

  static final _meetings = <(DateTime, String)>[
    (DateTime(2026, 7,  29), '28–29 Jul 2026'),
    (DateTime(2026, 9,  16), '15–16 Set 2026'),
    (DateTime(2026, 10, 28), '27–28 Out 2026'),
    (DateTime(2026, 12,  9), '8–9 Dez 2026'),
    (DateTime(2027, 1,  27), '26–27 Jan 2027'),
    (DateTime(2027, 3,  17), '16–17 Mar 2027'),
    (DateTime(2027, 4,  28), '27–28 Abr 2027'),
    (DateTime(2027, 6,   9), '8–9 Jun 2027'),
  ];

  String get _fedRange {
    final v = fedFunds?.value;
    if (v == null) return '—';
    final lower = (v / 0.25).floor() * 0.25;
    return '${lower.toStringAsFixed(2)}–${(lower + 0.25).toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = _meetings.where((m) => m.$1.isAfter(now)).toList();
    // Hardcoded schedule exhausted → show an honest placeholder instead of
    // silently vanishing (and never fabricate unconfirmed FOMC dates).
    if (upcoming.isEmpty) return const _FomcOutdated();

    final next     = upcoming.first;
    final daysLeft = next.$1.difference(now).inDays + 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Icon(Icons.event_rounded, size: 14, color: AppColors.emerald),
          const SizedBox(width: 6),
          Text('CALENDÁRIO FOMC', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            letterSpacing: 1.1, color: context.colors.textMuted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Fed: $_fedRange', style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.emerald)),
          ),
        ]),

        const SizedBox(height: 14),

        // Next meeting highlighted
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PRÓXIMA REUNIÃO', style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600,
                letterSpacing: 0.6, color: context.colors.textMuted)),
              const SizedBox(height: 3),
              Text(next.$2, style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: context.colors.textPrimary)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('em', style: TextStyle(
                fontSize: 9, color: context.colors.textMuted)),
              Text('$daysLeft dias', style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: AppColors.emerald)),
            ]),
          ]),
        ),

        const SizedBox(height: 12),

        // Remaining meetings
        ...upcoming.skip(1).take(5).map((m) {
          final d = m.$1.difference(now).inDays + 1;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Container(width: 6, height: 6,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: context.colors.textMuted, shape: BoxShape.circle)),
              Text(m.$2, style: TextStyle(
                fontSize: 12, color: context.colors.textSecond)),
              const Spacer(),
              Text('em $d dias', style: TextStyle(
                fontSize: 10, color: context.colors.textMuted)),
            ]),
          );
        }),
      ]),
    );
  }
}

class _FomcOutdated extends StatelessWidget {
  const _FomcOutdated();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      const Icon(Icons.event_busy_rounded, size: 16, color: AppColors.emerald),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'Calendário FOMC será atualizado com as próximas datas.',
        style: TextStyle(fontSize: 12, color: context.colors.textMuted))),
    ]),
  );
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(label.toUpperCase(), style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      letterSpacing: 1.1, color: context.colors.textMuted)),
  );
}

// ── Full Indicator Card ───────────────────────────────────────────────────────

class _FullIndicatorCard extends ConsumerStatefulWidget {
  final MacroIndicator indicator;
  const _FullIndicatorCard({required this.indicator});

  @override
  ConsumerState<_FullIndicatorCard> createState() => _FullIndicatorCardState();
}

class _FullIndicatorCardState extends ConsumerState<_FullIndicatorCard> {
  String _range = '5A';
  static const _ranges = ['1A', '2A', '5A', '10A', 'Máx'];

  @override
  Widget build(BuildContext context) {
    final ind    = widget.indicator;
    final dAsync = ref.watch(macroDetailProvider(ind.id));

    final changeColor = ind.isImproving ? AppColors.emerald
        : ind.isWorsening ? AppColors.red
        : context.colors.textMuted;
    final changeIcon = ind.isImproving ? Icons.arrow_upward_rounded
        : ind.isWorsening ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: context.colors.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ind.label, style: TextStyle(
                  fontSize: 12, color: context.colors.textMuted)),
                const SizedBox(height: 2),
                Text(_fmtValue(ind.value, ind.unit), style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary)),
              ])),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(changeIcon, size: 13, color: changeColor),
                const SizedBox(width: 2),
                Text(_fmtChange(ind.change, ind.unit), style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: changeColor)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          // Detail
          dAsync.when(
            loading: () => SizedBox(height: 100, child: Center(
              child: CircularProgressIndicator(
                color: AppColors.emerald, strokeWidth: 2))),
            error: (e, _) => _InlineError(
              onRetry: () => ref.invalidate(macroDetailProvider(ind.id))),
            data: (detail) => _DetailContent(
              detail: detail, range: _range, ranges: _ranges,
              onRange: (r) => setState(() => _range = r),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Detail Content ────────────────────────────────────────────────────────────

class _DetailContent extends StatelessWidget {
  final MacroDetailData detail;
  final String range;
  final List<String> ranges;
  final ValueChanged<String> onRange;
  const _DetailContent({
    required this.detail,
    required this.range,
    required this.ranges,
    required this.onRange,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = detail.filter(range);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: ranges.map((r) => _RangeChip(
        label: r, selected: r == range, onTap: () => onRange(r),
      )).toList()),
      const SizedBox(height: 10),
      if (filtered.length >= 2)
        SizedBox(height: 200, child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _MacroChart(detail: detail, filtered: filtered),
        )),
      const SizedBox(height: 14),
      _StatsRow(detail: detail),
      const Divider(height: 28),
      Text('Sobre este indicador', style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        letterSpacing: 0.5, color: context.colors.textMuted)),
      const SizedBox(height: 6),
      Text(detail.description, style: TextStyle(
        fontSize: 12, color: context.colors.textSecond, height: 1.65)),
      const Divider(height: 28),
      _HistorySection(
        key: ValueKey('${detail.id}_$range'),
        detail: detail, filtered: filtered),
    ]);
  }
}

// ── Range Chip ────────────────────────────────────────────────────────────────

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.emerald : context.colors.surfaceAlt),
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? Colors.white : context.colors.textMuted)),
      ),
    ),
  );
}

// ── Chart ─────────────────────────────────────────────────────────────────────

class _MacroChart extends StatelessWidget {
  final MacroDetailData detail;
  final List<MacroDataPoint> filtered;
  const _MacroChart({required this.detail, required this.filtered});

  @override
  Widget build(BuildContext context) {
    if (filtered.length < 2) return const SizedBox.shrink();

    final values    = filtered.map((p) => p.value).toList();
    final minY      = values.reduce(math.min);
    final maxY      = values.reduce(math.max);
    final spread    = maxY - minY;
    final pad       = spread > 0 ? spread * 0.2 : (maxY.abs() * 0.2).clamp(0.1, 10.0);
    final chartMinY = minY - pad;
    final chartMaxY = maxY + pad;

    final spots = filtered.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();

    final lineColor =
        ((filtered.last.value - filtered.first.value) * detail.direction) >= 0
            ? AppColors.emerald : AppColors.red;

    final recBands = _recessionBars(
        filtered, detail.recessions, chartMinY, chartMaxY);

    final step = (filtered.length - 1) / 4.0;
    final xLabels = <int, String>{};
    for (int i = 0; i < 5; i++) {
      final idx = (i * step).round().clamp(0, filtered.length - 1);
      xLabels[idx] = _shortDate(filtered[idx].date);
    }
    final yInterval = spread > 0 ? spread / 4 : 1.0;

    return LineChart(LineChartData(
      minY: chartMinY, maxY: chartMaxY,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true, drawHorizontalLine: true, drawVerticalLine: false,
        horizontalInterval: yInterval > 0 ? yInterval : 1,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: context.colors.surfaceAlt, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: true, border: Border(
        bottom: BorderSide(color: context.colors.surfaceAlt),
        left:   BorderSide(color: context.colors.surfaceAlt),
      )),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 46,
          interval: yInterval > 0 ? yInterval : 1,
          getTitlesWidget: (v, _) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(_fmtAxisY(v, detail.unit),
              style: TextStyle(fontSize: 9, color: context.colors.textMuted),
              textAlign: TextAlign.right)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 20,
          getTitlesWidget: (v, _) {
            final label = xLabels[v.round()];
            if (label == null) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(label, style: TextStyle(
                fontSize: 9, color: context.colors.textMuted)));
          },
        )),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
      ),
      // Touch disabled: these charts live inside a scrolling ListView, so the
      // chart must not capture vertical drags (it would block page scroll).
      // Exact values are available in the history table below each card.
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        ...recBands,
        LineChartBarData(
          spots: spots, isCurved: true, color: lineColor, barWidth: 2,
          dotData: FlDotData(show: filtered.length < 36),
          belowBarData: BarAreaData(
            show: true, color: lineColor.withValues(alpha: 0.08)),
        ),
      ],
    ));
  }

  static List<LineChartBarData> _recessionBars(
    List<MacroDataPoint> filtered,
    List<RecessionPeriod> recessions,
    double chartMinY, double chartMaxY,
  ) {
    final bars = <LineChartBarData>[];
    for (final rec in recessions) {
      final rs = DateTime.parse(rec.start);
      final re = DateTime.parse(rec.end);
      int? xs, xe;
      for (int i = 0; i < filtered.length; i++) {
        final d = DateTime.parse(filtered[i].date);
        if (!d.isBefore(rs) && xs == null) xs = i;
        if (!d.isAfter(re)) xe = i;
      }
      if (xs == null || xe == null || xs > xe) continue;
      bars.add(LineChartBarData(
        spots: [
          FlSpot(xs.toDouble(), chartMaxY),
          FlSpot(xe.toDouble(), chartMaxY),
        ],
        isCurved: false, color: Colors.transparent, barWidth: 0,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true, color: Colors.grey.withValues(alpha: 0.18)),
      ));
    }
    return bars;
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final MacroDetailData detail;
  const _StatsRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    if (detail.data.isEmpty) return const SizedBox.shrink();
    final current   = detail.data.last.value;
    final allValues = detail.data.map((p) => p.value).toList();
    final maxAll    = allValues.reduce(math.max);
    final minAll    = allValues.reduce(math.min);
    final cutoff    = DateTime.now().subtract(const Duration(days: 365));
    final prevYear  = detail.data
        .where((p) => DateTime.parse(p.date).isBefore(cutoff))
        .lastOrNull?.value;
    final yearChange = prevYear != null ? current - prevYear : null;
    Color? yearColor;
    if (yearChange != null) {
      yearColor = yearChange * detail.direction > 0 ? AppColors.emerald
          : yearChange * detail.direction < 0 ? AppColors.red : null;
    }

    return Row(children: [
      _StatCell(label: '1A atrás',
        value: prevYear != null ? _fmtValue(prevYear, detail.unit) : '—'),
      _VDivider(),
      _StatCell(label: 'Var. anual',
        value: yearChange != null ? _fmtChange(yearChange, detail.unit) : '—',
        valueColor: yearColor),
      _VDivider(),
      _StatCell(label: 'Máx.', value: _fmtValue(maxAll, detail.unit)),
      _VDivider(),
      _StatCell(label: 'Mín.', value: _fmtValue(minAll, detail.unit)),
    ]);
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatCell({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(label, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 9, color: context.colors.textMuted)),
      const SizedBox(height: 3),
      Text(value, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: valueColor ?? context.colors.textPrimary)),
    ]),
  );
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: context.colors.surfaceAlt);
}

// ── History Section ───────────────────────────────────────────────────────────

class _HistorySection extends StatefulWidget {
  final MacroDetailData detail;
  final List<MacroDataPoint> filtered;
  const _HistorySection(
      {super.key, required this.detail, required this.filtered});

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  bool _showAll = false;
  static const _preview = 5;

  @override
  Widget build(BuildContext context) {
    final rows    = widget.filtered.reversed.toList();
    final display = _showAll ? rows : rows.take(_preview).toList();
    final extra   = rows.length - _preview;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Histórico', style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        letterSpacing: 0.5, color: context.colors.textMuted)),
      const SizedBox(height: 6),
      // Header row
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text('Data', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w600,
            color: context.colors.textMuted))),
          Text('Valor', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w600,
            color: context.colors.textMuted)),
          SizedBox(width: 62, child: Text('Var.', textAlign: TextAlign.right,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
              color: context.colors.textMuted))),
        ]),
      ),
      Divider(height: 1, color: context.colors.surfaceAlt),
      // Data rows
      ...display.asMap().entries.map((e) {
        final i      = e.key;
        final pt     = e.value;
        final prev   = (i + 1 < rows.length) ? rows[i + 1] : null;
        final change = prev != null ? pt.value - prev.value : null;
        final isGood = change != null && change * widget.detail.direction > 0;
        final chCol  = (change == null || change.abs() < 0.0001)
            ? context.colors.textMuted
            : isGood ? AppColors.emerald : AppColors.red;

        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text(_longDate(pt.date), style: TextStyle(
                fontSize: 12, color: context.colors.textSecond))),
              Text(_fmtValue(pt.value, widget.detail.unit), style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: context.colors.textPrimary)),
              SizedBox(width: 62, child: change != null
                  ? Text(_fmtChange(change, widget.detail.unit),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, color: chCol))
                  : null),
            ]),
          ),
          if (i < display.length - 1)
            Divider(height: 1, color: context.colors.surfaceAlt),
        ]);
      }),
      // Ver mais / Ver menos
      if (extra > 0)
        GestureDetector(
          onTap: () => setState(() => _showAll = !_showAll),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_showAll ? 'Ver menos' : 'Ver mais ($extra anteriores)',
                style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: AppColors.emerald)),
              const SizedBox(width: 4),
              Icon(
                _showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16, color: AppColors.emerald),
            ]),
          ),
        ),
    ]);
  }
}

// ── Error widgets ─────────────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: context.colors.textMuted),
      const SizedBox(height: 12),
      Text(message, style: TextStyle(color: context.colors.textMuted)),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: onRetry,
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.emerald,
          side: const BorderSide(color: AppColors.emerald)),
        child: const Text('Retry')),
    ]),
  );
}

class _InlineError extends StatelessWidget {
  final VoidCallback onRetry;
  const _InlineError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Icon(Icons.cloud_off_rounded, size: 16, color: context.colors.textMuted),
      const SizedBox(width: 8),
      Text('Dados indisponíveis', style: TextStyle(
        fontSize: 12, color: context.colors.textMuted)),
      const Spacer(),
      TextButton(onPressed: onRetry,
        child: const Text('Tentar novamente',
          style: TextStyle(fontSize: 11))),
    ]),
  );
}

class _FredCredit extends StatelessWidget {
  const _FredCredit();
  @override
  Widget build(BuildContext context) => Center(
    child: Text('Fonte: Federal Reserve Bank of St. Louis (FRED)',
      style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
  );
}

// ── Formatting ────────────────────────────────────────────────────────────────

String _fmtValue(double v, String unit) {
  switch (unit) {
    case '%':   return '${v.toStringAsFixed(2)}%';
    case 'K':   return '${v.toStringAsFixed(0)}K';
    case 'T':   return '${v.toStringAsFixed(2)}T';
    case 'M':   return '${v.toStringAsFixed(2)}M';
    case 'B':   return '\$${v.abs().toStringAsFixed(0)}B';
    case 'pts': return v.toStringAsFixed(1);
    case 'idx': return v.toStringAsFixed(1);
    case '\$':  return '\$${v.toStringAsFixed(v >= 1000 ? 0 : 2)}';
    default:    return '${v.toStringAsFixed(2)}$unit';
  }
}

String _fmtChange(double c, String unit) {
  final s = c >= 0 ? '+' : '';
  switch (unit) {
    case '%':   return '$s${c.toStringAsFixed(2)}pp';
    case 'K':   return '$s${c.toStringAsFixed(0)}K';
    case 'T':   return '$s${c.toStringAsFixed(3)}T';
    case 'M':   return '$s${c.toStringAsFixed(2)}M';
    case 'B':   return '$s\$${c.abs().toStringAsFixed(0)}B';
    case 'pts': return '$s${c.toStringAsFixed(1)}';
    case 'idx': return '$s${c.toStringAsFixed(1)}';
    case '\$': {
      final sign = c >= 0 ? '+' : '-';
      return '$sign\$${c.abs().toStringAsFixed(2)}';
    }
    default:    return '$s${c.toStringAsFixed(2)}';
  }
}

String _fmtAxisY(double v, String unit) {
  switch (unit) {
    case 'K':   return '${v.toStringAsFixed(0)}K';
    case 'T':   return '${v.toStringAsFixed(1)}T';
    case 'M':   return '${v.toStringAsFixed(1)}M';
    case 'pts': return v.toStringAsFixed(0);
    case 'idx': return v.toStringAsFixed(0);
    case '\$':  return '\$${v.toStringAsFixed(v >= 100 ? 0 : 2)}';
    default:    return v.toStringAsFixed(1);
  }
}

String _shortDate(String iso) {
  try { return DateFormat('MMM yy').format(DateTime.parse(iso)); }
  catch (_) { return iso; }
}

String _longDate(String iso) {
  try { return DateFormat('MMM yyyy').format(DateTime.parse(iso)); }
  catch (_) { return iso; }
}
