import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// تخزين آمن (Keystore على أندرويد عبر flutter_secure_storage) لرمز GitHub
/// واسم المستخدم. flutter_secure_storage يستخدم EncryptedSharedPreferences
/// داخليًا على أندرويد — نفس الأسلوب الذي استخدمناه في نسخة Kotlin سابقًا.
class SecureStore {
  SecureStore._();
  static final SecureStore instance = SecureStore._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyAccessToken = 'github_access_token';
  static const _keyUsername = 'github_username';

  Future<void> saveAccessToken(String token) => _storage.write(key: _keyAccessToken, value: token);

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);

  Future<void> saveUsername(String username) => _storage.write(key: _keyUsername, value: username);

  Future<String?> getUsername() => _storage.read(key: _keyUsername);

  Future<bool> isLoggedIn() async => (await getAccessToken()) != null;

  Future<void> clear() => _storage.deleteAll();
}
