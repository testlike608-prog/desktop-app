import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_state.dart';

/// ApiService: بيتعامل مع كل الـ REST calls للـ Python backend
class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://127.0.0.1:8000'});

  Future<T> _get<T>(String path, T Function(dynamic) parse) async {
    final res = await http.get(Uri.parse('$baseUrl$path'));
    if (res.statusCode != 200) throw Exception('GET $path failed: ${res.statusCode}');
    return parse(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res));
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res));
    }
    return jsonDecode(res.body);
  }

  /// يستخرج رسالة خطأ واضحة من أي response — JSON أو plain text أو HTML
  static String _extractError(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      return (j['detail'] ?? j['message'] ?? res.body).toString();
    } catch (_) {
      // الـ body مش JSON (ممكن يكون HTML أو plain text من uvicorn)
      final body = res.body.trim();
      if (body.isEmpty) return 'HTTP ${res.statusCode}';
      // نشيل HTML tags لو موجودة
      final text = body.replaceAll(RegExp(r'<[^>]+>'), ' ').trim();
      return text.length > 200 ? '${text.substring(0, 200)}...' : text;
    }
  }

  // ── State ──────────────────────────────────────────────────────────────────
  Future<AppState> getState() =>
      _get('/api/state', (j) => AppState.fromJson(j));

  // ── Control ────────────────────────────────────────────────────────────────
  Future<void> startApp() => _post('/api/start');
  Future<void> stopApp()  => _post('/api/stop');

  // ── Config ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getConfig() =>
      _get('/api/config', (j) => Map<String, dynamic>.from(j));

  Future<void> updateConfig(Map<String, dynamic> updates) =>
      _patch('/api/config', {'updates': updates});

  Future<void> resetConfig() => _post('/api/config/reset');

  Future<bool> verifyPassword(String password) async {
    final res = await _post('/api/config/verify-password', {'password': password});
    return res['ok'] == true;
  }

  Future<void> changePassword(String oldPw, String newPw) =>
      _post('/api/config/change-password', {
        'old_password': oldPw,
        'new_password': newPw,
      });

  // ── Logs ───────────────────────────────────────────────────────────────────
  Future<List<LogEntry>> getLogHistory() async {
    final res = await http.get(Uri.parse('$baseUrl/api/logs/history'));
    final list = jsonDecode(res.body) as List;
    return list.map((e) => LogEntry.fromJson(e)).toList();
  }

  // ── Camera ─────────────────────────────────────────────────────────────────
  Future<String?> getCameraFrame() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/camera/frame'));
      final body = jsonDecode(res.body);
      if (body['ok'] == true) return body['frame'] as String?;
    } catch (_) {}
    return null;
  }

  /// يتحقق إذا الـ backend شغّال
  Future<bool> isBackendAlive() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/state'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
