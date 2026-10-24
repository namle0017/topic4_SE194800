import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> readToken();
  Future<void> writeToken(String value);
  Future<void> deleteToken();
}

class SecureStorageService implements TokenStorage {
  const SecureStorageService([this._storage = const FlutterSecureStorage()]);

  static const _tokenKey = 'application_access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String value) =>
      _storage.write(key: _tokenKey, value: value);

  @override
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}
