import 'package:flutter/material.dart';
import '../models/linked_device.dart';
import '../services/bindcurse_protocol.dart';
import '../services/udp_audio_service.dart';
import '../theme/obsidian_theme.dart';

class DevicesTab extends StatefulWidget {
  final UdpAudioService audioService;
  final VoidCallback onSwitchToConnectTab;

  const DevicesTab({
    super.key,
    required this.audioService,
    required this.onSwitchToConnectTab,
  });

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  UdpAudioService get _service => widget.audioService;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LinkedDevice> get _filtered {
    final all = _service.devices;
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            (d.os ?? '').toLowerCase().contains(q) ||
            d.address.contains(q))
        .toList();
  }

  IconData _iconForOs(String? os) {
    final lower = (os ?? '').toLowerCase();
    if (lower.contains('darwin') || lower.contains('mac')) return Icons.laptop_mac;
    if (lower.contains('linux')) return Icons.terminal;
    if (lower.contains('windows')) return Icons.desktop_windows;
    return Icons.dns_outlined;
  }

  Future<void> _connect(LinkedDevice device) async {
    widget.onSwitchToConnectTab();
    await _service.quickReconnect(device: device);
  }

  // ---------------------------------------------------------------- dialogs
  Widget _dialogInput(
    String label,
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: ObsidianTheme.labelSm(color: ObsidianTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          autocorrect: false,
          keyboardType: isNumber ? TextInputType.number : TextInputType.url,
          style: ObsidianTheme.labelLg(color: ObsidianTheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ObsidianTheme.labelMd(color: ObsidianTheme.outline),
            filled: true,
            fillColor: ObsidianTheme.surfaceContainerLowest,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddressDialog({LinkedDevice? device}) async {
    final nameCtrl = TextEditingController(text: device?.name ?? '');
    final ipCtrl = TextEditingController(text: device?.ip ?? '');
    final portCtrl = TextEditingController(
      text: (device?.port ?? _service.port).toString(),
    );
    final editing = device != null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObsidianTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ObsidianTheme.primary.withValues(alpha: 0.3)),
        ),
        title: Text(
          editing ? 'Asignar IP / Puerto UDP' : 'Añadir IP Fija',
          style: ObsidianTheme.headlineSm(),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!editing) ...[
                _dialogInput('Nombre (opcional)', nameCtrl, 'Ej. PC Estudio'),
                const SizedBox(height: 10),
              ],
              _dialogInput('Dirección IP', ipCtrl, '192.168.1.50'),
              const SizedBox(height: 10),
              _dialogInput('Puerto UDP', portCtrl, '9920', isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: ObsidianTheme.labelMd(color: ObsidianTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ObsidianTheme.primary,
              foregroundColor: ObsidianTheme.onPrimary,
            ),
            onPressed: () {
              final ip = ipCtrl.text.trim();
              final port = int.tryParse(portCtrl.text.trim());
              if (ip.isEmpty || port == null || port <= 0 || port > 65535) {
                return;
              }
              if (editing) {
                _service.updateDeviceAddress(device.id, ip, port);
              } else {
                _service.addDevice(name: nameCtrl.text, ip: ip, port: port);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(editing ? 'Actualizar' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(LinkedDevice device) async {
    final ctrl = TextEditingController(text: device.name);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ObsidianTheme.surfaceContainerHigh,
        title: Text('Renombrar Altar', style: ObsidianTheme.headlineSm()),
        content: _dialogInput('Nuevo nombre', ctrl, device.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: ObsidianTheme.labelMd(color: ObsidianTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ObsidianTheme.primary,
              foregroundColor: ObsidianTheme.onPrimary,
            ),
            onPressed: () {
              _service.renameDevice(device.id, ctrl.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _openContextSheet(LinkedDevice device) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ObsidianTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ObsidianTheme.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AJUSTES DEL ALTAR',
                        style: ObsidianTheme.labelSm(color: ObsidianTheme.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device.name,
                        style: ObsidianTheme.headlineSm(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close, size: 18, color: ObsidianTheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _sheetItem(
              icon: Icons.network_ping,
              color: ObsidianTheme.primary,
              title: 'Comprobar conexión',
              subtitle: 'Enviar BINDCURSE_DISCOVER y medir RTT',
              onTap: () {
                Navigator.of(ctx).pop();
                _service.probeDevice(device);
              },
            ),
            _sheetItem(
              icon: Icons.edit,
              color: ObsidianTheme.primary,
              title: 'Renombrar altar',
              subtitle: 'Cambiar nombre local',
              onTap: () {
                Navigator.of(ctx).pop();
                _showRenameDialog(device);
              },
            ),
            _sheetItem(
              icon: Icons.push_pin_outlined,
              color: ObsidianTheme.secondary,
              title: 'Asignar IP Fija / Puerto UDP',
              subtitle: device.address,
              onTap: () {
                Navigator.of(ctx).pop();
                _showAddressDialog(device: device);
              },
            ),
            _sheetItem(
              icon: Icons.delete_sweep_outlined,
              color: ObsidianTheme.error,
              title: 'Romper vínculo',
              subtitle: 'Eliminar de los guardados',
              destructive: true,
              onTap: () {
                Navigator.of(ctx).pop();
                _service.removeDevice(device.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ObsidianTheme.bodyMd(
                      color: destructive ? ObsidianTheme.error : ObsidianTheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: ObsidianTheme.labelSm(
                      color: destructive
                          ? ObsidianTheme.error.withValues(alpha: 0.8)
                          : ObsidianTheme.outline,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final service = _service;
    final filtered = _filtered;
    final discovered = service.discovered;

    return RefreshIndicator(
      color: ObsidianTheme.primary,
      backgroundColor: ObsidianTheme.surfaceContainerHigh,
      onRefresh: service.scanNetwork,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBanner(service),
            const SizedBox(height: 12),
            if (service.devices.isNotEmpty) ...[
              _buildSearchBar(service.devices.length),
              const SizedBox(height: 12),
            ],
            if (service.devices.isEmpty)
              _buildEmptyState()
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Ningún altar coincide con "$_query".',
                  textAlign: TextAlign.center,
                  style: ObsidianTheme.bodySm(),
                ),
              )
            else
              for (final device in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildDeviceCard(device),
                ),
            if (discovered.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionLabel('DETECTADOS EN LA RED LOCAL'),
              const SizedBox(height: 8),
              for (final info in discovered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildDiscoveredCard(info),
                ),
            ],
            const SizedBox(height: 10),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: ObsidianTheme.labelSm(color: ObsidianTheme.secondary, letterSpacing: 1),
      );

  Widget _buildBanner(UdpAudioService service) {
    return Container(
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
              const Icon(Icons.wifi_tethering, color: ObsidianTheme.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'BÚSQUEDA LAN · PUERTO ${service.port}',
                  style: ObsidianTheme.labelSm(
                    color: ObsidianTheme.secondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: service.isScanning ? null : service.scanNetwork,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ObsidianTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: ObsidianTheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: service.isScanning
                            ? const CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: ObsidianTheme.primary,
                              )
                            : const Icon(Icons.sync, size: 14, color: ObsidianTheme.primary),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        service.isScanning ? 'Rastreando…' : 'Rastrear Señal',
                        style: ObsidianTheme.labelMd(color: ObsidianTheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Dispositivos Sellados', style: ObsidianTheme.headlineSm()),
          const SizedBox(height: 2),
          Text(
            'Servidores BindCurse guardados. "Rastrear" comprueba cuáles '
            'responden y busca nuevos en tu red.',
            style: ObsidianTheme.bodySm(color: ObsidianTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: ObsidianTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ObsidianTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.link_off, color: ObsidianTheme.outline, size: 32),
          const SizedBox(height: 8),
          Text('Aún no hay altares sellados', style: ObsidianTheme.bodyMd()),
          const SizedBox(height: 4),
          Text(
            'Se guardan automáticamente al enlazar con éxito, o puedes '
            'añadirlos manualmente.',
            textAlign: TextAlign.center,
            style: ObsidianTheme.bodySm(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(int total) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: ObsidianTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: ObsidianTheme.outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: ObsidianTheme.bodyMd(),
              decoration: InputDecoration(
                hintText: 'Filtrar por nombre, SO o IP...',
                hintStyle: ObsidianTheme.bodyMd(color: ObsidianTheme.outline),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ObsidianTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: ObsidianTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              '$total ${total == 1 ? 'altar' : 'altares'}',
              style: ObsidianTheme.labelSm(color: ObsidianTheme.secondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(LinkedDevice device) {
    final service = _service;
    final active = service.isActiveDevice(device);
    final probing = service.isProbing(device.id);
    final probe = service.probeFor(device.id);
    final online = active || (probe?.online ?? false);
    final offline = !active && probe != null && !probe.online;

    final String statusText;
    final Color statusColor;
    if (active) {
      statusText = service.linkState == LinkState.lost
          ? 'Enlace caído'
          : 'Transmitiendo${service.rttMs != null ? ' · ${service.rttMs} ms' : ''}';
      statusColor = service.linkState == LinkState.lost
          ? ObsidianTheme.signalClip
          : ObsidianTheme.signalOnline;
    } else if (probing) {
      statusText = 'Comprobando…';
      statusColor = ObsidianTheme.signalWarning;
    } else if (probe == null) {
      statusText = 'Sin comprobar';
      statusColor = ObsidianTheme.outline;
    } else if (probe.online) {
      statusText = 'En línea${probe.rttMs != null ? ' · ${probe.rttMs} ms' : ''}';
      statusColor = ObsidianTheme.primary;
    } else {
      statusText = 'Sin respuesta';
      statusColor = ObsidianTheme.outline;
    }

    final cardBg = offline ? ObsidianTheme.surfaceContainerLow : ObsidianTheme.surfaceContainer;
    final borderColor = active
        ? ObsidianTheme.signalOnline.withValues(alpha: 0.4)
        : online
            ? ObsidianTheme.primary.withValues(alpha: 0.32)
            : ObsidianTheme.outlineVariant.withValues(alpha: 0.3);

    return Opacity(
      opacity: offline ? 0.85 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: online
                            ? ObsidianTheme.surfaceContainerHighest
                            : ObsidianTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: online
                            ? Border.all(color: ObsidianTheme.primary.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Icon(
                        _iconForOs(device.os),
                        color: online ? ObsidianTheme.primary : ObsidianTheme.outline,
                        size: 24,
                      ),
                    ),
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardBg, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              device.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ObsidianTheme.bodyLg(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (device.os != null && device.os!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ObsidianTheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                device.os!,
                                style: ObsidianTheme.labelSm(color: ObsidianTheme.secondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: device.address),
                            TextSpan(
                              text: ' · ',
                              style: ObsidianTheme.labelMd(color: ObsidianTheme.outline),
                            ),
                            TextSpan(
                              text: statusText,
                              style: ObsidianTheme.labelMd(color: statusColor),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ObsidianTheme.labelMd(color: ObsidianTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openContextSheet(device),
                  icon: const Icon(Icons.more_vert, size: 20, color: ObsidianTheme.outline),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.history, size: 12, color: ObsidianTheme.outlineVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    formatLastSeen(device.lastConnected),
                    style: ObsidianTheme.labelSm(color: ObsidianTheme.outline),
                  ),
                ),
                _buildCardAction(device, active: active, online: online),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAction(
    LinkedDevice device, {
    required bool active,
    required bool online,
  }) {
    if (active) {
      return GestureDetector(
        onTap: _service.disconnect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ObsidianTheme.signalClip.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ObsidianTheme.signalClip.withValues(alpha: 0.4)),
          ),
          child: Text(
            'Cortar',
            style: ObsidianTheme.labelMd(
              color: ObsidianTheme.signalClip,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    final busy = _service.isConnecting;
    return GestureDetector(
      onTap: busy ? null : () => _connect(device),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: online
              ? ObsidianTheme.primary
              : ObsidianTheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: online
              ? null
              : Border.all(color: ObsidianTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt,
              size: 16,
              color: online ? ObsidianTheme.onPrimary : ObsidianTheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Vincular',
              style: ObsidianTheme.labelMd(
                color: online ? ObsidianTheme.onPrimary : ObsidianTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveredCard(ServerInfo info) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ObsidianTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ObsidianTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ObsidianTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconForOs(info.os), color: ObsidianTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ObsidianTheme.bodyMd(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.ip}:${info.port}'
                  '${info.rttMs != null ? ' · ${info.rttMs} ms' : ''}'
                  '${info.os.isNotEmpty ? ' · ${info.os}' : ''}',
                  style: ObsidianTheme.labelSm(color: ObsidianTheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Guardar',
            onPressed: () => _service.saveDiscovered(info),
            icon: const Icon(Icons.bookmark_add_outlined, color: ObsidianTheme.secondary, size: 20),
          ),
          GestureDetector(
            onTap: _service.isConnecting
                ? null
                : () => _connect(_service.saveDiscovered(info)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ObsidianTheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Vincular',
                style: ObsidianTheme.labelMd(
                  color: ObsidianTheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showAddressDialog(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: ObsidianTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ObsidianTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, color: ObsidianTheme.primary, size: 22),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Añadir IP Fija', style: ObsidianTheme.bodyMd(fontWeight: FontWeight.w600)),
                    Text(
                      'Vínculo Manual',
                      style: ObsidianTheme.labelSm(
                        color: ObsidianTheme.outline,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ObsidianTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ObsidianTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.token_outlined, size: 16, color: ObsidianTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Protocolo BindCurse UDP v${BindCurseProtocol.version}',
                  style: ObsidianTheme.labelSm(
                    color: ObsidianTheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Text(
                'PCM 16-bit · 48 kHz',
                style: ObsidianTheme.labelSm(
                  color: ObsidianTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
