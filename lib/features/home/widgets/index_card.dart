import 'package:flutter/material.dart';
import '../../../core/models/market_model.dart';
import '../../../core/theme/app_theme.dart';

class IndexCard extends StatelessWidget {
  final MarketIndex index;
  const IndexCard({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final up = index.changePct >= 0;
    final color = up ? AppColors.emerald : AppColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(index.name,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            index.price.toStringAsFixed(index.price >= 1000 ? 0 : 2),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: color, size: 16),
              Text(
                '${up ? '+' : ''}${index.changePct.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
