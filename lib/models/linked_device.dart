/// A BindCurse server saved by the user. Only real data is stored: the name
/// given by the user (or reported by the server), its address, the OS reported
/// in the last successful handshake and when it was last linked.
class LinkedDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String? os;
  final DateTime? lastConnected;

  const LinkedDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    this.os,
    this.lastConnected,
  });

  String get address => '$ip:$port';

  LinkedDevice copyWith({
    String? name,
    String? ip,
    int? port,
    String? os,
    DateTime? lastConnected,
  }) {
    return LinkedDevice(
      id: id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      os: os ?? this.os,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'port': port,
        'os': os,
        'lastConnected': lastConnected?.toIso8601String(),
      };

  factory LinkedDevice.fromJson(Map<String, dynamic> json) {
    final last = json['lastConnected'] as String?;
    return LinkedDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      os: json['os'] as String?,
      lastConnected: last == null ? null : DateTime.tryParse(last),
    );
  }
}

/// Result of probing a saved server with `BINDCURSE_DISCOVER`.
class DeviceProbe {
  final bool online;
  final int? rttMs;
  final DateTime at;

  const DeviceProbe({required this.online, this.rttMs, required this.at});
}

/// Human readable relative timestamp without extra dependencies.
String formatLastSeen(DateTime? time) {
  if (time == null) return 'Nunca enlazado';
  final now = DateTime.now();
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy, $hh:$mm';
  if (diff == 1) return 'Ayer, $hh:$mm';
  if (diff < 7) return 'Hace $diff días';
  const months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${time.day} ${months[time.month - 1]} ${time.year}';
}
