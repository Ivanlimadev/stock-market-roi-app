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
  final double? volume;
  final double? dividendYield;
  final String? sector;
  final String? industry;
  final double? pe;
  final double? forwardPE;
  final double? pb;
  final double? roe;
  final double? beta;
  final double? week52High;
  final double? week52Low;
  final double? eps;

  const StockQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
    this.marketCap,
    this.volume,
    this.dividendYield,
    this.sector,
    this.industry,
    this.pe,
    this.forwardPE,
    this.pb,
    this.roe,
    this.beta,
    this.week52High,
    this.week52Low,
    this.eps,
  });

  factory StockQuote.fromJson(Map<String, dynamic> j) => StockQuote(
    symbol:        j['symbol']        as String,
    name:          j['name']          as String,
    price:         (j['price']        as num).toDouble(),
    changePct:     (j['changePct']    as num).toDouble(),
    marketCap:     (j['marketCap']    as num?)?.toDouble(),
    volume:        (j['volume']       as num?)?.toDouble(),
    dividendYield: (j['dividendYield'] as num?)?.toDouble(),
    sector:        j['sector']        as String?,
    industry:      j['industry']      as String?,
    pe:            (j['pe']           as num?)?.toDouble(),
    forwardPE:     (j['forwardPE']    as num?)?.toDouble(),
    pb:            (j['pb']           as num?)?.toDouble(),
    roe:           (j['roe']          as num?)?.toDouble(),
    beta:          (j['beta']         as num?)?.toDouble(),
    week52High:    (j['week52High']   as num?)?.toDouble(),
    week52Low:     (j['week52Low']    as num?)?.toDouble(),
    eps:           (j['eps']          as num?)?.toDouble(),
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
