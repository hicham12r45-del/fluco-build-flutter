/// الإعدادات الثابتة للاتصال بـ GitHub.
/// لا يوجد Client Secret هنا لأن Device Flow لا يحتاجه إطلاقًا.
class GitHubConfig {
  GitHubConfig._();

  // معرّف تطبيق OAuth الخاص بـ Fluco Build
  static const String clientId = 'Ov23lieh5qYV2h9ElOGo';

  static const String deviceCodeUrl = 'https://github.com/login/device/code';
  static const String accessTokenUrl = 'https://github.com/login/oauth/access_token';

  static const String scopes = 'repo workflow';

  static const String apiBaseUrl = 'https://api.github.com';

  static const String workflowFile = 'main.yml';

  static const String artifactName = 'app-release';

  static const int defaultPollIntervalSeconds = 5;
}
