class MarketIndex {
  final String symbol;
  final String name;
  final double price;
  final double changePct;

  const MarketIndex({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
  });

  factory MarketIndex.fromJson(Map<String, dynamic> j) => MarketIndex(
    symbol:    j['symbol'] as String,
    name:      j['name'] as String? ?? j['symbol'] as String,
    price:     (j['price'] as num).toDouble(),
    changePct: (j['changePct'] as num).toDouble(),
  );
}

class StockQuote {
  final String symbol;
  final String name;
  final double price;
  final double changePct;
  final double? marketCap;
  final String? sector;

  const StockQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
    this.marketCap,
    this.sector,
  });

  factory StockQuote.fromJson(Map<String, dynamic> j) => StockQuote(
    symbol:    j['symbol'] as String,
    name:      j['name'] as String,
    price:     (j['price'] as num).toDouble(),
    changePct: (j['changePct'] as num).toDouble(),
    marketCap: j['marketCap'] != null ? (j['marketCap'] as num).toDouble() : null,
    sector:    j['sector'] as String?,
  );
}

class MarketOverview {
  final List<MarketIndex> indices;
  final List<StockQuote> blueChips;

  const MarketOverview({required this.indices, required this.blueChips});

  factory MarketOverview.fromJson(Map<String, dynamic> j) => MarketOverview(
    indices:   (j['indices'] as List).map((e) => MarketIndex.fromJson(e as Map<String, dynamic>)).toList(),
    blueChips: (j['blueChips'] as List).map((e) => StockQuote.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
