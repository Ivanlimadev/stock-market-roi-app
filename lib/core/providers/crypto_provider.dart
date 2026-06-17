import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/crypto_model.dart';

final cryptoMarketsProvider = FutureProvider.autoDispose<List<CryptoMarket>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/crypto/markets', params: {'limit': '20'});
  return data.map((e) => CryptoMarket.fromJson(e as Map<String, dynamic>)).toList();
});
