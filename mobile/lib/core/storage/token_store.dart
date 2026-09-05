import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/session.dart';

abstract interface class TokenStore {
  Future<SessionTokens?> read();
  Future<void> write(SessionTokens tokens);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore(this.storage);
  final FlutterSecureStorage storage;
  static const _key = 'relaycontent.session.v1';

  @override
  Future<SessionTokens?> read() async {
    final raw = await storage.read(key: _key);
    if (raw == null) return null;
    try {
      return SessionTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(SessionTokens tokens) =>
      storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => storage.delete(key: _key);
}
