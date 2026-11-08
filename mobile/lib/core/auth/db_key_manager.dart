import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DbKeyManager {
  static const _keyName = 'cashscope_db_key_v1';

  final FlutterSecureStorage _storage;

  DbKeyManager([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final passphrase = base64UrlEncode(bytes);
    await _storage.write(key: _keyName, value: passphrase);
    return passphrase;
  }

  Future<void> wipe() => _storage.delete(key: _keyName);
}
