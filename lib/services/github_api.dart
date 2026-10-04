import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/github_models.dart';
import 'github_config.dart';

/// الطبقة المسؤولة عن كل تواصل مع GitHub REST API.
class GitHubApi {
  GitHubApi._();

  static final http.Client _client = http.Client();

  // ---------- Device Authorization Flow ----------

  static Future<ApiResult<DeviceCodeResponse>> requestDeviceCode() async {
    try {
      final response = await _client.post(
        Uri.parse(GitHubConfig.deviceCodeUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': GitHubConfig.clientId,
          'scope': GitHubConfig.scopes,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResult.success(DeviceCodeResponse.fromJson(json));
      }
      return ApiResult.error('فشل طلب رمز الجهاز', statusCode: response.statusCode);
    } catch (e) {
      return ApiResult.error('تعذّر الاتصال بـ GitHub: $e');
    }
  }

  static Future<TokenPollResult> pollForAccessToken(String deviceCode) async {
    try {
      final response = await _client.post(
        Uri.parse(GitHubConfig.accessTokenUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': GitHubConfig.clientId,
          'device_code': deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json.containsKey('access_token')) {
        return TokenPollResult.success(json['access_token'] as String);
      }

      switch (json['error']) {
        case 'authorization_pending':
          return TokenPollResult.pending();
        case 'slow_down':
          return TokenPollResult.slowDown();
        case 'expired_token':
          return TokenPollResult.expired();
        case 'access_denied':
          return TokenPollResult.denied();
        default:
          return TokenPollResult.unknownError(
            (json['error_description'] as String?) ?? 'خطأ غير معروف',
          );
      }
    } catch (e) {
      return TokenPollResult.unknownError('تعذّر الاتصال: $e');
    }
  }

  // ---------- معلومات المستخدم ----------

  static Future<ApiResult<GitHubUser>> getCurrentUser(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('${GitHubConfig.apiBaseUrl}/user'),
        headers: _authHeaders(token),
      );

      if (response.statusCode == 200) {
        return ApiResult.success(
          GitHubUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
        );
      }
      return ApiResult.error('فشل جلب معلومات المستخدم', statusCode: response.statusCode);
    } catch (e) {
      return ApiResult.error('تعذّر الاتصال: $e');
    }
  }

  // ---------- المستودعات ----------

  static Future<ApiResult<GitHubRepo>> createRepository(String token, String name) async {
    try {
      final response = await _client.post(
        Uri.parse('${GitHubConfig.apiBaseUrl}/user/repos'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'name': name,
          'private': true,
          'auto_init': true,
        }),
      );

      if (response.statusCode == 201) {
        return ApiResult.success(
          GitHubRepo.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
        );
      }
      return ApiResult.error('فشل إنشاء المستودع', statusCode: response.statusCode);
    } catch (e) {
      return ApiResult.error('تعذّر الاتصال: $e');
    }
  }

  // ---------- رفع الملفات (Contents API) ----------

  static Future<ApiResult<void>> uploadFile({
    required String token,
    required String owner,
    required String repo,
    required String path,
    required List<int> contentBytes,
    String? existingSha,
    String commitMessage = 'Fluco Build: upload file',
  }) async {
    try {
      final base64Content = base64Encode(contentBytes);
      final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
      final url = '${GitHubConfig.apiBaseUrl}/repos/$owner/$repo/contents/$encodedPath';

      final body = <String, dynamic>{
        'message': commitMessage,
        'content': base64Content,
      };
      if (existingSha != null) body['sha'] = existingSha;

      final response = await _client.put(
        Uri.parse(url),
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResult.success(null);
      }
      return ApiResult.error('فشل رفع الملف: $path', statusCode: response.statusCode);
    } catch (e) {
      return ApiResult.error('تعذّر رفع الملف $path: $e');
    }
  }

  // ---------- GitHub Actions ----------

  static Future<ApiResult<void>> triggerWorkflow({
    required String token,
    required String owner,
    required String repo,
    String workflowFile = GitHubConfig.workflowFile,
    String branch = 'main',
    Map<String, String>? inputs,
  }) async {
    try {
      final url =
          '${GitHubConfig.apiBaseUrl}/repos/$owner/$repo/actions/workflows/$workflowFile/dispatches';

      final body = <String, dynamic>{'ref': branch};
      if (inputs != null) body['inputs'] = inputs;

      final response = await _client.post(
        Uri.parse(url),
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 204) {
        return ApiResult.success(null);
      }
      return ApiResult.error('فشل تشغيل سير العمل', statusCode: response.statusCode);
    } catch (e) {
      return ApiResult.error('تعذّر تشغيل سير العمل: $e');
    }
  }

  static Future<ApiResult<WorkflowRun>> getLatestWorkflowRun({
    required String token,
    required String owner,
    required String repo,
    String workflowFile = GitHubConfig.workflowFile,
  }) async {
    try {
      final url =
          '${GitHubConfig.apiBaseUrl}/repos/$owner/$repo/actions/workflows/$workflowFile/runs?per_page=1';

      final response = await _client.get(Uri.parse(url), headers: _authHeaders(token));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final runs = json['workflow_runs'] as List<dynamic>;
        if (runs.isEmpty) {
          return ApiResult.error('لا توجد تشغيلات بعد');
        }
        return ApiResult.success(WorkflowRun.fromJson(runs.first as Map<String, dynamic>));
      }
      return ApiResult.error('فشل جلب حالة التشغيل', statusCode: response.statusCode);
    } catch (e) {
      return ApiResult.error('تعذّر الاتصال: $e');
    }
  }

  static Future<ApiResult<WorkflowRun>> getWorkflowRunStatus({
    required String token,
    required String owner,
    required String repo,
    required int runId,
  }) async {
    try {
      final url = '${GitHubConfig.apiBaseUrl}/repos/$owner/$repo/actions/runs/$runId';
      final response = await _client.get(Uri.parse(url), headers: _authHeaders(token));

      if (response.statusCode == 200) {
        return ApiResult.success(
          WorkflowRun.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
        );
      }
      return ApiResult.error('فشل جلب حالة التشغيل', statusCode: response.statusCode);
    } catch (e) {
      return ApiResult.error('تعذّر الاتصال: $e');
    }
  }

  // ---------- الـ Artifacts ----------

  static Future<ApiResult<List<BuildArtifact>>> listArtifacts({
    required String token,
    required String owner,
    required String repo,
    required int runId,
  }) async {
    try {
      final url = '${GitHubConfig.apiBaseUrl}/repos/$owner/$repo/actions/runs/$runId/artifacts';
      final response = await _client.get(Uri.parse(url), headers: _authHeaders(token));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (json['artifacts'] as List<dynamic>)
            .map((e) => BuildArtifact.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResult.success(list);
      }
      return ApiResult.error('فشل جلب قائمة الملفات الناتجة', statusCode: response.statusCode);
    } catch (e) {
      return ApiResult.error('تعذّر الاتصال: $e');
    }
  }

  static Future<List<int>?> downloadArtifactZip(String token, String downloadUrl) async {
    try {
      final response = await _client.get(
        Uri.parse(downloadUrl),
        headers: _authHeaders(token),
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _authHeaders(String token) => {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
}
