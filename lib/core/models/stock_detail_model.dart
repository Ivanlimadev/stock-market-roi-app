class StockDetail {
  final String symbol;
  final String name;
  final double currentPrice;
  final double prevClose;
  final double change;
  final double changePct;
  final String? exchange;
  final StockInfo? info;

  const StockDetail({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.prevClose,
    required this.change,
    required this.changePct,
    this.exchange,
    this.info,
  });

  factory StockDetail.fromJson(Map<String, dynamic> j) => StockDetail(
    symbol:       j['symbol']       as String? ?? '',
    name:         j['name']         as String? ?? '',
    currentPrice: (j['currentPrice'] as num?)?.toDouble() ?? 0,
    prevClose:    (j['prevClose']    as num?)?.toDouble() ?? 0,
    change:       (j['change']       as num?)?.toDouble() ?? 0,
    changePct:    (j['changePct']    as num?)?.toDouble() ?? 0,
    exchange:     j['exchange'] as String?,
    info: j['info'] != null
        ? StockInfo.fromJson(j['info'] as Map<String, dynamic>)
        : null,
  );
}

class HistoryBar {
  final String date;
  final double close;
  const HistoryBar({required this.date, required this.close});

  factory HistoryBar.fromJson(Map<String, dynamic> j) => HistoryBar(
    date:  j['date']  as String? ?? '',
    close: (j['close'] as num?)?.toDouble() ??
           (j['adj_close'] as num?)?.toDouble() ?? 0,
  );
}

class StockInfo {
  final String? description;
  final String? sector;
  final String? industry;
  final String? website;
  final double? marketCap;
  final double? pe;
  final double? forwardPE;
  final double? dividendYield;
  final double? week52High;
  final double? week52Low;
  final double? avgVolume10d;
  final double? beta;
  final double? eps;
  final String? recommendationKey;
  final double? targetMeanPrice;

  const StockInfo({
    this.description, this.sector, this.industry, this.website,
    this.marketCap, this.pe, this.forwardPE, this.dividendYield,
    this.week52High, this.week52Low, this.avgVolume10d, this.beta,
    this.eps, this.recommendationKey, this.targetMeanPrice,
  });

  factory StockInfo.fromJson(Map<String, dynamic> j) => StockInfo(
    description:       j['description']      as String?,
    sector:            j['sector']           as String?,
    industry:          j['industry']         as String?,
    website:           j['website']          as String?,
    marketCap:         (j['marketCap']       as num?)?.toDouble(),
    pe:                (j['pe']              as num?)?.toDouble(),
    forwardPE:         (j['forwardPE']       as num?)?.toDouble(),
    dividendYield:     (j['dividendYield']   as num?)?.toDouble(),
    week52High:        (j['week52High']      as num?)?.toDouble(),
    week52Low:         (j['week52Low']       as num?)?.toDouble(),
    avgVolume10d:      (j['avgVolume10d']    as num?)?.toDouble(),
    beta:              (j['beta']            as num?)?.toDouble(),
    eps:               (j['eps']            as num?)?.toDouble(),
    recommendationKey: j['recommendationKey'] as String?,
    targetMeanPrice:   (j['targetMeanPrice'] as num?)?.toDouble(),
  );
}
