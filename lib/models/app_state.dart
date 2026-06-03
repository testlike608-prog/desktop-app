/// AppState: كل الـ state القادم من الـ backend
class AppState {
  final bool isRunning;
  final String stage;
  final String? barcode;
  final dynamic program;
  final int step;
  final int visionTestCount;
  final double lastEventTime;
  final double uptime;
  final Map<String, int> stats;
  final Map<String, int> queueSizes;
  final Map<String, bool> connections;
  final Map<String, String> endpoints;
  final String? error;

  const AppState({
    this.isRunning = false,
    this.stage = 'IDLE',
    this.barcode,
    this.program,
    this.step = 0,
    this.visionTestCount = 6,
    this.lastEventTime = 0,
    this.uptime = 0,
    this.stats = const {'total': 0, 'pass': 0, 'fail': 0, 'errors': 0},
    this.queueSizes = const {'vision_queue': 0, 'scanner_queue': 0},
    this.connections = const {
      'VisionClient_TRIG': false,
      'VisionClient_ID': false,
      'cobotClient': false,
      'triggerserver': false,
    },
    this.endpoints = const {
      'VisionClient_TRIG': '127.0.0.1:8081',
      'VisionClient_ID':   '127.0.0.1:8080',
      'cobotClient':       '192.168.57.2:9000',
      'triggerserver':     '0.0.0.0:5000',
    },
    this.error,
  });

  factory AppState.fromJson(Map<String, dynamic> json) {
    return AppState(
      isRunning: json['is_running'] ?? false,
      stage: json['stage'] ?? 'IDLE',
      barcode: json['barcode'],
      program: json['program'],
      step: json['step'] ?? 0,
      visionTestCount: json['vision_test_count'] ?? 6,
      lastEventTime: (json['last_event_time'] ?? 0).toDouble(),
      uptime: (json['uptime'] ?? 0).toDouble(),
      stats: Map<String, int>.from(
        (json['stats'] ?? {}).map((k, v) => MapEntry(k, (v as num).toInt())),
      ),
      queueSizes: Map<String, int>.from(
        (json['queue_sizes'] ?? {}).map((k, v) => MapEntry(k, (v as num).toInt())),
      ),
      connections: Map<String, bool>.from(json['connections'] ?? {}),
      endpoints: Map<String, String>.from(json['endpoints'] ?? {}),
      error: json['error'],
    );
  }

  static const AppState initial = AppState();
}

/// LogEntry: رسالة log واحدة
class LogEntry {
  final double ts;
  final String level;
  final String name;
  final String message;

  const LogEntry({
    required this.ts,
    required this.level,
    required this.name,
    required this.message,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        ts: (json['ts'] ?? 0).toDouble(),
        level: json['level'] ?? 'INFO',
        name: json['name'] ?? '',
        message: json['message'] ?? '',
      );
}
