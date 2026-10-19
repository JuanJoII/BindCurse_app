import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../theme/obsidian_theme.dart';
import 'udp_audio_service.dart';

// The callback function must be a top-level or static function for the background isolate.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BindCurseTaskHandler());
}

/// TaskHandler running in the background isolate.
class BindCurseTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    // Forward the button press action to the main isolate
    FlutterForegroundTask.sendDataToMain(id);
  }

  @override
  void onNotificationPressed() {
    // Bring the app to the foreground when notification is tapped
    FlutterForegroundTask.launchApp();
  }
}

/// Manages the Android/iOS foreground service, keep-alive notification, and remote actions.
class BackgroundServiceManager {
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool _initialized = false;
  static UdpAudioService? _audioService;

  /// Initializes communication and notification channels.
  static void initialize(UdpAudioService audioService) {
    _audioService = audioService;
    if (!isSupported) return;

    if (!_initialized) {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'bindcurse_stream_service',
          channelName: 'BindCurse Transmisión de Audio',
          channelDescription:
              'Mantiene la captura del micrófono y envío UDP activo en segundo plano.',
          channelImportance: NotificationChannelImportance.DEFAULT,
          priority: NotificationPriority.DEFAULT,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );

      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
      _initialized = true;
    }
  }

  static void _onReceiveTaskData(Object data) {
    if (data == 'btn_mute') {
      _audioService?.toggleMute();
    } else if (data == 'btn_disconnect') {
      _audioService?.disconnect();
    }
  }

  /// Requests notification permission (required on Android 13+).
  static Future<void> requestPermissions() async {
    if (!isSupported) return;
    try {
      final NotificationPermission notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  /// Syncs foreground service state with the current connection and mute status.
  static Future<void> syncServiceState({
    required bool isStreaming,
    required bool isMuted,
    required String connectionTarget,
  }) async {
    if (!isSupported) return;

    if (!isStreaming) {
      await stopService();
      return;
    }

    await startOrUpdateService(
      connectionTarget: connectionTarget,
      isMuted: isMuted,
    );
  }

  /// Starts or updates the foreground service notification.
  static Future<void> startOrUpdateService({
    required String connectionTarget,
    required bool isMuted,
  }) async {
    if (!isSupported) return;

    final title = isMuted
        ? 'BindCurse · Micrófono Silenciado'
        : 'BindCurse · Transmitiendo';
    final text = 'Conectado a: $connectionTarget';

    final buttons = [
      NotificationButton(
        id: 'btn_mute',
        text: isMuted ? 'Unmute' : 'Mute',
        textColor:
            isMuted ? ObsidianTheme.signalOnline : ObsidianTheme.signalWarning,
      ),
      const NotificationButton(
        id: 'btn_disconnect',
        text: 'Desconectar',
        textColor: ObsidianTheme.signalClip,
      ),
    ];

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
          notificationButtons: buttons,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          serviceTypes: [
            ForegroundServiceTypes.microphone,
          ],
          notificationTitle: title,
          notificationText: text,
          notificationButtons: buttons,
          callback: startCallback,
        );
      }
    } catch (e) {
      debugPrint('Error starting or updating foreground service: $e');
    }
  }

  /// Stops the background foreground service.
  static Future<void> stopService() async {
    if (!isSupported) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Error stopping foreground service: $e');
    }
  }

  /// Cleanup when application is disposed.
  static void dispose() {
    if (isSupported && _initialized) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
      _initialized = false;
    }
    _audioService = null;
  }
}
