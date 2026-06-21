import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/macro_model.dart';
import '../../core/providers/macro_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────

class MacroDetailPage extends ConsumerStatefulWidget {
  final String seriesId;
  const MacroDetailPage({super.key, required this.seriesId});

  @override
  ConsumerState<MacroDetailPage> createState() => _MacroDetailPageState();
}

class _MacroDetailPageState extends ConsumerState<MacroDetailPage> {
  String _range = '5A';
  static const _ranges = ['1A', '2A', '5A', '10A', 'Máx'];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(macroDetailProvider(widget.seriesId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.seriesId),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(macroDetailProvider(widget.seriesId)),
          ),
          MainShellMenu.themeButton(),
          MainShellMenu.button(),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => _ErrorRetry(
          message: 'Dados indisponíveis',
          onRetry: () => ref.invalidate(macroDetailProvider(widget.seriesId)),
        ),
        data: (detail) {
          // Update AppBar title reactively
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
          return _DetailBody(
            detail: detail,
            range: _range,
            ranges: _ranges,
            onRangeChanged: (r) => setState(() => _range = r),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  final MacroDetailData detail;
  final String range;
  final List<String> ranges;
  final ValueChanged<String> onRangeChanged;

  const _DetailBody({
    required this.detail,
    required this.range,
    required this.ranges,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = detail.filter(range);
    if (filtered.isEmpty) {
      return const Center(child: Text('Sem dados para o período selecionado'));
    }

    final values    = filtered.map((p) => p.value).toList();
    final current   = values.last;
    final allValues = detail.data.map((p) => p.value).toList();
    final maxAll    = allValues.reduce(math.max);
    final minAll    = allValues.reduce(math.min);

    // 1-year-ago value
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    final prevYearPt = detail.data.where((p) => DateTime.parse(p.date).isBefore(oneYearAgo)).lastOrNull;
    final prevYear   = prevYearPt?.value;
    final yearChange = prevYear != null ? current - prevYear : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          _Header(detail: detail, current: current, filtered: filtered),

          // ── Range selector ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: ranges.map((r) => _RangeChip(
                label: r,
                selected: r == range,
                onTap: () => onRangeChanged(r),
              )).toList(),
            ),
          ),

          // ── Chart ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: SizedBox(
              height: 240,
              child: _MacroChart(
                detail:   detail,
                filtered: filtered,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Stats row ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _StatsRow(
              detail:     detail,
              current:    current,
              prevYear:   prevYear,
              yearChange: yearChange,
              maxAll:     maxAll,
              minAll:     minAll,
            ),
          ),

          const Divider(height: 24),

