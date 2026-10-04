import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/github_models.dart';
import 'github_api.dart';
import 'secure_store.dart';

enum AuthStatus { loggedOut, awaitingAuthorization, loggedIn, error }

/// ينسّق عملية GitHub Device Flow كاملة ويعرض حالته عبر ChangeNotifier
/// بحيث تستطيع أي شاشة الاستماع للتغيّرات مباشرة.
class AuthManager extends ChangeNotifier {
  AuthStatus status = AuthStatus.loggedOut;
  DeviceCodeResponse? pendingDeviceCode;
  String? errorMessage;
  String? username;

  Timer? _pollTimer;
  int _elapsedSeconds = 0;

  Future<void> initialize() async {
    final loggedIn = await SecureStore.instance.isLoggedIn();
    if (loggedIn) {
      username = await SecureStore.instance.getUsername();
      status = AuthStatus.loggedIn;
    } else {
      status = AuthStatus.loggedOut;
    }
    notifyListeners();
  }

  Future<String?> getAccessToken() => SecureStore.instance.getAccessToken();

  Future<void> startLogin() async {
    final result = await GitHubApi.requestDeviceCode();

    if (!result.isSuccess || result.data == null) {
      status = AuthStatus.error;
      errorMessage = result.errorMessage;
      notifyListeners();
      return;
    }

    pendingDeviceCode = result.data;
    status = AuthStatus.awaitingAuthorization;
    _elapsedSeconds = 0;
    notifyListeners();

    _startPolling(result.data!);
  }

  void _startPolling(DeviceCodeResponse deviceCode) {
    _pollTimer?.cancel();
    var interval = deviceCode.pollIntervalSeconds;

    _pollTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
      _elapsedSeconds += interval;

      if (_elapsedSeconds >= deviceCode.expiresInSeconds) {
        timer.cancel();
        status = AuthStatus.error;
        errorMessage = 'انتهت مهلة تسجيل الدخول، حاول مجددًا';
        notifyListeners();
        return;
      }

      final result = await GitHubApi.pollForAccessToken(deviceCode.deviceCode);

      switch (result.status) {
        case TokenPollStatus.success:
          timer.cancel();
          await _onLoginSuccess(result.accessToken!);
          break;
        case TokenPollStatus.pending:
          // طبيعي — ننتظر المستخدم
          break;
        case TokenPollStatus.slowDown:
          timer.cancel();
          interval += 5;
          _startPolling(deviceCode);
          break;
        case TokenPollStatus.expired:
          timer.cancel();
          status = AuthStatus.error;
          errorMessage = 'انتهت صلاحية رمز الجهاز، حاول مجددًا';
          notifyListeners();
          break;
        case TokenPollStatus.denied:
          timer.cancel();
          status = AuthStatus.error;
          errorMessage = 'تم رفض التفويض';
          notifyListeners();
          break;
        case TokenPollStatus.unknownError:
          timer.cancel();
          status = AuthStatus.error;
          errorMessage = result.errorMessage;
          notifyListeners();
          break;
      }
    });
  }

  Future<void> _onLoginSuccess(String accessToken) async {
    await SecureStore.instance.saveAccessToken(accessToken);

    final userResult = await GitHubApi.getCurrentUser(accessToken);
    if (userResult.isSuccess && userResult.data != null) {
      username = userResult.data!.login;
      await SecureStore.instance.saveUsername(username!);
    }

    status = AuthStatus.loggedIn;
    pendingDeviceCode = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await SecureStore.instance.clear();
    username = null;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
