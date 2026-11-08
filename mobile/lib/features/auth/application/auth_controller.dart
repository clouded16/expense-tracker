import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/api_client.dart';


enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthStatus>(
        (ref) => AuthController(ref));

class AuthController extends StateNotifier<AuthStatus> {
  final Ref ref;
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  AuthController(this.ref) : super(AuthStatus.unknown) {
    _initialize();
  }

  Future<void> _initialize() async {
    final refreshToken = await storage.read(key: 'refresh_token');

    debugPrint("Startup refresh token: ${refreshToken != null ? '[present]' : '[null]'}");

    if (refreshToken == null) {
      state = AuthStatus.unauthenticated;
      return;
    }

    final api = ref.read(apiClientProvider);

    final success = await api.tryRefreshOnStartup();

    debugPrint("Startup refresh result: $success");

    state = success
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
  }

  Future<void> loginSuccess() async {
    
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    state = AuthStatus.unauthenticated; // First

    try {
      final refresh = await storage.read(key: 'refresh_token');
      if (refresh != null) {
        final api = ref.read(apiClientProvider);
        await api.post('/auth/logout', {'refresh_token': refresh});
      }
    } catch (_) {}

    await storage.deleteAll();

    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
  }
}