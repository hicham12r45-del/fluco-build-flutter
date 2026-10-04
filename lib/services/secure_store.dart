import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// تخزين آمن (Keystore على أندرويد عبر flutter_secure_storage) لرمز GitHub
/// واسم المستخدم. flutter_secure_storage يستخدم EncryptedSharedPreferences
/// داخليًا على أندرويد.
///
/// resetOnError: true يجعل المكتبة تمسح البيانات التالفة تلقائيًا وتعيد
/// المحاولة بدل رمي استثناء Keystore دائم — هذا تحديدًا ما كان يسبب تجمّد
/// حالة تسجيل الدخول صامتًا عند أول كتابة فاشلة (مشكلة معروفة وموثّقة في
/// flutter_secure_storage على بعض أجهزة أندرويد).
///
/// كل دالة هنا محاطة أيضًا بـ try/catch في AuthManager (وليس هنا) حتى
/// تبقى هذه الطبقة بسيطة وتترك قرار المعالجة لمن يستدعيها.
class SecureStore {
  SecureStore._();
  static final SecureStore instance = SecureStore._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
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
