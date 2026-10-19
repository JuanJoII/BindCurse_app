import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/udp_audio_service.dart';
import '../theme/obsidian_theme.dart';

class BindCurseHeader extends StatelessWidget {
  final UdpAudioService audioService;

  const BindCurseHeader({super.key, required this.audioService});

  @override
  Widget build(BuildContext context) {
    final state = audioService.linkState;
    final (String statusLabel, Color statusColor, bool highlighted) =
        switch (state) {
      LinkState.idle => ('Sin Enlace', ObsidianTheme.secondary, false),
      LinkState.connecting => ('Negociando…', ObsidianTheme.signalWarning, true),
      LinkState.linked => ('Enlazado UDP', ObsidianTheme.signalOnline, true),
      LinkState.lost => ('Enlace Caído', ObsidianTheme.signalClip, true),
    };

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: ObsidianTheme.surface.withValues(alpha: 0.82),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand Logo & Title
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ObsidianTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ObsidianTheme.primary.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC084FC).withValues(alpha: 0.35),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_fix_high,
                      color: ObsidianTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BindCurse',
                        style: ObsidianTheme.headlineSm(
                          color: ObsidianTheme.primary,
                          fontWeight: FontWeight.w600,
                        ).copyWith(height: 1.0, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'CURSED LINK // UDP',
                        style: ObsidianTheme.labelSm(
                          color: ObsidianTheme.secondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Right Status Pill & Flare Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: highlighted
                          ? statusColor.withValues(alpha: 0.14)
                          : ObsidianTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                      border: highlighted
                          ? Border.all(
                              color: statusColor.withValues(alpha: 0.4),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulsingDot(
                          color: highlighted
                              ? statusColor
                              : ObsidianTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: ObsidianTheme.labelMd(color: statusColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ObsidianTheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ObsidianTheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.flare,
                      color: ObsidianTheme.primary,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: 0.3 + (_controller.value * 0.5),
                ),
                blurRadius: 4 + (_controller.value * 6),
                spreadRadius: _controller.value * 1.5,
              ),
            ],
          ),
        );
      },
    );
  }
}
