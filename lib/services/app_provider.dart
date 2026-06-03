import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/app_state.dart';
import 'api_service.dart';

/// AppProvider: الـ state management الرئيسي — بيربط الـ WebSocket بالـ UI
class AppProvider extends ChangeNotifier {
  final ApiService api;

  AppProvider({ApiService? apiService})
      : api = apiService ?? ApiService();

  // ── State ──────────────────────────────────────────────────────────────────
  AppState _state = AppState.initial;
  AppState get state => _state;

  // ── Logs ───────────────────────────────────────────────────────────────────
  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  // ── Connection ─────────────────────────────────────────────────────────────
  bool _backendConnected = false;
  bool get backendConnected => _backendConnected;

  String? _lastError;
  String? get lastError => _lastError;

  // ── WebSocket channels ─────────────────────────────────────────────────────
  WebSocketChannel? _stateChannel;
  WebSocketChannel? _logChannel;
  StreamSubscription? _stateSub;
  StreamSubscription? _logSub;

  // ── Polling timer (fallback) ───────────────────────────────────────────────
  Timer? _reconnectTimer;

  static const _wsStateUrl = 'ws://127.0.0.1:8000/ws/state';
  static const _wsLogUrl   = 'ws://127.0.0.1:8000/ws/logs';

  // ─────────────────────────────────────────────────────────────────────────
  void init() {
    _connect();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_backendConnected) _connect();
    });
  }

  void _connect() {
    _connectStateWs();
    _connectLogWs();
  }

  void _connectStateWs() {
    try {
      _stateChannel?.sink.close();
      _stateSub?.cancel();

      _stateChannel = WebSocketChannel.connect(Uri.parse(_wsStateUrl));
      _stateSub = _stateChannel!.stream.listen(
        (data) {
          final json = jsonDecode(data as String);
          _state = AppState.fromJson(json);
          _backendConnected = true;
          _lastError = null;
          notifyListeners();
        },
        onError: (e) => _onDisconnected('State WS error: $e'),
        onDone: ()  => _onDisconnected('State WS closed'),
      );
    } catch (e) {
      _onDisconnected('State WS connect failed: $e');
    }
  }

  void _connectLogWs() {
    try {
      _logChannel?.sink.close();
      _logSub?.cancel();

      _logChannel = WebSocketChannel.connect(Uri.parse(_wsLogUrl));
      _logSub = _logChannel!.stream.listen(
        (data) {
          final json = jsonDecode(data as String);
          _logs.add(LogEntry.fromJson(json));
          if (_logs.length > 3000) _logs.removeRange(0, _logs.length - 3000);
          notifyListeners();
        },
        onError: (_) {},
        onDone: ()  {},
      );
    } catch (_) {}
  }

  void _onDisconnected(String reason) {
    if (_backendConnected) {
      _backendConnected = false;
      _lastError = 'Backend disconnected';
      notifyListeners();
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> startApp() async {
    await api.startApp();
  }

  Future<void> stopApp() async {
    await api.stopApp();
  }

  Future<Map<String, dynamic>> getConfig() => api.getConfig();

  Future<void> updateConfig(Map<String, dynamic> updates) =>
      api.updateConfig(updates);

  Future<void> resetConfig() => api.resetConfig();

  Future<bool> verifyPassword(String pw) => api.verifyPassword(pw);

  Future<void> changePassword(String old, String newPw) =>
      api.changePassword(old, newPw);

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  // ── Formatting helpers ─────────────────────────────────────────────────────
  String formatUptime(double seconds) {
    if (seconds <= 0) return '-';
    final s = seconds.toInt();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }

  String formatTimeAgo(double ts) {
    if (ts == 0) return '-';
    final delta = DateTime.now().millisecondsSinceEpoch / 1000 - ts;
    if (delta < 1)    return 'الآن';
    if (delta < 60)   return 'منذ ${delta.toInt()}ث';
    if (delta < 3600) return 'منذ ${(delta / 60).toInt()}د';
    return 'منذ ${(delta / 3600).toInt()}س';
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _stateSub?.cancel();
    _logSub?.cancel();
    _stateChannel?.sink.close();
    _logChannel?.sink.close();
    super.dispose();
  }
}
