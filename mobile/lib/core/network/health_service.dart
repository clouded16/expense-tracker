import 'package:http/http.dart' as http;

class HealthService {
  static Future<String> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/health"),
      );

      if (response.statusCode == 200) {
        return "Backend is healthy ✅";
      } else {
        return "Backend error: ${response.statusCode}";
      }
    } catch (e) {
      return "Connection failed: $e";
    }
  }
}