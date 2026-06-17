class CryptoMarket {
  final String id;
  final String symbol;
  final String name;
  final String image;
  final double currentPrice;
  final double priceChangePercentage24h;
  final double marketCap;
  final int? marketCapRank;

  const CryptoMarket({
    required this.id,
    required this.symbol,
    required this.name,
    required this.image,
    required this.currentPrice,
    required this.priceChangePercentage24h,
    required this.marketCap,
    this.marketCapRank,
  });

  factory CryptoMarket.fromJson(Map<String, dynamic> j) => CryptoMarket(
    id:                         j['id'] as String,
    symbol:                     j['symbol'] as String,
    name:                       j['name'] as String,
    image:                      j['image'] as String,
    currentPrice:               (j['current_price'] as num).toDouble(),
    priceChangePercentage24h:   (j['price_change_percentage_24h'] as num? ?? 0).toDouble(),
    marketCap:                  (j['market_cap'] as num? ?? 0).toDouble(),
    marketCapRank:              j['market_cap_rank'] as int?,
  );
}
