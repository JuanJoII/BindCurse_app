import 'package:flutter/material.dart';
import '../services/udp_audio_service.dart';
import '../theme/obsidian_theme.dart';

class ConnectTab extends StatefulWidget {
  final UdpAudioService audioService;

  const ConnectTab({super.key, required this.audioService});

  @override
  State<ConnectTab> createState() => _ConnectTabState();
}

class _ConnectTabState extends State<ConnectTab> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;

  UdpAudioService get _service => widget.audioService;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: _service.hostIp);
    _portController = TextEditingController(text: _service.port.toString());
    _service.addListener(_syncControllers);
  }

  void _syncControllers() {
    if (_ipController.text.trim() != _service.hostIp) {
      _ipController.text = _service.hostIp;
    }
    final port = _service.port.toString();
    if (_portController.text != port) _portController.text = port;
  }

  @override
  void dispose() {
    _service.removeListener(_syncControllers);
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
          if (service.errorMessage != null) ...[
            _buildErrorBanner(service),
            const SizedBox(height: 12),
          ],
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

  // ------------------------------------------------------------------ error
  Widget _buildErrorBanner(UdpAudioService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ObsidianTheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ObsidianTheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: ObsidianTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              service.errorMessage!,
              style: ObsidianTheme.bodySm(color: ObsidianTheme.onErrorContainer),
            ),
          ),
          GestureDetector(
            onTap: service.clearError,
            child: const Icon(
              Icons.close,
              color: ObsidianTheme.onErrorContainer,
              size: 16,
            ),
          ),
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
      LinkState.linked => ('TRANSMITIENDO PCM 48KHZ', ObsidianTheme.signalOnline),
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
                      color: titleColor,
                      shape: BoxShape.circle,
                      boxShadow: capturing
                          ? [BoxShadow(color: titleColor, blurRadius: 8)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: ObsidianTheme.labelMd(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildMonitorToggle(service),
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
              const SizedBox(height: 6),
              Container(
                height: 36,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ObsidianTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(bars.length, (index) {
                    final value = bars[index];
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == bars.length - 1 ? 0 : 4,
                        ),
                        child: FractionallySizedBox(
                          heightFactor: value.clamp(0.06, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 60),
                            decoration: BoxDecoration(
                              color: _barColor(value, clipping),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
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
              if (service.isStreaming) ...[
                const SizedBox(height: 10),
                _buildTelemetryRow(service),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorToggle(UdpAudioService service) {
    final streaming = service.isStreaming || service.isConnecting;
    final on = service.monitorEnabled;
    return GestureDetector(
      onTap: streaming ? null : service.toggleMonitor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: on
              ? ObsidianTheme.primary.withValues(alpha: 0.18)
              : ObsidianTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ObsidianTheme.primary.withValues(alpha: on ? 0.5 : 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.hearing : Icons.hearing_disabled,
              size: 12,
              color: on ? ObsidianTheme.primary : ObsidianTheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              on ? 'MONITOR ON' : 'MONITOR',
              style: ObsidianTheme.labelSm(
                color: on ? ObsidianTheme.primary : ObsidianTheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryRow(UdpAudioService service) {
    final mb = service.bytesSent / (1024 * 1024);
    final items = <(String, String)>[
      ('PAQUETES', '${service.packetsSent}'),
      ('ENVIADO', '${mb.toStringAsFixed(2)} MB'),
      ('RTT', service.rttMs == null ? '—' : '${service.rttMs} ms'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: ObsidianTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    items[i].$1,
                    style: ObsidianTheme.labelSm(color: ObsidianTheme.outline),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$2,
                    style: ObsidianTheme.labelMd(
                      color: ObsidianTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _barColor(double value, bool clipping) {
    if (clipping && value > 0.9) return ObsidianTheme.signalClip;
    if (value > 0.85) return ObsidianTheme.primary;
    if (value > 0.55) return ObsidianTheme.primaryContainer;
    if (value > 0.3) return ObsidianTheme.secondaryContainer;
    return ObsidianTheme.surfaceContainerHigh;
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
    final state = service.linkState;
    final String badge = switch (state) {
      LinkState.idle => 'UDP · HANDSHAKE',
      LinkState.connecting => 'NEGOCIANDO…',
      LinkState.linked =>
        service.rttMs == null ? 'ENLAZADO' : 'RTT ${service.rttMs} MS',
      LinkState.lost => 'SIN RESPUESTA',
    };
    final Color badgeColor = switch (state) {
      LinkState.idle => ObsidianTheme.primary,
      LinkState.connecting => ObsidianTheme.signalWarning,
      LinkState.linked => ObsidianTheme.signalOnline,
      LinkState.lost => ObsidianTheme.signalClip,
    };

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
                  Icon(
                    locked ? Icons.lock : Icons.lock_open,
                    color: ObsidianTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text('Vínculo de Red', style: ObsidianTheme.headlineSm()),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(badge, style: ObsidianTheme.labelSm(color: badgeColor)),
                  ],
                ),
              ),
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
                  Text(
                    service.activeAddress ?? '',
                    style: ObsidianTheme.labelSm(
                      color: ObsidianTheme.signalOnline,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: ObsidianTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ObsidianTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.graphic_eq, size: 16, color: ObsidianTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'PCM crudo vía UDP',
                    style: ObsidianTheme.labelSm(
                      color: ObsidianTheme.secondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Text(
                  '48 kHz / 16-bit Mono',
                  style: ObsidianTheme.labelSm(
                    color: ObsidianTheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
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
              Row(
                children: [
                  const Icon(
                    Icons.speed,
                    size: 14,
                    color: ObsidianTheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Paquete: ${service.latencyTarget.packetMs}ms',
                    style: ObsidianTheme.labelSm(color: ObsidianTheme.primary),
                  ),
                ],
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
                gainStr,
                style: ObsidianTheme.labelMd(
                  color: ObsidianTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
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
          const SizedBox(height: 14),
          Text(
            'TAMAÑO DE PAQUETE (LATENCIA)',
            style: ObsidianTheme.labelSm(color: ObsidianTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: LatencyTarget.values.map((target) {
              final selected = service.latencyTarget == target;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: target == LatencyTarget.values.last ? 0 : 6,
                  ),
                  child: GestureDetector(
                    onTap: () => service.setLatencyTarget(target),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? ObsidianTheme.surfaceContainerHighest
                            : ObsidianTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? ObsidianTheme.primary.withValues(alpha: 0.35)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            target.label,
                            style: ObsidianTheme.labelMd(
                              color: selected
                                  ? ObsidianTheme.primary
                                  : ObsidianTheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${target.rangeLabel} · ${target.chunkBytes} B',
                            style: ObsidianTheme.labelSm(
                              color: selected
                                  ? ObsidianTheme.secondary
                                  : ObsidianTheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ main action
  Widget _buildMainTransmitAction(UdpAudioService service) {
    final state = service.linkState;
    final active = state != LinkState.idle;
    final connecting = state == LinkState.connecting;

    final String label = switch (state) {
      LinkState.idle => 'Vincular Audio (Bind)',
      LinkState.connecting => 'Negociando… (Cancelar)',
      LinkState.linked || LinkState.lost => 'Cortar Vínculo (Stop)',
    };

    return Column(
      children: [
        GestureDetector(
          onTap: service.toggleStreaming,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: active && !connecting
                    ? const [Color(0xFF991B1B), Color(0xFFEF4444), Color(0xFFB91C1C)]
                    : const [
                        ObsidianTheme.onPrimaryFixedVariant,
                        ObsidianTheme.primaryContainer,
                        ObsidianTheme.secondaryContainer,
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active && !connecting
                    ? ObsidianTheme.signalClip.withValues(alpha: 0.6)
                    : ObsidianTheme.primary.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: active && !connecting
                      ? ObsidianTheme.signalClip.withValues(alpha: 0.4)
                      : const Color(0xFFC084FC).withValues(alpha: 0.4),
                  blurRadius: 24,
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
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: ObsidianTheme.headlineSm(color: Colors.white),
                  ),
                ),
                if (!connecting) ...[
                  const SizedBox(width: 6),
                  Icon(
                    active ? Icons.graphic_eq : Icons.bolt,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.token_outlined, size: 14, color: ObsidianTheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: ObsidianTheme.bodySm(color: ObsidianTheme.onSurfaceVariant),
                  children: [
                    const TextSpan(text: 'El receptor debe ejecutar '),
                    TextSpan(
                      text: 'bindcurse_server.py',
                      style: ObsidianTheme.bodySm(
                        color: ObsidianTheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' en el puerto indicado.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
