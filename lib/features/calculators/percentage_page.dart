import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'calc_widgets.dart';
import '../../core/widgets/app_bottom_nav.dart';

const _violet = Color(0xFF8B5CF6);

class PercentagePage extends StatefulWidget {
  const PercentagePage({super.key});

  @override
  State<PercentagePage> createState() => _PercentagePageState();
}

class _PercentagePageState extends State<PercentagePage> {
  int _tab = 0;

  // Tab 0: "What is X% of Y?"
  final _t0x = TextEditingController(text: '15');
  final _t0y = TextEditingController(text: '200');

  // Tab 1: "X is what % of Y?"
  final _t1x = TextEditingController(text: '30');
  final _t1y = TextEditingController(text: '200');

  // Tab 2: "% change from X to Y"
  final _t2x = TextEditingController(text: '100');
  final _t2y = TextEditingController(text: '125');

  // Tab 3: "X% off Y (discount)"
  final _t3x = TextEditingController(text: '20');
  final _t3y = TextEditingController(text: '79.99');

  @override
  void dispose() {
    _t0x.dispose(); _t0y.dispose();
    _t1x.dispose(); _t1y.dispose();
    _t2x.dispose(); _t2y.dispose();
    _t3x.dispose(); _t3y.dispose();
    super.dispose();
  }

