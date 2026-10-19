import 'package:flutter/material.dart';
import '../theme/obsidian_theme.dart';

class AudioWaveVisualizer extends StatelessWidget {
  final List<double> values;
  final bool isClipping;
  final double height;

  const AudioWaveVisualizer({
    super.key,
    required this.values,
    this.isClipping = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(
          values: values,
          isClipping: isClipping,
          primaryColor: ObsidianTheme.primary,
          secondaryColor: ObsidianTheme.secondary,
          clipColor: ObsidianTheme.signalClip,
          glowColor: const Color(0xFFC084FC),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> values;
  final bool isClipping;
  final Color primaryColor;
  final Color secondaryColor;
  final Color clipColor;
  final Color glowColor;

  _WavePainter({
    required this.values,
    required this.isClipping,
    required this.primaryColor,
    required this.secondaryColor,
    required this.clipColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerY = size.height / 2;
    final w = size.width;
    final h = size.height;

    // Background center reference line (subtle guideline)
    final refPaint = Paint()
      ..color = ObsidianTheme.outlineVariant.withValues(alpha: 0.18)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, centerY), Offset(w, centerY), refPaint);

    if (values.isEmpty) return;

    final n = values.length;
    final points = <Offset>[];
    final bottomPoints = <Offset>[];

    for (var i = 0; i < n; i++) {
      final x = (i / (n - 1)) * w;
      // Value in [0, 1] mapped to peak amplitude around centerY
      final amplitude = (values[i].clamp(0.04, 1.0) * (h * 0.46));
      points.add(Offset(x, centerY - amplitude));
      bottomPoints.add(Offset(x, centerY + amplitude));
    }

    // 1. Fill gradient path for the wave area
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      fillPath.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    fillPath.lineTo(points.last.dx, points.last.dy);

    // Connect to bottom mirrored curve
    for (var i = bottomPoints.length - 1; i >= 0; i--) {
      fillPath.lineTo(bottomPoints[i].dx, bottomPoints[i].dy);
    }
    fillPath.close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isClipping
          ? [
              clipColor.withValues(alpha: 0.35),
              clipColor.withValues(alpha: 0.05),
              clipColor.withValues(alpha: 0.35),
            ]
          : [
              primaryColor.withValues(alpha: 0.28),
              secondaryColor.withValues(alpha: 0.04),
              primaryColor.withValues(alpha: 0.28),
            ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 2. Stroke lines (top and bottom curves) with neon glow
    final strokeColor = isClipping ? clipColor : primaryColor;

    final strokeGlowPaint = Paint()
      ..color = (isClipping ? clipColor : glowColor).withValues(alpha: 0.4)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    final strokeMainPaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final topPath = Path()..moveTo(points.first.dx, points.first.dy);
    final bottomPath = Path()..moveTo(bottomPoints.first.dx, bottomPoints.first.dy);

    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      topPath.quadraticBezierTo(p0.dx, p0.dy, midX, midY);

      final b0 = bottomPoints[i - 1];
      final b1 = bottomPoints[i];
      final bMidX = (b0.dx + b1.dx) / 2;
      final bMidY = (b0.dy + b1.dy) / 2;
      bottomPath.quadraticBezierTo(b0.dx, b0.dy, bMidX, bMidY);
    }
    topPath.lineTo(points.last.dx, points.last.dy);
    bottomPath.lineTo(bottomPoints.last.dx, bottomPoints.last.dy);

    canvas.drawPath(topPath, strokeGlowPaint);
    canvas.drawPath(bottomPath, strokeGlowPaint);
    canvas.drawPath(topPath, strokeMainPaint);
    canvas.drawPath(bottomPath, strokeMainPaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.isClipping != isClipping ||
        oldDelegate.primaryColor != primaryColor;
  }
}
