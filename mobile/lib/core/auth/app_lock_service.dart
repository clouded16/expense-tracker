import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../db/database.dart';
import 'db_key_manager.dart';

enum AppLockStatus {
  unknown,
  locked,
  unlocking,
  unlocked,
  unavailable,
}

class AppLockState {
  final AppLockStatus status;
  final AppDatabase? db;
  final String? error;

  const AppLockState({
    required this.status,
    this.db,
    this.error,
  });

  const AppLockState.initial() : this(status: AppLockStatus.unknown);

  AppLockState copyWith({
    AppLockStatus? status,
    AppDatabase? db,
    String? error,
    bool clearError = false,
    bool clearDb = false,
  }) {
    return AppLockState(
      status: status ?? this.status,
      db: clearDb ? null : (db ?? this.db),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final appLockProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final state = ref.watch(appLockProvider);
  final db = state.db;
  if (db == null) {
    throw StateError('App is locked. Database is not available.');
  }
  return db;
});

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController({
    LocalAuthentication? localAuth,
    DbKeyManager? keyManager,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _keyManager = keyManager ?? DbKeyManager(),
        super(const AppLockState.initial()) {
    _bootstrap();
  }

  final LocalAuthentication _localAuth;
  final DbKeyManager _keyManager;

  Future<void> _bootstrap() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) {
        state = state.copyWith(
          status: AppLockStatus.unavailable,
          error: 'Device does not support biometric/PIN auth',
        );
        return;
      }
      state = state.copyWith(status: AppLockStatus.locked, clearError: true);
    } catch (e) {
      state = state.copyWith(
        status: AppLockStatus.unavailable,
        error: e.toString(),
      );
    }
  }

  Future<bool> unlock() async {
    if (state.status == AppLockStatus.unlocked && state.db != null) return true;
    state = state.copyWith(status: AppLockStatus.unlocking, clearError: true);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock CashScope to access your finances',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!authenticated) {
        state = state.copyWith(
          status: AppLockStatus.locked,
          error: 'Authentication cancelled',
        );
        return false;
      }

      final passphrase = await _keyManager.getOrCreate();
      final db = AppDatabase(openEncryptedDatabase(passphrase));
      await db.customSelect('SELECT 1;').get();

      state = AppLockState(status: AppLockStatus.unlocked, db: db);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AppLockStatus.locked,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> lock() async {
    final db = state.db;
    if (db != null) {
      await db.close();
    }
    state = const AppLockState(status: AppLockStatus.locked);
  }
}
