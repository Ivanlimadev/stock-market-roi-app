import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'calc_widgets.dart';
import '../../core/widgets/app_bottom_nav.dart';

const _orange = Color(0xFFF97316);

class ROIPage extends StatefulWidget {
  const ROIPage({super.key});

  @override
  State<ROIPage> createState() => _ROIPageState();
}

class _ROIPageState extends State<ROIPage> {
  // Mode: 'value' (any investment) | 'stock' (stock trade)
  String _mode = 'value';

  // Value mode
  final _startCtrl = TextEditingController(text: '10000');
  final _endCtrl   = TextEditingController(text: '15000');

  // Stock mode
  final _buyCtrl    = TextEditingController(text: '150');
  final _sellCtrl   = TextEditingController(text: '200');
  final _sharesCtrl = TextEditingController(text: '100');
  final _divCtrl    = TextEditingController(text: '0');

  // Duration (shared)
  final _yrsCtrl = TextEditingController(text: '3');
  final _mosCtrl = TextEditingController(text: '0');

  // Results
  double? _roi;
  double? _cagr;
  double? _gain;
  double? _spReturn;
  double? _breakEven;

  static const _periodPresets = [
    (label: '6mo', yrs: '0', mos: '6'),
    (label: '1y',  yrs: '1', mos: '0'),
    (label: '3y',  yrs: '3', mos: '0'),
    (label: '5y',  yrs: '5', mos: '0'),
    (label: '10y', yrs: '10', mos: '0'),
  ];

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _startCtrl.dispose(); _endCtrl.dispose();
    _buyCtrl.dispose(); _sellCtrl.dispose();
    _sharesCtrl.dispose(); _divCtrl.dispose();
    _yrsCtrl.dispose(); _mosCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final years  = (double.tryParse(_yrsCtrl.text) ?? 0) +
                   (double.tryParse(_mosCtrl.text) ?? 0) / 12.0;
    double pv, ev;

    if (_mode == 'value') {
      pv = double.tryParse(_startCtrl.text) ?? 0;
      ev = double.tryParse(_endCtrl.text) ?? 0;
    } else {
      final buy    = double.tryParse(_buyCtrl.text) ?? 0;
      final sell   = double.tryParse(_sellCtrl.text) ?? 0;
      final shares = double.tryParse(_sharesCtrl.text) ?? 0;
      final div    = double.tryParse(_divCtrl.text) ?? 0;
      pv = buy * shares;
      ev = sell * shares + div;
    }

    if (pv <= 0 || ev < 0 || years < 0) {
      setState(() => _roi = null);
      return;
    }

    final gain      = ev - pv;
    final roi       = (gain / pv) * 100;
    final cagrRaw   = years > 0 && ev > 0 && pv > 0
        ? (math.pow(ev / pv, 1 / years).toDouble() - 1) * 100
        : null;
    final spReturn  = years > 0
        ? (math.pow(1.10, years).toDouble() - 1) * 100
        : null;
    final breakEven = roi < 0 ? (pv / ev - 1) * 100 : null;

