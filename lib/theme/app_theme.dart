import 'package:flutter/material.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────
const kBgDark       = Color(0xFF0F172A);
const kSidebarDark  = Color(0xFF1E293B);
const kCardDark     = Color(0xFF1E293B);
const kBorderDark   = Color(0xFF334155);
const kTextPrimary  = Color(0xFFF1F5F9);
const kTextSub      = Color(0xFF94A3B8);
const kAccent       = Color(0xFF6366F1);
const kSuccess      = Color(0xFF10B981);
const kDanger       = Color(0xFFEF4444);
const kWarning      = Color(0xFFF59E0B);

// ── Log colors (match Python gui_styles.LOG_COLORS["dark"]) ──────────────────
const kLogColors = {
  'DEBUG':    Color(0xFF64748B),   // dim slate
  'INFO':     Color(0xFFE5E7EB),   // near-white
  'WARNING':  Color(0xFFFBBF24),   // amber
  'ERROR':    Color(0xFFF87171),   // soft red
  'CRITICAL': Color(0xFFFCA5A5),   // pink-red
};

Color logColor(String level) => kLogColors[level] ?? kLogColors['INFO']!;

// ── Stage display info ────────────────────────────────────────────────────────
class StageInfo {
  final String label;
  final int percent;
  const StageInfo(this.label, this.percent);
}

const Map<String, StageInfo> kStages = {
  'IDLE':             StageInfo('في الانتظار', 0),
  'BARCODE_RECEIVED': StageInfo('استقبال الباركود', 10),
  'PROGRAM_LOOKUP':   StageInfo('البحث عن البرنامج', 20),
  'SENDING_PROGRAM':  StageInfo('إرسال للكوبوت', 30),
  'VISION_TEST_1':    StageInfo('Vision test 1', 40),
  'VISION_TEST_2':    StageInfo('Vision test 2', 50),
  'VISION_TEST_3':    StageInfo('Vision test 3', 60),
  'VISION_TEST_4':    StageInfo('Vision test 4', 70),
  'VISION_TEST_5':    StageInfo('Vision test 5', 80),
  'VISION_TEST_6':    StageInfo('Vision test 6', 90),
  'REPORTING':        StageInfo('كتابة التقرير', 95),
  'DONE':             StageInfo('انتهى', 100),
  'ERROR':            StageInfo('خطأ', 100),
};

StageInfo stageInfo(String stage, int step, int total) {
  if (stage.startsWith('VISION_TEST') && step > 0) {
    final pct = 30 + ((step / total.clamp(1, 30)) * 60).toInt();
    return StageInfo('Vision test $step/$total', pct.clamp(30, 90));
  }
  return kStages[stage] ?? const StageInfo('في الانتظار', 0);
}

// ── Theme ─────────────────────────────────────────────────────────────────────
ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBgDark,
    colorScheme: const ColorScheme.dark(
      surface: kBgDark,
      primary: kAccent,
      secondary: kSuccess,
      error: kDanger,
    ),
    cardTheme: CardThemeData(
      color: kCardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorderDark),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: kTextPrimary, fontSize: 14),
      bodySmall:  TextStyle(color: kTextSub,     fontSize: 12),
    ),
  );
}
