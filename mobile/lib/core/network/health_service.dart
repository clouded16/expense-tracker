import 'package:dio/dio.dart';
import '../api_client.dart';

class HealthService {
  static Future<String> checkHealth() async {
    final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));
    final response = await dio.get('/health');
    return response.data.toString();
  }
}
