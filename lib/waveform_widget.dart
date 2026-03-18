import 'package:flutter/widgets.dart';

class WaveformWidget extends StatelessWidget {
  final List<double> waveform;

  const WaveformWidget({super.key, required this.waveform});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 100),
      painter: WaveformPainter(waveform),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveform;

  WaveformPainter(this.waveform);

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) {
      return;
    }

    final paint = Paint()..strokeWidth = 2;

    final width = size.width / waveform.length;

    for (int i = 0; i < waveform.length; i++) {
      final x = i * width;
      final height = waveform[i] * size.height;

      canvas.drawLine(
        Offset(x, size.height / 2 - height / 2),
        Offset(x, size.height / 2 + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
