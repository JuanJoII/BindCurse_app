import 'package:flutter/material.dart';
import '../services/udp_audio_service.dart';
import '../theme/obsidian_theme.dart';
import '../widgets/audio_wave_visualizer.dart';
import '../widgets/curse_glow_button.dart';
import '../widgets/top_toast.dart';

class ConnectTab extends StatefulWidget {
  final UdpAudioService audioService;

  const ConnectTab({super.key, required this.audioService});

  @override
  State<ConnectTab> createState() => _ConnectTabState();
}

class _ConnectTabState extends State<ConnectTab> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  String? _lastReportedError;

  UdpAudioService get _service => widget.audioService;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: _service.hostIp);
    _portController = TextEditingController(text: _service.port.toString());
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    _syncControllers();
    _checkErrorToast();
  }

  void _syncControllers() {
    if (_ipController.text.trim() != _service.hostIp) {
      _ipController.text = _service.hostIp;
    }
    final port = _service.port.toString();
    if (_portController.text != port) _portController.text = port;
  }

  void _checkErrorToast() {
    final err = _service.errorMessage;
    if (err != null && err != _lastReportedError) {
      _lastReportedError = err;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        TopToast.show(
          context,
          message: err,
          icon: Icons.error_outline,
          color: ObsidianTheme.signalClip,
        );
      });
    } else if (err == null) {
      _lastReportedError = null;
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMeterCard(service),
          const SizedBox(height: 16),
          if (service.lastLink != null) ...[
            _buildQuickReconnectChip(service),
            const SizedBox(height: 16),
          ],
          _buildNetworkLinkCard(service),
          const SizedBox(height: 16),
          _buildAudioCalibrationCard(service),
          const SizedBox(height: 20),
          _buildMainTransmitAction(service),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ meter
  Widget _buildMeterCard(UdpAudioService service) {
    final capturing = service.isCapturing;
    final state = service.linkState;
    final bars = service.spectrumBars;
    final db = service.currentDb;
    final clipping = service.isClipping;

    final (String title, Color titleColor) = switch (state) {
      LinkState.linked => ('TRANSMITIENDO', ObsidianTheme.signalOnline),
      LinkState.lost => ('ENLACE CAÍDO · SIN PONG', ObsidianTheme.signalClip),
      LinkState.connecting => ('NEGOCIANDO ENLACE', ObsidianTheme.signalWarning),
      LinkState.idle => capturing
          ? ('MONITOR DE MICRÓFONO', ObsidianTheme.primary)
          : ('MICRÓFONO INACTIVO', ObsidianTheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ObsidianTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: capturing
              ? titleColor.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -28,
            top: -28,
            child: IgnorePointer(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ObsidianTheme.primary.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: service.isMuted
                          ? ObsidianTheme.signalClip
                          : titleColor,
                      shape: BoxShape.circle,
                      boxShadow: capturing
                          ? [
                              BoxShadow(
                                color: service.isMuted
                                    ? ObsidianTheme.signalClip
                                    : titleColor,
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.isMuted ? 'SILENCIADO' : title,
                      style: ObsidianTheme.labelMd(
                        color: service.isMuted
                            ? ObsidianTheme.signalClip
                            : titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (service.isStreaming) ...[
                    GestureDetector(
                      onTap: service.toggleMute,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: service.isMuted
                              ? ObsidianTheme.signalClip.withValues(alpha: 0.16)
                              : ObsidianTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: service.isMuted
                                ? ObsidianTheme.signalClip.withValues(alpha: 0.6)
                                : ObsidianTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              service.isMuted ? Icons.mic_off : Icons.mic,
                              size: 13,
                              color: service.isMuted
                                  ? ObsidianTheme.signalClip
                                  : ObsidianTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              service.isMuted ? 'SILENCIADO' : 'MUTE',
                              style: ObsidianTheme.labelSm(
                                color: service.isMuted
                                    ? ObsidianTheme.signalClip
                                    : ObsidianTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        capturing ? Icons.mic : Icons.mic_off,
                        size: 14,
                        color: ObsidianTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sensibilidad de entrada',
                        style: ObsidianTheme.labelSm(
                          color: ObsidianTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    db == null
                        ? '— dB'
                        : '${db.toStringAsFixed(1)} dBFS${clipping ? ' · CLIP' : ''}',
                    style: ObsidianTheme.labelSm(
                      color: clipping
                          ? ObsidianTheme.signalClip
                          : ObsidianTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: ObsidianTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AudioWaveVisualizer(
                  values: bars,
                  isClipping: clipping,
                  height: 42,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final label in const ['60 Hz', '1 kHz', '16 kHz'])
                    Text(
                      label,
                      style: ObsidianTheme.labelSm(
                        color: ObsidianTheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- quick reconnect
  Widget _buildQuickReconnectChip(UdpAudioService service) {
    final last = service.lastLink!;
    final active = service.isActiveDevice(last);
    final busy = service.isConnecting;
    return Material(
      color: ObsidianTheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: active || busy ? null : () => service.quickReconnect(),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ObsidianTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: ObsidianTheme.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.hub_outlined,
                  color: ObsidianTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ÚLTIMO VÍNCULO SELLADO',
                      style: ObsidianTheme.labelSm(
                        color: ObsidianTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      last.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ObsidianTheme.headlineSm().copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      last.address,
                      style: ObsidianTheme.labelMd(color: ObsidianTheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (active ? ObsidianTheme.signalOnline : ObsidianTheme.primary)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (active
                            ? ObsidianTheme.signalOnline
                            : ObsidianTheme.primary)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      active ? 'Enlazado' : 'Revincular',
                      style: ObsidianTheme.labelMd(
                        color: active
                            ? ObsidianTheme.signalOnline
                            : ObsidianTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      active ? Icons.link : Icons.bolt,
                      color: active
                          ? ObsidianTheme.signalOnline
                          : ObsidianTheme.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ network card
  Widget _buildNetworkLinkCard(UdpAudioService service) {
    final locked = service.isStreaming || service.isConnecting;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ObsidianTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                locked ? Icons.lock : Icons.lock_open,
                color: ObsidianTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('Vínculo de Red', style: ObsidianTheme.headlineSm()),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildField(
                  label: 'DIRECCIÓN IP DEL HOST',
                  controller: _ipController,
                  hint: '192.168.1.X',
                  enabled: !locked,
                  keyboardType: TextInputType.url,
                  onChanged: service.setHostIp,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 104,
                child: _buildField(
                  label: 'PUERTO',
                  controller: _portController,
                  hint: '9920',
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) service.setPort(parsed);
                  },
                ),
              ),
            ],
          ),
          if (service.server != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: ObsidianTheme.signalOnline.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ObsidianTheme.signalOnline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.dns_outlined,
                    size: 16,
                    color: ObsidianTheme.signalOnline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Servidor: ${service.server!.name}'
                      '${service.server!.os.isEmpty ? '' : ' · ${service.server!.os}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ObsidianTheme.labelSm(
                        color: ObsidianTheme.onSurface,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    required TextInputType keyboardType,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ObsidianTheme.labelSm(color: ObsidianTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: ObsidianTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            autocorrect: false,
            style: ObsidianTheme.labelLg(
              color: enabled
                  ? ObsidianTheme.onSurface
                  : ObsidianTheme.onSurfaceVariant,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: ObsidianTheme.labelLg(color: ObsidianTheme.outline),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ calibration
  Widget _buildAudioCalibrationCard(UdpAudioService service) {
    final gain = service.gainDb;
    final gainStr = '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)} dB';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ObsidianTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.equalizer, color: ObsidianTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Calibración de Audio', style: ObsidianTheme.headlineSm()),
                ],
              ),
              Text(
                gainStr,
                style: ObsidianTheme.labelMd(
                  color: ObsidianTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ganancia de Entrada',
                style: ObsidianTheme.labelMd(color: ObsidianTheme.onSurface),
              ),
              Text(
                'Nivel digital',
                style: ObsidianTheme.labelSm(color: ObsidianTheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: ObsidianTheme.primary,
              inactiveTrackColor: ObsidianTheme.surfaceContainerLowest,
              thumbColor: ObsidianTheme.primary,
              overlayColor: ObsidianTheme.primary.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: gain,
              min: -24.0,
              max: 18.0,
              divisions: 84,
              onChanged: service.setGainDb,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in const ['-24 dB', '0 dB', '+18 dB'])
                Text(
                  label,
                  style: ObsidianTheme.labelSm(
                    color: ObsidianTheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ main action
  Widget _buildMainTransmitAction(UdpAudioService service) {
    return CurseGlowButton(
      linkState: service.linkState,
      onTap: () {
        if (service.linkState == LinkState.idle) {
          TopToast.show(
            context,
            message:
                'No olvides ejecutar BindCurse Desktop para que la conexión funcione',
            icon: Icons.info_outline,
            color: ObsidianTheme.signalWarning,
          );
        }
        service.toggleStreaming();
      },
    );
  }
}
