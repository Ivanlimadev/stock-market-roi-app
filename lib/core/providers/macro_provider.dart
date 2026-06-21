import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/macro_model.dart';

final macroUsProvider = FutureProvider.autoDispose<List<MacroIndicator>>((ref) async {
  final res = await ApiClient.dio.get('/macro/us');
  final list = res.data as List;
  return list.map((e) => MacroIndicator.fromJson(e as Map<String, dynamic>)).toList();
});

final macroDetailProvider =
    FutureProvider.autoDispose.family<MacroDetailData, String>((ref, id) async {
  final res = await ApiClient.dio.get('/macro/us/$id');
  return MacroDetailData.fromJson(res.data as Map<String, dynamic>);
});
