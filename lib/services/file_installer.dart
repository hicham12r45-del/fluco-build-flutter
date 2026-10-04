import 'dart:io';
import 'package:open_filex/open_filex.dart';

/// يفتح/يثبّت ملف APK المُنزَّل عبر نظام أندرويد مباشرة.
/// open_filex يتولى إنشاء FileProvider URI المطلوب داخليًا.
class FileInstaller {
  FileInstaller._();

  static Future<void> install(File apkFile) async {
    await OpenFilex.open(apkFile.path);
  }
}
