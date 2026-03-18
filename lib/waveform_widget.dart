import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class WaveformWidget extends StatelessWidget {
  final List<double> waveform;

  /// Playback progress from 0.0 (start) to 1.0 (end).
  /// Bars up to this fraction are drawn in the played colour.
  final double progress;

  const WaveformWidget({
    super.key,
    required this.waveform,
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox.expand(
        child: CustomPaint(
          painter: WaveformPainter(waveform, progress),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final double progress;

  WaveformPainter(this.waveform, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final backgroundPaint = Paint()..color = const Color(0xFFF2EEF8);
    final playedPaint = Paint()..color = const Color(0xFF4A3B8F);
    final unplayedPaint = Paint()..color = const Color(0xFFCBC6E8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      backgroundPaint,
    );

    const double gap = 2;
    final double barWidth =
        math.max(2, (size.width - ((waveform.length - 1) * gap)) / waveform.length);
    final double totalWidth =
        (barWidth * waveform.length) + (gap * (waveform.length - 1));
    final double startX = (size.width - totalWidth) / 2;
    final double maxValue = waveform.reduce(math.max).clamp(0.01, 1.0);
    final int playedCount = (progress * waveform.length).round();

    for (int i = 0; i < waveform.length; i++) {
      final double normalized = (waveform[i] / maxValue).clamp(0.0, 1.0);
      final double eased = math.sqrt(normalized);
      final double barHeight = math.max(8, eased * size.height * 0.78);
      final double left = startX + i * (barWidth + gap);
      final double top = (size.height - barHeight) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        i < playedCount ? playedPaint : unplayedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter old) =>
      old.progress != progress || old.waveform != waveform;
}
