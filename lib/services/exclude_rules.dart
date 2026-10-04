import 'dart:io';

/// قواعد استبعاد الملفات الحساسة أو غير الضرورية قبل الرفع إلى GitHub.
class ExcludeRules {
  ExcludeRules._();

  static const _excludedFolderNames = {
    '.git',
    'build',
    '.dart_tool',
    '.idea',
    'android/.gradle',
    'ios/Pods',
  };

  static const _excludedExtensions = {'jks', 'keystore', 'pem', 'p12'};
  static const _excludedFileNames = {'local.properties', 'key.properties'};

  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  static bool isExcludedDir(String dirName) => _excludedFolderNames.contains(dirName);

  static bool isExcludedFile(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';

    if (_excludedFileNames.contains(name)) return true;
    if (_excludedExtensions.contains(extension)) return true;

    try {
      if (file.lengthSync() > maxFileSizeBytes) return true;
    } catch (_) {
      return true; // تعذّر قراءة حجمه — الأسلم استبعاده
    }

    return false;
  }
}
