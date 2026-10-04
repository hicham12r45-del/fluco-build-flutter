import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_manager.dart';
import '../theme/app_theme.dart';

/// يفتح صفحة تفويض GitHub Device Flow داخل متصفح مدمج (WebView) بدل
/// الانتقال لتطبيق متصفح خارجي — المستخدم يبقى داخل Fluco Build بالكامل.
///
/// يستمع مباشرة لـ authManager ويغلق نفسه تلقائيًا (Navigator.pop) بمجرد
/// نجاح تسجيل الدخول في الخلفية — هذا ضروري لأن MaterialApp.home في main.dart
/// يستبدل الشجرة بالكامل عند تغيّر الحالة، وبدون هذا الإغلاق التلقائي
/// تبقى هذه الشاشة عالقة فوق الـ Navigator القديم حتى لو كان المستخدم
/// قد أكمل التفويض بنجاح فعليًا على صفحة GitHub.
class GitHubWebViewScreen extends StatefulWidget {
  final String verificationUri;
  final String userCode;
  final AuthManager authManager;

  const GitHubWebViewScreen({
    super.key,
    required this.verificationUri,
    required this.userCode,
    required this.authManager,
  });

  @override
  State<GitHubWebViewScreen> createState() => _GitHubWebViewScreenState();
}

class _GitHubWebViewScreenState extends State<GitHubWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    widget.authManager.addListener(_onAuthChanged);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) {
            setState(() => _isLoading = false);
            _tryAutofillCode();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.verificationUri));
  }

  void _onAuthChanged() {
    // بمجرد نجاح تسجيل الدخول (أو حدوث خطأ) في الخلفية، نغلق هذه الشاشة
    // تلقائيًا حتى تظهر الشاشة الرئيسية التي استبدلتها MaterialApp فورًا.
    final status = widget.authManager.status;
    if (status == AuthStatus.loggedIn || status == AuthStatus.error) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    widget.authManager.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// يحاول تعبئة حقل الرمز تلقائيًا عبر JavaScript بسيط.
  Future<void> _tryAutofillCode() async {
    final js = '''
      (function() {
        var inputs = document.querySelectorAll('input[type="text"], input:not([type])');
        for (var i = 0; i < inputs.length; i++) {
          if (inputs[i].offsetParent !== null) {
            inputs[i].value = "${widget.userCode}";
            inputs[i].dispatchEvent(new Event('input', { bubbles: true }));
            break;
          }
        }
      })();
    ''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // تجاهل بصمت — التعبئة اليدوية تبقى متاحة دائمًا
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.userCode,
          style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(color: AppTheme.accent, minHeight: 2),
        ],
      ),
    );
  }
}
