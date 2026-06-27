class PortfolioTransaction {
  final String id;
  final String symbol;
  final String assetType; // stock | reit | etf | crypto
  final String type;      // buy | sell
  final double quantity;
  final double pricePerShare;
  final String date; // YYYY-MM-DD
  final double fees;
  final DateTime createdAt;

  const PortfolioTransaction({
    required this.id,
    required this.symbol,
    required this.assetType,
    required this.type,
    required this.quantity,
    required this.pricePerShare,
    required this.date,
    required this.fees,
    required this.createdAt,
  });

  factory PortfolioTransaction.fromJson(Map<String, dynamic> j) =>
      PortfolioTransaction(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        assetType: j['asset_type'] as String? ?? 'stock',
        type: j['type'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        pricePerShare: (j['price_per_share'] as num).toDouble(),
        date: j['date'] as String,
        fees: (j['fees'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  double get subtotal => quantity * pricePerShare;
  double get total => type == 'buy' ? subtotal + fees : subtotal - fees;
}

class PortfolioHolding {
  final String symbol;
  final String assetType;
  final double netShares;
  final double avgPrice;
  final double totalCost;
  final String? firstPurchaseDate;
  final double? currentPrice;
  final double? dayChangePct; // today's price change %, when available
  final String? sector;       // GICS sector, when available

  const PortfolioHolding({
    required this.symbol,
    required this.assetType,
    required this.netShares,
    required this.avgPrice,
    required this.totalCost,
    this.firstPurchaseDate,
    this.currentPrice,
    this.dayChangePct,
    this.sector,
  });

  factory PortfolioHolding.fromJson(Map<String, dynamic> j) => PortfolioHolding(
        symbol: j['symbol'] as String,
        assetType: j['asset_type'] as String? ?? 'stock',
        netShares: (j['net_shares'] as num).toDouble(),
        avgPrice: (j['avg_price'] as num).toDouble(),
        totalCost: (j['total_cost'] as num).toDouble(),
        firstPurchaseDate: j['first_purchase_date'] as String?,
      );

  PortfolioHolding withPrice(double price,
          {double? dayChangePct, String? sector}) =>
      PortfolioHolding(
        symbol: symbol,
        assetType: assetType,
        netShares: netShares,
        avgPrice: avgPrice,
        totalCost: totalCost,
        firstPurchaseDate: firstPurchaseDate,
        currentPrice: price,
        dayChangePct: dayChangePct ?? this.dayChangePct,
        sector: sector ?? this.sector,
      );

  double get effectivePrice => currentPrice ?? avgPrice;
  double get currentValue => netShares * effectivePrice;

  /// Cost basis of the *current* position: shares held × average buy price.
  /// `totalCost` from the view is the gross cost of all buys, so using it
  /// directly overstates the basis (and understates gains) after a partial
  /// sell. With no sells the two are identical.
  double get costBasis => netShares * avgPrice;
  double get gainLoss => currentValue - costBasis;
  double get gainLossPct => costBasis > 0 ? (gainLoss / costBasis) * 100 : 0;
  bool get hasLivePrice => currentPrice != null;

  /// The position's dollar move today, derived from [dayChangePct].
  double? get dayChangeValue {
    final p = dayChangePct;
    if (p == null || p <= -100) return null;
    return currentValue * (p / 100) / (1 + p / 100);
  }
}

class DividendInfo {
  final String symbol;
  final String assetType;
  final double netShares;
  final double? dividendRate;   // annual dividend per share (USD)
  final double? dividendYield;  // 0.0–1.0
  final String? exDividendDate;
  final String? dividendDate;
  final double? payoutRatio;
  final double? costPerShare; // your average price — for yield-on-cost

  const DividendInfo({
    required this.symbol,
    required this.assetType,
    required this.netShares,
    this.dividendRate,
    this.dividendYield,
    this.exDividendDate,
    this.dividendDate,
    this.payoutRatio,
    this.costPerShare,
  });

  bool get paysDividends => (dividendRate ?? 0) > 0;
  double get annualTotal => (dividendRate ?? 0) * netShares;
  double get yieldPct => (dividendYield ?? 0) * 100;

  /// Yield on cost: annual dividend per share over *your* average price.
  double get yieldOnCostPct =>
      (dividendRate ?? 0) > 0 && (costPerShare ?? 0) > 0
          ? (dividendRate! / costPerShare!) * 100
          : 0;
}

class PortfolioSnapshot {
  final String date; // YYYY-MM-DD
  final double totalValue;
  final double totalInvested;

  const PortfolioSnapshot({
    required this.date,
    required this.totalValue,
    required this.totalInvested,
  });

  factory PortfolioSnapshot.fromJson(Map<String, dynamic> j) => PortfolioSnapshot(
        date:          j['snapshot_date'] as String,
        totalValue:    (j['total_value']    as num).toDouble(),
        totalInvested: (j['total_invested'] as num).toDouble(),
      );
}
