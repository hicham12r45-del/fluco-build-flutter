import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/github_models.dart';
import 'github_api.dart';
import 'secure_store.dart';

enum AuthStatus { loggedOut, awaitingAuthorization, loggedIn, error }

/// ينسّق عملية GitHub Device Flow كاملة ويعرض حالته عبر ChangeNotifier
/// بحيث تستطيع أي شاشة الاستماع للتغيّرات مباشرة.
///
/// كل مسار قد يرمي استثناءً (خصوصًا SecureStore الذي يعتمد على Keystore
/// وقد يفشل أحيانًا عند أول كتابة) محاط بـ try/catch صريح. بدون هذا،
/// استثناء غير متوقع داخل Timer.periodic يُبتلع صامتًا من قبل Dart
/// (التايمر يستمر لكن هذه الدورة تُفقد بلا أثر) ويترك الحالة عالقة
/// إلى الأبد على "awaitingAuthorization" حتى لو نجح التفويض فعليًا على GitHub.
class AuthManager extends ChangeNotifier {
  AuthStatus status = AuthStatus.loggedOut;
  DeviceCodeResponse? pendingDeviceCode;
  String? errorMessage;
  String? username;

  Timer? _pollTimer;
  int _elapsedSeconds = 0;

  Future<void> initialize() async {
    try {
      final loggedIn = await SecureStore.instance.isLoggedIn();
      if (loggedIn) {
        username = await SecureStore.instance.getUsername();
        status = AuthStatus.loggedIn;
      } else {
        status = AuthStatus.loggedOut;
      }
    } catch (e) {
      // فشل قراءة التخزين الآمن عند بدء التشغيل لا يجب أن يجمّد الشاشة
      // على splash للأبد — نعامله كغير مسجّل دخول ونكمل بشكل طبيعي.
      status = AuthStatus.loggedOut;
    }
    notifyListeners();
  }

  Future<String?> getAccessToken() async {
    try {
      return await SecureStore.instance.getAccessToken();
    } catch (_) {
      return null;
    }
  }

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
    errorMessage = null;
    _elapsedSeconds = 0;
    notifyListeners();

    _startPolling(result.data!);
  }

  void _startPolling(DeviceCodeResponse deviceCode) {
    _pollTimer?.cancel();
    var interval = deviceCode.pollIntervalSeconds;

    _pollTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
      // شبكة أمان شاملة: أي استثناء غير متوقع من أي مصدر هنا (شبكة،
      // تخزين آمن، تحليل JSON) يُمسك هنا بدل أن يُبتلع صامتًا من قبل
      // Dart ويُجمّد الحالة للأبد.
      try {
        await _pollOnce(timer, deviceCode, interval, (newInterval) => interval = newInterval);
      } catch (e) {
        timer.cancel();
        status = AuthStatus.error;
        errorMessage = 'حدث خطأ غير متوقع أثناء تسجيل الدخول: $e';
        notifyListeners();
      }
    });
  }

  Future<void> _pollOnce(
    Timer timer,
    DeviceCodeResponse deviceCode,
    int currentInterval,
    void Function(int) onIntervalChanged,
  ) async {
    _elapsedSeconds += currentInterval;

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
        onIntervalChanged(currentInterval + 5);
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
  }

  Future<void> _onLoginSuccess(String accessToken) async {
    // نحفظ الحالة الناجحة فورًا — حتى لو فشلت خطوات لاحقة (حفظ التوكن
    // محليًا، أو جلب اسم المستخدم)، يجب أن يرى المستخدم نتيجة واضحة
    // (نجاح أو خطأ صريح) بدل البقاء عالقًا على "في انتظار التفويض".
    try {
      await SecureStore.instance.saveAccessToken(accessToken);
    } catch (e) {
      status = AuthStatus.error;
      errorMessage = 'تعذّر حفظ جلسة تسجيل الدخول محليًا: $e';
      notifyListeners();
      return;
    }

    try {
      final userResult = await GitHubApi.getCurrentUser(accessToken);
      if (userResult.isSuccess && userResult.data != null) {
        username = userResult.data!.login;
        await SecureStore.instance.saveUsername(username!);
      }
    } catch (_) {
      // فشل جلب اسم المستخدم أو حفظه ليس سببًا كافيًا لإفشال تسجيل
      // الدخول بأكمله — التوكن نفسه محفوظ بنجاح بالفعل في الخطوة السابقة.
    }

    status = AuthStatus.loggedIn;
    pendingDeviceCode = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await SecureStore.instance.clear();
    } catch (_) {
      // حتى لو فشل مسح التخزين، نعيد حالة التطبيق لتسجيل الخروج محليًا
    }
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
