import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/macro_model.dart';
import '../../core/providers/macro_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shell/main_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────

class UsMacroPage extends ConsumerWidget {
  const UsMacroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(macroUsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('US Economy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(macroUsProvider),
          ),
          MainShellMenu.themeButton(),
          MainShellMenu.button(),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => _ErrorRetry(
          message: 'Macro data unavailable',
          onRetry: () => ref.invalidate(macroUsProvider),
        ),
        data: (indicators) => _MacroBody(indicators: indicators),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MacroBody extends StatelessWidget {
  final List<MacroIndicator> indicators;
  const _MacroBody({required this.indicators});

  static const _sectionOrder = [
    'fed', 'labor', 'inflation', 'growth', 'bonds', 'consumer',
  ];
  static const _sectionLabels = {
    'fed':       'Federal Reserve',
    'labor':     'Labor Market',
    'inflation': 'Inflation',
    'growth':    'Economic Growth',
    'bonds':     'Fixed Income',
    'consumer':  'Consumer',
  };

  @override
  Widget build(BuildContext context) {
    final bySection = <String, List<MacroIndicator>>{};
    for (final ind in indicators) {
      bySection.putIfAbsent(ind.section, () => []).add(ind);
    }

    final items = <Widget>[];
    for (final sec in _sectionOrder) {
      final group = bySection[sec];
      if (group == null || group.isEmpty) continue;
      items.add(_SectionHeader(label: _sectionLabels[sec] ?? sec.toUpperCase()));
      for (final ind in group) {
        items.add(_IndicatorCard(indicator: ind));
      }
    }
    items.add(const SizedBox(height: 24));
    items.add(const _FredCredit());
    items.add(const SizedBox(height: 32));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: items,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: context.colors.textMuted,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _IndicatorCard extends StatelessWidget {
  final MacroIndicator indicator;
  const _IndicatorCard({required this.indicator});

  Color _changeColor(BuildContext context) {
    if (indicator.isImproving) return AppColors.emerald;
    if (indicator.isWorsening) return AppColors.red;
    return context.colors.textMuted;
  }

  String _fmtValue(double v, String unit) {
    if (unit == 'K') {
      // Job gains: show as +236K or -12K
      final sign = v >= 0 ? '+' : '';
      return '$sign${v.toStringAsFixed(0)}K';
    }
    final sign = v >= 0 ? '' : '';
    return '$sign${v.toStringAsFixed(2)}$unit';
  }

  String _fmtChange(double c, String unit) {
    final sign = c >= 0 ? '+' : '';
    if (unit == 'K') return '$sign${c.toStringAsFixed(0)}K MoM';
    if (unit == '%') return '$sign${c.toStringAsFixed(2)}pp';
    return '$sign${c.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = _changeColor(context);
    final changeIcon  = indicator.isImproving
        ? Icons.arrow_upward_rounded
        : indicator.isWorsening
            ? Icons.arrow_downward_rounded
            : Icons.remove_rounded;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: context.colors.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/us-macro/${indicator.id}'),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: label | value + change
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    indicator.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtValue(indicator.value, indicator.unit),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(changeIcon, size: 13, color: changeColor),
                        const SizedBox(width: 2),
                        Text(
                          _fmtChange(indicator.change, indicator.unit),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: changeColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // Sparkline
            if (indicator.history.length >= 2) ...[
              const SizedBox(height: 10),
              _Sparkline(values: indicator.history, color: changeColor),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _Sparkline({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final minY = values.reduce(math.min);
    final maxY = values.reduce(math.max);
    final range = maxY - minY;
    final pad   = range > 0 ? range * 0.15 : 0.5;

    return SizedBox(
      height: 64,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData:   const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots:    spots,
              isCurved: true,
              color:    color,
              barWidth: 1.8,
              dotData:  const FlDotData(show: false),
              belowBarData: BarAreaData(
                show:  true,
                color: color.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
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
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _FredCredit extends StatelessWidget {
  const _FredCredit();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Data: Federal Reserve Bank of St. Louis (FRED)',
        style: TextStyle(fontSize: 11, color: context.colors.textMuted),
      ),
    );
  }
}
