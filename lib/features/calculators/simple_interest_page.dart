import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import 'calc_widgets.dart';
import '../../core/widgets/app_bottom_nav.dart';

final _usd = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
const _blue = Color(0xFF3B82F6);

class SimpleInterestPage extends StatefulWidget {
  const SimpleInterestPage({super.key});

  @override
  State<SimpleInterestPage> createState() => _SimpleInterestPageState();
}

class _SimpleInterestPageState extends State<SimpleInterestPage> {
  final _principalCtrl = TextEditingController(text: '10000');
  final _rateCtrl      = TextEditingController(text: '5');
  final _yearsCtrl     = TextEditingController(text: '10');
  String _rateMode = 'annual';

  double? _interest;
  double? _total;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final principal = double.tryParse(_principalCtrl.text) ?? 0;
    final rateInput = double.tryParse(_rateCtrl.text) ?? 0;
    final years     = double.tryParse(_yearsCtrl.text) ?? 0;

    if (principal <= 0 || rateInput < 0 || years <= 0) {
      setState(() => _interest = null);
      return;
    }

    final rateMonthly = _rateMode == 'annual' ? rateInput / 12 : rateInput;
    final months      = years * 12;
    final interest    = principal * (rateMonthly / 100) * months;

    setState(() {
      _interest = interest;
      _total    = principal + interest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final principal = double.tryParse(_principalCtrl.text) ?? 0;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('Simple Interest')),
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
                    CalcField(
                      controller: _principalCtrl,
                      label: 'Principal',
                      prefix: '\$',
                      focusColor: _blue,
                      onChanged: (_) => _calculate(),
                    ),
                    const SizedBox(height: 12),
                    const CalcLabel('Interest rate'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: CalcField(
                        controller: _rateCtrl, label: 'Rate',
                        suffix: '%', focusColor: _blue,
                        onChanged: (_) => _calculate(),
                      )),
                      const SizedBox(width: 12),
                      CalcToggle(
                        options: const ['Annual', 'Monthly'],
                        selected: _rateMode == 'annual' ? 0 : 1,
                        color: _blue,
                        onChanged: (i) {
                          setState(() => _rateMode = i == 0 ? 'annual' : 'monthly');
                          _calculate();
                        },
                      ),
                    ]),
                    const SizedBox(height: 12),
                    CalcField(
                      controller: _yearsCtrl, label: 'Duration',
                      suffix: 'years', focusColor: _blue,
                      onChanged: (_) => _calculate(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Results ───────────────────────────────────────────────────
              if (_interest != null)
                CalcCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CalcLabel('Results'),
                      const SizedBox(height: 14),
                      Row(children: [
                        CalcKpi(
                          label: 'Final amount',
                          value: _usd.format(_total),
                          valueColor: _blue,
                        ),
                        CalcKpi(label: 'Principal',     value: _usd.format(principal)),
                        CalcKpi(label: 'Total interest', value: _usd.format(_interest),
                            valueColor: AppColors.emerald),
                      ]),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (principal / _total!).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: _blue.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            _blue.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(principal / _total! * 100).toStringAsFixed(1)}% principal',
                            style: TextStyle(fontSize: 11,
                                color: context.colors.textMuted),
                          ),
                          Text(
                            '${(_interest! / _total! * 100).toStringAsFixed(1)}% interest',
                            style: const TextStyle(
                              fontSize: 11, color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(
                        label: 'Formula',
                        value: 'Interest = P × r × t',
                        c: context.colors,
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                        label: 'Note',
                        value: 'No compounding — interest is earned on principal only.',
                        c: context.colors,
                      ),
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

class _InfoRow extends StatelessWidget {
  final String label, value;
  final AppThemeColors c;
  const _InfoRow({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: c.textMuted)),
          Expanded(child: Text(value,
              style: TextStyle(fontSize: 11, color: c.textMuted))),
        ],
      );
}
