import 'package:flutter/material.dart';
import '../services/bindcurse_protocol.dart';
import '../services/udp_audio_service.dart';
import '../theme/obsidian_theme.dart';

class AdvancedTab extends StatelessWidget {
  final UdpAudioService audioService;

  const AdvancedTab({super.key, required this.audioService});

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObsidianTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ObsidianTheme.primary.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: ObsidianTheme.primary, size: 24),
            const SizedBox(width: 10),
            Text('Acerca de BindCurse', style: ObsidianTheme.headlineSm()),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BindCurse Virtual Audio Link',
                style: ObsidianTheme.bodyMd(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Cliente móvil de transmisión de micrófono en tiempo real de ultra baja latencia.',
                style: ObsidianTheme.bodySm(),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Versión de la App', 'v1.0.0'),
              _buildInfoRow('Protocolo UDP', 'BindCurse v${BindCurseProtocol.version}'),
              _buildInfoRow('Formato de Audio', 'PCM 16-bit Signed LE'),
              _buildInfoRow('Frecuencia de Muestreo', '${UdpAudioService.sampleRate} Hz (48 kHz)'),
              _buildInfoRow('Canales', 'Mono (1 canal)'),
              _buildInfoRow('Header Binario', 'BCPM (8 bytes)'),
              _buildInfoRow('Puerto por Defecto', '${BindCurseProtocol.defaultPort} UDP'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ObsidianTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Text(
                  'El servidor receptor bindcurse_server.py admite recepción de audio directo, monitoreo VU y reproducción opcional en altavoces.',
                  style: ObsidianTheme.labelSm(
                    color: ObsidianTheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ObsidianTheme.primary,
              foregroundColor: ObsidianTheme.onPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cerrar',
              style: ObsidianTheme.labelMd(
                color: ObsidianTheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ObsidianTheme.bodySm(color: ObsidianTheme.onSurfaceVariant)),
          Text(
            value,
            style: ObsidianTheme.labelMd(
              color: ObsidianTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = audioService;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de sección
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ObsidianTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: ObsidianTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'CONFIGURACIÓN AVANZADA',
                      style: ObsidianTheme.labelSm(
                        color: ObsidianTheme.secondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Parámetros de Red y Buffer', style: ObsidianTheme.headlineSm()),
                const SizedBox(height: 2),
                Text(
                  'Ajusta la segmentación de paquetes UDP para optimizar la latencia según la estabilidad de tu conexión.',
                  style: ObsidianTheme.bodySm(color: ObsidianTheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selector de Tamaño de Paquete (Latencia)
          Container(
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
                        const Icon(Icons.speed, color: ObsidianTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('Tamaño de Paquete (Latencia)', style: ObsidianTheme.headlineSm()),
                      ],
                    ),
                    Text(
                      '${service.latencyTarget.packetMs}ms',
                      style: ObsidianTheme.labelSm(
                        color: ObsidianTheme.signalOnline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Determina cuántos milisegundos de audio PCM se agrupan en cada datagrama UDP enviado.',
                  style: ObsidianTheme.bodySm(),
                ),
                const SizedBox(height: 14),
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
                              vertical: 12,
                              horizontal: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? ObsidianTheme.surfaceContainerHighest
                                  : ObsidianTheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? ObsidianTheme.primary.withValues(alpha: 0.45)
                                    : Colors.transparent,
                                width: 1.5,
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
                                const SizedBox(height: 4),
                                Text(
                                  '${target.rangeLabel} · ${target.chunkBytes} B',
                                  style: ObsidianTheme.labelSm(
                                    color: selected
                                        ? ObsidianTheme.secondary
                                        : ObsidianTheme.onSurfaceVariant.withValues(
                                            alpha: 0.7,
                                          ),
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
          ),
          const SizedBox(height: 16),

          // Métricas de Tráfico de Red (Telemetría en vivo)
          Container(
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
                        const Icon(
                          Icons.analytics_outlined,
                          color: ObsidianTheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tráfico de Red (Telemetría)',
                          style: ObsidianTheme.headlineSm(),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (service.isStreaming
                                ? ObsidianTheme.signalOnline
                                : ObsidianTheme.secondary)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        service.isStreaming ? 'ACTIVO' : 'EN ESPERA',
                        style: ObsidianTheme.labelSm(
                          color: service.isStreaming
                              ? ObsidianTheme.signalOnline
                              : ObsidianTheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitoreo técnico en tiempo real del flujo de datagramas UDP y latencia de ida y vuelta.',
                  style: ObsidianTheme.bodySm(),
                ),
                const SizedBox(height: 12),
                _buildTelemetryGrid(service),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botón Acerca de la App
          Material(
            color: ObsidianTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showAboutDialog(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ObsidianTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: ObsidianTheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: ObsidianTheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: ObsidianTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acerca de la app',
                            style: ObsidianTheme.bodyLg(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Detalles del protocolo UDP, formato PCM y versión',
                            style: ObsidianTheme.labelSm(color: ObsidianTheme.outline),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: ObsidianTheme.outline,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryGrid(UdpAudioService service) {
    final mb = service.bytesSent / (1024 * 1024);
    final items = <(String, String, IconData)>[
      ('PAQUETES', '${service.packetsSent}', Icons.tag),
      ('ENVIADO', '${mb.toStringAsFixed(2)} MB', Icons.cloud_upload_outlined),
      ('RTT', service.rttMs == null ? '—' : '${service.rttMs} ms', Icons.timer_outlined),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: ObsidianTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(items[i].$3, size: 16, color: ObsidianTheme.outline),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$1,
                    style: ObsidianTheme.labelSm(color: ObsidianTheme.outline),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$2,
                    style: ObsidianTheme.labelMd(
                      color: ObsidianTheme.primary,
                      fontWeight: FontWeight.w700,
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
}
