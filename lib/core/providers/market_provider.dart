import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/market_model.dart';

final marketOverviewProvider = FutureProvider.autoDispose<MarketOverview>((ref) async {
  final data = await ApiClient.get<Map<String, dynamic>>('/market');
  final timer = Timer(const Duration(minutes: 2), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return MarketOverview.fromJson(data);
});
