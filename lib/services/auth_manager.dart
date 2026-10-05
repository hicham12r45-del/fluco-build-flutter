import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/github_models.dart';
import 'github_api.dart';
import 'secure_store.dart';

enum AuthStatus { loggedOut, awaitingAuthorization, loggedIn, error }

/// ينسّق عملية GitHub Device Flow كاملة ويعرض حالته عبر ChangeNotifier.
///
/// بنية الاستطلاع (polling) هنا مبنية على نفس المبدأ المستخدم في تطبيقات
/// إنتاجية مشابهة تعتمد هذا التدفق بالذات: حلقة واحدة متواصلة (async loop
/// بدل Timer.periodic المتكرر)، تعمل بأكملها داخل try/catch واحد يغلّف كل
/// شيء من الاتصال بالشبكة إلى تفسير الرد، وتستدعي نتيجة واحدة فقط (نجاح
/// أو خطأ) في نهايتها. هذا يتجنب تمامًا مشكلة الطبقات المتعددة من
/// Timer + إعادة استدعاء ذاتية عند slow_down + حالة متبعثرة عبر عدة
/// أماكن — وهي الأسباب الجذرية التي جعلت الحالة تتجمّد صامتة سابقًا رغم
/// نجاح التفويض فعليًا على GitHub.
class AuthManager extends ChangeNotifier {
  AuthStatus status = AuthStatus.loggedOut;
  DeviceCodeResponse? pendingDeviceCode;
  String? errorMessage;
  String? username;

  // يُستخدم لإلغاء حلقة الاستطلاع الحالية إن بدأ المستخدم محاولة دخول جديدة
  int _loginAttemptId = 0;

  Future<void> initialize() async {
    try {
      final loggedIn = await SecureStore.instance.isLoggedIn();
      if (loggedIn) {
        username = await SecureStore.instance.getUsername();
        status = AuthStatus.loggedIn;
      } else {
        status = AuthStatus.loggedOut;
      }
    } catch (_) {
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
    final attemptId = ++_loginAttemptId;

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
    notifyListeners();

    // حلقة استطلاع واحدة متواصلة — نفس بنية الحلقة المرجعية: نوم بين كل
    // محاولة، ثم تحقق من المهلة الكلية، ثم طلب واحد، كل هذا داخل try/catch
    // واحد يغلّف الحلقة بأكملها.
    await _pollLoop(attemptId, result.data!);
  }

  Future<void> _pollLoop(int attemptId, DeviceCodeResponse deviceCode) async {
    try {
      final deadline = DateTime.now().add(Duration(seconds: deviceCode.expiresInSeconds));
      var interval = deviceCode.pollIntervalSeconds < 5 ? 5 : deviceCode.pollIntervalSeconds;

      while (true) {
        if (DateTime.now().isAfter(deadline)) {
          throw Exception('انتهت مهلة تسجيل الدخول، حاول مجددًا');
        }

        await Future.delayed(Duration(seconds: interval));

        // إن بدأ المستخدم محاولة دخول جديدة أثناء الانتظار، نوقف هذه
        // الحلقة القديمة بصمت بدل أن تتعارض مع المحاولة الجديدة.
        if (attemptId != _loginAttemptId) return;

        final result = await GitHubApi.pollForAccessToken(deviceCode.deviceCode);

        switch (result.status) {
          case TokenPollStatus.success:
            await _onLoginSuccess(result.accessToken!);
            return;

          case TokenPollStatus.pending:
            continue; // طبيعي — نكمل الحلقة وننتظر المستخدم

          case TokenPollStatus.slowDown:
            interval += 5;
            continue;

          case TokenPollStatus.expired:
            throw Exception('انتهت صلاحية رمز الجهاز، حاول مجددًا');

          case TokenPollStatus.denied:
            throw Exception('تم رفض التفويض');

          case TokenPollStatus.unknownError:
            throw Exception(result.errorMessage ?? 'خطأ غير معروف');
        }
      }
    } catch (e) {
      if (attemptId != _loginAttemptId) return; // محاولة قديمة أُلغيت بالفعل
      status = AuthStatus.error;
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> _onLoginSuccess(String accessToken) async {
    // نحفظ النتيجة النهائية بغض النظر عن نجاح الخطوات الفرعية (حفظ محلي،
    // جلب اسم المستخدم) — فشل خطوة فرعية لا يجب أن يُسقط تسجيل الدخول
    // بأكمله بصمت.
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
      // غير حرج — التوكن محفوظ بالفعل، يكفي لإكمال تسجيل الدخول
    }

    status = AuthStatus.loggedIn;
    pendingDeviceCode = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _loginAttemptId++; // يلغي أي حلقة استطلاع قديمة ما زالت قيد الانتظار
    try {
      await SecureStore.instance.clear();
    } catch (_) {
      // نكمل تسجيل الخروج محليًا حتى لو فشل المسح
    }
    username = null;
    pendingDeviceCode = null;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }
}
