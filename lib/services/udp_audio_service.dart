import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/linked_device.dart';
import 'background_service_manager.dart';
import 'bindcurse_protocol.dart';
import 'spectrum_analyzer.dart';

/// Packet duration presets. At 48 kHz / 16-bit / mono the stream is
/// 96 000 bytes per second, so 1 ms = 96 bytes of PCM.
enum LatencyTarget {
  ultraLow(label: 'Ultra Baja', packetMs: 10),
  studio(label: 'Estudio', packetMs: 20),
  safe(label: 'Segura', packetMs: 48);

  final String label;
  final int packetMs;

  const LatencyTarget({required this.label, required this.packetMs});

  int get chunkBytes => packetMs * 96;
  String get rangeLabel => '$packetMs ms';
}

enum LinkState { idle, connecting, linked, lost }

class UdpAudioService extends ChangeNotifier {
  static const int sampleRate = 48000;
  static const int numChannels = 1;
  static const int bitsPerSample = 16;
  static const int barCount = 15;
  static const double idleBar = 0.06;

  // ---------------------------------------------------------------- capture
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _captureSub;
  bool _isCapturing = false;
  bool _monitorEnabled = false;
  bool _captureStarting = false;
  bool _isMuted = false;

  final SpectrumAnalyzer _analyzer = SpectrumAnalyzer(bandCount: barCount);
  List<double> _bars = List<double>.filled(barCount, idleBar);
  double? _currentDb;
  DateTime _clipUntil = DateTime.fromMillisecondsSinceEpoch(0);
  final Stopwatch _uiThrottle = Stopwatch()..start();

  // ------------------------------------------------------------------- link
  UdpChannel? _channel;
  StreamSubscription<Datagram>? _sessionSub;
  InternetAddress? _targetAddress;
  int _targetPort = BindCurseProtocol.defaultPort;
  LinkState _linkState = LinkState.idle;
  ServerInfo? _server;
  int? _rttMs;
  DateTime _lastPongAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _pingTimer;
  int _pingSeq = 0;
  final Map<int, DateTime> _pingsInFlight = {};
  int _audioSeq = 0;
  int _connectToken = 0;
  final BytesBuilder _outgoing = BytesBuilder(copy: false);
  int _packetsSent = 0;
  int _bytesSent = 0;

  // --------------------------------------------------------------- settings
  String _hostInput = '';
  int _port = BindCurseProtocol.defaultPort;
  double _gainDb = 0.0;
  LatencyTarget _latencyTarget = LatencyTarget.studio;
  String? _errorMessage;

  // ---------------------------------------------------------------- devices
  List<LinkedDevice> _devices = [];
  LinkedDevice? _lastLink;
  final Map<String, DeviceProbe> _probes = {};
  final Set<String> _probing = {};
  List<ServerInfo> _discovered = [];
  bool _isScanning = false;
  bool _isPreferencesLoaded = false;
  final Completer<void> _prefsCompleter = Completer<void>();

  UdpAudioService() {
    _loadPreferences();
  }

  // ---------------------------------------------------------------- getters
  bool get isCapturing => _isCapturing;
  bool get monitorEnabled => _monitorEnabled;
  bool get isMuted => _isMuted;
  List<double> get spectrumBars => _bars;
  double? get currentDb => _currentDb;
  bool get isClipping => DateTime.now().isBefore(_clipUntil);

  LinkState get linkState => _linkState;
  bool get isStreaming =>
      _linkState == LinkState.linked || _linkState == LinkState.lost;
  bool get isConnecting => _linkState == LinkState.connecting;
  ServerInfo? get server => _server;
  int? get rttMs => _rttMs;
  int get packetsSent => _packetsSent;
  int get bytesSent => _bytesSent;
  String? get activeAddress => _targetAddress == null
      ? null
      : '${_targetAddress!.address}:$_targetPort';

  String get hostIp => _hostInput;
  int get port => _port;
  double get gainDb => _gainDb;
  LatencyTarget get latencyTarget => _latencyTarget;
  String? get errorMessage => _errorMessage;

