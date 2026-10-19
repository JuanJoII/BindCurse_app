import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bind_curse_app/models/linked_device.dart';
import 'package:bind_curse_app/services/udp_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinkedDevice JSON robustness', () {
    test('parses int, string and num ports reliably', () {
      final jsonInt = {
        'id': '1',
        'name': 'Studio 1',
        'ip': '192.168.1.100',
        'port': 9920,
      };
      final dev1 = LinkedDevice.fromJson(jsonInt);
      expect(dev1.port, 9920);

      final jsonString = {
        'id': '2',
        'name': 'Studio 2',
        'ip': '192.168.1.101',
        'port': '9921',
      };
      final dev2 = LinkedDevice.fromJson(jsonString);
      expect(dev2.port, 9921);

      final jsonNum = {
        'id': '3',
        'name': 'Studio 3',
        'ip': '192.168.1.102',
        'port': 9922.0,
      };
      final dev3 = LinkedDevice.fromJson(jsonNum);
      expect(dev3.port, 9922);

      final jsonMissing = {
        'id': '4',
        'ip': '192.168.1.103',
      };
      final dev4 = LinkedDevice.fromJson(jsonMissing);
      expect(dev4.port, 5005);
      expect(dev4.name, '192.168.1.103');
    });
  });

  group('UdpAudioService persistence', () {
    test('defaults to port 5005 when clean', () async {
      SharedPreferences.setMockInitialValues({});
      final service = UdpAudioService();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.port, 5005);
    });

    test('loads saved devices and remembers last link', () async {
      SharedPreferences.setMockInitialValues({
        'saved_hosts_v2': jsonEncode([
          {
            'id': 'altar-1',
            'name': 'PC Gaming',
            'ip': '192.168.1.50',
            'port': 5005,
            'os': 'windows',
            'lastConnected': '2026-10-19T12:00:00.000Z',
          },
          {
            'id': 'altar-2',
            'name': 'MacBook Pro',
            'ip': '192.168.1.60',
            'port': 5005,
            'os': 'darwin',
            'lastConnected': '2026-10-19T11:00:00.000Z',
          }
        ]),
        'last_link_v2': jsonEncode({
          'id': 'altar-1',
          'name': 'PC Gaming',
          'ip': '192.168.1.50',
          'port': 5005,
          'os': 'windows',
          'lastConnected': '2026-10-19T12:00:00.000Z',
        }),
        'host_ip_v2': '192.168.1.50',
        'host_port_v2': 5005,
      });

      final service = UdpAudioService();

      // Allow preferences to load
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.devices.length, 2);
      expect(service.devices.first.name, 'PC Gaming');
      expect(service.lastLink, isNotNull);
      expect(service.lastLink!.name, 'PC Gaming');
      expect(service.hostIp, '192.168.1.50');
      expect(service.port, 5005);
    });

    test('recovers legacy data when saved_hosts_v2 is missing', () async {
      SharedPreferences.setMockInitialValues({
        'linked_devices': jsonEncode([
          {
            'id': 'legacy-1',
            'name': 'Legacy Altar',
            'ip': '192.168.1.88',
            'port': 5005,
          }
        ]),
        'last_sealed_ip': '192.168.1.88',
        'last_sealed_port': 5005,
        'last_sealed_name': 'Legacy Altar',
      });

      final service = UdpAudioService();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.devices.length, 1);
      expect(service.devices.first.name, 'Legacy Altar');
      expect(service.lastLink, isNotNull);
      expect(service.lastLink!.ip, '192.168.1.88');
      expect(service.hostIp, '192.168.1.88');
    });

    test('prevents race conditions when saving before load completes', () async {
      SharedPreferences.setMockInitialValues({
        'saved_hosts_v2': jsonEncode([
          {
            'id': 'altar-race',
            'name': 'Altar Safe',
            'ip': '192.168.1.77',
            'port': 5005,
          }
        ]),
      });

      final service = UdpAudioService();
      // Instantly call setGainDb before load completes
      service.setGainDb(3.0);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Check that existing device was NOT erased by setGainDb
      expect(service.devices.isNotEmpty, isTrue);
      expect(service.devices.first.ip, '192.168.1.77');
      expect(service.gainDb, 3.0);
      service.dispose();
    });
  });
}
