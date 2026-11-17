import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _tokenTypeKey = 'token_type';

  Future<void> saveAccessToken({
    required String accessToken,
    String tokenType = 'Bearer',
  }) async {
    final token = accessToken.trim();

    if (token.isEmpty) {
      throw ArgumentError('Access token cannot be empty.');
    }

    await _storage.write(key: _accessTokenKey, value: token);

    await _storage.write(
      key: _tokenTypeKey,
      value: tokenType.trim().isEmpty ? 'Bearer' : tokenType.trim(),
    );
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);

    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return token;
  }

  Future<String?> getTokenType() async {
    return _storage.read(key: _tokenTypeKey);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _tokenTypeKey);
  }

  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null;
  }
}