  List<LinkedDevice> get devices => List.unmodifiable(_devices);
  LinkedDevice? get lastLink => _lastLink;
  DeviceProbe? probeFor(String id) => _probes[id];
  bool isProbing(String id) => _probing.contains(id);
  List<ServerInfo> get discovered => List.unmodifiable(_discovered);
  bool get isScanning => _isScanning;

  bool isActiveDevice(LinkedDevice d) =>
      isStreaming &&
      _targetAddress?.address == d.ip &&
      _targetPort == d.port;

  // ------------------------------------------------------------ persistence
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check legacy 'linked_devices' if saved_hosts_v2 is missing
      var devicesJson = prefs.getString('saved_hosts_v2');
      if (devicesJson == null || devicesJson.isEmpty) {
        final legacyJson = prefs.getString('linked_devices');
        if (legacyJson != null && legacyJson.isNotEmpty) {
          devicesJson = legacyJson;
        }
      }

      // Check legacy last sealed info if last_link_v2 is missing
      final lastJson = prefs.getString('last_link_v2');
      LinkedDevice? legacyLastLink;
      if (lastJson == null || lastJson.isEmpty) {
        final legacyIp = prefs.getString('last_sealed_ip');
        final legacyPort = prefs.getInt('last_sealed_port');
        final legacyName = prefs.getString('last_sealed_name');
        if (legacyIp != null && legacyIp.isNotEmpty) {
          legacyLastLink = LinkedDevice(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: (legacyName != null && legacyName.isNotEmpty) ? legacyName : legacyIp,
            ip: legacyIp,
            port: legacyPort ?? BindCurseProtocol.defaultPort,
          );
        }
      }

      // Drop obsolete keys now that we've checked for any migration
      for (final key in const [
        'linked_devices',
        'last_sealed_name',
        'last_sealed_ip',
        'last_sealed_port',
      ]) {
        await prefs.remove(key);
      }

      _hostInput = prefs.getString('host_ip_v2') ?? _hostInput;
      final savedPort = prefs.getInt('host_port_v2');
      if (savedPort == null || savedPort == 9920) {
        _port = BindCurseProtocol.defaultPort;
      } else {
        _port = savedPort;
      }
      _gainDb = prefs.getDouble('gain_db_v2') ?? _gainDb;
      final latency = prefs.getString('latency_v2');
      if (latency != null) {
        _latencyTarget = LatencyTarget.values.firstWhere(
          (l) => l.name == latency,
          orElse: () => _latencyTarget,
        );
      }

