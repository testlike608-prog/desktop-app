import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/stage_progress_card.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  // ── فتح ملف أو فولدر عبر الـ backend ──────────────────────────────────────
  static Future<void> _openPath(
    BuildContext context,
    String endpoint,
    String path,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      );
      if (res.statusCode != 200) {
        final detail = jsonDecode(res.body)['detail'] ?? res.body;
        if (context.mounted) _showSnack(context, detail.toString(), isError: true);
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, 'تعذّر الفتح: $e', isError: true);
    }
  }

  static Future<Map<String, String>> _fetchPaths() async {
    try {
      final res = await http
          .get(Uri.parse('http://127.0.0.1:8000/api/paths'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return {
          'results_file': j['results_file'] ?? '',
          'logs_dir':     j['logs_dir'] ?? '',
        };
      }
    } catch (_) {}
    return {};
  }

  static void _showSnack(BuildContext ctx, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? kDanger : kSuccess,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final st   = prov.state;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + badge + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text(
                        'Status Dashboard',
                        style: TextStyle(color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      _StateBadge(isRunning: st.isRunning),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      st.isRunning
                          ? 'البرنامج شغّال — يستقبل باركودات'
                          : 'البرنامج متوقف — اضغط Start للبدء',
                      style: TextStyle(color: st.isRunning ? kSuccess : kDanger, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // Buttons row
              Wrap(
                spacing: 8,
                children: [
                  // Start
                  _HeaderBtn(
                    label: '▶  Start',
                    color: kSuccess,
                    enabled: !st.isRunning && prov.backendConnected,
                    onPressed: () async {
                      try { await prov.startApp(); }
                      catch (e) { _showSnack(context, e.toString(), isError: true); }
                    },
                  ),
                  // Stop
                  _HeaderBtn(
                    label: '■  Stop',
                    color: kDanger,
                    enabled: st.isRunning,
                    onPressed: () async {
                      try { await prov.stopApp(); }
                      catch (e) { _showSnack(context, e.toString(), isError: true); }
                    },
                  ),
                  // Divider
                  Container(width: 1, height: 36, color: const Color(0xFF334155),
                      margin: const EdgeInsets.symmetric(vertical: 2)),
                  // Open Excel
                  _HeaderBtn(
                    label: '📊  فتح ملف التقرير',
                    color: kAccent,
                    enabled: prov.backendConnected,
                    onPressed: () async {
                      final paths = await _fetchPaths();
                      if (context.mounted && paths['results_file'] != null) {
                        await _openPath(context, '/api/open-file', paths['results_file']!);
                      }
                    },
                  ),
                  // Open Logs Folder
                  _HeaderBtn(
                    label: '📁  فولدر اللوج',
                    color: const Color(0xFF475569),
                    enabled: prov.backendConnected,
                    onPressed: () async {
                      final paths = await _fetchPaths();
                      if (context.mounted && paths['logs_dir'] != null) {
                        await _openPath(context, '/api/open-folder', paths['logs_dir']!);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Stage Progress ──────────────────────────────────────────────────
          StageProgressCard(
            stage:      st.stage,
            barcode:    st.barcode,
            program:    st.program,
            step:       st.step,
            totalSteps: st.visionTestCount,
          ),

          const SizedBox(height: 20),

          // ── Live Camera Preview ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CameraPreviewWidget(),
              const SizedBox(width: 16),
              // يمكن إضافة widgets إضافية جنب الكاميرا هنا
            ],
          ),

          const SizedBox(height: 20),

          // ── Connections ─────────────────────────────────────────────────────
          const _SectionTitle('الاتصالات'),
          const SizedBox(height: 10),
          _ConnectionsGrid(connections: st.connections, endpoints: st.endpoints),

          const SizedBox(height: 20),

          // ── Stats ────────────────────────────────────────────────────────────
          const _SectionTitle('الإحصائيات'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              StatCard(title: 'TOTAL SCANNED', value: '${st.stats['total'] ?? 0}', subtitle: 'إجمالي الباركودات'),
              StatCard(title: 'PASSED',  value: '${st.stats['pass'] ?? 0}',   subtitle: 'نجحت',  valueColor: kSuccess),
              StatCard(title: 'FAILED',  value: '${st.stats['fail'] ?? 0}',   subtitle: 'فشلت',  valueColor: kDanger),
              StatCard(title: 'ERRORS',  value: '${st.stats['errors'] ?? 0}', subtitle: 'أخطاء', valueColor: kWarning),
            ],
          ),

          const SizedBox(height: 12),

          // ── Queue / timing ───────────────────────────────────────────────────
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              StatCard(
                title: 'VISION QUEUE',
                value: '${st.queueSizes['vision_queue'] ?? 0}',
                subtitle: 'Scanner: ${st.queueSizes['scanner_queue'] ?? 0}',
              ),
              StatCard(title: 'LAST BARCODE', value: st.barcode ?? '-', subtitle: 'آخر باركود'),
              StatCard(title: 'LAST EVENT',   value: prov.formatTimeAgo(st.lastEventTime), subtitle: 'آخر حدث'),
              StatCard(title: 'UPTIME',       value: prov.formatUptime(st.uptime), subtitle: 'وقت التشغيل'),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Live Camera Preview Widget ───────────────────────────────────────────────
class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({super.key});

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  static const _w = 320.0;
  static const _h = 240.0;
  static const _url = 'http://127.0.0.1:8000/api/camera/frame';

  Timer?     _timer;
  Uint8List? _frame;
  bool       _active = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final res = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(milliseconds: 200));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['ok'] == true && body['frame'] != null) {
          final bytes = base64Decode(body['frame'] as String);
          if (mounted) setState(() { _frame = bytes; _active = true; });
          return;
        }
      }
    } catch (_) {}
    if (mounted && _active) setState(() { _frame = null; _active = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            const Text(
              '📷  Live Camera',
              style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Icon(Icons.circle, size: 10, color: _active ? kSuccess : const Color(0xFF4B5563)),
          ],
        ),
        const SizedBox(height: 8),

        // Frame container
        Container(
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorderDark),
          ),
          clipBehavior: Clip.hardEdge,
          child: _frame != null
              ? Image.memory(
                  _frame!,
                  width: _w,
                  height: _h,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off, color: Color(0xFF4B5563), size: 36),
                      SizedBox(height: 8),
                      Text(
                        'الكاميرا غير متصلة\nأو لم تبدأ بعد',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Connections Grid ─────────────────────────────────────────────────────────
class _ConnectionsGrid extends StatelessWidget {
  final Map<String, bool> connections;
  final Map<String, String> endpoints;
  const _ConnectionsGrid({required this.connections, required this.endpoints});

  static const _cards = [
    ('VisionClient_TRIG', 'Vision (Trigger)', '127.0.0.1:8081'),
    ('VisionClient_ID',   'Vision (ID)',      '127.0.0.1:8080'),
    ('cobotClient',       'Cobot',            '192.168.57.2:9000'),
    ('triggerserver',     'Trigger Server',   '0.0.0.0:5000'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.8,
      children: _cards.map((c) {
        final (key, label, fallback) = c;
        return ConnectionCard(
          name:      label,
          endpoint:  endpoints[key] ?? fallback,
          connected: connections[key] ?? false,
        );
      }).toList(),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _StateBadge extends StatelessWidget {
  final bool isRunning;
  const _StateBadge({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    final color = isRunning ? kSuccess : kDanger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        isRunning ? '▶  RUNNING' : '⏹  STOPPED',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  const _HeaderBtn({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : const Color(0xFF1F2937),
        foregroundColor: enabled ? Colors.white : const Color(0xFF4B5563),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w600));
  }
}
