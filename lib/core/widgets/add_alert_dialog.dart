import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../providers/watchlist_provider.dart';
import '../utils/formatters.dart';

/// Shows a dialog to set a price alert for a stock or crypto asset.
/// [currentPrice] is the live price to show as reference.
/// [assetType] is 'stock' or 'crypto'.
Future<void> showAddAlertDialog(
  BuildContext context, {
  required String symbol,
  required String name,
  required double currentPrice,
  required String assetType,
  String? coingeckoId,
  String? image,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _AddAlertDialog(
      symbol:       symbol,
      name:         name,
      currentPrice: currentPrice,
      assetType:    assetType,
      coingeckoId:  coingeckoId,
      image:        image,
    ),
  );
}

class _AddAlertDialog extends StatefulWidget {
  final String symbol, name, assetType;
  final double currentPrice;
  final String? coingeckoId, image;

  const _AddAlertDialog({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.assetType,
    this.coingeckoId,
    this.image,
  });

  @override
  State<_AddAlertDialog> createState() => _AddAlertDialogState();
}

class _AddAlertDialogState extends State<_AddAlertDialog> {
  String _condition = 'above';
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = double.tryParse(_ctrl.text.replaceAll(',', ''));
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await WatchlistService.addAlert(
        symbol:         widget.symbol,
        name:           widget.name,
        assetType:      widget.assetType,
        condition:      _condition,
        targetPrice:    price,
        referencePrice: widget.currentPrice,
        coingeckoId:    widget.coingeckoId,
        image:          widget.image,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Failed to set alert'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fmt = widget.assetType == 'crypto'
        ? fmtCryptoPrice(widget.currentPrice)
        : fmtStockPrice(widget.currentPrice);

    return AlertDialog(
      backgroundColor: c.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Price Alert — ${widget.symbol}',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current price: $fmt',
            style: TextStyle(fontSize: 13, color: c.textMuted),
          ),
          const SizedBox(height: 16),
          Text('Alert when price is', style: TextStyle(fontSize: 13, color: c.textSecond)),
          const SizedBox(height: 10),
          Row(
            children: [
              _ConditionBtn(
                label: 'Above',
                icon: Icons.arrow_upward_rounded,
                active: _condition == 'above',
                color: AppColors.emerald,
                onTap: () => setState(() => _condition = 'above'),
                c: c,
              ),
              const SizedBox(width: 10),
              _ConditionBtn(
                label: 'Below',
                icon: Icons.arrow_downward_rounded,
                active: _condition == 'below',
                color: AppColors.red,
                onTap: () => setState(() => _condition = 'below'),
                c: c,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Target price',
              prefixText: '\$ ',
              labelStyle: TextStyle(color: c.textMuted, fontSize: 13),
              prefixStyle: TextStyle(color: c.textMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.emerald),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: c.textMuted)),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Set Alert'),
        ),
      ],
    );
  }
}

class _ConditionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final AppThemeColors c;

  const _ConditionBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.12) : c.surface,
              border: Border.all(
                  color: active ? color.withValues(alpha: 0.4) : c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: active ? color : c.textMuted),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? color : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
