import 'package:flutter/material.dart';
import '../services/auth_manager.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final AuthManager authManager;

  const SettingsScreen({super.key, required this.authManager});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoInstall = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel('الحساب'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  leading: const CircleAvatar(radius: 18, backgroundColor: AppTheme.surfaceAlt),
                  title: '@${widget.authManager.username ?? ''}',
                  subtitle: 'GitHub',
                ),
                const Divider(color: AppTheme.border, height: 1),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  iconColor: AppTheme.danger,
                  title: 'تسجيل الخروج',
                  titleColor: AppTheme.danger,
                  subtitle: 'إلغاء ربط حساب GitHub',
                  onTap: () async {
                    await widget.authManager.logout();
                    if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('البناء'),
            _SettingsGroup(
              children: [
                _SettingsToggleRow(
                  icon: Icons.install_mobile_rounded,
                  title: 'تثبيت تلقائي بعد البناء',
                  subtitle: 'سيتم تثبيت التطبيق تلقائيًا بعد نجاح البناء',
                  value: _autoInstall,
                  onChanged: (v) => setState(() => _autoInstall = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('عن التطبيق'),
            _SettingsGroup(
              children: [
                _SettingsRow(icon: Icons.sell_outlined, title: 'إصدار التطبيق', subtitle: 'v1.0.0'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(text, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsRow({
    this.icon,
    this.leading,
    this.iconColor = AppTheme.accent,
    required this.title,
    this.titleColor,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: leading ??
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
      title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: AppTheme.accent, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
