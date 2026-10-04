import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/github_models.dart';
import '../services/auth_manager.dart';
import '../services/build_orchestrator.dart';
import '../services/file_installer.dart';
import '../theme/app_theme.dart';

class BuildProgressScreen extends StatefulWidget {
  final AuthManager authManager;
  final FlutterProject project;

  const BuildProgressScreen({super.key, required this.authManager, required this.project});

  @override
  State<BuildProgressScreen> createState() => _BuildProgressScreenState();
}

class _BuildProgressScreenState extends State<BuildProgressScreen> {
  final _orchestrator = BuildOrchestrator();
  final List<String> _logs = [];
  BuildStage _currentStage = BuildStage.creatingRepo;
  double _progress = 0;
  File? _resultApk;
  String? _failureMessage;

  @override
  void initState() {
    super.initState();
    _orchestrator.events.listen(_onEvent);
    _start();
  }

  Future<void> _start() async {
    final token = await widget.authManager.getAccessToken();
    if (token == null) {
      setState(() => _failureMessage = 'لم يتم العثور على جلسة تسجيل دخول صالحة');
      return;
    }

    final outputDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final repoName = widget.project.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    await _orchestrator.runFullBuild(
      token: token,
      projectFolder: Directory(widget.project.path),
      repoName: repoName,
      outputDir: Directory('${outputDir.path}/fluco_build'),
    );
  }

  void _onEvent(BuildEvent event) {
    setState(() {
      if (event is StageChangedEvent) {
        _currentStage = event.stage;
      } else if (event is LogEvent) {
        _logs.add(event.message);
      } else if (event is ProgressEvent) {
        _progress = event.fraction;
      } else if (event is FinishedEvent) {
        _resultApk = event.apkFile;
      } else if (event is FailedEvent) {
        _failureMessage = event.message;
      }
    });
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStagesList(),
              const SizedBox(height: 12),
              Expanded(child: _buildLogConsole()),
              const SizedBox(height: 12),
              _buildProgressBar(),
              if (_resultApk != null) _buildFinishedActions(),
              if (_failureMessage != null) _buildFailureBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStagesList() {
    final stages = [
      (BuildStage.creatingRepo, Icons.folder_open_rounded, 'إنشاء المستودع'),
      (BuildStage.uploading, Icons.cloud_upload_outlined, 'رفع الملفات'),
      (BuildStage.runningActions, Icons.settings_outlined, 'تشغيل GitHub Actions'),
      (BuildStage.buildingApk, Icons.build_outlined, 'بناء APK'),
      (BuildStage.downloading, Icons.download_outlined, 'تنزيل وتثبيت'),
    ];

    final currentIndex = stages.indexWhere((s) => s.$1 == _currentStage);

    return Column(
      children: stages.asMap().entries.map((entry) {
        final index = entry.key;
        final (stage, icon, label) = entry.value;
        final isDone = index < currentIndex || _resultApk != null;
        final isActive = index == currentIndex && _resultApk == null && _failureMessage == null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isDone || isActive) ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: isActive
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                        )
                      : Icon(
                          isDone ? Icons.check : icon,
                          color: isDone ? AppTheme.accent : AppTheme.textMuted,
                          size: 18,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLogConsole() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[_logs.length - 1 - index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              log,
              style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontFamily: 'monospace'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('التقدم الكلي للبناء', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            Text('${(_progress * 100).toInt()}%',
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            backgroundColor: AppTheme.surfaceAlt,
            valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => FileInstaller.install(_resultApk!),
          icon: const Icon(Icons.install_mobile_rounded),
          label: const Text('تثبيت التطبيق'),
        ),
      ),
    );
  }

  Widget _buildFailureBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
        ),
        child: Text(_failureMessage!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
      ),
    );
  }
}
