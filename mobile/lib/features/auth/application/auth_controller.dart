import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

    print("Startup refresh token: $refreshToken");

    if (refreshToken == null) {
      state = AuthStatus.unauthenticated;
      return;
    }

    final api = ref.read(apiClientProvider);

    final success = await api.tryRefreshOnStartup();

    print("Startup refresh result: $success");

    state = success
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
  }

  Future<void> loginSuccess() async {
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    final api = ref.read(apiClientProvider);

    try {
      final refresh = await storage.read(key: 'refresh_token');
      if (refresh != null) {
        await api.post('/auth/logout', {'refresh_token': refresh});
      }
    } catch (_) {}

    await storage.deleteAll();
    state = AuthStatus.unauthenticated;
  }
}