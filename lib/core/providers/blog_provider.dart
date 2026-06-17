import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/blog_post_model.dart';

final blogPostsProvider = FutureProvider.autoDispose<List<BlogPost>>((ref) async {
  final data = await ApiClient.get<List<dynamic>>('/blog/latest?limit=60');
  return data.map((e) => BlogPost.fromJson(e as Map<String, dynamic>)).toList();
});
