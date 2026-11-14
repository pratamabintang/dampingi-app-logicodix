import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/stored_session.dart';

/// The device-local home of the remembered Session and the email that
/// "Ingat saya" remembers. Both live in secure storage: tokens are equivalent
/// to passwords, and the email is still personal data.
abstract interface class SessionStore {
  Future<StoredSession?> readSession();

  Future<void> writeSession(StoredSession session);

  Future<void> clearSession();

  Future<String?> readEmail();

  Future<void> writeEmail(String email);

  Future<void> clearEmail();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore(this._storage);

  static const _sessionKey = 'dampingi.session.v1';
  static const _emailKey = 'dampingi.remembered-email.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return StoredSession.fromJson(decoded);
    } on FormatException {
      // A truncated or older payload is useless, not fatal: treat it as no
      // Session so the user simply logs in again.
      return null;
    }
  }

  @override
  Future<void> writeSession(StoredSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clearSession() => _storage.delete(key: _sessionKey);

  @override
  Future<String?> readEmail() async {
    final email = await _storage.read(key: _emailKey);
    if (email == null || email.isEmpty) return null;
    return email;
  }

  @override
  Future<void> writeEmail(String email) =>
      _storage.write(key: _emailKey, value: email);

  @override
  Future<void> clearEmail() => _storage.delete(key: _emailKey);
}

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(ref.watch(secureStorageProvider)),
);
