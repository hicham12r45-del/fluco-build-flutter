/// قواعد التحقق من صحة حقول إنشاء مشروع جديد.
class ProjectValidators {
  ProjectValidators._();

  /// اسم التطبيق: غير فارغ، بدون شرطة مائلة أو رموز قد تكسر مسار مجلد
  /// أو اسم مستودع GitHub (الذي سيُستخدم اسم التطبيق كاسم له مباشرة).
  static String? validateAppName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'اسم التطبيق مطلوب';
    if (trimmed.length > 50) return 'اسم التطبيق طويل جدًا';
    if (RegExp(r'[/\\:*?"<>|]').hasMatch(trimmed)) {
      return 'اسم التطبيق يحتوي على رموز غير مسموحة';
    }
    return null;
  }

  /// اسم الحزمة: صيغة Java/Kotlin package قياسية — أحرف صغيرة، أرقام،
  /// شرطة سفلية، مفصولة بنقاط، لا تبدأ بأي جزء برقم.
  static final RegExp packageNamePattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');

  static String? validatePackageName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'اسم الحزمة مطلوب';
    if (trimmed.length > 100) return 'اسم الحزمة طويل جدًا';
    if (!packageNamePattern.hasMatch(trimmed)) {
      return 'صيغة اسم الحزمة غير صحيحة';
    }
    return null;
  }

  static bool isPackageNameValid(String value) => validatePackageName(value) == null;
}
