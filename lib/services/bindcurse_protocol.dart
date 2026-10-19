import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// BindCurse UDP protocol v1.
///
/// Control messages are UTF-8 text, fields separated by `|`:
///   client -> server  `BINDCURSE_HELLO|1|48000|16|1|<clientName>`
///   server -> client  `BINDCURSE_ACK|<hostName>|<os>`
///   client -> server  `BINDCURSE_PING|<seq>`
///   server -> client  `BINDCURSE_PONG|<seq>`
///   client -> server  `BINDCURSE_BYE`
///   any    -> server  `BINDCURSE_DISCOVER`
///   server -> any     `BINDCURSE_HERE|<hostName>|<os>|<port>`
///
/// Audio packets are binary:
///   `BCPM` (4 bytes) + sequence (uint32 LE) + PCM 16-bit signed LE, 48 kHz, mono.
class BindCurseProtocol {
  static const int version = 1;
  static const int defaultPort = 9920;

  static const String hello = 'BINDCURSE_HELLO';
  static const String ack = 'BINDCURSE_ACK';
  static const String ping = 'BINDCURSE_PING';
  static const String pong = 'BINDCURSE_PONG';
  static const String bye = 'BINDCURSE_BYE';
  static const String discover = 'BINDCURSE_DISCOVER';
  static const String here = 'BINDCURSE_HERE';

  static const List<int> audioMagic = [0x42, 0x43, 0x50, 0x4D]; // "BCPM"
  static const int audioHeaderSize = 8;

  static const Duration handshakeTimeout = Duration(seconds: 2);
  static const Duration pingInterval = Duration(seconds: 2);
  static const Duration linkTimeout = Duration(seconds: 6);
  static const Duration discoveryWindow = Duration(milliseconds: 1500);

  /// Parses a control datagram. Returns null for anything that is not a
  /// BindCurse text message (e.g. audio packets or foreign traffic).
  static List<String>? parseControl(Uint8List data) {
    if (data.length < 10 || data.length > 512) return null;
    // Fast reject: must start with "BINDCURSE_".
    if (data[0] != 0x42 || data[1] != 0x49) return null;
    try {
      final text = utf8.decode(data);
      if (!text.startsWith('BINDCURSE_')) return null;
      return text.trim().split('|');
    } catch (_) {
      return null;
    }
  }
}

/// Information reported by a BindCurse server (ACK / HERE replies).
class ServerInfo {
  final String name;
  final String os;
  final String ip;
  final int port;
  final int? rttMs;

  const ServerInfo({
    required this.name,
    required this.os,
    required this.ip,
    required this.port,
    this.rttMs,
  });
}

/// Thin wrapper around [RawDatagramSocket] that exposes received datagrams as
/// a broadcast stream so several request/response flows can share one socket.
class UdpChannel {
  final RawDatagramSocket _socket;
  final StreamController<Datagram> _incoming =
      StreamController<Datagram>.broadcast();
  bool _closed = false;

  UdpChannel._(this._socket) {
    _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? d;
      while ((d = _socket.receive()) != null) {
        if (!_incoming.isClosed) _incoming.add(d!);
      }
    });
  }

  static Future<UdpChannel> bind() async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    return UdpChannel._(socket);
  }

  Stream<Datagram> get datagrams => _incoming.stream;
  bool get isClosed => _closed;

  /// Returns the number of bytes handed to the OS (0 if it could not send).
  int send(List<int> data, InternetAddress address, int port) {
    if (_closed) return 0;
    try {
      return _socket.send(data, address, port);
    } on SocketException {
      return 0;
    }
  }

  int sendText(String text, InternetAddress address, int port) =>
      send(utf8.encode(text), address, port);

  /// Sends [message] (retrying up to [attempts] times inside [timeout]) and
  /// waits for a control reply whose first field equals [expect] coming from
  /// [address]:[port]. Returns the reply fields or null on timeout.
  Future<List<String>?> request({
    required String message,
    required String expect,
    required InternetAddress address,
    required int port,
    Duration timeout = BindCurseProtocol.handshakeTimeout,
    int attempts = 3,
  }) async {
    final completer = Completer<List<String>?>();
    final sub = datagrams.listen((d) {
      if (d.address.address != address.address || d.port != port) return;
      final parts = BindCurseProtocol.parseControl(d.data);
      if (parts != null && parts.first == expect && !completer.isCompleted) {
        completer.complete(parts);
      }
    });

    final interval = Duration(
      milliseconds: timeout.inMilliseconds ~/ attempts,
    );
    for (var i = 0; i < attempts && !completer.isCompleted; i++) {
      sendText(message, address, port);
      await Future.any<void>([
        completer.future.then((_) {}),
        Future<void>.delayed(interval),
      ]);
    }
    if (!completer.isCompleted) completer.complete(null);
    await sub.cancel();
    return completer.future;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _socket.close();
    _incoming.close();
  }
}