          // ── Description ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('O que é este indicador?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                    fontSize: 14,
                  )),
                const SizedBox(height: 8),
                Text(detail.description,
                  style: TextStyle(
                    color: context.colors.textSecond,
                    height: 1.6,
                    fontSize: 13,
                  )),
              ],
            ),
          ),

          const Divider(height: 32),

          // ── Historical table ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Histórico',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: context.colors.textMuted,
                letterSpacing: 0.8,
              )),
          ),
          const SizedBox(height: 4),
          _HistoryTable(detail: detail, filtered: filtered),

          const SizedBox(height: 16),
          const _FredCredit(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final MacroDetailData detail;
  final double current;
  final List<MacroDataPoint> filtered;

  const _Header({required this.detail, required this.current, required this.filtered});

  @override
  Widget build(BuildContext context) {
    final lastDate = filtered.isNotEmpty ? _longDate(filtered.last.date) : '';
    final prev     = filtered.length >= 2 ? filtered[filtered.length - 2].value : current;
    final change   = current - prev;
    final isGood   = change * detail.direction > 0;
    final isNeutral = change.abs() < 0.001;
    final changeColor = isNeutral
        ? context.colors.textMuted
        : isGood ? AppColors.emerald : AppColors.red;
    final changeIcon  = isNeutral ? Icons.remove_rounded
        : change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.label,
            style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtValue(current, detail.unit),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Icon(changeIcon, size: 14, color: changeColor),
                    const SizedBox(width: 2),
                    Text(
                      _fmtChange(change, detail.unit),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(lastDate,
                style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MacroChart extends StatefulWidget {
  final MacroDetailData detail;
  final List<MacroDataPoint> filtered;

  const _MacroChart({required this.detail, required this.filtered});

  @override
  State<_MacroChart> createState() => _MacroChartState();
}

class _MacroChartState extends State<_MacroChart> {
  int? _touchedIdx;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.filtered;
    if (filtered.length < 2) return const SizedBox.shrink();

    final values = filtered.map((p) => p.value).toList();
    final minY   = values.reduce(math.min);
    final maxY   = values.reduce(math.max);
    final range  = maxY - minY;
    final pad    = range > 0 ? range * 0.2 : (maxY.abs() * 0.2).clamp(0.1, 10.0);
    final chartMinY = minY - pad;
    final chartMaxY = maxY + pad;

    final spots = filtered.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    // Determine line color based on trend
    final firstVal = filtered.first.value;
    final lastVal  = filtered.last.value;
    final lineColor = ((lastVal - firstVal) * widget.detail.direction) >= 0
        ? AppColors.emerald
        : AppColors.red;

    // Build recession bands
    final recBands = _buildRecessionBars(
      filtered, widget.detail.recessions, chartMinY, chartMaxY);

    // X-axis labels: 5 evenly spaced
    final step = (filtered.length - 1) / 4.0;
    final xLabels = <int, String>{};
    for (int i = 0; i < 5; i++) {
      final idx = (i * step).round().clamp(0, filtered.length - 1);
      xLabels[idx] = _shortDate(filtered[idx].date);
    }

    // Y-axis interval
    final yInterval = range > 0 ? range / 4 : 1.0;

    return LineChart(
      LineChartData(
        minY: chartMinY,
        maxY: chartMaxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval > 0 ? yInterval : 1,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: context.colors.surfaceAlt, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: context.colors.surfaceAlt),
            left:   BorderSide(color: context.colors.surfaceAlt),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: yInterval > 0 ? yInterval : 1,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  _fmtAxisY(v, widget.detail.unit),
                  style: TextStyle(fontSize: 9, color: context.colors.textMuted),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final idx = v.round();
                final label = xLabels[idx];
                if (label == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                    style: TextStyle(fontSize: 9, color: context.colors.textMuted)),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (response?.lineBarSpots != null) {
              setState(() {
                _touchedIdx = response!.lineBarSpots!
                    .where((s) => s.barIndex == recBands.length)
                    .map((s) => s.x.round())
                    .firstOrNull;
              });
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.colors.surface,
            tooltipBorder: BorderSide(color: context.colors.surfaceAlt),
            getTooltipItems: (spots) => spots.map((s) {
              if (s.barIndex != recBands.length) return null;
              final idx = s.x.round();
              if (idx < 0 || idx >= filtered.length) return null;
              return LineTooltipItem(
                '${_longDate(filtered[idx].date)}\n${_fmtValue(s.y, widget.detail.unit)}',
                TextStyle(
                  color: lineColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          ...recBands,
          LineChartBarData(
            spots:    spots,
            isCurved: true,
            color:    lineColor,
            barWidth: 2,
            dotData:  FlDotData(
              show: filtered.length < 36,
              getDotPainter: (_, __, ___, i) => FlDotCirclePainter(
                radius: 3,
                color:  lineColor,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show:  true,
              color: lineColor.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  List<LineChartBarData> _buildRecessionBars(
    List<MacroDataPoint> filtered,
    List<RecessionPeriod> recessions,
    double chartMinY,
    double chartMaxY,
  ) {
    final bars = <LineChartBarData>[];
    for (final rec in recessions) {
      final recStart = DateTime.parse(rec.start);
      final recEnd   = DateTime.parse(rec.end);

      int? xStart, xEnd;
      for (int i = 0; i < filtered.length; i++) {
        final d = DateTime.parse(filtered[i].date);
        if (!d.isBefore(recStart) && xStart == null) xStart = i;
        if (!d.isAfter(recEnd)) xEnd = i;
      }

      if (xStart == null || xEnd == null || xStart > xEnd) continue;

      bars.add(LineChartBarData(
        spots: [
          FlSpot(xStart.toDouble(), chartMaxY),
          FlSpot(xEnd.toDouble(), chartMaxY),
        ],
        isCurved:  false,
        color:     Colors.transparent,
        barWidth:  0,
        dotData:   const FlDotData(show: false),
        belowBarData: BarAreaData(
          show:  true,
          color: Colors.grey.withValues(alpha: 0.18),
        ),
      ));
    }
    return bars;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.emerald : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.emerald : context.colors.surfaceAlt,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? Colors.white : context.colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final MacroDetailData detail;
  final double current;
  final double? prevYear;
  final double? yearChange;
  final double maxAll;
  final double minAll;

  const _StatsRow({
    required this.detail,
    required this.current,
    required this.prevYear,
    required this.yearChange,
    required this.maxAll,
    required this.minAll,
  });

  @override
  Widget build(BuildContext context) {
    Color? yearChangeColor;
    if (yearChange != null) {
      yearChangeColor = yearChange! * detail.direction > 0
          ? AppColors.emerald
          : yearChange! * detail.direction < 0 ? AppColors.red : null;
    }

    return Row(
      children: [
        _StatCell(
          label: '1A atrás',
          value: prevYear != null ? _fmtValue(prevYear!, detail.unit) : '—',
        ),
        _Divider(),
        _StatCell(
          label: 'Var. anual',
          value: yearChange != null
              ? _fmtChange(yearChange!, detail.unit)
              : '—',
          valueColor: yearChangeColor,
        ),
        _Divider(),
        _StatCell(
          label: 'Máx. histórico',
          value: _fmtValue(maxAll, detail.unit),
        ),
        _Divider(),
        _StatCell(
          label: 'Mín. histórico',
          value: _fmtValue(minAll, detail.unit),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatCell({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
          const SizedBox(height: 4),
          Text(value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? context.colors.textPrimary,
            )),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: context.colors.surfaceAlt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HistoryTable extends StatelessWidget {
  final MacroDetailData detail;
  final List<MacroDataPoint> filtered;
  const _HistoryTable({required this.detail, required this.filtered});

  @override
  Widget build(BuildContext context) {
    // Show last 24 points, reversed (newest first)
    final rows = filtered.reversed.take(24).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // Table header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text('Data',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: context.colors.textMuted))),
              Text('Valor',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: context.colors.textMuted)),
              const SizedBox(width: 60),
              Text('Var.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: context.colors.textMuted)),
            ],
          ),
        ),
        const Divider(height: 1),
        ...rows.asMap().entries.map((entry) {
          final i   = entry.key;
          final pt  = entry.value;
          // Previous point in filtered (next in reversed = older)
          final prevPt = (i + 1 < rows.length) ? rows[i + 1] : null;
          final change = prevPt != null ? pt.value - prevPt.value : null;
          final isGood = change != null && change * detail.direction > 0;
          final changeColor = change == null || change.abs() < 0.001
              ? context.colors.textMuted
              : isGood ? AppColors.emerald : AppColors.red;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_longDate(pt.date),
                        style: TextStyle(fontSize: 12, color: context.colors.textSecond)),
                    ),
                    Text(_fmtValue(pt.value, detail.unit),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      )),
                    SizedBox(
                      width: 60,
                      child: change != null
                          ? Text(
                              '${change >= 0 ? '+' : ''}${_fmtRaw(change, detail.unit)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 11, color: changeColor),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              if (entry.key < rows.length - 1)
                Divider(height: 1, color: context.colors.surfaceAlt),
            ],
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: context.colors.textMuted),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: context.colors.textMuted)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emerald,
              side: const BorderSide(color: AppColors.emerald),
            ),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _FredCredit extends StatelessWidget {
  const _FredCredit();
  @override
  Widget build(BuildContext context) => Center(
    child: Text('Fonte: Federal Reserve Bank of St. Louis (FRED)',
      style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers

String _fmtValue(double v, String unit) {
  if (unit == 'K') {
    final sign = v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(0)}K';
  }
  return '${v.toStringAsFixed(2)}$unit';
}

String _fmtRaw(double v, String unit) {
  if (unit == 'K') return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)}K';
  return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}';
}

String _fmtChange(double c, String unit) {
  final sign = c >= 0 ? '+' : '';
  if (unit == 'K') return '$sign${c.toStringAsFixed(0)}K';
  if (unit == '%') return '$sign${c.toStringAsFixed(2)}pp';
  return '$sign${c.toStringAsFixed(2)}';
}

String _fmtAxisY(double v, String unit) {
  if (unit == 'K') return '${(v / 1).toStringAsFixed(0)}K';
  return v.toStringAsFixed(1);
}

String _shortDate(String iso) {
  try { return DateFormat('MMM yy').format(DateTime.parse(iso)); }
  catch (_) { return iso; }
}

String _longDate(String iso) {
  try { return DateFormat('MMM yyyy').format(DateTime.parse(iso)); }
  catch (_) { return iso; }
}
