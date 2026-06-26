import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/screener_provider.dart';
import '../../core/models/market_model.dart';
import '../portfolio/add_transaction_sheet.dart';

final _searchProvider = StateProvider<String>((ref) => '');

class StocksPage extends ConsumerWidget {
  const StocksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query   = ref.watch(_searchProvider);
    final stocks  = ref.watch(screenerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Stocks')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search symbol or name…',
                prefixIcon: Icon(Icons.search_rounded, color: context.colors.textMuted),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, color: context.colors.textMuted, size: 18),
                        onPressed: () => ref.read(_searchProvider.notifier).state = '',
                      )
                    : null,
              ),
              onChanged: (v) => ref.read(_searchProvider.notifier).state = v.trim(),
            ),
          ),

          Expanded(
            child: stocks.when(
              loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              error:   (e, _) => Center(
                child: Text('Failed to load stocks', style: TextStyle(color: context.colors.textMuted))),
              data: (all) {
                final filtered = query.isEmpty
                    ? all
                    : all.where((s) =>
                        s.symbol.toUpperCase().contains(query.toUpperCase()) ||
                        s.name.toLowerCase().contains(query.toLowerCase())).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No results for "$query"',
                      style: TextStyle(color: context.colors.textMuted)));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _StockListTile(stock: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StockListTile extends StatelessWidget {
  final StockQuote stock;
  const _StockListTile({required this.stock});

  @override
  Widget build(BuildContext context) {
    final up    = stock.changePct >= 0;
    final color = up ? AppColors.emerald : AppColors.red;

    return InkWell(
      onTap: () => context.push('/stocks/${stock.symbol}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                'https://assets.parqet.com/logos/symbol/${stock.symbol}?format=png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(stock.symbol.length >= 2 ? stock.symbol.substring(0, 2) : stock.symbol,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colors.textMuted)),
                ),
              ),
            ),
            SizedBox(width: 8),
            // Quick add-to-portfolio (opens the transaction sheet pre-filled).
            IconButton(
              onPressed: () =>
                  showAddTransactionSheet(context, initialSymbol: stock.symbol),
              icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.emerald),
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              tooltip: 'Add to portfolio',
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.symbol,
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                  Text(stock.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${stock.price.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${up ? '+' : ''}${stock.changePct.toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
