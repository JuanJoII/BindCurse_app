import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/connect_tab.dart';
import 'screens/devices_tab.dart';
import 'services/udp_audio_service.dart';
import 'theme/obsidian_theme.dart';
import 'widgets/bind_curse_header.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ObsidianTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BindCurseApp());
}

class BindCurseApp extends StatelessWidget {
  const BindCurseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BindCurse',
      debugShowCheckedModeBanner: false,
      theme: ObsidianTheme.themeData,
      home: const BindCurseShell(),
    );
  }
}

class BindCurseShell extends StatefulWidget {
  const BindCurseShell({super.key});

  @override
  State<BindCurseShell> createState() => _BindCurseShellState();
}

class _BindCurseShellState extends State<BindCurseShell> {
  late final UdpAudioService _audioService;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _audioService = UdpAudioService();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _audioService,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: ObsidianTheme.surface,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                BindCurseHeader(audioService: _audioService),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      ConnectTab(audioService: _audioService),
                      DevicesTab(
                        audioService: _audioService,
                        onSwitchToConnectTab: () {
                          setState(() => _selectedIndex = 0);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavBar(),
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: ObsidianTheme.surface.withValues(alpha: 0.90),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.tune,
                    label: 'Conectar',
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.devices,
                    label: 'Dispositivos',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? ObsidianTheme.primary
        : ObsidianTheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => _selectedIndex = index);
        if (index == 1) _audioService.scanNetwork();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: ObsidianTheme.labelMd(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
