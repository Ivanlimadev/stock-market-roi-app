import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import 'calc_widgets.dart';
import '../../core/widgets/app_bottom_nav.dart';

final _usd  = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
final _usd2 = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
const _amber = Color(0xFFF59E0B);
const _goal  = 1000000.0;

class FirstMillionPage extends StatefulWidget {
  const FirstMillionPage({super.key});

  @override
  State<FirstMillionPage> createState() => _FirstMillionPageState();
}

class _FirstMillionPageState extends State<FirstMillionPage> {
  // Mode: 'when' = when do I reach $1M | 'how' = how much to invest/mo
  String _mode = 'when';

  final _ageCtrl       = TextEditingController(text: '30');
  final _principalCtrl = TextEditingController(text: '10000');
  final _pmtCtrl       = TextEditingController(text: '500');
  final _rateCtrl      = TextEditingController(text: '10');
  final _targetAgeCtrl = TextEditingController(text: '55');
  String _rateMode = 'annual';

  // 'when' mode result
  int?    _yearsToGoal;
  int?    _targetAge;
  double? _finalBalance; // may exceed 1M slightly
  bool    _unreachable = false;

  // 'how' mode result
  double? _requiredPmt;

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
    _ageCtrl.dispose();
    _principalCtrl.dispose();
    _pmtCtrl.dispose();
    _rateCtrl.dispose();
    _targetAgeCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final currentAge = int.tryParse(_ageCtrl.text) ?? 0;
    final principal  = double.tryParse(_principalCtrl.text) ?? 0;
    final rateInput  = double.tryParse(_rateCtrl.text) ?? 0;

    if (rateInput <= 0 || rateInput > 100) {
      setState(() { _yearsToGoal = null; _requiredPmt = null; });
      return;
    }

    final r = _rateMode == 'annual'
        ? math.pow(1 + rateInput / 100, 1 / 12.0) - 1
        : rateInput / 100;

