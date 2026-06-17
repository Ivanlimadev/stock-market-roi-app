class CryptoMarket {
  final String id;
  final String symbol;
  final String name;
  final String image;
  final double currentPrice;
  final double priceChangePercentage24h;
  final double? priceChange1h;
  final double? priceChange7d;
  final double? priceChange30d;
  final double? priceChange1y;
  final double marketCap;
  final double? totalVolume;
  final int? marketCapRank;

  const CryptoMarket({
    required this.id,
    required this.symbol,
    required this.name,
    required this.image,
    required this.currentPrice,
    required this.priceChangePercentage24h,
    this.priceChange1h,
    this.priceChange7d,
    this.priceChange30d,
    this.priceChange1y,
    required this.marketCap,
    this.totalVolume,
    this.marketCapRank,
  });

  factory CryptoMarket.fromJson(Map<String, dynamic> j) => CryptoMarket(
    id:            j['id'] as String,
    symbol:        j['symbol'] as String,
    name:          j['name'] as String,
    image:         j['image'] as String,
    currentPrice:  (j['current_price'] as num).toDouble(),
    priceChangePercentage24h:
        (j['price_change_percentage_24h'] as num? ?? 0).toDouble(),
    priceChange1h:
        (j['price_change_percentage_1h_in_currency'] as num?)?.toDouble(),
    priceChange7d:
        (j['price_change_percentage_7d_in_currency'] as num?)?.toDouble(),
    priceChange30d:
        (j['price_change_percentage_30d_in_currency'] as num?)?.toDouble(),
    priceChange1y:
        (j['price_change_percentage_1y_in_currency'] as num?)?.toDouble(),
    marketCap:    (j['market_cap'] as num? ?? 0).toDouble(),
    totalVolume:  (j['total_volume'] as num?)?.toDouble(),
    marketCapRank: j['market_cap_rank'] as int?,
  );
}

// ─── Global Market Data ──────────────────────────────────────────────────────

class DominanceEntry {
  final String symbol;
  final double pct;
  const DominanceEntry({required this.symbol, required this.pct});
  factory DominanceEntry.fromJson(Map<String, dynamic> j) =>
      DominanceEntry(symbol: j['symbol'] as String, pct: (j['pct'] as num).toDouble());
}

class CryptoGlobal {
  final int activeCryptocurrencies;
  final int markets;
  final double totalMarketCapUsd;
  final double totalVolumeUsd;
  final double marketCapChange24h;
  final double btcDominance;
  final double ethDominance;
  final List<DominanceEntry> topDominances;

  const CryptoGlobal({
    required this.activeCryptocurrencies,
    required this.markets,
    required this.totalMarketCapUsd,
    required this.totalVolumeUsd,
    required this.marketCapChange24h,
    required this.btcDominance,
    required this.ethDominance,
    required this.topDominances,
  });

  factory CryptoGlobal.fromJson(Map<String, dynamic> j) => CryptoGlobal(
    activeCryptocurrencies: (j['active_cryptocurrencies'] as num).toInt(),
    markets:                (j['markets'] as num).toInt(),
    totalMarketCapUsd:      (j['total_market_cap_usd'] as num).toDouble(),
    totalVolumeUsd:         (j['total_volume_usd'] as num).toDouble(),
    marketCapChange24h:     (j['market_cap_change_percentage_24h'] as num).toDouble(),
    btcDominance:           (j['btc_dominance'] as num).toDouble(),
    ethDominance:           (j['eth_dominance'] as num).toDouble(),
    topDominances: (j['top_dominances'] as List<dynamic>)
        .map((e) => DominanceEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ─── Trending ────────────────────────────────────────────────────────────────

class TrendingCoin {
  final String id, name, symbol, image;
  final double price;
  final double priceChange24h;
  final int marketCapRank;

  const TrendingCoin({
    required this.id,
    required this.name,
    required this.symbol,
    required this.image,
    required this.price,
    required this.priceChange24h,
    required this.marketCapRank,
  });

  factory TrendingCoin.fromJson(Map<String, dynamic> j) => TrendingCoin(
    id:            j['id'] as String,
    name:          j['name'] as String,
    symbol:        (j['symbol'] as String).toUpperCase(),
    image:         j['image'] as String,
    price:         (j['price'] as num? ?? 0).toDouble(),
    priceChange24h:(j['price_change_percentage_24h'] as num? ?? 0).toDouble(),
    marketCapRank: (j['market_cap_rank'] as num? ?? 0).toInt(),
  );
}

// ─── Fear & Greed ────────────────────────────────────────────────────────────

class FearGreedPoint {
  final int value;
  final String classification;
  final int timestamp;

  const FearGreedPoint({
    required this.value,
    required this.classification,
    required this.timestamp,
  });

  factory FearGreedPoint.fromJson(Map<String, dynamic> j) => FearGreedPoint(
    value:          (j['value'] as num).toInt(),
    classification: j['classification'] as String,
    timestamp:      (j['timestamp'] as num).toInt(),
  );
}
