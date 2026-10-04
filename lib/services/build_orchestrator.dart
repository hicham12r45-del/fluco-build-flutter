import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import '../models/github_models.dart';
import 'github_api.dart';
import 'github_config.dart';
import 'project_uploader.dart';

enum BuildStage { creatingRepo, uploading, runningActions, buildingApk, downloading }

abstract class BuildEvent {}

class StageChangedEvent extends BuildEvent {
  final BuildStage stage;
  StageChangedEvent(this.stage);
}

class LogEvent extends BuildEvent {
  final String message;
  LogEvent(this.message);
}

class ProgressEvent extends BuildEvent {
  final double fraction; // 0.0..1.0
  ProgressEvent(this.fraction);
}

class FinishedEvent extends BuildEvent {
  final File apkFile;
  FinishedEvent(this.apkFile);
}

class FailedEvent extends BuildEvent {
  final String message;
  FailedEvent(this.message);
}

/// ينسّق تسلسل البناء الكامل: إنشاء مستودع → رفع الملفات → تشغيل
/// GitHub Actions → مراقبة النتيجة → تنزيل الـ APK.
/// يبث كل الأحداث عبر Stream بحيث يمكن لواجهة Flutter عرض السجل المباشر.
class BuildOrchestrator {
  final _uploader = ProjectUploader();
  final _controller = StreamController<BuildEvent>.broadcast();

  Stream<BuildEvent> get events => _controller.stream;

  Future<void> runFullBuild({
    required String token,
    required Directory projectFolder,
    required String repoName,
    required Directory outputDir,
  }) async {
    void emit(BuildEvent e) => _controller.add(e);

    // 1) إنشاء المستودع
    emit(StageChangedEvent(BuildStage.creatingRepo));
    emit(LogEvent('جارٍ إنشاء المستودع: $repoName'));

    final repoResult = await GitHubApi.createRepository(token, repoName);
    if (!repoResult.isSuccess || repoResult.data == null) {
      emit(FailedEvent('فشل إنشاء المستودع: ${repoResult.errorMessage}'));
      return;
    }
    final repo = repoResult.data!;
    emit(LogEvent('تم إنشاء المستودع بنجاح: ${repo.fullName}'));
    emit(ProgressEvent(0.1));

    // 2) رفع الملفات
    emit(StageChangedEvent(BuildStage.uploading));
    emit(LogEvent('بدء رفع الملفات إلى GitHub...'));

    final uploadResult = await _uploader.uploadProject(
      token: token,
      owner: repo.owner,
      repo: repo.name,
      projectRoot: projectFolder,
      onProgress: (progress) {
        emit(LogEvent('تم رفع: ${progress.currentFileName}'));
        final fraction = 0.1 + 0.3 * (progress.currentFileIndex / progress.totalFiles.clamp(1, 1 << 30));
        emit(ProgressEvent(fraction));
      },
    );

    if (!uploadResult.isSuccess) {
      emit(FailedEvent(uploadResult.errorMessage ?? 'فشل رفع الملفات'));
      return;
    }
    emit(LogEvent('تم رفع جميع الملفات بنجاح'));
    emit(ProgressEvent(0.4));

    // 3) تشغيل GitHub Actions
    emit(StageChangedEvent(BuildStage.runningActions));
    emit(LogEvent('تشغيل GitHub Actions workflow...'));

    await Future.delayed(const Duration(seconds: 3));

    final triggerResult = await GitHubApi.triggerWorkflow(
      token: token,
      owner: repo.owner,
      repo: repo.name,
      branch: repo.defaultBranch,
    );
    if (!triggerResult.isSuccess) {
      emit(FailedEvent('فشل تشغيل سير العمل: ${triggerResult.errorMessage}'));
      return;
    }
    emit(LogEvent('تم تشغيل سير العمل: ${GitHubConfig.workflowFile}'));
    emit(ProgressEvent(0.5));

    // 4) العثور على التشغيلة التي بدأناها للتو
    await Future.delayed(const Duration(seconds: 3));
    final runResult = await GitHubApi.getLatestWorkflowRun(
      token: token,
      owner: repo.owner,
      repo: repo.name,
    );
    if (!runResult.isSuccess || runResult.data == null) {
      emit(FailedEvent('تعذّر العثور على تشغيلة البناء: ${runResult.errorMessage}'));
      return;
    }
    final runId = runResult.data!.id;

    // 5) مراقبة حالة التشغيل حتى الاكتمال
    emit(StageChangedEvent(BuildStage.buildingApk));
    emit(LogEvent('جارٍ بناء APK على خوادم GitHub...'));

    var completed = false;
    var attempts = 0;
    const maxAttempts = 60; // ~10 دقائق

    while (!completed && attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 10));
      attempts++;

      final statusResult = await GitHubApi.getWorkflowRunStatus(
        token: token,
        owner: repo.owner,
        repo: repo.name,
        runId: runId,
      );

      if (statusResult.isSuccess && statusResult.data != null) {
        final run = statusResult.data!;
        emit(LogEvent('حالة البناء: ${run.status}'));
        emit(ProgressEvent(0.5 + 0.3 * (attempts / maxAttempts)));

        if (run.status == 'completed') {
          completed = true;
          if (run.conclusion != 'success') {
            emit(FailedEvent('فشل البناء على GitHub Actions (${run.conclusion})'));
            return;
          }
        }
      } else {
        emit(LogEvent('تعذّر التحقق من الحالة، إعادة المحاولة...'));
      }
    }

    if (!completed) {
      emit(FailedEvent('انتهت مهلة انتظار البناء'));
      return;
    }

    emit(LogEvent('اكتمل البناء بنجاح، جارٍ جلب سجل الملفات الناتجة...'));
    emit(ProgressEvent(0.85));

    // 6) تنزيل الـ APK
    emit(StageChangedEvent(BuildStage.downloading));

    final artifactsResult = await GitHubApi.listArtifacts(
      token: token,
      owner: repo.owner,
      repo: repo.name,
      runId: runId,
    );

    BuildArtifact? artifact;
    if (artifactsResult.isSuccess && artifactsResult.data != null) {
      for (final a in artifactsResult.data!) {
        if (a.name == GitHubConfig.artifactName) {
          artifact = a;
          break;
        }
      }
    }

    if (artifact == null) {
      emit(FailedEvent('لم يتم العثور على ملف APK الناتج'));
      return;
    }

    emit(LogEvent('جارٍ تنزيل APK من GitHub...'));
    final zipBytes = await GitHubApi.downloadArtifactZip(token, artifact.archiveDownloadUrl);
    if (zipBytes == null) {
      emit(FailedEvent('فشل تنزيل ملف APK'));
      return;
    }

    final apkFile = _extractApkFromZip(zipBytes, outputDir);
    if (apkFile == null) {
      emit(FailedEvent('فشل استخراج APK من الأرشيف المُنزَّل'));
      return;
    }

    emit(ProgressEvent(1.0));
    emit(LogEvent('تم تنزيل APK بنجاح: ${apkFile.path.split(Platform.pathSeparator).last}'));
    emit(FinishedEvent(apkFile));
  }

  /// GitHub يرجع الـ artifact كملف ZIP دائمًا؛ نستخرج ملف الـ APK منه
  File? _extractApkFromZip(List<int> zipBytes, Directory outputDir) {
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.apk')) {
          final outFile = File('${outputDir.path}/app-release.apk');
          outFile.writeAsBytesSync(file.content as List<int>);
          return outFile;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void dispose() {
    _controller.close();
  }
}