    if (_mode == 'when') {
      final pmt = double.tryParse(_pmtCtrl.text) ?? 0;
      double balance = principal;
      int months = 0;

      while (balance < _goal && months < 600) {
        balance = balance * (1 + r) + pmt;
        months++;
      }

      setState(() {
        if (balance >= _goal) {
          _yearsToGoal  = (months / 12).ceil();
          _targetAge    = currentAge > 0 ? currentAge + _yearsToGoal! : null;
          _finalBalance = balance;
          _unreachable  = false;
        } else {
          _unreachable  = true;
          _yearsToGoal  = null;
          _targetAge    = null;
          _finalBalance = balance;
        }
        _requiredPmt = null;
      });
    } else {
      final targetAge = int.tryParse(_targetAgeCtrl.text) ?? 0;
      final years     = (currentAge > 0 && targetAge > currentAge)
          ? targetAge - currentAge : 0;

      if (years <= 0) {
        setState(() { _requiredPmt = null; _yearsToGoal = null; });
        return;
      }

      final n = years * 12;
      final growth = math.pow(1 + r, n);
      final pmt    = (_goal - principal * growth) * r / (growth - 1);

      setState(() {
        _requiredPmt  = pmt < 0 ? 0 : pmt;
        _yearsToGoal  = null;
        _unreachable  = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('First Million')),
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
                      label: 'When do I reach \$1M?',
                      active: _mode == 'when',
                      onTap: () { setState(() => _mode = 'when'); _calculate(); },
                      c: c,
                    ),
                    _ModeTab(
                      label: 'How much to invest?',
                      active: _mode == 'how',
                      onTap: () { setState(() => _mode = 'how'); _calculate(); },
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
                    const CalcLabel('Rate presets'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _presets.map((p) {
                        final active = _rateCtrl.text == p.rate && _rateMode == p.mode;
                        return CalcChip(
                          label: p.label, active: active, color: _amber,
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
                        controller: _ageCtrl, label: 'Current age',
                        focusColor: _amber, onChanged: (_) => _calculate(),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: CalcField(
                        controller: _principalCtrl, label: 'Starting balance',
                        prefix: '\$', focusColor: _amber,
                        onChanged: (_) => _calculate(),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    if (_mode == 'when')
                      CalcField(
                        controller: _pmtCtrl, label: 'Monthly contribution',
                        prefix: '\$', focusColor: _amber,
                        onChanged: (_) => _calculate(),
                      )
                    else
                      CalcField(
                        controller: _targetAgeCtrl, label: 'Target age',
                        focusColor: _amber, onChanged: (_) => _calculate(),
                      ),
                    const SizedBox(height: 14),
                    const CalcLabel('Annual return'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: CalcField(
                        controller: _rateCtrl, label: 'Rate',
                        suffix: '%', focusColor: _amber,
                        onChanged: (_) => _calculate(),
                      )),
                      const SizedBox(width: 12),
                      CalcToggle(
                        options: const ['Annual', 'Monthly'],
                        selected: _rateMode == 'annual' ? 0 : 1,
                        color: _amber,
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
              // ── Results: when mode ─────────────────────────────────────────
              if (_mode == 'when' && _yearsToGoal != null)
                _WhenResult(
                  years: _yearsToGoal!,
                  targetAge: _targetAge,
                  balance: _finalBalance!,
                  c: c,
                ),
              if (_mode == 'when' && _unreachable)
                _UnreachableCard(balance: _finalBalance, c: c),
              // ── Results: how mode ──────────────────────────────────────────
              if (_mode == 'how' && _requiredPmt != null)
                _HowResult(
                  pmt: _requiredPmt!,
                  targetAge: int.tryParse(_targetAgeCtrl.text) ?? 0,
                  c: c,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Result widgets ────────────────────────────────────────────────────────────

class _WhenResult extends StatelessWidget {
  final int years;
  final int? targetAge;
  final double balance;
  final AppThemeColors c;
  const _WhenResult({
    required this.years, required this.targetAge,
    required this.balance, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return CalcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CalcLabel('Result'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$years', style: const TextStyle(
                fontSize: 52, fontWeight: FontWeight.w800, color: _amber,
                height: 1.0,
              )),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(years == 1 ? 'year' : 'years',
                    style: TextStyle(fontSize: 18, color: c.textMuted,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            targetAge != null
                ? 'You\'ll reach \$1,000,000 at age $targetAge'
                : 'You\'ll reach \$1,000,000 in $years years',
            style: TextStyle(fontSize: 15, color: c.textPrimary,
                fontWeight: FontWeight.w600),
          ),
          if (targetAge != null) ...[
            const SizedBox(height: 14),
            _ProgressToMillion(balance: balance),
          ],
        ],
      ),
    );
  }
}

class _HowResult extends StatelessWidget {
  final double pmt;
  final int targetAge;
  final AppThemeColors c;
  const _HowResult({required this.pmt, required this.targetAge, required this.c});

  @override
  Widget build(BuildContext context) {
    return CalcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CalcLabel('Required monthly investment'),
          const SizedBox(height: 14),
          Text(
            _usd2.format(pmt),
            style: const TextStyle(
              fontSize: 40, fontWeight: FontWeight.w800, color: _amber, height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pmt <= 0
                ? 'Your current balance already exceeds \$1M or will without contributions.'
                : 'Invest this amount monthly to reach \$1M by age $targetAge.',
            style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _UnreachableCard extends StatelessWidget {
  final double? balance;
  final AppThemeColors c;
  const _UnreachableCard({required this.balance, required this.c});

  @override
  Widget build(BuildContext context) {
    return CalcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'With these inputs, \$1M is not reachable within 50 years.',
              style: TextStyle(fontSize: 13, color: c.textMuted),
            )),
          ]),
          if (balance != null) ...[
            const SizedBox(height: 10),
            Text(
              'Balance after 50 years: ${_usd.format(balance)}',
              style: TextStyle(fontSize: 13, color: c.textSecond),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Try increasing your monthly contribution or expected return rate.',
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ProgressToMillion extends StatelessWidget {
  final double balance;
  const _ProgressToMillion({required this.balance});

  @override
  Widget build(BuildContext context) {
    final pct = (balance / _goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CalcLabel('Progress to \$1,000,000'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 8,
            backgroundColor: _amber.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation(_amber),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(pct * 100).toStringAsFixed(1)}% of goal reached',
          style: TextStyle(fontSize: 11, color: context.colors.textMuted),
        ),
      ],
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
              color: active ? _amber.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? _amber : c.textMuted,
              ),
            ),
          ),
        ),
      );
}
