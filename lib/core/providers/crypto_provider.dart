import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/crypto_model.dart';

final cryptoMarketsProvider = FutureProvider.autoDispose<List<CryptoMarket>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>(
    '/crypto/markets',
    params: {'limit': '100'},
  );
  return data.map((e) => CryptoMarket.fromJson(e as Map<String, dynamic>)).toList();
});

final cryptoGlobalProvider = FutureProvider.autoDispose<CryptoGlobal>((ref) async {
  final data = await ApiClient.get<Map<String, dynamic>>('/crypto/global');
  return CryptoGlobal.fromJson(data);
});

final cryptoTrendingProvider = FutureProvider.autoDispose<List<TrendingCoin>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/crypto/trending');
  return data.map((e) => TrendingCoin.fromJson(e as Map<String, dynamic>)).toList();
});

final cryptoFearGreedProvider = FutureProvider.autoDispose<FearGreedPoint>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/crypto/fear-greed');
  final list = (data).map((e) => FearGreedPoint.fromJson(e as Map<String, dynamic>)).toList();
  return list.first;
});
