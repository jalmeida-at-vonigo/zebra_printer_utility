import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'dart:ui';

void main() {
  group('ZebraDevice', () {
    group('constructor', () {
      test('should create device with required fields', () {
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        expect(device.address, equals('192.168.1.100'));
        expect(device.name, equals('Test Printer'));
        expect(device.isWifi, isTrue);
        expect(device.status, equals('Ready'));
        expect(device.isConnected, isFalse);
        expect(device.color, equals(const Color.fromARGB(255, 255, 0, 0)));
      });

      test('should create device with all fields', () {
        const customColor = Color.fromARGB(255, 0, 255, 0);
        final device = ZebraDevice(
          address: '00:11:22:33:44:55',
          name: 'Bluetooth Printer',
          isWifi: false,
          status: 'Connected',
          isConnected: true,
          color: customColor,
        );

        expect(device.address, equals('00:11:22:33:44:55'));
        expect(device.name, equals('Bluetooth Printer'));
        expect(device.isWifi, isFalse);
        expect(device.status, equals('Connected'));
        expect(device.isConnected, isTrue);
        expect(device.color, equals(customColor));
      });
    });

    group('empty factory', () {
      test('should create empty device', () {
        final device = ZebraDevice.empty();

        expect(device.address, equals(''));
        expect(device.name, equals(''));
        expect(device.isWifi, isFalse);
        expect(device.status, equals(''));
        expect(device.isConnected, isFalse);
        expect(device.color, equals(const Color.fromARGB(255, 255, 0, 0)));
      });
    });

    group('fromJson factory', () {
      test('should create device from JSON with IP address', () {
        final json = {
          'ipAddress': '192.168.1.100',
          'name': 'Test Printer',
          'isWifi': 'true',
          'status': 'Ready',
          'isConnected': true,
        };

        final device = ZebraDevice.fromJson(json);

        expect(device.address, equals('192.168.1.100'));
        expect(device.name, equals('Test Printer'));
        expect(device.isWifi, isTrue);
        expect(device.status, equals('Ready'));
        expect(device.isConnected, isTrue);
      });

      test('should create device from JSON with MAC address', () {
        final json = {
          'macAddress': '00:11:22:33:44:55',
          'name': 'Bluetooth Printer',
          'isWifi': 'false',
          'status': 'Connected',
          'isConnected': false,
        };

        final device = ZebraDevice.fromJson(json);

        expect(device.address, equals('00:11:22:33:44:55'));
        expect(device.name, equals('Bluetooth Printer'));
        expect(device.isWifi, isFalse);
        expect(device.status, equals('Connected'));
        expect(device.isConnected, isFalse);
      });

      test('should prefer IP address over MAC address', () {
        final json = {
          'ipAddress': '192.168.1.100',
          'macAddress': '00:11:22:33:44:55',
          'name': 'Test Printer',
          'isWifi': 'true',
          'status': 'Ready',
          'isConnected': true,
        };

        final device = ZebraDevice.fromJson(json);

        expect(device.address, equals('192.168.1.100'));
      });

      test('should handle missing address fields', () {
        final json = {
          'name': 'Test Printer',
          'isWifi': 'true',
          'status': 'Ready',
          'isConnected': true,
        };

        final device = ZebraDevice.fromJson(json);

        expect(device.address, equals(''));
        expect(device.name, equals('Test Printer'));
        expect(device.isWifi, isTrue);
        expect(device.status, equals('Ready'));
        expect(device.isConnected, isTrue);
      });

      test('should handle various boolean string formats', () {
        final json = {
          'ipAddress': '192.168.1.100',
          'name': 'Test Printer',
          'isWifi': true, // boolean instead of string
          'status': 'Ready',
          'isConnected': true,
        };

        final device = ZebraDevice.fromJson(json);

        expect(device.isWifi, isTrue);
      });

      test('should handle false boolean string', () {
        final json = {
          'ipAddress': '192.168.1.100',
          'name': 'Test Printer',
          'isWifi': 'false',
          'status': 'Ready',
          'isConnected': true,
        };

        final device = ZebraDevice.fromJson(json);

        expect(device.isWifi, isFalse);
      });

      test('should handle malformed JSON gracefully', () {
        final json = {
          'ipAddress': null,
          'name': null,
          'isWifi': 'invalid',
          'status': null,
          'isConnected': 'invalid',
        };

        final device = ZebraDevice.fromJson(json);

        expect(device.address, equals(''));
        expect(device.name, equals(''));
        expect(device.isWifi, isFalse);
        expect(device.status, equals(''));
        expect(device.isConnected, isFalse);
      });

      test('should handle empty JSON object', () {
        final json = <String, dynamic>{};

        final device = ZebraDevice.fromJson(json);

        expect(device.address, equals(''));
        expect(device.name, equals(''));
        expect(device.isWifi, isFalse);
        expect(device.status, equals(''));
        expect(device.isConnected, isFalse);
      });
    });

    group('toJson method', () {
      test('should convert device to JSON', () {
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
          isConnected: true,
          color: const Color.fromARGB(255, 0, 255, 0),
        );

        final json = device.toJson();

        expect(json['address'], equals('192.168.1.100'));
        expect(json['name'], equals('Test Printer'));
        expect(json['isWifi'], isTrue);
        expect(json['status'], equals('Ready'));
        expect(json['isConnected'], isTrue);
        expect(
            json['color'],
            equals(const Color.fromARGB(255, 0, 255, 0).toARGB32()));
      });

      test('should handle default values in JSON', () {
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        final json = device.toJson();

        expect(json['isConnected'], isFalse);
        expect(
            json['color'],
            equals(const Color.fromARGB(255, 255, 0, 0).toARGB32()));
      });
    });

    group('equality', () {
      test('should be equal when addresses are the same', () {
        final device1 = ZebraDevice(
          address: '192.168.1.100',
          name: 'Printer 1',
          isWifi: true,
          status: 'Ready',
        );

        final device2 = ZebraDevice(
          address: '192.168.1.100',
          name: 'Printer 2', // Different name
          isWifi: false, // Different wifi status
          status: 'Connected', // Different status
          isConnected: true, // Different connection status
        );

        expect(device1, equals(device2));
        expect(device1.hashCode, equals(device2.hashCode));
      });

      test('should not be equal when addresses are different', () {
        final device1 = ZebraDevice(
          address: '192.168.1.100',
          name: 'Printer 1',
          isWifi: true,
          status: 'Ready',
        );

        final device2 = ZebraDevice(
          address: '192.168.1.101', // Different address
          name: 'Printer 1',
          isWifi: true,
          status: 'Ready',
        );

        expect(device1, isNot(equals(device2)));
        expect(device1.hashCode, isNot(equals(device2.hashCode)));
      });

      test('should be equal to itself', () {
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        expect(device, equals(device));
      });

      test('should not be equal to different type', () {
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        expect(device, isNot(equals('not a device')));
      });
    });

    group('copyWith method', () {
      test('should create copy with no changes', () {
        final original = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
          isConnected: true,
          color: const Color.fromARGB(255, 0, 255, 0),
        );

        final copy = original.copyWith();

        expect(copy.address, equals(original.address));
        expect(copy.name, equals(original.name));
        expect(copy.isWifi, equals(original.isWifi));
        expect(copy.status, equals(original.status));
        expect(copy.isConnected, equals(original.isConnected));
        expect(copy.color, equals(original.color));
        expect(copy, isNot(same(original))); // Should be a new instance
      });

      test('should create copy with changed address', () {
        final original = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        final copy = original.copyWith(address: '192.168.1.101');

        expect(copy.address, equals('192.168.1.101'));
        expect(copy.name, equals(original.name));
        expect(copy.isWifi, equals(original.isWifi));
        expect(copy.status, equals(original.status));
        expect(copy.isConnected, equals(original.isConnected));
        expect(copy.color, equals(original.color));
      });

      test('should create copy with changed name', () {
        final original = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        final copy = original.copyWith(name: 'Updated Printer');

        expect(copy.address, equals(original.address));
        expect(copy.name, equals('Updated Printer'));
        expect(copy.isWifi, equals(original.isWifi));
        expect(copy.status, equals(original.status));
        expect(copy.isConnected, equals(original.isConnected));
        expect(copy.color, equals(original.color));
      });

      test('should create copy with changed wifi status', () {
        final original = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        final copy = original.copyWith(isWifi: false);

        expect(copy.address, equals(original.address));
        expect(copy.name, equals(original.name));
        expect(copy.isWifi, isFalse);
        expect(copy.status, equals(original.status));
        expect(copy.isConnected, equals(original.isConnected));
        expect(copy.color, equals(original.color));
      });

      test('should create copy with changed status', () {
        final original = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        final copy = original.copyWith(status: 'Connected');

        expect(copy.address, equals(original.address));
        expect(copy.name, equals(original.name));
        expect(copy.isWifi, equals(original.isWifi));
        expect(copy.status, equals('Connected'));
        expect(copy.isConnected, equals(original.isConnected));
        expect(copy.color, equals(original.color));
      });

      test('should create copy with changed connection status', () {
        final original = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        final copy = original.copyWith(isConnected: true);

        expect(copy.address, equals(original.address));
        expect(copy.name, equals(original.name));
        expect(copy.isWifi, equals(original.isWifi));
        expect(copy.status, equals(original.status));
        expect(copy.isConnected, isTrue);
        expect(copy.color, equals(original.color));
      });

      test('should create copy with changed color', () {
        final original = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        const newColor = Color.fromARGB(255, 0, 0, 255);
        final copy = original.copyWith(color: newColor);

        expect(copy.address, equals(original.address));
        expect(copy.name, equals(original.name));
        expect(copy.isWifi, equals(original.isWifi));
        expect(copy.status, equals(original.status));
        expect(copy.isConnected, equals(original.isConnected));
        expect(copy.color, equals(newColor));
      });

      test('should create copy with multiple changes', () {
        final original = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
        );

        const newColor = Color.fromARGB(255, 0, 0, 255);
        final copy = original.copyWith(
          name: 'Updated Printer',
          isWifi: false,
          status: 'Connected',
          isConnected: true,
          color: newColor,
        );

        expect(copy.address, equals(original.address));
        expect(copy.name, equals('Updated Printer'));
        expect(copy.isWifi, isFalse);
        expect(copy.status, equals('Connected'));
        expect(copy.isConnected, isTrue);
        expect(copy.color, equals(newColor));
      });
    });

    group('toString method', () {
      test('should provide meaningful string representation', () {
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Ready',
          isConnected: true,
        );

        final string = device.toString();

        expect(string, contains('192.168.1.100'));
        expect(string, contains('Test Printer'));
      });
    });
  });

  group('ZebraDevice JSON functions', () {
    test('zebraDevicesModelFromJson should parse list of devices', () {
      const jsonString = '''
      [
        {
          "ipAddress": "192.168.1.100",
          "name": "Printer 1",
          "isWifi": "true",
          "status": "Ready",
          "isConnected": true
        },
        {
          "macAddress": "00:11:22:33:44:55",
          "name": "Printer 2",
          "isWifi": "false",
          "status": "Connected",
          "isConnected": false
        }
      ]
      ''';

      final devices = zebraDevicesModelFromJson(jsonString);

      expect(devices, hasLength(2));
      expect(devices[0].address, equals('192.168.1.100'));
      expect(devices[0].name, equals('Printer 1'));
      expect(devices[0].isWifi, isTrue);
      expect(devices[1].address, equals('00:11:22:33:44:55'));
      expect(devices[1].name, equals('Printer 2'));
      expect(devices[1].isWifi, isFalse);
    });

    test('zebraDevicesToJson should serialize list of devices', () {
      final devices = [
        ZebraDevice(
          address: '192.168.1.100',
          name: 'Printer 1',
          isWifi: true,
          status: 'Ready',
          isConnected: true,
        ),
        ZebraDevice(
          address: '00:11:22:33:44:55',
          name: 'Printer 2',
          isWifi: false,
          status: 'Connected',
          isConnected: false,
        ),
      ];

      final jsonString = zebraDevicesToJson(devices);
      final parsedDevices = zebraDevicesModelFromJson(jsonString);

      expect(parsedDevices, hasLength(2));
      expect(parsedDevices[0].address, equals(devices[0].address));
      expect(parsedDevices[0].name, equals(devices[0].name));
      expect(parsedDevices[0].isWifi, equals(devices[0].isWifi));
      expect(parsedDevices[1].address, equals(devices[1].address));
      expect(parsedDevices[1].name, equals(devices[1].name));
      expect(parsedDevices[1].isWifi, equals(devices[1].isWifi));
    });

    test('zebraDeviceModelFromJson should parse single device', () {
      const jsonString = '''
      {
        "ipAddress": "192.168.1.100",
        "name": "Test Printer",
        "isWifi": "true",
        "status": "Ready",
        "isConnected": true
      }
      ''';

      final device = zebraDeviceModelFromJson(jsonString);

      expect(device.address, equals('192.168.1.100'));
      expect(device.name, equals('Test Printer'));
      expect(device.isWifi, isTrue);
      expect(device.status, equals('Ready'));
      expect(device.isConnected, isTrue);
    });
  });
}
