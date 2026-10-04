import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_manager.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatelessWidget {
  final AuthManager authManager;

  const LoginScreen({super.key, required this.authManager});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authManager,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 72),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: AppTheme.accent, size: 44),
                  ),
                  const SizedBox(height: 20),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(text: 'Fluco ', style: TextStyle(color: Colors.white)),
                        TextSpan(text: 'Build', style: TextStyle(color: AppTheme.accent)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ابنِ تطبيقات Flutter من هاتفك عبر GitHub Actions',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: authManager.status == AuthStatus.awaitingAuthorization
                          ? null
                          : () => authManager.startLogin(),
                      icon: const Icon(Icons.code_rounded, size: 20),
                      label: const Text('تسجيل الدخول عبر GitHub'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (authManager.status == AuthStatus.awaitingAuthorization &&
                      authManager.pendingDeviceCode != null)
                    _DeviceCodeCard(
                      userCode: authManager.pendingDeviceCode!.userCode,
                      verificationUri: authManager.pendingDeviceCode!.verificationUri,
                    ),
                  if (authManager.status == AuthStatus.error && authManager.errorMessage != null)
                    _ErrorCard(message: authManager.errorMessage!),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeviceCodeCard extends StatelessWidget {
  final String userCode;
  final String verificationUri;

  const _DeviceCodeCard({required this.userCode, required this.verificationUri});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 28),
                Text(
                  userCode,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppTheme.accent, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: userCode));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(verificationUri), mode: LaunchMode.externalApplication),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'افتح ',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  TextSpan(
                    text: verificationUri.replaceAll('https://', ''),
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(
                    text: ' وأدخل هذا الرمز',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2.5),
          ),
          const SizedBox(height: 10),
          const Text('في انتظار التفويض...', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
        ],
      ),
    );
  }
}
