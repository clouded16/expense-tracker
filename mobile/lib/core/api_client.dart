import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  static const String baseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

  final Dio dio;
  final FlutterSecureStorage storage;

  ApiClient()
      : dio = Dio(BaseOptions(baseUrl: baseUrl)),
        storage = const FlutterSecureStorage() {
          print("API Client initialized with base URL: $baseUrl");
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: 'auth_token');

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },

        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {

            final refreshed = await _attemptRefresh();

            if (refreshed) {
              final newToken = await storage.read(key: 'auth_token');

              error.requestOptions.headers['Authorization'] =
                  'Bearer $newToken';

              final retryResponse = await dio.fetch(error.requestOptions);

              return handler.resolve(retryResponse);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _attemptRefresh() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');

      if (refreshToken == null) return false;

      final response = await dio.post(
        '/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
        options: Options(
          headers: {},
          extra: {'requiresAuth': false},
        ),
      );

      final newAccess = response.data['access_token'];
      final newRefresh = response.data['refresh_token'];

      await storage.write(key: 'auth_token', value: newAccess);
      await storage.write(key: 'refresh_token', value: newRefresh);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> tryRefreshOnStartup() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));

      final response = await refreshDio.post(
        '/auth/refresh',
        data: {
          'refresh_token': refreshToken,
        },
      );

      await storage.write(
          key: 'auth_token', value: response.data['access_token']);
      await storage.write(
          key: 'refresh_token', value: response.data['refresh_token']);

      return true;
    } catch (_) {
      return false;
    }
  }

  
  Future<Response> get(String path) => dio.get(path);
  Future<Response> post(String path, dynamic data) => dio.post(path, data: data);
  Future<Response> put(String path, dynamic data) => dio.put(path, data: data);
  Future<Response> delete(String path) => dio.delete(path);
}