import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../api/api_client.dart';
import '../models/portfolio_model.dart';
import 'realtime_price_provider.dart';

/// "Street mode": when true, monetary balances are masked across the
/// portfolio. In-memory (resets on restart), mirroring the theme preference.
final hideBalancesProvider = StateProvider<bool>((ref) => false);

// Ticker symbol → CoinGecko ID (mirrors realtime_price_provider's map)
const kCryptoTickerToCoinId = <String, String>{
  'BTC':  'bitcoin',
  'ETH':  'ethereum',
  'SOL':  'solana',
  'XRP':  'ripple',
  'ADA':  'cardano',
  'DOGE': 'dogecoin',
  'AVAX': 'avalanche-2',
  'LINK': 'chainlink',
  'LTC':  'litecoin',
  'BCH':  'bitcoin-cash',
  'DOT':  'polkadot',
  'UNI':  'uniswap',
  'ATOM': 'cosmos',
  'NEAR': 'near',
  'SHIB': 'shiba-inu',
  'TRX':  'tron',
  'XLM':  'stellar',
  'XMR':  'monero',
  'PEPE': 'pepe',
  'SUI':  'sui',
  'AAVE': 'aave',
};

// Raw holdings from Supabase view
final portfolioHoldingsProvider =
    FutureProvider.autoDispose<List<PortfolioHolding>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final res = await Supabase.instance.client
      .from('portfolio_holdings')
      .select()
      .eq('user_id', user.id)
      .order('total_cost', ascending: false);

  return (res as List)
      .map((e) => PortfolioHolding.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Uppercase symbols currently held in the portfolio — for "is this in my
/// portfolio?" checks (e.g. the add-to-portfolio button on the stock detail).
final portfolioSymbolsProvider = Provider.autoDispose<Set<String>>((ref) {
  final holdings = ref.watch(portfolioHoldingsProvider).valueOrNull ?? [];
  return holdings.map((h) => h.symbol.toUpperCase()).toSet();
});

/// Live quote for a stock holding: price + today's change % + sector.
typedef StockQuote = ({double price, double? changePct, String? sector});

// Live quotes for the stock holdings, fetched once. This deliberately does NOT
// watch the realtime crypto feed, so it isn't re-fetched on every WebSocket
// tick (which previously hammered the API and made the page reload-loop).
final _portfolioStockPricesProvider =
    FutureProvider.autoDispose<Map<String, StockQuote>>((ref) async {
  final holdings = await ref.watch(portfolioHoldingsProvider.future);
  final symbols = holdings
      .where((h) => h.assetType != 'crypto')
      .map((h) => h.symbol)
      .toSet();
  final quotes = <String, StockQuote>{};
  await Future.wait(symbols.map((sym) async {
    try {
      final res = await ApiClient.dio.get('/stocks/$sym');
      final data = res.data as Map<String, dynamic>?;
      // Price/change live at the response root; sector is under `info`.
      final price = (data?['currentPrice'] as num?)?.toDouble();
      if (price != null && price > 0) {
        final info = data?['info'] as Map<String, dynamic>?;
        quotes[sym] = (
          price: price,
          changePct: (data?['changePct'] as num?)?.toDouble(),
          sector: info?['sector'] as String?,
        );
      }
    } catch (_) {}
  }));
  return quotes;
});

// Holdings enriched with live prices: stock prices come from the cached
// provider above; crypto prices are reactive from the realtime feed. They're
// combined in-memory, so a crypto tick re-renders without re-fetching stocks.
final portfolioEnrichedProvider =
    FutureProvider.autoDispose<List<PortfolioHolding>>((ref) async {
  final holdings = await ref.watch(portfolioHoldingsProvider.future);
  if (holdings.isEmpty) return [];

  // read (not watch): take a one-shot snapshot of realtime crypto prices so a
  // WebSocket tick (many per second) doesn't re-run this provider — which made
  // the page flash its loading spinner over and over. Refreshes on pull-to-
  // refresh / invalidate.
  final cryptoPrices = ref.read(realtimePriceProvider);
  final stockQuotes = await ref.watch(_portfolioStockPricesProvider.future);

  return holdings.map((h) {
    if (h.assetType == 'crypto') {
      final coinId = kCryptoTickerToCoinId[h.symbol.toUpperCase()];
      final price = coinId != null ? cryptoPrices[coinId] : null;
      return price != null ? h.withPrice(price) : h;
    }
    final q = stockQuotes[h.symbol];
    return q != null
        ? h.withPrice(q.price, dayChangePct: q.changePct, sector: q.sector)
        : h;
  }).toList();
});

// Dividend info for each non-crypto holding
final portfolioDividendsProvider =
    FutureProvider.autoDispose<List<DividendInfo>>((ref) async {
  final holdings = await ref.watch(portfolioHoldingsProvider.future);
  final stockHoldings = holdings.where((h) => h.assetType != 'crypto').toList();
  if (stockHoldings.isEmpty) return [];

  return await Future.wait(stockHoldings.map((h) async {
    try {
      final res = await ApiClient.dio.get('/stocks/${h.symbol}');
      final info = res.data?['info'] as Map<String, dynamic>?;
      return DividendInfo(
        symbol: h.symbol,
        assetType: h.assetType,
        netShares: h.netShares,
        dividendRate: (info?['dividendRate'] as num?)?.toDouble(),
        dividendYield: (info?['dividendYield'] as num?)?.toDouble(),
        exDividendDate: info?['exDividendDate'] as String?,
        dividendDate: info?['dividendDate'] as String?,
        payoutRatio: (info?['payoutRatio'] as num?)?.toDouble(),
        costPerShare: h.avgPrice,
      );
    } catch (_) {
      return DividendInfo(
          symbol: h.symbol,
          assetType: h.assetType,
          netShares: h.netShares,
          costPerShare: h.avgPrice);
    }
  }));
});

// Dividends the user actually received, computed from their transaction
// history × each stock's dividend payment history (from /stocks/{sym}). For a
// payment on its ex-date, counts the net shares held strictly before that date.
// Estimate: ignores stock splits between the payment and today.
final portfolioReceivedDividendsProvider =
    FutureProvider.autoDispose<List<ReceivedDividend>>((ref) async {
  final txs = await ref.watch(portfolioTransactionsProvider.future);
  final symbols = txs
      .where((t) => t.assetType != 'crypto')
      .map((t) => t.symbol)
      .toSet();
  if (symbols.isEmpty) return [];

  final result = <ReceivedDividend>[];
  await Future.wait(symbols.map((sym) async {
    try {
      final res = await ApiClient.dio.get('/stocks/$sym');
      final divs = (res.data?['dividends'] as List?) ?? const [];
      final symTx = txs.where((t) => t.symbol == sym).toList();

      for (final d in divs) {
        final m = d as Map<String, dynamic>;
        final perShare = (m['dividend'] as num?)?.toDouble();
        final exDate = DateTime.tryParse(m['date'] as String? ?? '');
        if (perShare == null || perShare <= 0 || exDate == null) continue;

        // Net shares held strictly before the ex-dividend date.
        var shares = 0.0;
        for (final t in symTx) {
          final td = DateTime.tryParse(t.date);
          if (td != null && td.isBefore(exDate)) {
            shares += t.type == 'buy' ? t.quantity : -t.quantity;
          }
        }
        if (shares > 1e-9) {
          result.add(ReceivedDividend(
              symbol: sym, date: exDate, perShare: perShare, shares: shares));
        }
      }
    } catch (_) {}
  }));

  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
});

// Full transaction history
final portfolioTransactionsProvider =
    FutureProvider.autoDispose<List<PortfolioTransaction>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final res = await Supabase.instance.client
      .from('portfolio_transactions')
      .select()
      .eq('user_id', user.id)
      .order('date', ascending: false);

  return (res as List)
      .map((e) => PortfolioTransaction.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Portfolio history snapshots ────────────────────────────────────────────────

final portfolioSnapshotsProvider =
    FutureProvider.autoDispose<List<PortfolioSnapshot>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return [];
  final res = await Supabase.instance.client
      .from('portfolio_snapshots')
      .select('snapshot_date, total_value, total_invested')
      .eq('user_id', uid)
      .order('snapshot_date', ascending: true)
      .limit(90);
  return (res as List)
      .map((e) => PortfolioSnapshot.fromJson(e as Map<String, dynamic>))
      .toList();
});

Future<void> savePortfolioSnapshotIfNeeded({
  required double totalValue,
  required double totalInvested,
}) async {
  if (totalValue <= 0) return;
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final existing = await Supabase.instance.client
      .from('portfolio_snapshots')
      .select('id')
      .eq('user_id', uid)
      .eq('snapshot_date', today)
      .maybeSingle();

  if (existing != null) return;

  await Supabase.instance.client.from('portfolio_snapshots').insert({
    'user_id':        uid,
    'snapshot_date':  today,
    'total_value':    totalValue,
    'total_invested': totalInvested,
  });
}
