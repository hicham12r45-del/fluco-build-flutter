import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/github_models.dart';
import '../services/project_scaffolder.dart';
import '../services/project_validators.dart';
import '../theme/app_theme.dart';

const _flutterVersions = ['3.47.2 (الأحدث)', '3.35.0', '3.32.4', '3.29.0'];
const _targetApis = ['36 (Android 16)', '35 (Android 15)', '34 (Android 14)', '33 (Android 13)'];

class NewProjectScreen extends StatefulWidget {
  /// يُستدعى بعد إنشاء المشروع بنجاح على القرص، لإضافته لقائمة
  /// المشاريع الأخيرة في الشاشة الرئيسية.
  final void Function(FlutterProject project) onProjectCreated;

  const NewProjectScreen({super.key, required this.onProjectCreated});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _appNameController = TextEditingController();
  final _packageNameController = TextEditingController(text: 'com.example.myapp');

  String _flutterVersion = _flutterVersions.first;
  String _targetApi = _targetApis.firstWhere((v) => v.startsWith('33'));
  bool _isPrivateRepo = false;
  File? _iconFile;
  bool _isCreating = false;
  String? _creationError;

  String? _appNameError;
  String? _packageNameError;

  @override
  void dispose() {
    _appNameController.dispose();
    _packageNameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => _iconFile = File(result.files.single.path!));
  }

  Future<void> _pickFlutterVersion() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => _OptionsSheet(title: 'إصدار Flutter', options: _flutterVersions, selected: _flutterVersion),
    );
    if (selected != null) setState(() => _flutterVersion = selected);
  }

  Future<void> _pickTargetApi() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => _OptionsSheet(title: 'Target API', options: _targetApis, selected: _targetApi),
    );
    if (selected != null) setState(() => _targetApi = selected);
  }

  bool _validateAll() {
    setState(() {
      _appNameError = ProjectValidators.validateAppName(_appNameController.text);
      _packageNameError = ProjectValidators.validatePackageName(_packageNameController.text);
    });
    return _appNameError == null && _packageNameError == null;
  }

  Future<void> _createProject() async {
    if (!_validateAll()) return;

    setState(() {
      _isCreating = true;
      _creationError = null;
    });

    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      final projectsRoot = Directory('${appDocsDir.path}/fluco_projects');

      final spec = NewProjectSpec(
        appName: _appNameController.text.trim(),
        packageName: _packageNameController.text.trim(),
        flutterVersion: _flutterVersion,
        targetApi: _targetApi,
        isPrivateRepo: _isPrivateRepo,
        iconFile: _iconFile,
      );

      final projectDir = await ProjectScaffolder().createProject(projectsRoot, spec);

      if (!mounted) return;

      widget.onProjectCreated(FlutterProject(
        name: spec.appName,
        path: projectDir.path,
        packageName: spec.packageName,
      ));

      Navigator.pop(context);
    } catch (e) {
      setState(() => _creationError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Spacer(),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('إنشاء مشروع جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text(
                          'ابدأ مشروعك بسهولة عن طريق إعداد كل التفاصيل ثم إنشاء المشروع.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.flutter_dash_rounded, color: Colors.lightBlueAccent, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _FieldLabel(icon: Icons.notes_rounded, label: 'اسم التطبيق'),
            TextField(
              controller: _appNameController,
              decoration: InputDecoration(hintText: 'My App', errorText: _appNameError),
              onChanged: (_) {
                if (_appNameError != null) setState(() => _appNameError = null);
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'ملاحظة: سيتم استخدام اسم التطبيق كاسم المستودع على GitHub، تأكد من اختيار اسم فريد.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.inventory_2_outlined, label: 'اسم الحزمة'),
            TextField(
              controller: _packageNameController,
              decoration: InputDecoration(hintText: 'com.example.myapp', errorText: _packageNameError),
              onChanged: (_) {
                if (_packageNameError != null) setState(() => _packageNameError = null);
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'يجب أن يكون اسم الحزمة بصيغة صحيحة وبدون مسافات.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.flutter_dash_rounded, label: 'إصدار Flutter'),
            _PickerField(value: _flutterVersion, onTap: _pickFlutterVersion),
            const SizedBox(height: 4),
            const Text('نوصي باستخدام أحدث إصدار للحصول على أفضل أداء.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.android_rounded, label: 'Target API'),
            _PickerField(value: _targetApi, onTap: _pickTargetApi),
            const SizedBox(height: 4),
            const Text('حدد إصدار Android المستهدف لمشروعك.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.code_rounded, label: 'نوع المشروع على GitHub'),
            Row(
              children: [
                Expanded(
                  child: _VisibilityOption(
                    icon: Icons.lock_outline_rounded,
                    title: 'خاص (Private)',
                    subtitle: 'مخصص خاص ولا يمكن لأي شخص رؤيته',
                    selected: _isPrivateRepo,
                    onTap: () => setState(() => _isPrivateRepo = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VisibilityOption(
                    icon: Icons.public_rounded,
                    title: 'عام (Public)',
                    subtitle: 'متاح للجميع ومجاني',
                    selected: !_isPrivateRepo,
                    onTap: () => setState(() => _isPrivateRepo = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _FieldLabel(icon: Icons.image_outlined, label: 'أيقونة التطبيق (اختياري)'),
            GestureDetector(
              onTap: _pickIcon,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _iconFile?.path.split('/').last ?? 'اختر أيقونة',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ),
                    if (_iconFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(_iconFile!, width: 28, height: 28, fit: BoxFit.cover),
                      )
                    else
                      const Icon(Icons.image_outlined, color: AppTheme.textMuted, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'يمكنك اختيار أيقونة مخصصة لتطبيقك (بصيغة JPG أو PNG).',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            if (_creationError != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                ),
                child: Text(_creationError!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCreating ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCreating ? null : _createProject,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: Text(_isCreating ? 'جارٍ الإنشاء...' : 'إنشاء'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FieldLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _PickerField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: const TextStyle(fontSize: 14)),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withOpacity(0.1) : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: selected ? AppTheme.accent : AppTheme.textMuted),
                const Spacer(),
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 18,
                  color: selected ? AppTheme.accent : AppTheme.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _OptionsSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;

  const _OptionsSheet({required this.title, required this.options, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...options.map((option) => ListTile(
                title: Text(option),
                trailing: option == selected ? const Icon(Icons.check_rounded, color: AppTheme.accent) : null,
                onTap: () => Navigator.pop(context, option),
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
