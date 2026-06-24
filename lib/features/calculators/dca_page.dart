import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import 'calc_widgets.dart';
import '../../core/widgets/app_bottom_nav.dart';

final _usd = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
const _cyan = Color(0xFF06B6D4);

enum _Freq { weekly, biweekly, monthly }

extension _FreqExt on _Freq {
  String get label => switch (this) {
    _Freq.weekly    => 'Weekly',
    _Freq.biweekly  => 'Bi-weekly',
    _Freq.monthly   => 'Monthly',
  };
  double get perYear => switch (this) {
    _Freq.weekly    => 52.0,
    _Freq.biweekly  => 26.0,
    _Freq.monthly   => 12.0,
  };
}

class DCAPage extends StatefulWidget {
  const DCAPage({super.key});

  @override
  State<DCAPage> createState() => _DCAPageState();
}

class _DCAPageState extends State<DCAPage> {
  final _amountCtrl = TextEditingController(text: '500');
  final _rateCtrl   = TextEditingController(text: '10');
  final _yearsCtrl  = TextEditingController(text: '20');
  final _ageCtrl    = TextEditingController(text: '30');
  _Freq _freq = _Freq.monthly;

  double? _dcaFinal;
  double? _lumpSumFinal;
  double? _totalInvested;
  List<({double dca, double lump, int year})> _chartPts = [];

  static const _amountPresets = ['100', '250', '500', '1000'];
  static const _yearPresets   = ['5', '10', '20', '30'];

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final rate   = double.tryParse(_rateCtrl.text) ?? 0;
    final years  = int.tryParse(_yearsCtrl.text) ?? 0;

    if (amount <= 0 || rate <= 0 || years <= 0 || years > 50) {
      setState(() => _dcaFinal = null);
      return;
    }

    final perYear      = _freq.perYear;
    final r            = math.pow(1 + rate / 100, 1 / perYear) - 1;
    final n            = (years * perYear).round();
    final totalInvested = amount * n;
    final dcaFinal     = amount * (math.pow(1 + r, n) - 1) / r;

    // Lump sum: same total invested all on day 1
    final rAnnual   = rate / 100;
    final lumpFinal = totalInvested * math.pow(1 + rAnnual, years.toDouble());

    // Build yearly chart points
    final pts = <({double dca, double lump, int year})>[];
    for (var yr = 0; yr <= years; yr++) {
      final nYr = (yr * perYear).round();
      final dcaYr = yr == 0 ? 0.0 : amount * (math.pow(1 + r, nYr) - 1) / r;
      final invYr = amount * nYr;
      final lumpYr = invYr * math.pow(1 + rAnnual, yr.toDouble());
      pts.add((dca: dcaYr, lump: lumpYr, year: yr));
    }

