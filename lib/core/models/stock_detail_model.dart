class StockDetail {
  final String symbol;
  final String name;
  final double currentPrice;
  final double prevClose;
  final double change;
  final double changePct;
  final String? exchange;
  final StockInfo? info;
  final List<DividendPayment> dividends;

  const StockDetail({
    required this.symbol,
    required this.name,
    required this.currentPrice,
    required this.prevClose,
    required this.change,
    required this.changePct,
    this.exchange,
    this.info,
    this.dividends = const [],
  });

  factory StockDetail.fromJson(Map<String, dynamic> j) => StockDetail(
    symbol:       j['symbol']        as String? ?? '',
    name:         j['name']          as String? ?? '',
    currentPrice: (j['currentPrice'] as num?)?.toDouble() ?? 0,
    prevClose:    (j['prevClose']    as num?)?.toDouble() ?? 0,
    change:       (j['change']       as num?)?.toDouble() ?? 0,
    changePct:    (j['changePct']    as num?)?.toDouble() ?? 0,
    exchange:     j['exchange']      as String?,
    info: j['info'] != null
        ? StockInfo.fromJson(j['info'] as Map<String, dynamic>)
        : null,
    dividends: (j['dividends'] as List? ?? [])
        .map((e) => DividendPayment.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class DividendPayment {
  final String date;
  final double amount;
  const DividendPayment({required this.date, required this.amount});

  factory DividendPayment.fromJson(Map<String, dynamic> j) => DividendPayment(
    date:   j['date']     as String? ?? '',
    amount: (j['dividend'] as num?)?.toDouble() ?? 0,
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
  final String? country;
  final String? city;
  final int? employees;

  // Price & Valuation
  final double? marketCap;
  final double? pe;
  final double? forwardPE;
  final double? pegRatio;
  final double? eps;
  final double? priceToBook;
  final double? bookValue;

  // Trading
  final double? week52High;
  final double? week52Low;
  final double? avgVolume10d;
  final double? avgVolume3m;
  final double? beta;

  // Dividends
  final double? dividendYield;
  final double? dividendRate;
  final String? exDividendDate;
  final String? dividendDate;
  final double? payoutRatio;

  // Earnings
  final String? nextEarningsDate;

  // Profitability
  final double? profitMargin;
  final double? operatingMargin;
  final double? roe;
  final double? roa;
  final double? revenueGrowth;
  final double? earningsGrowth;

  // Balance Sheet
  final double? totalRevenue;
  final double? totalDebt;
  final double? debtToEquity;
  final double? currentRatio;
  final double? freeCashflow;

  // Analyst
  final String? recommendationKey;
  final double? targetMeanPrice;
  final double? targetHighPrice;
  final double? targetLowPrice;
  final int? numberOfAnalystOpinions;

  const StockInfo({
    this.description, this.sector, this.industry, this.website,
    this.country, this.city, this.employees,
    this.marketCap, this.pe, this.forwardPE, this.pegRatio,
    this.eps, this.priceToBook, this.bookValue,
    this.week52High, this.week52Low, this.avgVolume10d, this.avgVolume3m, this.beta,
    this.dividendYield, this.dividendRate, this.exDividendDate,
    this.dividendDate, this.payoutRatio,
    this.nextEarningsDate,
    this.profitMargin, this.operatingMargin, this.roe, this.roa,
    this.revenueGrowth, this.earningsGrowth,
    this.totalRevenue, this.totalDebt, this.debtToEquity,
    this.currentRatio, this.freeCashflow,
    this.recommendationKey, this.targetMeanPrice,
    this.targetHighPrice, this.targetLowPrice, this.numberOfAnalystOpinions,
  });

  factory StockInfo.fromJson(Map<String, dynamic> j) {
    double? n(String k) => (j[k] as num?)?.toDouble();
    int? i(String k)    => (j[k] as num?)?.toInt();
    return StockInfo(
      description:              j['description']            as String?,
      sector:                   j['sector']                 as String?,
      industry:                 j['industry']               as String?,
      website:                  j['website']                as String?,
      country:                  j['country']                as String?,
      city:                     j['city']                   as String?,
      employees:                i('employees'),
      marketCap:                n('marketCap'),
      pe:                       n('pe'),
      forwardPE:                n('forwardPE'),
      pegRatio:                 n('pegRatio'),
      eps:                      n('eps'),
      priceToBook:              n('priceToBook'),
      bookValue:                n('bookValue'),
      week52High:               n('week52High'),
      week52Low:                n('week52Low'),
      avgVolume10d:             n('avgVolume10d'),
      avgVolume3m:              n('avgVolume3m'),
      beta:                     n('beta'),
      dividendYield:            n('dividendYield'),
      dividendRate:             n('dividendRate'),
      exDividendDate:           j['exDividendDate']         as String?,
      dividendDate:             j['dividendDate']           as String?,
      payoutRatio:              n('payoutRatio'),
      nextEarningsDate:         j['nextEarningsDate']       as String?,
      profitMargin:             n('profitMargin'),
      operatingMargin:          n('operatingMargin'),
      roe:                      n('roe'),
      roa:                      n('roa'),
      revenueGrowth:            n('revenueGrowth'),
      earningsGrowth:           n('earningsGrowth'),
      totalRevenue:             n('totalRevenue'),
      totalDebt:                n('totalDebt'),
      debtToEquity:             n('debtToEquity'),
      currentRatio:             n('currentRatio'),
      freeCashflow:             n('freeCashflow'),
      recommendationKey:        j['recommendationKey']      as String?,
      targetMeanPrice:          n('targetMeanPrice'),
      targetHighPrice:          n('targetHighPrice'),
      targetLowPrice:           n('targetLowPrice'),
      numberOfAnalystOpinions:  i('numberOfAnalystOpinions'),
    );
  }
}
