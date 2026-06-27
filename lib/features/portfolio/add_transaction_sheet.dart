import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/models/market_model.dart';
import '../../core/providers/portfolio_provider.dart' hide StockQuote;
import '../../core/providers/realtime_price_provider.dart';
import '../../core/providers/screener_provider.dart';

Future<void> showAddTransactionSheet(BuildContext context, {String? initialSymbol}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddTransactionSheet(initialSymbol: initialSymbol),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _AddTransactionSheet extends ConsumerStatefulWidget {
  final String? initialSymbol;
  const _AddTransactionSheet({this.initialSymbol});

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _symbolCtrl =
      TextEditingController(text: widget.initialSymbol?.toUpperCase() ?? '');
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _feesCtrl = TextEditingController();

  String _assetType = 'stock';
  String _operation = 'buy';
  DateTime _date = DateTime.now();
  bool _loading = false;

  // Live-quote auto-fill for the price field.
  bool _priceLoading = false;
  String? _autoFilledPrice; // last value we auto-filled (to detect manual edits)
  Timer? _priceDebounce;

  // Symbol autocomplete: the symbol the user explicitly picked (or that exactly
  // matched the known universe) + its resolved name. While [_selectedSymbol] is
  // null with a non-empty query we show ranked suggestions instead.
  String? _selectedSymbol;
  String? _resolvedName;

  @override
  void initState() {
    super.initState();
    final sym = widget.initialSymbol?.trim();
    if (sym != null && sym.isNotEmpty) {
      _selectedSymbol = sym.toUpperCase(); // opened from an asset → pre-confirmed
      _prefillPrice(sym.toUpperCase());
    }
  }

  @override
  void dispose() {
    _priceDebounce?.cancel();
    _symbolCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _feesCtrl.dispose();
    super.dispose();
  }

  /// Whether the price field is empty or still holds the value we last
  /// auto-filled — i.e. the user hasn't manually edited it, so it's safe to
  /// overwrite with a fresh quote.
  bool get _priceUntouched =>
      _priceCtrl.text.isEmpty || _priceCtrl.text == _autoFilledPrice;

  /// Fetches the current quote for [symbol] and fills the price field, unless
  /// the user already typed their own price. Crypto uses the live WebSocket
  /// feed; everything else uses the REST quote endpoint.
  Future<void> _prefillPrice(String symbol) async {
    if (symbol.isEmpty) return;
    setState(() => _priceLoading = true);
    double? price;
    try {
      if (_assetType == 'crypto') {
        final id = kCryptoTickerToCoinId[symbol];
        if (id != null) price = ref.read(realtimePriceProvider)[id];
      }
      if (price == null) {
        final res = await ApiClient.dio.get('/stocks/$symbol');
        final info = res.data as Map<String, dynamic>?;
        price = (info?['currentPrice'] as num?)?.toDouble() ??
            (info?['price'] as num?)?.toDouble();
      }
    } catch (_) {
      // Quote unavailable — leave the field for manual entry.
    }
    if (!mounted) return;
    setState(() {
      _priceLoading = false;
      if (price != null && price > 0 && _priceUntouched) {
        final text = price.toStringAsFixed(2);
        _priceCtrl.text = text;
        _autoFilledPrice = text;
      }
    });
  }

  /// Debounced quote refresh while the user types a symbol.
  void _onSymbolChanged(String value) {
    _priceDebounce?.cancel();
    final sym = value.trim().toUpperCase();
    if (sym.isEmpty) {
      setState(() {
        _selectedSymbol = null;
        _resolvedName = null;
      });
      return;
    }
    // Exact match against the known universe → auto-confirm (no tap needed).
    if (_assetType == 'crypto') {
      if (kCryptoTickerToCoinId.containsKey(sym)) {
        _confirmCrypto(sym, setText: false, unfocus: false);
        return;
      }
    } else {
      final all = ref.read(screenerProvider).valueOrNull ?? const <StockQuote>[];
      for (final s in all) {
        if (s.symbol.toUpperCase() == sym) {
          _confirmStock(s, setText: false, unfocus: false);
          return;
        }
      }
    }
    // No exact match yet — clear any prior selection so suggestions show.
    setState(() {
      _selectedSymbol = null;
      _resolvedName = null;
    });
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
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    // Capture before the await so we never touch a disposed sheet context.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final symbol = _symbolCtrl.text.trim().toUpperCase();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await Supabase.instance.client.from('portfolio_transactions').insert({
        'user_id': user.id,
        'symbol': symbol,
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

      // Always close the sheet on success.
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(
            '$symbol ${_operation == 'buy' ? 'comprado' : 'vendido'} — carteira atualizada'),
        backgroundColor: AppColors.emerald,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(
        content: Text('Erro: $e'),
        backgroundColor: AppColors.red,
      ));
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
                  onSelect: (v) {
                    setState(() => _assetType = v);
                    final sym = _symbolCtrl.text.trim().toUpperCase();
                    if (sym.isNotEmpty) _prefillPrice(sym);
                  },
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
                        onChanged: _onSymbolChanged,
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
                _buildSymbolArea(),
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
                        suffix: _priceLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.emerald),
                                ),
                              )
                            : null,
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

  /// Symbol area under the field: a ranked suggestions dropdown while typing,
  /// or a compact confirmation (logo + name + check) once a ticker is chosen.
  Widget _buildSymbolArea() {
    final query = _symbolCtrl.text.trim();
    if (query.isEmpty) return const SizedBox.shrink();

    final screener =
        ref.watch(screenerProvider).valueOrNull ?? const <StockQuote>[];

    // A ticker was chosen / exact-matched → confirm it.
    if (_selectedSymbol != null) {
      final name = _resolvedName ?? _nameFor(_selectedSymbol!, screener);
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            _symbolLogo(_selectedSymbol!, 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.check_circle_rounded,
                size: 18, color: AppColors.emerald),
          ],
        ),
      );
    }

    // Still typing → ranked suggestions to pick from.
    final tiles = <Widget>[];
    if (_assetType == 'crypto') {
      for (final sym in _cryptoSuggestions(query)) {
        tiles.add(_suggestionTile(
          symbol: sym,
          title: sym,
          subtitle: 'Crypto',
          onTap: () => _confirmCrypto(sym),
        ));
      }
    } else {
      for (final q in _stockSuggestions(screener, query)) {
        tiles.add(_suggestionTile(
          symbol: q.symbol,
          title: q.symbol,
          subtitle: q.name,
          price: q.price,
          onTap: () => _confirmStock(q, setText: true, unfocus: true),
        ));
      }
    }

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 248),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: tiles,
        ),
      ),
    );
  }

  Widget _suggestionTile({
    required String symbol,
    required String title,
    required String subtitle,
    double? price,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _symbolLogo(symbol.toUpperCase(), 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: context.colors.textMuted)),
                ],
              ),
            ),
            if (price != null && price > 0) ...[
              const SizedBox(width: 8),
              Text('\$${price.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecond)),
            ],
          ],
        ),
      ),
    );
  }

  /// Company/asset name for a symbol, falling back to the symbol itself.
  String _nameFor(String symbol, List<StockQuote> all) {
    for (final s in all) {
      if (s.symbol.toUpperCase() == symbol) return s.name;
    }
    return symbol;
  }

  /// Ranked stock matches: exact symbol → symbol prefix → name-word prefix →
  /// contains; ties broken by market cap (so the principais surface first).
  List<StockQuote> _stockSuggestions(List<StockQuote> all, String q) {
    final query = q.toUpperCase();
    if (query.isEmpty) return const [];
    final scored = <(int, StockQuote)>[];
    for (final s in all) {
      final sym = s.symbol.toUpperCase();
      final name = s.name.toUpperCase();
      int score;
      if (sym == query) {
        score = 0;
      } else if (sym.startsWith(query)) {
        score = 1;
      } else if (name.split(RegExp(r'\s+')).any((w) => w.startsWith(query))) {
        score = 2;
      } else if (sym.contains(query)) {
        score = 3;
      } else if (name.contains(query)) {
        score = 4;
      } else {
        continue;
      }
      scored.add((score, s));
    }
    scored.sort((a, b) {
      if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
      return (b.$2.marketCap ?? 0).compareTo(a.$2.marketCap ?? 0);
    });
    return scored.take(7).map((e) => e.$2).toList();
  }

  List<String> _cryptoSuggestions(String q) {
    final query = q.toUpperCase();
    if (query.isEmpty) return const [];
    final syms = kCryptoTickerToCoinId.keys
        .where((k) => k.toUpperCase().contains(query))
        .toList();
    syms.sort((a, b) {
      final ap = a.toUpperCase().startsWith(query) ? 0 : 1;
      final bp = b.toUpperCase().startsWith(query) ? 0 : 1;
      if (ap != bp) return ap.compareTo(bp);
      return a.compareTo(b);
    });
    return syms.take(7).toList();
  }

  void _confirmStock(StockQuote q, {bool setText = false, bool unfocus = false}) {
    setState(() {
      if (setText) {
        _symbolCtrl.text = q.symbol.toUpperCase();
        _symbolCtrl.selection =
            TextSelection.collapsed(offset: _symbolCtrl.text.length);
      }
      _selectedSymbol = q.symbol.toUpperCase();
      _resolvedName = q.name;
      if (q.price > 0 && _priceUntouched) {
        final text = q.price.toStringAsFixed(2);
        _priceCtrl.text = text;
        _autoFilledPrice = text;
      }
    });
    if (unfocus) FocusScope.of(context).unfocus();
  }

  void _confirmCrypto(String sym, {bool setText = true, bool unfocus = true}) {
    final s = sym.toUpperCase();
    setState(() {
      if (setText) {
        _symbolCtrl.text = s;
        _symbolCtrl.selection =
            TextSelection.collapsed(offset: _symbolCtrl.text.length);
      }
      _selectedSymbol = s;
      _resolvedName = s;
    });
    _prefillPrice(s);
    if (unfocus) FocusScope.of(context).unfocus();
  }

  /// Small rounded asset logo (parqet), with a 2-letter monogram fallback.
  Widget _symbolLogo(String symbol, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        'https://assets.parqet.com/logos/symbol/$symbol?format=png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Center(
          child: Text(
            symbol.length >= 2 ? symbol.substring(0, 2) : symbol,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: context.colors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? suffix,
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
          suffixIcon: suffix,
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
