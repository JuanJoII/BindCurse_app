import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/udp_audio_service.dart';
import '../theme/obsidian_theme.dart';

class CurseGlowButton extends StatefulWidget {
  final LinkState linkState;
  final VoidCallback onTap;

  const CurseGlowButton({
    super.key,
    required this.linkState,
    required this.onTap,
  });

  @override
  State<CurseGlowButton> createState() => _CurseGlowButtonState();
}

class _CurseGlowButtonState extends State<CurseGlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Theme colors requested by user:
  // Curse: Fill #491185, Border gradient #D030F0 <-> #30BDF0
  static const Color curseFill = Color(0xFF491185);
  static const Color curseBorderA = Color(0xFFD030F0);
  static const Color curseBorderB = Color(0xFF30BDF0);

  // Break Curse: Fill #CC2916, Border gradient #F2D82E <-> #F2862E
  static const Color breakFill = Color(0xFFCC2916);
  static const Color breakBorderA = Color(0xFFF2D82E);
  static const Color breakBorderB = Color(0xFFF2862E);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.linkState;
    final active = state == LinkState.linked || state == LinkState.lost;
    final connecting = state == LinkState.connecting;

    final String label = switch (state) {
      LinkState.idle => 'Curse',
      LinkState.connecting => 'Negociando…',
      LinkState.linked || LinkState.lost => 'Break Curse',
    };

    final Color fillColor = active ? breakFill : curseFill;
    final Color borderA = active ? breakBorderA : curseBorderA;
    final Color borderB = active ? breakBorderB : curseBorderB;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CurseBorderGlowPainter(
              animationValue: _controller.value,
              colorA: borderA,
              colorB: borderB,
              borderRadius: 14.0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (active ? breakBorderB : curseBorderA)
                        .withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: connecting
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            active ? Icons.stop_rounded : Icons.all_inclusive,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: ObsidianTheme.headlineSm(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CurseBorderGlowPainter extends CustomPainter {
  final double animationValue;
  final Color colorA;
  final Color colorB;
  final double borderRadius;

  _CurseBorderGlowPainter({
    required this.animationValue,
    required this.colorA,
    required this.colorB,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final rotation = animationValue * 2 * math.pi;

    final sweepShader = SweepGradient(
      colors: [colorA, colorB, colorA],
      transform: GradientRotation(rotation),
    ).createShader(rect);

    // Glowing blurred outline
    final glowPaint = Paint()
      ..shader = sweepShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rrect, glowPaint);

    // Sharp neon border
    final strokePaint = Paint()
      ..shader = sweepShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CurseBorderGlowPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.colorA != colorA ||
        oldDelegate.colorB != colorB;
  }
}
