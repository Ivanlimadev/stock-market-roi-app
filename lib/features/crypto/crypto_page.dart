import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/crypto_provider.dart';
import '../../core/models/crypto_model.dart';

class CryptoPage extends ConsumerWidget {
  const CryptoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cryptoAsync = ref.watch(cryptoMarketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(cryptoMarketsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.emerald,
        onRefresh: () async {
          ref.invalidate(cryptoMarketsProvider);
          await ref.read(cryptoMarketsProvider.future).then((_) {}).catchError((_) {});
        },
        child: cryptoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 48),
                const SizedBox(height: 12),
                const Text('Failed to load crypto data',
                  style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(cryptoMarketsProvider),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emerald,
                    side: const BorderSide(color: AppColors.emerald),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (coins) => ListView.builder(
            itemCount: coins.length,
            itemBuilder: (_, i) => _CoinTile(coin: coins[i], rank: i + 1),
          ),
        ),
      ),
    );
  }
}

class _CoinTile extends StatelessWidget {
  final CryptoMarket coin;
  final int rank;
  const _CoinTile({required this.coin, required this.rank});

  @override
  Widget build(BuildContext context) {
    final up    = coin.priceChangePercentage24h >= 0;
    final color = up ? AppColors.emerald : AppColors.red;

    return InkWell(
      onTap: () => context.push('/crypto/${coin.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text('#$rank',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                coin.image,
                width: 36, height: 36,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 36, height: 36,
                  color: AppColors.surfaceAlt,
                  child: Center(
                    child: Text(coin.symbol.toUpperCase().substring(0, 1),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coin.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(coin.symbol.toUpperCase(),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${_formatPrice(coin.currentPrice)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${up ? '+' : ''}${coin.priceChangePercentage24h.toStringAsFixed(2)}%',
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

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1)    return price.toStringAsFixed(2);
    return price.toStringAsFixed(6);
  }
}
