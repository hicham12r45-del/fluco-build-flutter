/// كل نماذج البيانات المستخدمة في التواصل مع GitHub API.

class DeviceCodeResponse {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresInSeconds;
  final int pollIntervalSeconds;

  DeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresInSeconds,
    required this.pollIntervalSeconds,
  });

  factory DeviceCodeResponse.fromJson(Map<String, dynamic> json) => DeviceCodeResponse(
        deviceCode: json['device_code'] as String,
        userCode: json['user_code'] as String,
        verificationUri: json['verification_uri'] as String,
        expiresInSeconds: json['expires_in'] as int,
        pollIntervalSeconds: (json['interval'] as int?) ?? 5,
      );
}

/// نتيجة التحقق من حالة التفويض أثناء الـ polling
enum TokenPollStatus { success, pending, slowDown, expired, denied, unknownError }

class TokenPollResult {
  final TokenPollStatus status;
  final String? accessToken;
  final String? errorMessage;

  TokenPollResult._(this.status, {this.accessToken, this.errorMessage});

  factory TokenPollResult.success(String token) =>
      TokenPollResult._(TokenPollStatus.success, accessToken: token);
  factory TokenPollResult.pending() => TokenPollResult._(TokenPollStatus.pending);
  factory TokenPollResult.slowDown() => TokenPollResult._(TokenPollStatus.slowDown);
  factory TokenPollResult.expired() => TokenPollResult._(TokenPollStatus.expired);
  factory TokenPollResult.denied() => TokenPollResult._(TokenPollStatus.denied);
  factory TokenPollResult.unknownError(String message) =>
      TokenPollResult._(TokenPollStatus.unknownError, errorMessage: message);
}

class GitHubUser {
  final String login;
  final String avatarUrl;

  GitHubUser({required this.login, required this.avatarUrl});

  factory GitHubUser.fromJson(Map<String, dynamic> json) => GitHubUser(
        login: json['login'] as String,
        avatarUrl: json['avatar_url'] as String,
      );
}

class GitHubRepo {
  final String name;
  final String fullName;
  final String owner;
  final String defaultBranch;

  GitHubRepo({
    required this.name,
    required this.fullName,
    required this.owner,
    required this.defaultBranch,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) => GitHubRepo(
        name: json['name'] as String,
        fullName: json['full_name'] as String,
        owner: (json['owner'] as Map<String, dynamic>)['login'] as String,
        defaultBranch: (json['default_branch'] as String?) ?? 'main',
      );
}

class WorkflowRun {
  final int id;
  final String status; // queued, in_progress, completed
  final String? conclusion; // success, failure, cancelled
  final String htmlUrl;

  WorkflowRun({
    required this.id,
    required this.status,
    required this.conclusion,
    required this.htmlUrl,
  });

  factory WorkflowRun.fromJson(Map<String, dynamic> json) => WorkflowRun(
        id: json['id'] as int,
        status: json['status'] as String,
        conclusion: json['conclusion'] as String?,
        htmlUrl: json['html_url'] as String,
      );
}

class BuildArtifact {
  final int id;
  final String name;
  final String archiveDownloadUrl;
  final int sizeInBytes;

  BuildArtifact({
    required this.id,
    required this.name,
    required this.archiveDownloadUrl,
    required this.sizeInBytes,
  });

  factory BuildArtifact.fromJson(Map<String, dynamic> json) => BuildArtifact(
        id: json['id'] as int,
        name: json['name'] as String,
        archiveDownloadUrl: json['archive_download_url'] as String,
        sizeInBytes: json['size_in_bytes'] as int,
      );
}

/// نتيجة عامة موحّدة لكل عمليات الشبكة
class ApiResult<T> {
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final bool isSuccess;

  ApiResult.success(this.data)
      : isSuccess = true,
        errorMessage = null,
        statusCode = null;

  ApiResult.error(this.errorMessage, {this.statusCode})
      : isSuccess = false,
        data = null;
}

/// مشروع Flutter محلي معروض في الشاشة الرئيسية
class FlutterProject {
  final String name;
  final String path;
  final String packageName;

  FlutterProject({required this.name, required this.path, required this.packageName});
}
