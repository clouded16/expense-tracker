import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_lock_service.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

final authControllerProvider = Provider<AuthStatus>((ref) {
  final lock = ref.watch(appLockProvider);
  switch (lock.status) {
    case AppLockStatus.unlocked:
      return AuthStatus.authenticated;
    case AppLockStatus.locked:
    case AppLockStatus.unavailable:
      return AuthStatus.unauthenticated;
    case AppLockStatus.unlocking:
    case AppLockStatus.unknown:
      return AuthStatus.unknown;
  }
});

extension AuthControllerActions on WidgetRef {
  Future<void> logout() async {
    await read(appLockProvider.notifier).lock();
  }
}
