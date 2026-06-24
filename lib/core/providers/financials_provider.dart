import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class FinancialPeriod {
  final String date;
  final double? revenue;
  final double? grossProfit;
  final double? operatingIncome;
  final double? netIncome;
  final double? eps;
  final double? netMargin;

  const FinancialPeriod({
    required this.date,
    this.revenue,
    this.grossProfit,
    this.operatingIncome,
    this.netIncome,
    this.eps,
    this.netMargin,
  });

  factory FinancialPeriod.fromJson(Map<String, dynamic> j) => FinancialPeriod(
    date:             j['date'] as String? ?? '',
    revenue:          (j['revenue'] as num?)?.toDouble(),
    grossProfit:      (j['grossProfit'] as num?)?.toDouble(),
    operatingIncome:  (j['operatingIncome'] as num?)?.toDouble(),
    netIncome:        (j['netIncome'] as num?)?.toDouble(),
    eps:              (j['eps'] as num?)?.toDouble(),
    netMargin:        (j['netMargin'] as num?)?.toDouble(),
  );
}

class StockFinancials {
  final List<FinancialPeriod> annual;
  final List<FinancialPeriod> quarterly;
  final double? cagr5yRevenue;
  final double? cagr5yNetIncome;

  const StockFinancials({
    required this.annual,
    required this.quarterly,
    this.cagr5yRevenue,
    this.cagr5yNetIncome,
  });

  factory StockFinancials.fromJson(Map<String, dynamic> j) => StockFinancials(
    annual:          (j['annual'] as List? ?? [])
        .map((e) => FinancialPeriod.fromJson(e as Map<String, dynamic>))
        .toList(),
    quarterly:       (j['quarterly'] as List? ?? [])
        .map((e) => FinancialPeriod.fromJson(e as Map<String, dynamic>))
        .toList(),
    cagr5yRevenue:   (j['cagr5yRevenue'] as num?)?.toDouble(),
    cagr5yNetIncome: (j['cagr5yNetIncome'] as num?)?.toDouble(),
  );
}

class SecFiling {
  final String form;
  final String filingDate;
  final String reportDate;
  final String description;
  final String url;
  final String indexUrl;

  const SecFiling({
    required this.form,
    required this.filingDate,
    required this.reportDate,
    required this.description,
    required this.url,
    required this.indexUrl,
  });

  factory SecFiling.fromJson(Map<String, dynamic> j) => SecFiling(
    form:        j['form'] as String? ?? '',
    filingDate:  j['filingDate'] as String? ?? '',
    reportDate:  j['reportDate'] as String? ?? '',
    description: j['description'] as String? ?? '',
    url:         j['url'] as String? ?? '',
    indexUrl:    j['indexUrl'] as String? ?? '',
  );
}

class InsiderTx {
  final String date;
  final String owner;
  final String role;
  final String code;
  final String type; // buy | sell | award | option | tax | gift | other
  final double? shares;
  final double? price;
  final double? value;

  const InsiderTx({
    required this.date,
    required this.owner,
    required this.role,
    required this.code,
    required this.type,
    this.shares,
    this.price,
    this.value,
  });

  factory InsiderTx.fromJson(Map<String, dynamic> j) => InsiderTx(
    date:   j['date'] as String? ?? '',
    owner:  j['owner'] as String? ?? 'Insider',
    role:   j['role'] as String? ?? '—',
    code:   j['code'] as String? ?? '',
    type:   j['type'] as String? ?? 'other',
    shares: (j['shares'] as num?)?.toDouble(),
    price:  (j['price'] as num?)?.toDouble(),
    value:  (j['value'] as num?)?.toDouble(),
  );
}

class InsiderData {
  final List<InsiderTx> transactions;
  final int months;
  final int buys;
  final int sells;
  final double buyValue;
  final double sellValue;
  final double netValue;

  const InsiderData({
    required this.transactions,
    required this.months,
    required this.buys,
    required this.sells,
    required this.buyValue,
    required this.sellValue,
    required this.netValue,
  });

