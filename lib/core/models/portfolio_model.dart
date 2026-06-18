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

  const PortfolioHolding({
    required this.symbol,
    required this.assetType,
    required this.netShares,
    required this.avgPrice,
    required this.totalCost,
    this.firstPurchaseDate,
    this.currentPrice,
  });

  factory PortfolioHolding.fromJson(Map<String, dynamic> j) => PortfolioHolding(
        symbol: j['symbol'] as String,
        assetType: j['asset_type'] as String? ?? 'stock',
        netShares: (j['net_shares'] as num).toDouble(),
        avgPrice: (j['avg_price'] as num).toDouble(),
        totalCost: (j['total_cost'] as num).toDouble(),
        firstPurchaseDate: j['first_purchase_date'] as String?,
      );

  PortfolioHolding withPrice(double price) => PortfolioHolding(
        symbol: symbol,
        assetType: assetType,
        netShares: netShares,
        avgPrice: avgPrice,
        totalCost: totalCost,
        firstPurchaseDate: firstPurchaseDate,
        currentPrice: price,
      );

  double get effectivePrice => currentPrice ?? avgPrice;
  double get currentValue => netShares * effectivePrice;
  double get costBasis => totalCost;
  double get gainLoss => currentValue - costBasis;
  double get gainLossPct => costBasis > 0 ? (gainLoss / costBasis) * 100 : 0;
  bool get hasLivePrice => currentPrice != null;
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

  const DividendInfo({
    required this.symbol,
    required this.assetType,
    required this.netShares,
    this.dividendRate,
    this.dividendYield,
    this.exDividendDate,
    this.dividendDate,
    this.payoutRatio,
  });

  bool get paysDividends => (dividendRate ?? 0) > 0;
  double get annualTotal => (dividendRate ?? 0) * netShares;
  double get yieldPct => (dividendYield ?? 0) * 100;
}
