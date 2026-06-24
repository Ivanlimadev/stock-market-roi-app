import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import 'calc_widgets.dart';
import '../../core/widgets/app_bottom_nav.dart';

final _usd = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

class CompoundInterestPage extends StatefulWidget {
  const CompoundInterestPage({super.key});

  @override
  State<CompoundInterestPage> createState() => _CompoundInterestPageState();
}

class _CompoundInterestPageState extends State<CompoundInterestPage> {
  final _principalCtrl = TextEditingController(text: '10000');
  final _pmtCtrl       = TextEditingController(text: '500');
  final _rateCtrl      = TextEditingController(text: '10');
  final _yearsCtrl     = TextEditingController(text: '20');
  final _ageCtrl       = TextEditingController(text: '30');
  String _rateMode = 'annual';

  double? _final;
  double? _invested;
  double? _interest;
  List<({double balance, double invested, int year})> _points = [];

  static const _presets = [
    (label: 'S&P 500', rate: '10', mode: 'annual'),
    (label: 'Growth',  rate: '7',  mode: 'annual'),
    (label: 'HYSA',    rate: '5',  mode: 'annual'),
    (label: 'Bonds',   rate: '4',  mode: 'annual'),
  ];

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _pmtCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final principal  = double.tryParse(_principalCtrl.text) ?? 0;
    final pmt        = double.tryParse(_pmtCtrl.text) ?? 0;
    final rateInput  = double.tryParse(_rateCtrl.text) ?? 0;
    final years      = int.tryParse(_yearsCtrl.text) ?? 0;

    if (years <= 0 || years > 50 || rateInput < 0 || rateInput > 100) {
      setState(() => _final = null);
      return;
    }

    final r = _rateMode == 'annual'
        ? math.pow(1 + rateInput / 100, 1 / 12.0) - 1
        : rateInput / 100;

    double balance  = principal;
    double invested = principal;
    final pts = <({double balance, double invested, int year})>[
      (balance: balance, invested: invested, year: 0),
    ];

    for (var m = 1; m <= years * 12; m++) {
      balance  = balance * (1 + r) + pmt;
      invested += pmt;
      if (m % 12 == 0) {
        pts.add((balance: balance, invested: invested, year: m ~/ 12));
      }
    }

    setState(() {
      _final    = balance;
      _invested = invested;
      _interest = balance - invested;
      _points   = pts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final age    = int.tryParse(_ageCtrl.text) ?? 0;
    final years  = int.tryParse(_yearsCtrl.text) ?? 0;
    final atAge  = age > 0 && years > 0 ? 'at age ${age + years}' : null;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('Compound Interest')),
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
                    const CalcLabel('Rate presets'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _presets.map((p) {
                        final active = _rateCtrl.text == p.rate && _rateMode == p.mode;
                        return CalcChip(
                          label: p.label,
                          active: active,
                          color: AppColors.emerald,
                          onTap: () => setState(() {
                            _rateCtrl.text = p.rate;
                            _rateMode = p.mode;
                            _calculate();
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: CalcField(
                        controller: _principalCtrl, label: 'Initial investment',
                        prefix: '\$', onChanged: (_) => _calculate(),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: CalcField(
                        controller: _pmtCtrl, label: 'Monthly contribution',
                        prefix: '\$', onChanged: (_) => _calculate(),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: CalcField(
                        controller: _yearsCtrl, label: 'Duration',
                        suffix: 'yrs', onChanged: (_) => _calculate(),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: CalcField(
                        controller: _ageCtrl, label: 'Current age',
                        onChanged: (_) => _calculate(),
                      )),
                    ]),
                    const SizedBox(height: 14),
                    const CalcLabel('Interest rate'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: CalcField(
                        controller: _rateCtrl, label: 'Rate',
                        suffix: '%', onChanged: (_) => _calculate(),
                      )),
                      const SizedBox(width: 12),
                      CalcToggle(
                        options: const ['Annual', 'Monthly'],
                        selected: _rateMode == 'annual' ? 0 : 1,
                        color: AppColors.emerald,
                        onChanged: (i) {
                          setState(() => _rateMode = i == 0 ? 'annual' : 'monthly');
                          _calculate();
                        },
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Results ───────────────────────────────────────────────────
              if (_final != null)
                CalcCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CalcLabel('Results'),
                      const SizedBox(height: 14),
                      Row(children: [
                        CalcKpi(label: 'Final value',    value: _usd.format(_final),
                            valueColor: AppColors.emerald, sub: atAge),
                        CalcKpi(label: 'Total invested', value: _usd.format(_invested)),
                        CalcKpi(label: 'Total interest', value: _usd.format(_interest),
                            valueColor: const Color(0xFFF59E0B)),
                      ]),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_invested! / _final!).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: AppColors.emerald.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.emerald.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(_invested! / _final! * 100).toStringAsFixed(1)}% invested',
                            style: TextStyle(fontSize: 11, color: c.textMuted),
                          ),
                          Text(
                            '${(_interest! / _final! * 100).toStringAsFixed(1)}% interest',
                            style: const TextStyle(
                              fontSize: 11, color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      if (_points.length > 2) ...[
                        const SizedBox(height: 20),
                        const CalcLabel('Growth over time'),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 150,
                          child: _GrowthChart(points: _points),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              _Legend(color: AppColors.emerald, label: 'Total balance'),
                              const SizedBox(width: 16),
                              _Legend(color: Colors.grey, label: 'Invested', dashed: true),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chart ─────────────────────────────────────────────────────────────────────

class _GrowthChart extends StatelessWidget {
  final List<({double balance, double invested, int year})> points;
  const _GrowthChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final balSpots = points
        .map((p) => FlSpot(p.year.toDouble(), p.balance))
        .toList();
    final invSpots = points
        .map((p) => FlSpot(p.year.toDouble(), p.invested))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: balSpots,
            isCurved: true,
            color: AppColors.emerald,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.emerald.withValues(alpha: 0.1),
            ),
          ),
          LineChartBarData(
            spots: invSpots,
            isCurved: false,
            color: Colors.grey.withValues(alpha: 0.5),
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            dashArray: [4, 4],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _Legend({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20, height: 2,
            color: dashed ? null : color,
            child: dashed
                ? Row(children: List.generate(
                    4, (_) => Expanded(child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(right: 2),
                      color: color,
                    )),
                  ))
                : null,
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
        ],
      );
}
