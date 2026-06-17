import 'package:dio/dio.dart';

class ApiClient {
  static const _baseUrl = 'https://stockmarketroi.com/api';

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Bypass iOS URLSession cache so prices always fetch fresh
        'Cache-Control': 'no-cache, no-store',
        'Pragma': 'no-cache',
      },
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          // Surface clean error messages
          final msg = error.response?.data is Map
              ? (error.response!.data as Map)['error'] ?? error.message
              : error.message;
          handler.next(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              message: msg?.toString(),
              type: error.type,
            ),
          );
        },
      ),
    );

  // Convenience methods
  static Future<T> get<T>(
    String path, {
    Map<String, dynamic>? params,
    T Function(dynamic)? fromJson,
  }) async {
    final res = await dio.get(path, queryParameters: params);
    return fromJson != null ? fromJson(res.data) : res.data as T;
  }

  static Future<T> post<T>(
    String path, {
    required Map<String, dynamic> body,
    T Function(dynamic)? fromJson,
  }) async {
    final res = await dio.post(path, data: body);
    return fromJson != null ? fromJson(res.data) : res.data as T;
  }
}
