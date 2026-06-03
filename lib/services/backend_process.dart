import 'dart:io';

/// BackendProcess
/// ─────────────────────────────────────────────────────────────────────────────
/// يشغّل api_server.exe كـ child process لما الأبلكيشن يبدأ،
/// ويقفله لما الأبلكيشن يتقفل.
///
/// التسلسل:
///   1. يدوّر على api_server.exe جنب Flutter exe
///   2. يشغّله كـ subprocess (بدون console window)
///   3. يستنى لحد ما /api/state يرد (polling)
///   4. [عند الخروج] يقفله
class BackendProcess {
  static Process? _process;
  static bool _exeFound = false;

  /// هل لقى الـ exe ؟
  static bool get exeFound => _exeFound;

  /// يشغّل الـ backend ويستنى لحد ما يجهز
  /// [timeout] = عدد ثواني الانتظار الأقصى
  static Future<BackendStartResult> start({int timeout = 30}) async {
    // ── ندوّر على api_server.exe ────────────────────────────────────────────
    final exeDir   = File(Platform.resolvedExecutable).parent.path;
    final exePath  = '$exeDir${Platform.pathSeparator}api_server.exe';

    if (!File(exePath).existsSync()) {
      // مفيش exe = وضع development (البايثون شغّال منفصل)
      _exeFound = false;
      return BackendStartResult.notFound;
    }
    _exeFound = true;

    // ── نشغّل العملية ──────────────────────────────────────────────────────
    try {
      _process = await Process.start(
        exePath,
        [],
        workingDirectory: exeDir,
        // مخفي على Windows — مش هتظهر نافذة سوداء
        mode: ProcessStartMode.detachedWithStdio,
      );
    } catch (e) {
      return BackendStartResult.failedToLaunch;
    }

    // ── نستنى لحد ما الـ API يرد ────────────────────────────────────────────
    final client   = HttpClient();
    client.connectionTimeout = const Duration(milliseconds: 300);
    final deadline = DateTime.now().add(Duration(seconds: timeout));

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 400));
      try {
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:8000/api/state'));
        final res = await req.close();
        await res.drain<void>();
        if (res.statusCode == 200) {
          client.close();
          return BackendStartResult.ok;
        }
      } catch (_) {}
    }

    client.close();
    return BackendStartResult.timeout;
  }

  /// يقفل الـ backend
  static void stop() {
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
  }
}

enum BackendStartResult {
  ok,           // اشتغل وجاهز
  notFound,     // مفيش exe (development mode)
  failedToLaunch,
  timeout,      // اشتغل بس مردش
}
