import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/market_model.dart';
import '../../../core/theme/app_theme.dart';

class StockRow extends StatelessWidget {
  final StockQuote stock;
  const StockRow({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final up = stock.changePct >= 0;
    final color = up ? AppColors.emerald : AppColors.red;

    return InkWell(
      onTap: () => context.push('/stocks/${stock.symbol}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Logo
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                'https://assets.parqet.com/logos/symbol/${stock.symbol}?format=png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(stock.symbol.substring(0, 2),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.colors.textMuted)),
                ),
              ),
            ),
            SizedBox(width: 12),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.symbol,
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                  Text(stock.name,
                    style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                    overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Price + change
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${stock.price.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
