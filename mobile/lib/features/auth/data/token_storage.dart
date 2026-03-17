import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoredAuthSession {
  const StoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
    this.userId,
    this.email,
  });

  final String accessToken;
  final String refreshToken;
  final String? userId;
  final String? email;
}

abstract class TokenStorage {
  Future<StoredAuthSession?> readSession();
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? email,
  });
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'email';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredAuthSession?> readSession() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);

    if (accessToken == null || refreshToken == null) {
      return null;
    }

    return StoredAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: await _storage.read(key: _userIdKey),
      email: await _storage.read(key: _emailKey),
    );
  }

  @override
  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? email,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);

    if (userId != null) {
      await _storage.write(key: _userIdKey, value: userId);
    }
    if (email != null) {
      await _storage.write(key: _emailKey, value: email);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _emailKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage(const FlutterSecureStorage());
});
