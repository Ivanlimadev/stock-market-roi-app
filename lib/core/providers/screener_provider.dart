import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/market_model.dart';

final screenerProvider = FutureProvider.autoDispose<List<StockQuote>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/screener');
  return data.map((e) => StockQuote.fromJson(e as Map<String, dynamic>)).toList();
});

// Top gainers and losers derived from screener
final topGainersProvider = Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) {
  return ref.watch(screenerProvider).whenData(
    (stocks) => [...stocks]
      ..sort((a, b) => b.changePct.compareTo(a.changePct))
      ..take(10).toList(),
  );
});

final topLosersProvider = Provider.autoDispose<AsyncValue<List<StockQuote>>>((ref) {
  return ref.watch(screenerProvider).whenData(
    (stocks) => [...stocks]
      ..sort((a, b) => a.changePct.compareTo(b.changePct))
      ..take(10).toList(),
  );
});