  factory InsiderData.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map<String, dynamic>?) ?? const {};
    return InsiderData(
      transactions: (j['transactions'] as List? ?? [])
          .map((e) => InsiderTx.fromJson(e as Map<String, dynamic>))
          .toList(),
      months:    (s['months'] as num?)?.toInt() ?? 6,
      buys:      (s['buys'] as num?)?.toInt() ?? 0,
      sells:     (s['sells'] as num?)?.toInt() ?? 0,
      buyValue:  (s['buyValue'] as num?)?.toDouble() ?? 0,
      sellValue: (s['sellValue'] as num?)?.toDouble() ?? 0,
      netValue:  (s['netValue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ExchangeTicker {
  final String exchange;
  final String target;
  final double price;
  final double volume24h;
  final String? trustScore;
  final String? tradeUrl;

  const ExchangeTicker({
    required this.exchange,
    required this.target,
    required this.price,
    required this.volume24h,
    this.trustScore,
    this.tradeUrl,
  });

  factory ExchangeTicker.fromJson(Map<String, dynamic> j) => ExchangeTicker(
    exchange:   j['exchange'] as String? ?? '',
    target:     j['target'] as String? ?? '',
    price:      (j['price'] as num?)?.toDouble() ?? 0,
    volume24h:  (j['volume24h'] as num?)?.toDouble() ?? 0,
    trustScore: j['trustScore'] as String?,
    tradeUrl:   j['tradeUrl'] as String?,
  );
}

class FundingRateItem {
  final String symbol;
  final double ratePct;
  final double annualPct;
  final int nextFunding;

  const FundingRateItem({
    required this.symbol,
    required this.ratePct,
    required this.annualPct,
    required this.nextFunding,
  });

  factory FundingRateItem.fromJson(Map<String, dynamic> j) => FundingRateItem(
    symbol:      j['symbol'] as String? ?? '',
    ratePct:     (j['ratePct'] as num?)?.toDouble() ?? 0,
    annualPct:   (j['annualPct'] as num?)?.toDouble() ?? 0,
    nextFunding: (j['nextFunding'] as num?)?.toInt() ?? 0,
  );
}

class LongShortItem {
  final String symbol;
  final double longPct;
  final double shortPct;
  final double ratio;

  const LongShortItem({
    required this.symbol,
    required this.longPct,
    required this.shortPct,
    required this.ratio,
  });

  factory LongShortItem.fromJson(Map<String, dynamic> j) => LongShortItem(
    symbol:   j['symbol'] as String? ?? '',
    longPct:  (j['longPct'] as num?)?.toDouble() ?? 50,
    shortPct: (j['shortPct'] as num?)?.toDouble() ?? 50,
    ratio:    (j['ratio'] as num?)?.toDouble() ?? 1,
  );
}

class DefiProtocol {
  final String name;
  final double tvl;
  final double change1d;
  final String category;

  const DefiProtocol({
    required this.name,
    required this.tvl,
    required this.change1d,
    required this.category,
  });

  factory DefiProtocol.fromJson(Map<String, dynamic> j) => DefiProtocol(
    name:     j['name'] as String? ?? '',
    tvl:      (j['tvl'] as num?)?.toDouble() ?? 0,
    change1d: (j['change1d'] as num?)?.toDouble() ?? 0,
    category: j['category'] as String? ?? 'DeFi',
  );
}

class DefiChain {
  final String name;
  final double tvl;
  final double share;

  const DefiChain({required this.name, required this.tvl, required this.share});

  factory DefiChain.fromJson(Map<String, dynamic> j) => DefiChain(
    name:  j['name'] as String? ?? '',
    tvl:   (j['tvl'] as num?)?.toDouble() ?? 0,
    share: (j['share'] as num?)?.toDouble() ?? 0,
  );
}

class DefiTvlData {
  final double totalTvl;
  final double change1d;
  final List<DefiProtocol> protocols;
  final List<DefiChain> chains;

  const DefiTvlData({
    required this.totalTvl,
    required this.change1d,
    required this.protocols,
    required this.chains,
  });

  factory DefiTvlData.fromJson(Map<String, dynamic> j) => DefiTvlData(
    totalTvl:  (j['totalTvl'] as num?)?.toDouble() ?? 0,
    change1d:  (j['change1d'] as num?)?.toDouble() ?? 0,
    protocols: (j['protocols'] as List? ?? [])
        .map((e) => DefiProtocol.fromJson(e as Map<String, dynamic>))
        .toList(),
    chains:    (j['chains'] as List? ?? [])
        .map((e) => DefiChain.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final stockFinancialsProvider = FutureProvider.autoDispose
    .family<StockFinancials, String>((ref, symbol) async {
  final json = await ApiClient.get('/stocks/$symbol/financials');
  return StockFinancials.fromJson(json as Map<String, dynamic>);
});

final stockFilingsProvider = FutureProvider.autoDispose
    .family<List<SecFiling>, String>((ref, symbol) async {
  final json = await ApiClient.get('/stocks/filings?symbol=$symbol');
  return (json as List)
      .map((e) => SecFiling.fromJson(e as Map<String, dynamic>))
      .toList();
});

final stockInsidersProvider = FutureProvider.autoDispose
    .family<InsiderData, String>((ref, symbol) async {
  final json = await ApiClient.get('/stocks/insiders?symbol=$symbol');
  return InsiderData.fromJson(json as Map<String, dynamic>);
});

final cryptoTickersProvider = FutureProvider.autoDispose
    .family<List<ExchangeTicker>, String>((ref, coinId) async {
  final json = await ApiClient.get('/crypto/$coinId/tickers');
  return (json as List)
      .map((e) => ExchangeTicker.fromJson(e as Map<String, dynamic>))
      .toList();
});

final cryptoFundingProvider = FutureProvider.autoDispose<List<FundingRateItem>>((ref) async {
  final json = await ApiClient.get('/crypto/funding');
  return (json as List)
      .map((e) => FundingRateItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final cryptoLongShortProvider = FutureProvider.autoDispose<List<LongShortItem>>((ref) async {
  final json = await ApiClient.get('/crypto/longshort');
  return (json as List)
      .map((e) => LongShortItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final defiTvlProvider = FutureProvider.autoDispose<DefiTvlData>((ref) async {
  final json = await ApiClient.get('/defi/tvl');
  return DefiTvlData.fromJson(json as Map<String, dynamic>);
});
