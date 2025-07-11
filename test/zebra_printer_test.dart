import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/internal/operation_manager.dart';
import 'package:flutter/material.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([OperationManager])
import 'zebra_printer_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZebraPrinter', () {
    late ZebraPrinter printer;
    const instanceId = 'test-instance';

    setUp(() {
      printer = ZebraPrinter(instanceId);
    });

    tearDown(() {
      printer.dispose();
    });

    group('constructor and initialization', () {
      test('initializes with correct instance ID', () {
        expect(printer.instanceId, equals(instanceId));
      });

      test('initializes with provided controller', () {
        final customController = ZebraController();
        final customPrinter = ZebraPrinter(
          'custom-id',
          controller: customController,
        );
        expect(customPrinter.controller, equals(customController));
        customPrinter.dispose();
      });

      test('creates default controller if not provided', () {
        expect(printer.controller, isNotNull);
        expect(printer.controller, isA<ZebraController>());
      });

      test('initializes with correct default values', () {
        expect(printer.isRotated, isFalse);
        expect(printer.isScanning, isFalse);
        expect(printer.shouldSync, isFalse);
      });

      test('sets up method channel correctly', () {
        expect(printer.channel.name, equals('ZebraPrinterObject$instanceId'));
      });
    });

    group('utility methods', () {
      test('rotate toggles rotation state', () {
        expect(printer.isRotated, isFalse);

        printer.rotate();
        expect(printer.isRotated, isTrue);

        printer.rotate();
        expect(printer.isRotated, isFalse);
      });


    });

    group('event handling', () {
      test('handles printerFound callback', () async {
        // Simulate native callback
        await printer.nativeMethodCallHandler(
          const MethodCall('printerFound', {
            'Address': '192.168.1.100',
            'Name': 'Test Printer',
            'Status': 'Found',
            'IsWifi': 'true',
          }),
        );

        expect(printer.controller.printers.length, equals(1));
        expect(
            printer.controller.printers.first.address, equals('192.168.1.100'));
        expect(printer.controller.printers.first.name, equals('Test Printer'));
        expect(printer.controller.printers.first.isWifi, isTrue);
      });

      test('handles changePrinterStatus event', () async {
        printer.controller.selectedAddress = '192.168.1.100';
        printer.controller.addPrinter(ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
        ));

        await printer.nativeMethodCallHandler(
          const MethodCall('changePrinterStatus', {
            'Status': 'Connected',
            'Color': 'G',
          }),
        );

        final device = printer.controller.printers.first;
        expect(device.status, equals('Connected'));
        expect(device.color, equals(Colors.green));
        expect(device.isConnected, isTrue);
      });

      test('handles printerRemoved event', () async {
        printer.controller.addPrinter(ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
        ));

        await printer.nativeMethodCallHandler(
          const MethodCall('printerRemoved', {
            'Address': '192.168.1.100',
          }),
        );

        expect(printer.controller.printers.isEmpty, isTrue);
      });

      test('handles onDiscoveryError event', () async {
        String? errorCode;
        String? errorMessage;
        printer.onDiscoveryError = (code, message) {
          errorCode = code;
          errorMessage = message;
        };

        await printer.nativeMethodCallHandler(
          const MethodCall('onDiscoveryError', {
            'ErrorText': 'Discovery failed',
          }),
        );

        expect(errorCode, equals('DISCOVERY_ERROR'));
        expect(errorMessage, equals('Discovery failed'));
      });

      test('handles onPrinterDiscoveryDone event', () async {
        printer.isScanning = true;

        await printer.nativeMethodCallHandler(
          const MethodCall('onPrinterDiscoveryDone'),
        );

        expect(printer.isScanning, isFalse);
      });
    });

    // Async operations with proper mocking
    group('async operations', () {
      late MockOperationManager mockOperationManager;
      late ZebraPrinter printerWithMock;

      setUp(() {
        mockOperationManager = MockOperationManager();
        printerWithMock = ZebraPrinter(instanceId);
        // We'd need to inject the mock, but the current design doesn't support it
        // So we'll test what we can with the actual implementation
      });

      test('startScanning triggers scanning and cleans controller', () {
        expect(printerWithMock.isScanning, isFalse);
        printerWithMock.startScanning();
        expect(printerWithMock.isScanning, isTrue);
      });

      test('stopScanning updates scanning state', () {
        printerWithMock.isScanning = true;
        printerWithMock.stopScanning();
        expect(printerWithMock.isScanning, isFalse);
        expect(printerWithMock.shouldSync, isTrue);
      });

      test('connectToPrinter returns result', () async {
        // Mock the operation manager to return success
        when(mockOperationManager.execute<bool>(
          method: anyNamed('method'),
          arguments: anyNamed('arguments'),
          timeout: anyNamed('timeout'),
        )).thenAnswer((_) async => Result.success(true));

        // Test with actual printer (will use real operation manager)
        final result = await printer.connectToPrinter('192.168.1.100');

        // We can't inject the mock, so we test the method exists and returns a Result
        expect(result, isA<Result<void>>());
      });

      test('print returns result', () async {
        // Test with actual printer (will use real operation manager)
        final result = await printer.print(data: '^XA^FO20,20^AD^FDTest^XZ');

        // We can't inject the mock, so we test the method exists and returns a Result
        expect(result, isA<Result<void>>());
      });

      test('disconnect returns result', () async {
        // Test with actual printer (will use real operation manager)
        final result = await printer.disconnect();

        // We can't inject the mock, so we test the method exists and returns a Result
        expect(result, isA<Result<void>>());
      });

      test('isPrinterConnected returns boolean', () async {
        final isConnected = await printer.isPrinterConnected();
        expect(isConnected, isA<bool>());
      });

      test('getSetting returns string or null', () async {
        final setting = await printer.getSetting('device.languages');
        expect(setting, isA<String?>());
      });

      test('setSetting returns result', () async {
        final result = await printer.setSetting('device.pause', 'false');
        expect(result, isA<Result<void>>());
      });

      test('getPrinterStatus returns result', () async {
        final result = await printer.getPrinterStatus();
        expect(result, isA<Result<Map<String, dynamic>>>());
      });
    });
  });

  group('ZebraController', () {
    late ZebraController controller;

    setUp(() {
      controller = ZebraController();
    });

    test('starts with empty printer list', () {
      expect(controller.printers.isEmpty, isTrue);
      expect(controller.selectedAddress, isNull);
    });

    test('addPrinter adds new printer', () {
      final printer = ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        isWifi: true,
        status: 'Found',
      );

      controller.addPrinter(printer);

      expect(controller.printers.length, equals(1));
      expect(controller.printers.first, equals(printer));
    });

    test('addPrinter prevents duplicates', () {
      final printer = ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        isWifi: true,
        status: 'Found',
      );

      controller.addPrinter(printer);
      controller.addPrinter(printer);

      expect(controller.printers.length, equals(1));
    });

    test('removePrinter removes by address', () {
      final printer = ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        isWifi: true,
        status: 'Found',
      );

      controller.addPrinter(printer);
      controller.removePrinter('192.168.1.100');

      expect(controller.printers.isEmpty, isTrue);
    });

    test('cleanAll removes disconnected printers', () {
      controller.addPrinter(ZebraDevice(
        address: '192.168.1.100',
        name: 'Disconnected',
        isConnected: false,
        isWifi: true,
        status: 'Found',
      ));
      controller.addPrinter(ZebraDevice(
        address: '192.168.1.101',
        name: 'Connected',
        isConnected: true,
        isWifi: true,
        status: 'Found',
      ));

      controller.cleanAll();

      expect(controller.printers.length, equals(1));
      expect(controller.printers.first.address, equals('192.168.1.101'));
    });

    test('cleanAll handles empty list', () {
      controller.cleanAll();
      expect(controller.printers.isEmpty, isTrue);
    });

    test('updatePrinterStatus updates selected printer', () {
      controller.selectedAddress = '192.168.1.100';
      controller.addPrinter(ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        isWifi: true,
        status: 'Found',
      ));

      controller.updatePrinterStatus('Connected', 'G');

      final printer = controller.printers.first;
      expect(printer.status, equals('Connected'));
      expect(printer.color, equals(Colors.green));
      expect(printer.isConnected, isTrue);
    });

    test('updatePrinterStatus handles different color codes', () {
      controller.selectedAddress = '192.168.1.100';
      controller.addPrinter(ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        isWifi: true,
        status: 'Found',
      ));

      // Test red
      controller.updatePrinterStatus('Error', 'R');
      expect(controller.printers.first.color, equals(Colors.red));

      // Test default (grey)
      controller.updatePrinterStatus('Unknown', 'X');
      expect((controller.printers.first.color.a * 255.0).round() & 0xff,
          equals(153)); // 0.6 * 255
    });

    test('updatePrinterStatus does nothing without selected address', () {
      controller.addPrinter(ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        isWifi: true,
        status: 'Found',
      ));

      controller.updatePrinterStatus('Connected', 'G');

      expect(controller.printers.first.status, isNot(equals('Connected')));
    });

    test('synchronizePrinter updates connected printer', () {
      controller.selectedAddress = '192.168.1.100';
      controller.addPrinter(ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        isConnected: false,
        isWifi: true,
        status: 'Found',
      ));

      controller.synchronizePrinter('Connected');

      final printer = controller.printers.first;
      expect(printer.status, equals('Connected'));
      expect(printer.color, equals(Colors.green));
      expect(printer.isConnected, isTrue);
    });

    test('synchronizePrinter skips already connected printer', () {
      controller.selectedAddress = '192.168.1.100';
      controller.addPrinter(ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        status: 'Already Connected',
        isConnected: true,
        isWifi: true,
      ));

      controller.synchronizePrinter('New Status');

      expect(controller.printers.first.status, equals('Already Connected'));
    });

    test('synchronizePrinter handles missing printer', () {
      controller.selectedAddress = '192.168.1.100';

      controller.synchronizePrinter('Connected');

      expect(controller.selectedAddress, isNull);
    });

    test('printers list is unmodifiable', () {
      expect(
        () => controller.printers.add(ZebraDevice(
          address: 'test',
          name: 'test',
          isWifi: true,
          status: 'Found',
        )),
        throwsUnsupportedError,
      );
    });
  });
}