    setState(() {
      _gain      = gain;
      _roi       = roi;
      _cagr      = cagrRaw;
      _spReturn  = spReturn;
      _breakEven = breakEven;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final isPos   = (_roi ?? 0) >= 0;
    final roiColor = isPos ? AppColors.emerald : AppColors.red;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('ROI Calculator')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Mode toggle ───────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _ModeTab(
                      label: 'Investment value',
                      active: _mode == 'value',
                      onTap: () { setState(() => _mode = 'value'); _calculate(); },
                      c: c,
                    ),
                    _ModeTab(
                      label: 'Stock trade',
                      active: _mode == 'stock',
                      onTap: () { setState(() => _mode = 'stock'); _calculate(); },
                      c: c,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Inputs ────────────────────────────────────────────────────
              CalcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_mode == 'value') ...[
                      Row(children: [
                        Expanded(child: CalcField(
                          controller: _startCtrl, label: 'Starting value',
                          prefix: '\$', focusColor: _orange,
                          onChanged: (_) => _calculate(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: CalcField(
                          controller: _endCtrl, label: 'Ending value',
                          prefix: '\$', focusColor: _orange,
                          onChanged: (_) => _calculate(),
                        )),
                      ]),
                    ] else ...[
                      Row(children: [
                        Expanded(child: CalcField(
                          controller: _buyCtrl, label: 'Buy price',
                          prefix: '\$', focusColor: _orange,
                          onChanged: (_) => _calculate(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: CalcField(
                          controller: _sellCtrl, label: 'Sell price',
                          prefix: '\$', focusColor: _orange,
                          onChanged: (_) => _calculate(),
                        )),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: CalcField(
                          controller: _sharesCtrl, label: 'Shares',
                          focusColor: _orange,
                          onChanged: (_) => _calculate(),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: CalcField(
                          controller: _divCtrl, label: 'Dividends',
                          prefix: '\$', focusColor: _orange,
                          onChanged: (_) => _calculate(),
                        )),
                      ]),
                    ],
                    const SizedBox(height: 14),
                    const CalcLabel('Holding period'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _periodPresets.map((p) {
                        final active = _yrsCtrl.text == p.yrs && _mosCtrl.text == p.mos;
                        return CalcChip(
                          label: p.label, active: active, color: _orange,
                          onTap: () => setState(() {
                            _yrsCtrl.text = p.yrs;
                            _mosCtrl.text = p.mos;
                            _calculate();
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: CalcField(
                        controller: _yrsCtrl, label: 'Years',
                        focusColor: _orange, onChanged: (_) => _calculate(),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: CalcField(
                        controller: _mosCtrl, label: 'Months',
                        focusColor: _orange, onChanged: (_) => _calculate(),
                      )),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Results ───────────────────────────────────────────────────
              if (_roi != null) ...[
                // Hero ROI card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPos
                        ? AppColors.emerald.withValues(alpha: 0.06)
                        : AppColors.red.withValues(alpha: 0.06),
                    border: Border.all(
                      color: isPos
                          ? AppColors.emerald.withValues(alpha: 0.25)
                          : AppColors.red.withValues(alpha: 0.25),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPos ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 16,
                            color: roiColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPos ? 'Profitable investment' : 'Loss',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700, color: roiColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        CalcKpi(
                          label: 'Total ROI',
                          value: '${isPos ? '+' : ''}${_roi!.toStringAsFixed(2)}%',
                          valueColor: roiColor,
                        ),
                        CalcKpi(
                          label: 'Total gain/loss',
                          value: '${isPos ? '+' : ''}\$${_gain!.abs().toStringAsFixed(2)}',
                          valueColor: roiColor,
                        ),
                        if (_cagr != null)
                          CalcKpi(
                            label: 'CAGR (annual)',
                            value: '${_cagr! >= 0 ? '+' : ''}${_cagr!.toStringAsFixed(2)}%',
                            valueColor: _cagr! >= 0 ? AppColors.emerald : AppColors.red,
                          ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // S&P 500 comparison
                if (_spReturn != null)
                  CalcCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CalcLabel('vs S&P 500 benchmark'),
                        const SizedBox(height: 14),
                        _BenchmarkBar(
                          label: 'Your investment',
                          pct: _roi!,
                          color: roiColor,
                          maxVal: math.max(_roi!.abs(), _spReturn!.abs()),
                        ),
                        const SizedBox(height: 8),
                        _BenchmarkBar(
                          label: 'S&P 500 (10%/yr)',
                          pct: _spReturn!,
                          color: c.textMuted,
                          maxVal: math.max(_roi!.abs(), _spReturn!.abs()),
                        ),
                        const SizedBox(height: 12),
                        _BenchmarkSummary(
                          roi: _roi!, spReturn: _spReturn!,
                          roiColor: roiColor, c: c,
                        ),
                        // Break-even
                        if (_breakEven != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.08),
                              border: Border.all(
                                  color: AppColors.orange.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 16, color: AppColors.orange),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                'Needs +${_breakEven!.toStringAsFixed(2)}% to break even',
                                style: TextStyle(fontSize: 12,
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w600),
                              )),
                            ]),
                          ),
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

// ── Benchmark bar ─────────────────────────────────────────────────────────────

class _BenchmarkBar extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;
  final double maxVal;
  const _BenchmarkBar({
    required this.label, required this.pct,
    required this.color, required this.maxVal,
  });

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final frac = maxVal > 0 ? (pct.abs() / maxVal).clamp(0.02, 1.0) : 0.02;

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(fontSize: 11, color: c.textMuted),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: pct < 0 ? 0.4 : 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BenchmarkSummary extends StatelessWidget {
  final double roi, spReturn;
  final Color roiColor;
  final AppThemeColors c;
  const _BenchmarkSummary({
    required this.roi, required this.spReturn,
    required this.roiColor, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final diff = roi - spReturn;
    if (diff >= 0) {
      return Text(
        'You outperformed S&P 500 by ${diff.toStringAsFixed(2)}%',
        style: TextStyle(fontSize: 12, color: AppColors.emerald,
            fontWeight: FontWeight.w600),
      );
    }
    return Text(
      'S&P 500 outperformed you by ${diff.abs().toStringAsFixed(2)}%',
      style: TextStyle(fontSize: 12, color: c.textMuted),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppThemeColors c;
  const _ModeTab({
    required this.label, required this.active,
    required this.onTap, required this.c,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: active ? _orange.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? _orange : c.textMuted,
              ),
            ),
          ),
        ),
      );
}
