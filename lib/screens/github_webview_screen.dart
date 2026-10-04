import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

/// يفتح صفحة تفويض GitHub Device Flow داخل متصفح مدمج (WebView) بدل
/// الانتقال لتطبيق متصفح خارجي — المستخدم يبقى داخل Fluco Build بالكامل.
/// الرمز (userCode) مكتوب أعلى الشاشة ليبقى ظاهرًا أثناء تعبئته يدويًا.
class GitHubWebViewScreen extends StatefulWidget {
  final String verificationUri;
  final String userCode;

  const GitHubWebViewScreen({
    super.key,
    required this.verificationUri,
    required this.userCode,
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

  /// يحاول تعبئة حقل الرمز تلقائيًا عبر JavaScript بسيط.
  /// صفحة GitHub تستخدم عادة حقل إدخال واحد ظاهر لرمز التفويض؛
  /// إن تغيّر هيكل الصفحة مستقبلًا، يبقى بإمكان المستخدم الكتابة يدويًا —
  /// هذا تحسين لتجربة الاستخدام وليس أساسيًا لعمل تسجيل الدخول.
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
