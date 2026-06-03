import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StageProgressCard extends StatelessWidget {
  final String stage;
  final String? barcode;
  final dynamic program;
  final int step;
  final int totalSteps;

  const StageProgressCard({
    super.key,
    required this.stage,
    this.barcode,
    this.program,
    this.step = 0,
    this.totalSteps = 6,
  });

  static const _stageOrder = [
    'IDLE', 'BARCODE_RECEIVED', 'PROGRAM_LOOKUP', 'SENDING_PROGRAM',
    'VISION_TEST_1', 'VISION_TEST_2', 'VISION_TEST_3',
    'VISION_TEST_4', 'VISION_TEST_5', 'VISION_TEST_6',
    'REPORTING', 'DONE',
  ];

  @override
  Widget build(BuildContext context) {
    final info = stageInfo(stage, step, totalSteps);
    final isError = stage == 'ERROR';

    // sub text
    final parts = <String>[];
    if (barcode != null) parts.add('باركود: $barcode');
    if (program != null) parts.add('برنامج: $program');
    if (stage.startsWith('VISION_TEST') && step > 0) parts.add('Step $step/$totalSteps');
    final subText = parts.isNotEmpty ? parts.join('  •  ') : 'جاهز لاستقبال باركود جديد';

    return Container(
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? kDanger.withOpacity(0.5) : kBorderDark,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title
          const Text(
            'المرحلة الحالية',
            style: TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // stage label
          Text(
            info.label,
            style: TextStyle(
              color: isError ? kDanger : kTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),

          // sub info
          Text(subText, style: const TextStyle(color: kTextSub, fontSize: 13)),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: info.percent / 100.0,
              minHeight: 8,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: AlwaysStoppedAnimation(
                isError ? kDanger : kAccent,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stage dots
          _buildStageDots(),
        ],
      ),
    );
  }

  Widget _buildStageDots() {
    final currentIdx = _stageOrder.indexOf(stage);
    return Row(
      children: _stageOrder.take(totalSteps + 4).map((key) {
        final idx = _stageOrder.indexOf(key);
        Color color;
        if (stage == 'ERROR' && key == 'ERROR') {
          color = kDanger;
        } else if (key == stage) {
          color = kAccent;
        } else if (currentIdx > idx) {
          color = kSuccess;
        } else {
          color = const Color(0xFF475569);
        }
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: key,
            child: Icon(Icons.circle, color: color, size: 10),
          ),
        );
      }).toList(),
    );
  }
}
