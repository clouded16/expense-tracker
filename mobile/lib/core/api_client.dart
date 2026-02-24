import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider((ref) => ApiClient());

class ApiClient {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    return 'http://192.168.29.27:8000'; // your PC IP
  }

  final Dio dio;
  final FlutterSecureStorage storage;

  ApiClient()
      : dio = Dio(BaseOptions(baseUrl: baseUrl)),
        storage = const FlutterSecureStorage() {
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
              // Retry original request
              final requestOptions = error.requestOptions;

              final newToken = await storage.read(key: 'auth_token');

              requestOptions.headers['Authorization'] = 'Bearer $newToken';

              final clonedRequest = await dio.fetch(requestOptions);

              return handler.resolve(clonedRequest);
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
        options: Options(headers: {
          'Authorization': null, // remove old header
        }),
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