    setState(() {
      _dcaFinal      = dcaFinal;
      _lumpSumFinal  = lumpFinal;
      _totalInvested = totalInvested;
      _chartPts      = pts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final age  = int.tryParse(_ageCtrl.text) ?? 0;
    final yrs  = int.tryParse(_yearsCtrl.text) ?? 0;
    final atAge = age > 0 && yrs > 0 ? 'at age ${age + yrs}' : null;

    final dcaWins  = (_dcaFinal ?? 0) >= (_lumpSumFinal ?? 0);

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('DCA Calculator')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Inputs ────────────────────────────────────────────────────
              CalcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CalcLabel('Amount per contribution'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _amountPresets.map((p) => CalcChip(
                        label: '\$$p', active: _amountCtrl.text == p,
                        color: _cyan,
                        onTap: () => setState(() {
                          _amountCtrl.text = p;
                          _calculate();
                        }),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                    CalcField(
                      controller: _amountCtrl, label: 'Custom amount',
                      prefix: '\$', focusColor: _cyan,
                      onChanged: (_) => _calculate(),
                    ),
                    const SizedBox(height: 14),
                    const CalcLabel('Frequency'),
                    const SizedBox(height: 10),
                    Row(
                      children: _Freq.values.map((f) {
                        final active = _freq == f;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: f != _Freq.monthly ? 8 : 0,
                            ),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _freq = f;
                                _calculate();
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: active ? _cyan : c.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: active ? _cyan : c.border,
                                  ),
                                ),
                                child: Text(
                                  f.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: active ? Colors.white : c.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const CalcLabel('Duration & return'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _yearPresets.map((p) => CalcChip(
                        label: '${p}y', active: _yearsCtrl.text == p,
                        color: _cyan,
                        onTap: () => setState(() {
                          _yearsCtrl.text = p;
                          _calculate();
                        }),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: CalcField(
                        controller: _yearsCtrl, label: 'Duration',
                        suffix: 'yrs', focusColor: _cyan,
                        onChanged: (_) => _calculate(),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: CalcField(
                        controller: _rateCtrl, label: 'Annual return',
                        suffix: '%', focusColor: _cyan,
                        onChanged: (_) => _calculate(),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    CalcField(
                      controller: _ageCtrl, label: 'Current age (optional)',
                      focusColor: _cyan, onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Results ───────────────────────────────────────────────────
              if (_dcaFinal != null) ...[
                CalcCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CalcLabel('DCA result'),
                      const SizedBox(height: 14),
                      Row(children: [
                        CalcKpi(
                          label: 'DCA final value',
                          value: _usd.format(_dcaFinal),
                          valueColor: _cyan,
                          sub: atAge,
                        ),
                        CalcKpi(
                          label: 'Total invested',
                          value: _usd.format(_totalInvested),
                        ),
                        CalcKpi(
                          label: 'Total gains',
                          value: _usd.format(_dcaFinal! - _totalInvested!),
                          valueColor: AppColors.emerald,
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── DCA vs Lump Sum ────────────────────────────────────────
                CalcCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CalcLabel('DCA vs Lump Sum'),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (dcaWins ? _cyan : AppColors.emerald)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dcaWins ? 'DCA wins' : 'Lump sum wins',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: dcaWins ? _cyan : AppColors.emerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        CalcKpi(
                          label: 'DCA',
                          value: _usd.format(_dcaFinal),
                          valueColor: _cyan,
                        ),
                        CalcKpi(
                          label: 'Lump sum',
                          value: _usd.format(_lumpSumFinal),
                          valueColor: AppColors.emerald,
                        ),
                        CalcKpi(
                          label: 'Difference',
                          value: _usd.format((_dcaFinal! - _lumpSumFinal!).abs()),
                          valueColor: context.colors.textMuted,
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Text(
                        'Lump sum assumes total invested (\$${_usd.format(_totalInvested)}) on day 1 at the same annual rate.',
                        style: TextStyle(fontSize: 11, color: c.textMuted, height: 1.4),
                      ),
                      if (_chartPts.length > 2) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 150,
                          child: _DCAChart(points: _chartPts),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          _DotLegend(color: _cyan,            label: 'DCA'),
                          const SizedBox(width: 16),
                          _DotLegend(color: AppColors.emerald, label: 'Lump sum'),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chart ─────────────────────────────────────────────────────────────────────

class _DCAChart extends StatelessWidget {
  final List<({double dca, double lump, int year})> points;
  const _DCAChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final dcaSpots  = points.map((p) => FlSpot(p.year.toDouble(), p.dca)).toList();
    final lumpSpots = points.map((p) => FlSpot(p.year.toDouble(), p.lump)).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: dcaSpots,
            isCurved: true,
            color: _cyan,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: _cyan.withValues(alpha: 0.08),
            ),
          ),
          LineChartBarData(
            spots: lumpSpots,
            isCurved: true,
            color: AppColors.emerald,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            dashArray: [5, 4],
          ),
        ],
      ),
    );
  }
}

class _DotLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _DotLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10,
              color: context.colors.textMuted)),
        ],
      );
}