      if (devicesJson != null && devicesJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(devicesJson);
          if (decoded is List) {
            final loaded = <LinkedDevice>[];
            for (final item in decoded) {
              try {
                if (item is Map) {
                  loaded.add(
                    LinkedDevice.fromJson(Map<String, dynamic>.from(item)),
                  );
                }
              } catch (e) {
                debugPrint('BindCurse: error parsing device: $e');
              }
            }
            if (loaded.isNotEmpty) {
              _devices = loaded;
            }
          }
        } catch (e) {
          debugPrint('BindCurse: error decoding devices JSON: $e');
        }
      }

      if (lastJson != null && lastJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(lastJson);
          if (decoded is Map) {
            _lastLink = LinkedDevice.fromJson(
              Map<String, dynamic>.from(decoded),
            );
          }
        } catch (e) {
          debugPrint('BindCurse: error decoding last link JSON: $e');
        }
      } else if (legacyLastLink != null) {
        _lastLink = legacyLastLink;
      }

      // Fallback: if no lastLink was persisted but we have saved devices, use the first one
      if (_lastLink == null && _devices.isNotEmpty) {
        _lastLink = _devices.first;
      }

      // If hostInput is empty and we have a lastLink, populate hostInput and port
      if (_hostInput.isEmpty && _lastLink != null) {
        _hostInput = _lastLink!.ip;
        _port = _lastLink!.port;
      }
    } catch (e) {
      debugPrint('BindCurse: error loading preferences: $e');
    } finally {
      _isPreferencesLoaded = true;
      if (!_prefsCompleter.isCompleted) {
        _prefsCompleter.complete();
      }
      // Activar micrófono de inmediato por defecto para mostrar el espectro visual
      _monitorEnabled = true;
      _startCapture();
      notifyListeners();
    }
  }

  Future<void> _savePreferences() async {
    if (!_isPreferencesLoaded) {
      await _prefsCompleter.future;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('host_ip_v2', _hostInput);
      await prefs.setInt('host_port_v2', _port);
      await prefs.setDouble('gain_db_v2', _gainDb);
      await prefs.setString('latency_v2', _latencyTarget.name);
      await prefs.setString(
        'saved_hosts_v2',
        jsonEncode(_devices.map((d) => d.toJson()).toList()),
      );
      if (_lastLink != null) {
        await prefs.setString('last_link_v2', jsonEncode(_lastLink!.toJson()));
      } else {
        await prefs.remove('last_link_v2');
      }
    } catch (e) {
      debugPrint('BindCurse: error saving preferences: $e');
    }
  }

  // --------------------------------------------------------------- settings
  void setHostIp(String value) {
    _hostInput = value.trim();
    _errorMessage = null;
    _savePreferences();
    notifyListeners();
  }

  void setPort(int value) {
    if (value <= 0 || value > 65535) return;
    _port = value;
    _errorMessage = null;
    _savePreferences();
    notifyListeners();
  }

  void setGainDb(double db) {
    _gainDb = db.clamp(-24.0, 18.0);
    _savePreferences();
    notifyListeners();
  }

  void setLatencyTarget(LatencyTarget target) {
    _latencyTarget = target;
    _savePreferences();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _syncForegroundService();
    notifyListeners();
  }

  void setMuted(bool value) {
    if (_isMuted != value) {
      _isMuted = value;
      _syncForegroundService();
      notifyListeners();
    }
  }

  void _syncForegroundService() {
    final target = _server != null && _server!.name.isNotEmpty
        ? '${_server!.name} ($activeAddress)'
        : (activeAddress ?? '$_hostInput:$_port');

    BackgroundServiceManager.syncServiceState(
      isStreaming: isStreaming,
      isMuted: _isMuted,
      connectionTarget: target,
    );
  }

  // ---------------------------------------------------------------- monitor
  Future<void> toggleMonitor() async {
    if (_monitorEnabled) {
      _monitorEnabled = false;
      if (!isStreaming && !isConnecting) await _stopCapture();
    } else {
      _monitorEnabled = true;
      notifyListeners();
      final ok = await _startCapture();
      if (!ok) _monitorEnabled = false;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------- link
  Future<void> toggleStreaming() async {
    if (isStreaming || isConnecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  /// Connects to [device] (or the last link if null) using the handshake.
  Future<void> quickReconnect({LinkedDevice? device}) async {
    final target = device ?? _lastLink;
    if (target == null) return;
    if (isStreaming || isConnecting) await disconnect();
    _hostInput = target.ip;
    _port = target.port;
    await _savePreferences();
    notifyListeners();
    await connect();
  }

  Future<InternetAddress?> _resolve(String host) async {
    final literal = InternetAddress.tryParse(host);
    if (literal != null) return literal;
    try {
      final results = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      return results.firstWhere(
        (a) => a.type == InternetAddressType.IPv4,
        orElse: () => results.first,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> connect() async {
    if (isStreaming || isConnecting) return;
    _errorMessage = null;

    final host = _hostInput.trim();
    if (host.isEmpty) {
      _errorMessage = 'Escribe la dirección IP del servidor.';
      notifyListeners();
      return;
    }
    if (_port <= 0 || _port > 65535) {
      _errorMessage = 'Puerto UDP inválido: $_port';
      notifyListeners();
      return;
    }

    await _savePreferences();

    final token = ++_connectToken;
    _linkState = LinkState.connecting;
    notifyListeners();

    final address = await _resolve(host);
    if (token != _connectToken) return;
    if (address == null) {
      _failConnect('No se pudo resolver la dirección "$host".');
      return;
    }

    UdpChannel channel;
    try {
      channel = await UdpChannel.bind();
    } catch (e) {
      _failConnect('No se pudo abrir un socket UDP: $e');
      return;
    }
    if (token != _connectToken) {
      channel.close();
      return;
    }

    final stopwatch = Stopwatch()..start();
    final reply = await channel.request(
      message: [
        BindCurseProtocol.hello,
        BindCurseProtocol.version,
        sampleRate,
        bitsPerSample,
        numChannels,
        'BindCurse-${Platform.operatingSystem}',
      ].join('|'),
      expect: BindCurseProtocol.ack,
      address: address,
      port: _port,
    );
    stopwatch.stop();

    if (token != _connectToken) {
      channel.close();
      return;
    }
    if (reply == null) {
      channel.close();
      _failConnect(
        'Sin respuesta de ${address.address}:$_port. Verifica que '
        'bindcurse_server.py esté en ejecución, que el puerto UDP esté '
        'abierto en el firewall y que ambos estén en la misma red.',
      );
      return;
    }

    final captureOk = await _startCapture();
    if (token != _connectToken) {
      channel.close();
      return;
    }
    if (!captureOk) {
      channel.sendText(BindCurseProtocol.bye, address, _port);
      channel.close();
      _linkState = LinkState.idle;
      notifyListeners();
      return;
    }

    _channel = channel;
    _targetAddress = address;
    _targetPort = _port;
    _server = ServerInfo(
      name: reply.length > 1 && reply[1].isNotEmpty ? reply[1] : address.address,
      os: reply.length > 2 ? reply[2] : '',
      ip: address.address,
      port: _port,
    );
    _rttMs = stopwatch.elapsedMilliseconds;
    _lastPongAt = DateTime.now();
    _pingsInFlight.clear();
    _audioSeq = 0;
    _packetsSent = 0;
    _bytesSent = 0;
    _outgoing.clear();
    _sessionSub = channel.datagrams.listen(_onSessionDatagram);
    _pingTimer = Timer.periodic(BindCurseProtocol.pingInterval, (_) => _tick());
    _linkState = LinkState.linked;

    _rememberLink(_server!);
    _syncForegroundService();
    notifyListeners();
  }

  void _failConnect(String message) {
    _linkState = LinkState.idle;
    _errorMessage = message;
    notifyListeners();
  }

  void _rememberLink(ServerInfo info) {
    final now = DateTime.now();
    final index =
        _devices.indexWhere((d) => d.ip == info.ip && d.port == info.port);
    if (index >= 0) {
      final existing = _devices[index];
      final updated = existing.copyWith(
        name: (info.name.isNotEmpty && info.name != info.ip)
            ? info.name
            : existing.name,
        os: info.os.isNotEmpty ? info.os : existing.os,
        lastConnected: now,
      );
      _devices = [
        updated,
        ..._devices.where((d) => d.id != updated.id),
      ];
      _lastLink = updated;
    } else {
      final device = LinkedDevice(
        id: now.microsecondsSinceEpoch.toString(),
        name: info.name.isNotEmpty ? info.name : info.ip,
        ip: info.ip,
        port: info.port,
        os: info.os.isNotEmpty ? info.os : null,
        lastConnected: now,
      );
      _devices = [device, ..._devices];
      _lastLink = device;
    }
    _probes[_lastLink!.id] =
        DeviceProbe(online: true, rttMs: _rttMs, at: now);
    _discovered.removeWhere((s) => s.ip == info.ip && s.port == info.port);
    _savePreferences();
  }

  void _onSessionDatagram(Datagram d) {
    if (d.address.address != _targetAddress?.address || d.port != _targetPort) {
      return;
    }
    final parts = BindCurseProtocol.parseControl(d.data);
    if (parts == null) return;
    switch (parts.first) {
      case BindCurseProtocol.pong:
        final seq = parts.length > 1 ? int.tryParse(parts[1]) : null;
        final sentAt = seq == null ? null : _pingsInFlight.remove(seq);
        if (sentAt != null) {
          _rttMs = DateTime.now().difference(sentAt).inMilliseconds;
        }
        _lastPongAt = DateTime.now();
        if (_linkState == LinkState.lost) {
          _linkState = LinkState.linked;
          _errorMessage = null;
          _syncForegroundService();
        }
        notifyListeners();
        break;
      case BindCurseProtocol.bye:
        _errorMessage = 'El servidor cerró el enlace.';
        disconnect(sendBye: false);
        break;
    }
  }

  void _tick() {
    final channel = _channel;
    final address = _targetAddress;
    if (channel == null || address == null) return;

    if (_linkState == LinkState.linked &&
        DateTime.now().difference(_lastPongAt) > BindCurseProtocol.linkTimeout) {
      _linkState = LinkState.lost;
      _rttMs = null;
      _outgoing.clear();
      _syncForegroundService();
      notifyListeners();
    }

    final seq = ++_pingSeq;
    _pingsInFlight[seq] = DateTime.now();
    if (_pingsInFlight.length > 16) {
      _pingsInFlight.remove(_pingsInFlight.keys.first);
    }
    channel.sendText('${BindCurseProtocol.ping}|$seq', address, _targetPort);
  }

  Future<void> disconnect({bool sendBye = true}) async {
    _connectToken++;
    _pingTimer?.cancel();
    _pingTimer = null;
    await _sessionSub?.cancel();
    _sessionSub = null;

    final channel = _channel;
    final address = _targetAddress;
    if (sendBye && channel != null && address != null) {
      channel.sendText(BindCurseProtocol.bye, address, _targetPort);
    }
    channel?.close();
    _channel = null;
    _targetAddress = null;
    _server = null;
    _rttMs = null;
    _outgoing.clear();
    _pingsInFlight.clear();
    _linkState = LinkState.idle;
    _syncForegroundService();

    if (!_monitorEnabled) await _stopCapture();
    notifyListeners();
  }

  // ---------------------------------------------------------------- capture
  Future<bool> _startCapture() async {
    if (_isCapturing) return true;
    if (_captureStarting) {
      while (_captureStarting) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return _isCapturing;
    }
    _captureStarting = true;
    try {
      if (!await _recorder.hasPermission()) {
        _errorMessage = 'Permiso de micrófono denegado.';
        return false;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: numChannels,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      _analyzer.reset();
      _bars = List<double>.filled(barCount, idleBar);
      _currentDb = -60.0;
      _captureSub = stream.listen(
        _onPcmChunk,
        onError: (Object e) {
          _errorMessage = 'Error del micrófono: $e';
          _monitorEnabled = false;
          disconnect(sendBye: true);
          _stopCapture();
        },
      );
      _isCapturing = true;
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo abrir el micrófono: $e';
      return false;
    } finally {
      _captureStarting = false;
      notifyListeners();
    }
  }

  Future<void> _stopCapture() async {
    await _captureSub?.cancel();
    _captureSub = null;
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
    _isCapturing = false;
    _currentDb = null;
    _bars = List<double>.filled(barCount, idleBar);
  }

  void _onPcmChunk(Uint8List raw) {
    final byteLength = raw.length & ~1;
    if (byteLength == 0) return;

    final input = ByteData.sublistView(raw, 0, byteLength);
    final processed = Uint8List(byteLength);
    final output = ByteData.sublistView(processed);
    final sampleCount = byteLength >> 1;

    if (_isMuted) {
      processed.fillRange(0, processed.length, 0);
      _currentDb = -60.0;
      if (_linkState == LinkState.linked) _sendAudio(processed);
      if (_uiThrottle.elapsedMilliseconds >= 33) {
        _uiThrottle.reset();
        _bars = List<double>.filled(barCount, idleBar);
        notifyListeners();
      }
      return;
    }

    final gain =
        _gainDb == 0.0 ? 1.0 : math.pow(10.0, _gainDb / 20.0).toDouble();

    var sumSquares = 0.0;
    var clipped = false;
    for (var i = 0; i < sampleCount; i++) {
      final offset = i << 1;
      var sample = input.getInt16(offset, Endian.little);
      if (gain != 1.0) {
        final scaled = (sample * gain).round();
        if (scaled > 32767 || scaled < -32768) clipped = true;
        sample = scaled.clamp(-32768, 32767);
      }
      if (sample >= 32767 || sample <= -32768) clipped = true;
      output.setInt16(offset, sample, Endian.little);
      final normalized = sample / 32768.0;
      sumSquares += normalized * normalized;
      _analyzer.addSample(normalized);
    }

    final rms = math.sqrt(sumSquares / sampleCount);
    final db = rms > 1e-6 ? 20.0 * math.log(rms) / math.ln10 : -60.0;
    _currentDb = db.clamp(-60.0, 0.0);
    if (clipped) {
      _clipUntil = DateTime.now().add(const Duration(milliseconds: 600));
    }

    if (_linkState == LinkState.linked) _sendAudio(processed);

    if (_uiThrottle.elapsedMilliseconds >= 33) {
      _uiThrottle.reset();
      final levels = _analyzer.computeBands();
      final next = List<double>.filled(barCount, idleBar);
      for (var b = 0; b < barCount; b++) {
        final target = levels[b];
        final prev = _bars[b];
        final v = target > prev
            ? prev + (target - prev) * 0.7
            : prev * 0.82 + target * 0.18;
        next[b] = v.clamp(idleBar, 1.0);
      }
      _bars = next;
      notifyListeners();
    }
  }

  void _sendAudio(Uint8List pcm) {
    final channel = _channel;
    final address = _targetAddress;
    if (channel == null || address == null) return;

    _outgoing.add(pcm);
    final chunk = _latencyTarget.chunkBytes;
    if (_outgoing.length < chunk) return;

    final buffered = _outgoing.takeBytes();
    var offset = 0;
    while (offset + chunk <= buffered.length) {
      final packet = Uint8List(BindCurseProtocol.audioHeaderSize + chunk);
      packet.setRange(0, 4, BindCurseProtocol.audioMagic);
      ByteData.sublistView(packet).setUint32(4, _audioSeq, Endian.little);
      packet.setRange(
        BindCurseProtocol.audioHeaderSize,
        packet.length,
        buffered,
        offset,
      );
      _audioSeq = (_audioSeq + 1) & 0xFFFFFFFF;
      final sent = channel.send(packet, address, _targetPort);
      if (sent > 0) {
        _packetsSent++;
        _bytesSent += sent;
      }
      offset += chunk;
    }
    if (offset < buffered.length) {
      _outgoing.add(Uint8List.sublistView(buffered, offset));
    }
  }

  // ---------------------------------------------------------------- devices
  /// Probes every saved server and broadcasts a discovery request on the LAN.
  Future<void> scanNetwork() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();
    await Future.wait([
      for (final d in _devices) probeDevice(d),
      _discover(),
    ]);
    _isScanning = false;
    notifyListeners();
  }

  Future<void> probeDevice(LinkedDevice device) async {
    if (_probing.contains(device.id)) return;
    _probing.add(device.id);
    notifyListeners();

    UdpChannel? channel;
    try {
      final address = await _resolve(device.ip);
      if (address != null) {
        channel = await UdpChannel.bind();
        final sw = Stopwatch()..start();
        final reply = await channel.request(
          message: BindCurseProtocol.discover,
          expect: BindCurseProtocol.here,
          address: address,
          port: device.port,
        );
        sw.stop();
        _probes[device.id] = DeviceProbe(
          online: reply != null,
          rttMs: reply != null ? sw.elapsedMilliseconds : null,
          at: DateTime.now(),
        );
        if (reply != null && reply.length > 2 && reply[2].isNotEmpty) {
          final i = _devices.indexWhere((d) => d.id == device.id);
          if (i >= 0) {
            _devices[i] = _devices[i].copyWith(os: reply[2]);
            if (_lastLink?.id == device.id) {
              _lastLink = _devices[i];
            }
          }
          _savePreferences();
        }
      } else {
        _probes[device.id] =
            DeviceProbe(online: false, at: DateTime.now());
      }
    } catch (_) {
      _probes[device.id] = DeviceProbe(online: false, at: DateTime.now());
    } finally {
      channel?.close();
      _probing.remove(device.id);
      notifyListeners();
    }
  }

  Future<void> _discover() async {
    UdpChannel? channel;
    final found = <String, ServerInfo>{};
    try {
      channel = await UdpChannel.bind();
      final sentAt = DateTime.now();
      final sub = channel.datagrams.listen((d) {
        final parts = BindCurseProtocol.parseControl(d.data);
        if (parts == null || parts.first != BindCurseProtocol.here) return;
        final port = parts.length > 3 ? int.tryParse(parts[3]) ?? d.port : d.port;
        found['${d.address.address}:$port'] = ServerInfo(
          name: parts.length > 1 && parts[1].isNotEmpty
              ? parts[1]
              : d.address.address,
          os: parts.length > 2 ? parts[2] : '',
          ip: d.address.address,
          port: port,
          rttMs: DateTime.now().difference(sentAt).inMilliseconds,
        );
      });

      final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final o = addr.rawAddress;
            // Assumes a /24 network, the common case for home/studio LANs.
            targets.add(InternetAddress.fromRawAddress(
              Uint8List.fromList([o[0], o[1], o[2], 255]),
            ));
          }
        }
      } catch (_) {}

      for (var attempt = 0; attempt < 3; attempt++) {
        for (final t in targets) {
          channel.sendText(BindCurseProtocol.discover, t, _port);
        }
        await Future<void>.delayed(
          Duration(
            milliseconds: BindCurseProtocol.discoveryWindow.inMilliseconds ~/ 3,
          ),
        );
      }
      await sub.cancel();
    } catch (_) {
      // Discovery is best-effort.
    } finally {
      channel?.close();
    }

    _discovered = found.values
        .where((s) => !_devices.any((d) => d.ip == s.ip && d.port == s.port))
        .toList();
    // Discovery replies also tell us which saved servers are online.
    for (final s in found.values) {
      for (final d in _devices.where((d) => d.ip == s.ip && d.port == s.port)) {
        _probes[d.id] = DeviceProbe(online: true, rttMs: s.rttMs, at: DateTime.now());
      }
    }
  }

  LinkedDevice addDevice({
    required String name,
    required String ip,
    required int port,
    String? os,
  }) {
    final trimmedIp = ip.trim();
    final trimmedName = name.trim().isEmpty ? trimmedIp : name.trim();
    final existing =
        _devices.where((d) => d.ip == trimmedIp && d.port == port).firstOrNull;
    if (existing != null) {
      final updated = existing.copyWith(
        name: trimmedName,
        os: (os != null && os.isNotEmpty) ? os : existing.os,
      );
      _devices = [
        updated,
        ..._devices.where((d) => d.id != updated.id),
      ];
      if (_lastLink?.id == updated.id) _lastLink = updated;
      _savePreferences();
      notifyListeners();
      probeDevice(updated);
      return updated;
    }
    final device = LinkedDevice(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmedName,
      ip: trimmedIp,
      port: port,
      os: (os == null || os.isEmpty) ? null : os,
    );
    _devices = [device, ..._devices];
    _lastLink ??= device;
    _discovered.removeWhere((s) => s.ip == device.ip && s.port == device.port);
    _savePreferences();
    notifyListeners();
    probeDevice(device);
    return device;
  }

  LinkedDevice saveDiscovered(ServerInfo info) =>
      addDevice(name: info.name, ip: info.ip, port: info.port, os: info.os);

  void renameDevice(String id, String newName) {
    if (newName.trim().isEmpty) return;
    _devices = [
      for (final d in _devices) d.id == id ? d.copyWith(name: newName.trim()) : d,
    ];
    if (_lastLink?.id == id) _lastLink = _lastLink!.copyWith(name: newName.trim());
    _savePreferences();
    notifyListeners();
  }

  void updateDeviceAddress(String id, String newIp, int newPort) {
    _devices = [
      for (final d in _devices)
        d.id == id ? d.copyWith(ip: newIp.trim(), port: newPort) : d,
    ];
    _probes.remove(id);
    if (_lastLink?.id == id) {
      _lastLink = _lastLink!.copyWith(ip: newIp.trim(), port: newPort);
    }
    _savePreferences();
    notifyListeners();
    final updated = _devices.where((d) => d.id == id).firstOrNull;
    if (updated != null) probeDevice(updated);
  }

  void removeDevice(String id) {
    _devices = _devices.where((d) => d.id != id).toList();
    _probes.remove(id);
    if (_lastLink?.id == id) {
      _lastLink = _devices.firstOrNull;
    }
    _savePreferences();
    notifyListeners();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _sessionSub?.cancel();
    if (_channel != null && _targetAddress != null) {
      _channel!.sendText(BindCurseProtocol.bye, _targetAddress!, _targetPort);
    }
    _channel?.close();
    _captureSub?.cancel();
    try {
      _recorder.dispose().catchError((_) {});
    } catch (_) {}
    try {
      BackgroundServiceManager.stopService();
    } catch (_) {}
    super.dispose();
  }
}
