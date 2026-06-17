import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/stock_detail_model.dart';

final stockDetailProvider = FutureProvider.autoDispose
    .family<StockDetail, String>((ref, symbol) async {
  final res = await ApiClient.dio.get('/stocks/${symbol.toUpperCase()}');
  return StockDetail.fromJson(res.data as Map<String, dynamic>);
});

final stockHistoryProvider = FutureProvider.autoDispose
    .family<List<HistoryBar>, String>((ref, symbol) async {
  final res = await ApiClient.dio.get(
    '/stocks/${symbol.toUpperCase()}/history',
    queryParameters: {'range': '3m'},
  );
  final bars = (res.data['bars'] as List? ?? []);
  return bars
      .map((b) => HistoryBar.fromJson(b as Map<String, dynamic>))
      .where((b) => b.close > 0)
      .toList();
});