  static const _tabs = [
    'X% of Y',
    'What %?',
    '% Change',
    'Discount',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(title: const Text('Percentage')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Tab selector ──────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: _tabs.asMap().entries.map((e) {
                    final active = e.key == _tab;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: active ? _violet.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            e.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active ? _violet : c.textMuted,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              // ── Mode content ──────────────────────────────────────────────
              if (_tab == 0) _Tab0(xCtrl: _t0x, yCtrl: _t0y),
              if (_tab == 1) _Tab1(xCtrl: _t1x, yCtrl: _t1y),
              if (_tab == 2) _Tab2(xCtrl: _t2x, yCtrl: _t2y),
              if (_tab == 3) _Tab3(xCtrl: _t3x, yCtrl: _t3y),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab 0: X% of Y ────────────────────────────────────────────────────────────

class _Tab0 extends StatefulWidget {
  final TextEditingController xCtrl, yCtrl;
  const _Tab0({required this.xCtrl, required this.yCtrl});

  @override
  State<_Tab0> createState() => _Tab0State();
}

class _Tab0State extends State<_Tab0> {
  double? _result;

  void _calc() {
    final x = double.tryParse(widget.xCtrl.text);
    final y = double.tryParse(widget.yCtrl.text);
    setState(() => _result = (x != null && y != null) ? y * x / 100 : null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What is X% of Y?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: CalcField(
                  controller: widget.xCtrl, label: 'X (%)',
                  suffix: '%', focusColor: _violet, onChanged: (_) => _calc(),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('of', style: TextStyle(color: c.textMuted,
                      fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Expanded(child: CalcField(
                  controller: widget.yCtrl, label: 'Y (value)',
                  focusColor: _violet, onChanged: (_) => _calc(),
                )),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_result != null)
          _ResultBanner(
            formula: '${widget.xCtrl.text}% of ${widget.yCtrl.text}',
            result: _result!.toStringAsFixed(2),
            suffix: '',
          ),
      ],
    );
  }
}

// ── Tab 1: X is what % of Y ───────────────────────────────────────────────────

class _Tab1 extends StatefulWidget {
  final TextEditingController xCtrl, yCtrl;
  const _Tab1({required this.xCtrl, required this.yCtrl});

  @override
  State<_Tab1> createState() => _Tab1State();
}

class _Tab1State extends State<_Tab1> {
  double? _result;

  void _calc() {
    final x = double.tryParse(widget.xCtrl.text);
    final y = double.tryParse(widget.yCtrl.text);
    setState(() => _result = (x != null && y != null && y != 0) ? x / y * 100 : null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('X is what % of Y?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: CalcField(
                  controller: widget.xCtrl, label: 'X (value)',
                  focusColor: _violet, onChanged: (_) => _calc(),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('of', style: TextStyle(color: c.textMuted,
                      fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Expanded(child: CalcField(
                  controller: widget.yCtrl, label: 'Y (total)',
                  focusColor: _violet, onChanged: (_) => _calc(),
                )),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_result != null)
          _ResultBanner(
            formula: '${widget.xCtrl.text} / ${widget.yCtrl.text} × 100',
            result: _result!.toStringAsFixed(4),
            suffix: '%',
          ),
      ],
    );
  }
}

// ── Tab 2: % Change ───────────────────────────────────────────────────────────

class _Tab2 extends StatefulWidget {
  final TextEditingController xCtrl, yCtrl;
  const _Tab2({required this.xCtrl, required this.yCtrl});

  @override
  State<_Tab2> createState() => _Tab2State();
}

class _Tab2State extends State<_Tab2> {
  double? _result;

  void _calc() {
    final x = double.tryParse(widget.xCtrl.text);
    final y = double.tryParse(widget.yCtrl.text);
    setState(() => _result =
        (x != null && y != null && x != 0) ? (y - x) / x.abs() * 100 : null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPos = (_result ?? 0) >= 0;
    final color = isPos ? AppColors.emerald : AppColors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('% change from X to Y',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: CalcField(
                  controller: widget.xCtrl, label: 'From (X)',
                  focusColor: _violet, onChanged: (_) => _calc(),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, color: c.textMuted, size: 18),
                ),
                Expanded(child: CalcField(
                  controller: widget.yCtrl, label: 'To (Y)',
                  focusColor: _violet, onChanged: (_) => _calc(),
                )),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_result != null)
          _ResultBanner(
            formula: '(${widget.yCtrl.text} - ${widget.xCtrl.text}) / |${widget.xCtrl.text}| × 100',
            result: '${isPos ? '+' : ''}${_result!.toStringAsFixed(4)}',
            suffix: '%',
            color: color,
          ),
      ],
    );
  }
}

// ── Tab 3: Discount ───────────────────────────────────────────────────────────

class _Tab3 extends StatefulWidget {
  final TextEditingController xCtrl, yCtrl;
  const _Tab3({required this.xCtrl, required this.yCtrl});

  @override
  State<_Tab3> createState() => _Tab3State();
}

class _Tab3State extends State<_Tab3> {
  double? _savings;
  double? _finalPrice;

  void _calc() {
    final pct   = double.tryParse(widget.xCtrl.text);
    final price = double.tryParse(widget.yCtrl.text);
    if (pct != null && price != null) {
      final savings = price * pct / 100;
      setState(() {
        _savings    = savings;
        _finalPrice = price - savings;
      });
    } else {
      setState(() { _savings = null; _finalPrice = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('X% off Y (discount)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: CalcField(
                  controller: widget.xCtrl, label: 'Discount (%)',
                  suffix: '%', focusColor: _violet, onChanged: (_) => _calc(),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('off', style: TextStyle(color: c.textMuted,
                      fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Expanded(child: CalcField(
                  controller: widget.yCtrl, label: 'Original price',
                  focusColor: _violet, onChanged: (_) => _calc(),
                )),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_finalPrice != null)
          CalcCard(
            child: Column(
              children: [
                Row(children: [
                  CalcKpi(
                    label: 'Final price',
                    value: '\$${_finalPrice!.toStringAsFixed(2)}',
                    valueColor: AppColors.emerald,
                  ),
                  CalcKpi(
                    label: 'You save',
                    value: '\$${_savings!.toStringAsFixed(2)}',
                    valueColor: AppColors.orange,
                  ),
                  CalcKpi(
                    label: 'Discount',
                    value: '${widget.xCtrl.text}%',
                    valueColor: _violet,
                  ),
                ]),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Shared result banner ──────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final String formula, result, suffix;
  final Color? color;
  const _ResultBanner({
    required this.formula,
    required this.result,
    required this.suffix,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final displayColor = color ?? _violet;
    return CalcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formula,
            style: TextStyle(fontSize: 11, color: c.textMuted,
                fontFamily: 'monospace'),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('= ', style: TextStyle(fontSize: 20, color: c.textMuted)),
              Text(
                '$result$suffix',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: displayColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
