import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/app_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _testMode = false;
  bool _loading  = true;
  Map<String, dynamic> _config = {};

  // Text controllers for simple fields
  final Map<String, TextEditingController> _ctrl = {};

  // Special state for complex fields
  String       _scanMode       = 'manual';
  int          _cameraIndex    = 0;
  String       _imagesFolder   = 'result_images';
  List<String> _backupFolders  = [];
  List<Map<String, dynamic>> _detectedCameras = [];
  bool _detectingCameras = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      // capture ref before await
      final prov = context.read<AppProvider>();
      final cfg  = await prov.getConfig();
      if (!mounted) return;
      setState(() {
        _config  = cfg;
        _loading = false;
        _initAll();
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initAll() {
    const textKeys = [
      'vision_trig_ip',    'vision_trig_port',
      'vision_id_ip',      'vision_id_port',
      'cobot_ip',          'cobot_port',
      'trigger_server_ip', 'trigger_server_port',
      'program_mapping_file', 'results_report_file',
      'vision_test_count',
      'watchdog_interval', 'reconnect_check_interval',
      'reconnect_retry_delay', 'debug_monitor_interval',
    ];
    for (final k in textKeys) {
      _ctrl[k]?.dispose();
      _ctrl[k] = TextEditingController(text: '${_config[k] ?? ''}');
    }
    _scanMode     = _config['scan_mode'] ?? 'manual';
    _cameraIndex  = (_config['camera_index'] as num?)?.toInt() ?? 0;
    _imagesFolder = _config['result_images_folder'] ?? 'result_images';
    final backups = _config['result_images_backup_folders'];
    _backupFolders = backups is List
        ? List<String>.from(backups.map((e) => e.toString()))
        : [];
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Test Mode ────────────────────────────────────────────────────────────────
  Future<void> _toggleTestMode() async {
    if (_testMode) {
      setState(() => _testMode = false);
      return;
    }
    final pw = await _showPasswordDialog();
    if (!mounted || pw == null) return;
    final prov = context.read<AppProvider>();
    final ok   = await prov.verifyPassword(pw);
    if (!mounted) return;
    if (ok) {
      setState(() => _testMode = true);
    } else {
      _showSnack('الباسوورد غلط', isError: true);
    }
  }

  Future<String?> _showPasswordDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardDark,
        title: const Row(children: [
          Text('🔒', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Text('Test Mode Login', style: TextStyle(color: kTextPrimary, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('ادخل باسوورد Test Mode للتعديل',
              style: TextStyle(color: kTextSub, fontSize: 13)),
          const SizedBox(height: 12),
          _PwField(
            ctrl: ctrl,
            hint: 'الباسوورد',
            autofocus: true,
            onSubmit: () => Navigator.of(ctx).pop(ctrl.text),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('إلغاء', style: TextStyle(color: kTextSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: kAccent, foregroundColor: Colors.white),
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

  // ── Detect Cameras ───────────────────────────────────────────────────────────
  Future<void> _detectCameras() async {
    setState(() => _detectingCameras = true);
    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/detect-cameras'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final body    = jsonDecode(res.body) as Map<String, dynamic>;
        final cameras = (body['cameras'] as List).cast<int>();
        setState(() {
          _detectedCameras = cameras
              .map((i) => <String, dynamic>{'index': i, 'label': 'Camera $i  (index=$i)'})
              .toList();
          if (_detectedCameras.isNotEmpty) {
            final stillExists =
                _detectedCameras.any((c) => c['index'] == _cameraIndex);
            if (!stillExists) _cameraIndex = cameras.first;
          }
        });
      }
    } catch (e) {
      if (mounted) _showSnack('فشل الاكتشاف: $e', isError: true);
    } finally {
      if (mounted) setState(() => _detectingCameras = false);
    }
  }

  // ── Pick Folder ──────────────────────────────────────────────────────────────
  Future<String?> _pickFolder(String current) {
    final ctrl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardDark,
        title: const Text('📂  مسار الفولدر',
            style: TextStyle(color: kTextPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('اكتب المسار الكامل للفولدر:',
              style: TextStyle(color: kTextSub, fontSize: 12)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(
                color: kTextPrimary, fontSize: 13, fontFamily: 'monospace'),
            decoration: _dlgInputDeco(r'مثال: C:\result_images'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('إلغاء', style: TextStyle(color: kTextSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: kAccent, foregroundColor: Colors.white),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  // ── Save ─────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final updates = <String, dynamic>{};

    for (final entry in _ctrl.entries) {
      final cfgKey = entry.key;
      final val    = entry.value.text.trim();
      if (val.isEmpty) {
        _showSnack('حقل $cfgKey فاضي', isError: true);
        return;
      }
      if (['vision_trig_port', 'vision_id_port', 'cobot_port',
           'trigger_server_port', 'vision_test_count'].contains(cfgKey)) {
        updates[cfgKey] = int.tryParse(val) ?? _config[cfgKey];
      } else if (['watchdog_interval', 'reconnect_check_interval',
                  'reconnect_retry_delay', 'debug_monitor_interval'].contains(cfgKey)) {
        updates[cfgKey] = double.tryParse(val) ?? _config[cfgKey];
      } else {
        updates[cfgKey] = val;
      }
    }

    updates['scan_mode']                    = _scanMode;
    updates['camera_index']                 = _cameraIndex;
    updates['result_images_folder']         = _imagesFolder;
    updates['result_images_backup_folders'] = _backupFolders;

    // capture before await
    final prov = context.read<AppProvider>();
    try {
      await prov.updateConfig(updates);
      if (!mounted) return;
      _showSnack('تم الحفظ بنجاح ✓  —  تغيير الـ IPs/Ports يحتاج restart');
    } catch (e) {
      if (!mounted) return;
      _showSnack('فشل الحفظ: $e', isError: true);
    }
  }

  // ── Reset ────────────────────────────────────────────────────────────────────
  Future<void> _reset() async {
    final ok = await _confirm(
        'هترجع كل الإعدادات للافتراضي.\nالباسوورد هيفضل زي ما هو.\n\nمتأكد؟');
    if (!ok || !mounted) return;
    final prov = context.read<AppProvider>();
    try {
      await prov.resetConfig();
      if (!mounted) return;
      await _loadConfig();
      if (!mounted) return;
      _showSnack('الإعدادات رجعت للافتراضي ✓');
    } catch (e) {
      if (!mounted) return;
      _showSnack('فشل: $e', isError: true);
    }
  }

  // ── Change Password ──────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final cfmC = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardDark,
        title: const Text('🔑  تغيير الباسوورد',
            style: TextStyle(color: kTextPrimary, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _PwField(ctrl: oldC, hint: 'الباسوورد الحالي'),
          const SizedBox(height: 8),
          _PwField(ctrl: newC, hint: 'باسوورد جديد (4+ حروف)'),
          const SizedBox(height: 8),
          _PwField(ctrl: cfmC, hint: 'أكد الباسوورد الجديد'),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(color: kTextSub)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newC.text != cfmC.text) {
                _showSnack('الباسوورد والتأكيد مش متطابقين', isError: true);
                return;
              }
              // capture before await
              final prov = context.read<AppProvider>();
              Navigator.of(ctx).pop();
              try {
                await prov.changePassword(oldC.text, newC.text);
                if (!mounted) return;
                _showSnack('تم تغيير الباسوورد ✓');
              } catch (e) {
                if (!mounted) return;
                _showSnack('فشل: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: kAccent, foregroundColor: Colors.white),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? kDanger : kSuccess,
    ));
  }

  Future<bool> _confirm(String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kCardDark,
            title: const Text('تأكيد', style: TextStyle(color: kTextPrimary)),
            content: Text(msg, style: const TextStyle(color: kTextSub)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('لا', style: TextStyle(color: kTextSub)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: kDanger),
                child: const Text('نعم', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  static InputDecoration _dlgInputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextSub),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBorderDark)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: kBorderDark)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  static InputDecoration _fieldDeco({bool enabled = true}) => InputDecoration(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: kBorderDark)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: kAccent)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: kBorderDark)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────────────────
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Settings',
                    style: TextStyle(color: kTextPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('الإعدادات قابلة للتعديل من Test Mode بدون إعادة بناء البرنامج',
                    style: TextStyle(color: kTextSub, fontSize: 13)),
              ]),
            ),
            _ModeBadge(testMode: _testMode),
          ]),
          const SizedBox(height: 16),

          // ── Test Mode bar ────────────────────────────────────────────────────
          _Card(child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Test Mode',
                    style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  _testMode
                      ? 'Test Mode مفعّل — تقدر تعدل كل الإعدادات. اضغط حفظ لما تخلص.'
                      : 'الإعدادات للقراءة فقط. ادخل Test Mode بالباسوورد عشان تعدل.',
                  style: const TextStyle(color: kTextSub, fontSize: 12),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _toggleTestMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: _testMode ? const Color(0xFF1F2937) : kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(_testMode ? '🔒  قفل (خروج)' : '🔓  دخول Test Mode'),
            ),
          ])),
          const SizedBox(height: 20),

          // ── Connections ──────────────────────────────────────────────────────
          const _SectionLabel('الاتصالات (Connections)'),
          _Card(child: Column(children: [
            _FieldRow(label: 'Vision (TRIG) IP',    cfgKey: 'vision_trig_ip',    ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Vision (TRIG) Port',  cfgKey: 'vision_trig_port',  ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Vision (ID) IP',      cfgKey: 'vision_id_ip',      ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Vision (ID) Port',    cfgKey: 'vision_id_port',    ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Cobot IP',            cfgKey: 'cobot_ip',          ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Cobot Port',          cfgKey: 'cobot_port',        ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Trigger Server IP',   cfgKey: 'trigger_server_ip', ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Trigger Server Port', cfgKey: 'trigger_server_port', ctrl: _ctrl, enabled: _testMode),
          ])),
          const SizedBox(height: 16),

          // ── Files ────────────────────────────────────────────────────────────
          const _SectionLabel('مسارات الملفات (File Paths)'),
          _Card(child: Column(children: [
            _FieldRow(label: 'Program mapping', cfgKey: 'program_mapping_file', ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Results report',  cfgKey: 'results_report_file',  ctrl: _ctrl, enabled: _testMode),
          ])),
          const SizedBox(height: 16),

          // ── Result Images ─────────────────────────────────────────────────────
          const _SectionLabel('صور النتيجة (Result Images)'),
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Primary images folder
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                const SizedBox(
                  width: 220,
                  child: Text('فولدر صور النتيجة',
                      style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  child: TextField(
                    enabled: _testMode,
                    controller: TextEditingController(text: _imagesFolder),
                    onChanged: (v) => _imagesFolder = v,
                    style: const TextStyle(
                        color: kTextPrimary, fontSize: 13, fontFamily: 'monospace'),
                    decoration: _fieldDeco(enabled: _testMode),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _testMode
                      ? () async {
                          final picked = await _pickFolder(_imagesFolder);
                          if (picked != null && mounted) {
                            setState(() => _imagesFolder = picked);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Browse'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _testMode ? kTextSub : const Color(0xFF4B5563),
                    side: BorderSide(
                        color: _testMode ? kBorderDark : const Color(0xFF2D3748)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ]),
            ),

            const Divider(color: kBorderDark, height: 20),

            // Backup folders
            Row(children: [
              const Expanded(
                child: Text('فولدرات نسخ إضافية (Backup)',
                    style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w500)),
              ),
              if (_testMode)
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickFolder('');
                    if (!mounted || picked == null || picked.isEmpty) return;
                    if (!_backupFolders.contains(picked)) {
                      setState(() => _backupFolders.add(picked));
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('➕  إضافة فولدر'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kSuccess,
                    side: const BorderSide(color: kSuccess),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorderDark),
              ),
              child: _backupFolders.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('لا توجد فولدرات نسخ احتياطي',
                          style: TextStyle(color: kTextSub, fontSize: 12)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _backupFolders.length,
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        title: Text(
                          _backupFolders[i],
                          style: const TextStyle(
                              color: kTextPrimary,
                              fontSize: 12,
                              fontFamily: 'monospace'),
                        ),
                        trailing: _testMode
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: kDanger, size: 18),
                                onPressed: () =>
                                    setState(() => _backupFolders.removeAt(i)),
                              )
                            : null,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            const Text(
              'كل صورة نتيجة هتتنسخ نسخة إضافية في كل الفولدرات دي.',
              style: TextStyle(color: kTextSub, fontSize: 11),
            ),
          ])),
          const SizedBox(height: 16),

          // ── Test Sequence ─────────────────────────────────────────────────────
          const _SectionLabel('Test Sequence'),
          _Card(child: Column(children: [
            _FieldRow(label: 'Vision test count', cfgKey: 'vision_test_count', ctrl: _ctrl, enabled: _testMode),
          ])),
          const SizedBox(height: 16),

          // ── Intervals ────────────────────────────────────────────────────────
          const _SectionLabel('الفترات الزمنية (Intervals — seconds)'),
          _Card(child: Column(children: [
            _FieldRow(label: 'Watchdog interval',        cfgKey: 'watchdog_interval',        ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Reconnect check interval', cfgKey: 'reconnect_check_interval', ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Reconnect retry delay',    cfgKey: 'reconnect_retry_delay',    ctrl: _ctrl, enabled: _testMode),
            _FieldRow(label: 'Debug monitor interval',   cfgKey: 'debug_monitor_interval',   ctrl: _ctrl, enabled: _testMode),
          ])),
          const SizedBox(height: 16),

          // ── Scan Input Mode ──────────────────────────────────────────────────
          const _SectionLabel('وضع قراءة الباركود (Scan Input Mode)'),
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'اختار Manual لو عندك سكانر باركود (بيتصل كـ keyboard)، '
              'أو Camera لو عايز تقرأ الباركود بكاميرا عادية.',
              style: TextStyle(color: kTextSub, fontSize: 11),
            ),
            const SizedBox(height: 12),
            const Divider(color: kBorderDark, height: 1),
            const SizedBox(height: 12),

            // Scan mode dropdown
            Row(children: [
              const SizedBox(
                width: 220,
                child: Text('وضع القراءة',
                    style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: IgnorePointer(
                  ignoring: !_testMode,
                  child: Opacity(
                    opacity: _testMode ? 1.0 : 0.5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorderDark),
                      ),
                      child: DropdownButton<String>(
                        value: _scanMode,
                        isExpanded: true,
                        dropdownColor: kCardDark,
                        underline: const SizedBox(),
                        style: const TextStyle(color: kTextPrimary, fontSize: 13),
                        items: const [
                          DropdownMenuItem(
                            value: 'manual',
                            child: Text('🖊  Manual Scanner (سكانر كيبورد)'),
                          ),
                          DropdownMenuItem(
                            value: 'camera',
                            child: Text('📷  Camera Scanner (كاميرا عادية)'),
                          ),
                        ],
                        onChanged: _testMode
                            ? (v) {
                                if (v != null) setState(() => _scanMode = v);
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Camera index
            Row(children: [
              const SizedBox(
                width: 220,
                child: Text('الكاميرا المستخدمة',
                    style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: IgnorePointer(
                  ignoring: !_testMode,
                  child: Opacity(
                    opacity: _testMode ? 1.0 : 0.5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorderDark),
                      ),
                      child: DropdownButton<int>(
                        value: _cameraIndex,
                        isExpanded: true,
                        dropdownColor: kCardDark,
                        underline: const SizedBox(),
                        style: const TextStyle(color: kTextPrimary, fontSize: 13),
                        items: _detectedCameras.isEmpty
                            ? [
                                DropdownMenuItem(
                                  value: _cameraIndex,
                                  child: Text('Camera $_cameraIndex'),
                                )
                              ]
                            : _detectedCameras
                                .map((c) => DropdownMenuItem<int>(
                                      value: c['index'] as int,
                                      child: Text('📷  ${c['label']}'),
                                    ))
                                .toList(),
                        onChanged: _testMode
                            ? (v) {
                                if (v != null) setState(() => _cameraIndex = v);
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: (_testMode && !_detectingCameras) ? _detectCameras : null,
                icon: _detectingCameras
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kAccent),
                      )
                    : const Icon(Icons.search, size: 16),
                label: Text(_detectingCameras ? 'يكتشف...' : '🔍  اكتشاف الكاميرات'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _testMode ? kAccent : const Color(0xFF4B5563),
                  side: BorderSide(
                      color: _testMode ? kAccent : const Color(0xFF2D3748)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ]),
          ])),
          const SizedBox(height: 16),

          // ── Actions ──────────────────────────────────────────────────────────
          _Card(child: Row(children: [
            const Expanded(
              child: Text(
                'ملاحظة: تغيير الـ IPs/Ports يحتاج إعادة تشغيل البرنامج',
                style: TextStyle(color: kWarning, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            if (_testMode) ...[
              _ActionBtn(label: '🔑  تغيير الباسوورد', onPressed: _changePassword),
              const SizedBox(width: 8),
              _ActionBtn(label: '↺  استعادة الافتراضيات', onPressed: _reset),
              const SizedBox(width: 8),
              _ActionBtn(label: '💾  حفظ التغييرات', onPressed: _save, isPrimary: true),
            ],
          ])),
          const SizedBox(height: 16),

          // ── About ─────────────────────────────────────────────────────────────
          _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ABOUT',
                style: TextStyle(
                    color: kTextSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            const Text(
              'Industrial Test Station Controller\n'
              'Version 1.0  •  Flutter + Python FastAPI\n'
              '© 2026 Meeserv',
              style: TextStyle(color: kTextSub, height: 1.6),
            ),
          ])),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: kCardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderDark),
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

// ─── Field Row ────────────────────────────────────────────────────────────────
// Note: field is named `cfgKey` (not `key`) to avoid conflict with Widget.key
class _FieldRow extends StatelessWidget {
  final String label;
  final String cfgKey;                        // ← renamed from `key`
  final Map<String, TextEditingController> ctrl;
  final bool enabled;

  const _FieldRow({
    required this.label,
    required this.cfgKey,
    required this.ctrl,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
            width: 220,
            child: Text(label,
                style: const TextStyle(
                    color: kTextPrimary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: TextField(
              controller: ctrl[cfgKey],
              enabled: enabled,
              style: const TextStyle(
                  color: kTextPrimary, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: kBorderDark)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: kAccent)),
                disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: kBorderDark)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ]),
      );
}

class _ModeBadge extends StatelessWidget {
  final bool testMode;
  const _ModeBadge({required this.testMode});

  @override
  Widget build(BuildContext context) {
    final c = testMode ? kSuccess : kDanger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Text(
        testMode ? '🔓 Test Mode' : '🔒 Read-only',
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionBtn({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? kAccent : const Color(0xFF1F2937),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      );
}

class _PwField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool autofocus;
  final VoidCallback? onSubmit;

  const _PwField({
    required this.ctrl,
    required this.hint,
    this.autofocus = false,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        obscureText: true,
        autofocus: autofocus,
        onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
        style: const TextStyle(color: kTextPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextSub),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kBorderDark)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kBorderDark)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
