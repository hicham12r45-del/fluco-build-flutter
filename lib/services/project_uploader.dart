import 'dart:io';
import '../models/github_models.dart';
import 'exclude_rules.dart';
import 'github_api.dart';
import 'github_config.dart';
import 'workflow_generator.dart';

class UploadProgress {
  final int currentFileIndex;
  final int totalFiles;
  final String currentFileName;

  UploadProgress({
    required this.currentFileIndex,
    required this.totalFiles,
    required this.currentFileName,
  });
}

/// يمسح مجلد مشروع Flutter محليًا، يستبعد الملفات الحساسة، ثم يرفعها
/// واحدًا تلو الآخر عبر GitHub Contents API.
class ProjectUploader {
  /// يجمع كل الملفات القابلة للرفع من مجلد المشروع، مع مسارها النسبي
  List<MapEntry<File, String>> collectFiles(Directory projectRoot) {
    final result = <MapEntry<File, String>>[];

    void walk(Directory dir) {
      List<FileSystemEntity> children;
      try {
        children = dir.listSync();
      } catch (_) {
        return;
      }

      for (final child in children) {
        final name = child.path.split(Platform.pathSeparator).last;

        if (child is Directory) {
          if (ExcludeRules.isExcludedDir(name)) continue;
          walk(child);
        } else if (child is File) {
          if (ExcludeRules.isExcludedFile(child)) continue;
          final relativePath = child.path
              .substring(projectRoot.path.length)
              .replaceAll(Platform.pathSeparator, '/')
              .replaceFirst(RegExp(r'^/'), '');
          result.add(MapEntry(child, relativePath));
        }
      }
    }

    walk(projectRoot);
    return result;
  }

  /// يرفع كل ملفات المشروع بالتسلسل، بما فيها ملف الـ workflow المولّد.
  Future<ApiResult<void>> uploadProject({
    required String token,
    required String owner,
    required String repo,
    required Directory projectRoot,
    required void Function(UploadProgress progress) onProgress,
  }) async {
    final files = collectFiles(projectRoot);
    final totalSteps = files.length + 1; // +1 لملف الـ workflow

    // رفع ملف GitHub Actions workflow أولاً
    onProgress(UploadProgress(
      currentFileIndex: 0,
      totalFiles: totalSteps,
      currentFileName: '.github/workflows/${GitHubConfig.workflowFile}',
    ));

    final workflowResult = await GitHubApi.uploadFile(
      token: token,
      owner: owner,
      repo: repo,
      path: '.github/workflows/${GitHubConfig.workflowFile}',
      contentBytes: WorkflowGenerator.generate().codeUnits,
      commitMessage: 'Fluco Build: add workflow',
    );

    if (!workflowResult.isSuccess) {
      return ApiResult.error('فشل رفع ملف سير العمل: ${workflowResult.errorMessage}');
    }

    // بقية ملفات المشروع
    for (var i = 0; i < files.length; i++) {
      final entry = files[i];
      onProgress(UploadProgress(
        currentFileIndex: i + 1,
        totalFiles: totalSteps,
        currentFileName: entry.value,
      ));

      final bytes = await entry.key.readAsBytes();
      final result = await GitHubApi.uploadFile(
        token: token,
        owner: owner,
        repo: repo,
        path: entry.value,
        contentBytes: bytes,
        commitMessage: 'Fluco Build: upload ${entry.value}',
      );

      if (!result.isSuccess) {
        return ApiResult.error('فشل رفع الملف: ${entry.value} — ${result.errorMessage}');
      }
    }

    return ApiResult.success(null);
  }
}
