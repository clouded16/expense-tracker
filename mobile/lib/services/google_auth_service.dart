import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/config/google_config.dart';

class GoogleAuthService {
  final _googleSignIn = GoogleSignIn(
    serverClientId: GoogleConfig.webClientId,
  );

  Future<Map<String, dynamic>?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) return null;

    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    debugPrint('Google backend error: ${response.body}');
    return null;
  }
}
