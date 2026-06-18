import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/stock_detail_model.dart';

final stockDetailProvider = FutureProvider.autoDispose
    .family<StockDetail, String>((ref, symbol) async {
  final res = await ApiClient.dio.get('/stocks/${symbol.toUpperCase()}');
  final timer = Timer(const Duration(seconds: 60), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return StockDetail.fromJson(res.data as Map<String, dynamic>);
});

final stockHistoryProvider = FutureProvider.autoDispose
    .family<List<HistoryBar>, String>((ref, symbol) async {
  final res = await ApiClient.dio.get(
    '/stocks/${symbol.toUpperCase()}/history',
    queryParameters: {'range': '1y'},
  );
  final bars = (res.data['bars'] as List? ?? []);
  return bars
      .map((b) => HistoryBar.fromJson(b as Map<String, dynamic>))
      .where((b) => b.close > 0)
      .toList();
});

final stockLongHistoryProvider = FutureProvider.autoDispose
    .family<List<HistoryBar>, String>((ref, symbol) async {
  final res = await ApiClient.dio.get(
    '/stocks/${symbol.toUpperCase()}/history',
    queryParameters: {'period': '10y'},
  );
  final bars = (res.data['bars'] as List? ?? []);
  return bars
      .map((b) => HistoryBar.fromJson(b as Map<String, dynamic>))
      .where((b) => b.close > 0)
      .toList();
});

class AIInsight {
  final String verdict;   // BUY | HOLD | SELL
  final String confidence;
  final String summary;
  final String? bull;
  final String? bear;
  final bool cached;
  const AIInsight({
    required this.verdict, required this.confidence,
    required this.summary, this.bull, this.bear, required this.cached,
  });
  factory AIInsight.fromJson(Map<String, dynamic> j) => AIInsight(
    verdict:    j['verdict']    as String? ?? 'HOLD',
    confidence: j['confidence'] as String? ?? 'Low',
    summary:    j['summary']    as String? ?? '',
    bull:       j['bull']       as String?,
    bear:       j['bear']       as String?,
    cached:     j['cached']     as bool? ?? true,
  );
}

final stockAIInsightProvider = FutureProvider.autoDispose
    .family<AIInsight, String>((ref, symbol) async {
  final res = await ApiClient.dio.get('/stocks/${symbol.toUpperCase()}/insight');
  return AIInsight.fromJson(res.data as Map<String, dynamic>);
});
