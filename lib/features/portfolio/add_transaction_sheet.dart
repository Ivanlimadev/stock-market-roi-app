import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/portfolio_provider.dart';

Future<void> showAddTransactionSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AddTransactionSheet(),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet();

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _symbolCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _feesCtrl = TextEditingController();

  String _assetType = 'stock';
  String _operation = 'buy';
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _feesCtrl.dispose();
    super.dispose();
  }

  double get _total {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final fees = double.tryParse(_feesCtrl.text) ?? 0;
    final subtotal = qty * price;
    return _operation == 'buy' ? subtotal + fees : subtotal - fees;
  }

  Color get _opColor => _operation == 'buy' ? AppColors.emerald : AppColors.red;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.emerald,
            onSurface: context.colors.textPrimary,
            surface: context.colors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await Supabase.instance.client.from('portfolio_transactions').insert({
        'user_id': user.id,
        'symbol': _symbolCtrl.text.trim().toUpperCase(),
        'asset_type': _assetType,
        'type': _operation,
        'quantity': double.parse(_qtyCtrl.text),
        'price_per_share': double.parse(_priceCtrl.text),
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'fees': double.tryParse(_feesCtrl.text) ?? 0,
      });

      ref.invalidate(portfolioHoldingsProvider);
      ref.invalidate(portfolioEnrichedProvider);
      ref.invalidate(portfolioTransactionsProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text('New Transaction',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary)),
          SizedBox(height: 24),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Asset type'),
                SizedBox(height: 8),
                _ChipRow(
                  options: const [
                    ('stock', 'Stock'),
                    ('reit', 'REIT'),
                    ('etf', 'ETF'),
                    ('crypto', 'Crypto'),
                  ],
                  selected: _assetType,
                  onSelect: (v) => setState(() => _assetType = v),
                  color: AppColors.emerald,
                ),
                SizedBox(height: 16),

                _sectionLabel('Operation'),
                SizedBox(height: 8),
                _ChipRow(
                  options: const [('buy', 'Buy'), ('sell', 'Sell')],
                  selected: _operation,
                  onSelect: (v) => setState(() => _operation = v),
                  color: _opColor,
                ),
                SizedBox(height: 16),

                // Symbol + Quantity
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _inputField(
                        controller: _symbolCtrl,
                        label: _assetType == 'crypto' ? 'Ticker' : 'Symbol',
                        hint: _assetType == 'crypto' ? 'BTC' : 'AAPL',
                        formatters: [_UpperCase()],
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _inputField(
                        controller: _qtyCtrl,
                        label: 'Quantity',
                        hint: '10',
                        keyboard: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if ((double.tryParse(v) ?? 0) <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Price + Date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _inputField(
                        controller: _priceCtrl,
                        label: 'Price (USD)',
                        hint: '150.00',
                        keyboard: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if ((double.tryParse(v) ?? 0) <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            labelStyle: TextStyle(
                                color: context.colors.textMuted, fontSize: 13),
                            filled: true,
                            fillColor: context.colors.background,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: context.colors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: context.colors.border),
                            ),
                          ),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(_date),
                            style: TextStyle(
                                fontSize: 14, color: context.colors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Fees optional
                _inputField(
                  controller: _feesCtrl,
                  label: 'Taxas / Corretagem (opcional)',
                  hint: '0.00',
                  keyboard:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 16),

                // Total row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total estimado',
                          style: TextStyle(
                              fontSize: 13, color: context.colors.textMuted)),
                      Text(
                        '\$${_total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _opColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _opColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _operation == 'buy'
                                ? 'Record Buy'
                                : 'Record Sell',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.colors.textMuted,
          letterSpacing: 0.6));

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: formatters,
        validator: validator,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 13),
          labelStyle:
              TextStyle(color: context.colors.textMuted, fontSize: 13),
          filled: true,
          fillColor: context.colors.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.emerald),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.red),
          ),
        ),
      );
}

// ── Chip row ──────────────────────────────────────────────────────────────────

class _ChipRow extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final void Function(String) onSelect;
  final Color color;

  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final (value, label) = opt;
        final isSelected = selected == value;
        return GestureDetector(
          onTap: () => onSelect(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : context.colors.background,
              border: Border.all(
                color: isSelected ? color : context.colors.border,
                width: isSelected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : context.colors.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Formatter ─────────────────────────────────────────────────────────────────

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue old, TextEditingValue next) =>
      next.copyWith(text: next.text.toUpperCase());
}
