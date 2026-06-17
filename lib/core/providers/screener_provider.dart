import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/market_model.dart';

final screenerProvider = FutureProvider.autoDispose<List<StockQuote>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/screener');
  return data.map((e) => StockQuote.fromJson(e as Map<String, dynamic>)).toList();
});

final trendingProvider = FutureProvider.autoDispose<List<StockQuote>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/trending');
  return data.map((e) => StockQuote.fromJson(e as Map<String, dynamic>)).toList();
});

final top10ByMarketCapProvider = Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) {
  return ref.watch(screenerProvider).whenData(
    (s) => ([...s]
      ..removeWhere((q) => (q.marketCap ?? 0) == 0)
      ..sort((a, b) => (b.marketCap ?? 0).compareTo(a.marketCap ?? 0))).take(10).toList(),
  );
});

final topGainersProvider = Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) {
  return ref.watch(screenerProvider).whenData(
    (s) => ([...s]
      ..removeWhere((q) => q.changePct <= 0)
      ..sort((a, b) => b.changePct.compareTo(a.changePct))).take(10).toList(),
  );
});

final topLosersProvider = Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) {
  return ref.watch(screenerProvider).whenData(
    (s) => ([...s]
      ..removeWhere((q) => q.changePct >= 0)
      ..sort((a, b) => a.changePct.compareTo(b.changePct))).take(10).toList(),
  );
});

final topByVolumeProvider = Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) {
  return ref.watch(screenerProvider).whenData(
    (s) => ([...s]
      ..removeWhere((q) => (q.volume ?? 0) == 0)
      ..sort((a, b) => (b.volume ?? 0).compareTo(a.volume ?? 0))).take(10).toList(),
  );
});

final topDividendProvider = Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) {
  return ref.watch(screenerProvider).whenData(
    (s) => ([...s]
      ..removeWhere((q) => (q.dividendYield ?? 0) == 0)
      ..sort((a, b) => (b.dividendYield ?? 0).compareTo(a.dividendYield ?? 0))).take(10).toList(),
  );
});
