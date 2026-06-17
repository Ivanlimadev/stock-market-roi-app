import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/news_model.dart';

final marketNewsProvider = FutureProvider.autoDispose<List<NewsItem>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/news/market');
  return data.map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
});
