import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for backend
  static const String baseUrl = 'http://192.168.29.70:8000';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<Map<String, dynamic>> uploadReceipt(File image) async {
    final uri = Uri.parse('$baseUrl/ingest/ocr');
    final token = await _getToken();

    print("TOKEN BEING SENT: $token");

    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final fileStream = http.ByteStream(image.openRead());
    final length = await image.length();

    final multipartFile = http.MultipartFile('file', fileStream, length,
        filename: image.path.split('/').last);

    request.files.add(multipartFile);

    final streamed = await request.send();
    final respStr = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      // try to parse message
      String message = respStr;
      try {
        final j = json.decode(respStr);
        message = j['detail'] ?? j['message'] ?? json.encode(j);
      } catch (_) {}
      throw Exception('Upload failed: $message');
    }

    return json.decode(respStr) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getIngestion(int id) async {
    final uri = Uri.parse('$baseUrl/ingestion/$id');
    final token = await _getToken();
    final res = await http.get(uri, headers: token != null ? {'Authorization': 'Bearer $token'} : null);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to fetch ingestion: ${res.body}');
    }

    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> approveIngestion(int id, {required String merchantName, required String categoryName}) async {
    final uri = Uri.parse('$baseUrl/ingestion/$id/approve');
    final token = await _getToken();

    final body = json.encode({
      'merchant_name': merchantName,
      'category_name': categoryName,
    });

    final res = await http.patch(uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Approve failed: ${res.body}');
    }
  }

  Future<void> rejectIngestion(int id) async {
    final uri = Uri.parse('$baseUrl/ingestion/$id/reject');
    final token = await _getToken();
    final res = await http.patch(uri, headers: token != null ? {'Authorization': 'Bearer $token'} : null);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Reject failed: ${res.body}');
    }
  }
}

final apiService = ApiService();
