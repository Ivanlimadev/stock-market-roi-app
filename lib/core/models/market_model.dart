class MarketIndex {
  final String symbol;
  final double close;
  final double open;
  final double high;
  final double low;

  const MarketIndex({
    required this.symbol,
    required this.close,
    required this.open,
    required this.high,
    required this.low,
  });

  double get changePct => open > 0 ? ((close - open) / open) * 100 : 0;

  String get displayName {
    switch (symbol) {
      case 'DJI.INDX': return 'Dow Jones';
      case 'IXIC.INDX': return 'Nasdaq';
      case 'RUT.INDX': return 'Russell 2000';
      case 'VIX.INDX': return 'VIX';
      default: return symbol;
    }
  }

  factory MarketIndex.fromJson(Map<String, dynamic> j) => MarketIndex(
    symbol: j['symbol'] as String,
    close:  (j['close'] as num).toDouble(),
    open:   (j['open'] as num).toDouble(),
    high:   (j['high'] as num).toDouble(),
    low:    (j['low'] as num).toDouble(),
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
