import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:zebrautil/internal/operation_manager.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';

@GenerateMocks([OperationManager])

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZebraPrinter Unit Tests', () {
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

    group('ZebraController', () {
      late ZebraController controller;

      setUp(() {
        controller = ZebraController();
      });

      tearDown(() {
        controller.dispose();
      });

      test('addPrinter adds printer to list', () {
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
        );

        controller.addPrinter(device);
        expect(controller.printers.length, equals(1));
        expect(controller.printers.first, equals(device));
      });

      test('addPrinter does not add duplicate printers', () {
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
        );

        controller.addPrinter(device);
        controller.addPrinter(device);
        expect(controller.printers.length, equals(1));
      });

      test('removePrinter removes printer by address', () {
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
        );

        controller.addPrinter(device);
        controller.removePrinter('192.168.1.100');
        expect(controller.printers.isEmpty, isTrue);
      });

      test('cleanAll removes disconnected printers', () {
        final connectedDevice = ZebraDevice(
          address: '192.168.1.100',
          name: 'Connected Printer',
          isWifi: true,
          status: 'Connected',
          isConnected: true,
        );
        final disconnectedDevice = ZebraDevice(
          address: '192.168.1.101',
          name: 'Disconnected Printer',
          isWifi: true,
          status: 'Disconnected',
          isConnected: false,
        );

        controller.addPrinter(connectedDevice);
        controller.addPrinter(disconnectedDevice);
        controller.cleanAll();
        
        expect(controller.printers.length, equals(1));
        expect(controller.printers.first.address, equals('192.168.1.100'));
      });

      test('updatePrinterStatus updates printer status and color', () {
        controller.selectedAddress = '192.168.1.100';
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
        );

        controller.addPrinter(device);
        controller.updatePrinterStatus('Connected', 'G');

        final updatedDevice = controller.printers.first;
        expect(updatedDevice.status, equals('Connected'));
        expect(updatedDevice.color, equals(Colors.green));
        expect(updatedDevice.isConnected, isTrue);
      });

      test('updatePrinterStatus handles red color', () {
        controller.selectedAddress = '192.168.1.100';
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
        );

        controller.addPrinter(device);
        controller.updatePrinterStatus('Error', 'R');

        final updatedDevice = controller.printers.first;
        expect(updatedDevice.color, equals(Colors.red));
        expect(updatedDevice.isConnected, isFalse);
      });

      test('updatePrinterStatus handles unknown color', () {
        controller.selectedAddress = '192.168.1.100';
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
        );

        controller.addPrinter(device);
        controller.updatePrinterStatus('Unknown', 'X');

        final updatedDevice = controller.printers.first;
        expect(updatedDevice.color, equals(Colors.grey.withValues(alpha: 0.6)));
        expect(updatedDevice.isConnected, isFalse);
      });

      test('synchronizePrinter updates printer to connected state', () {
        controller.selectedAddress = '192.168.1.100';
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
          isConnected: false,
        );

        controller.addPrinter(device);
        controller.synchronizePrinter('Connected');

        final updatedDevice = controller.printers.first;
        expect(updatedDevice.status, equals('Connected'));
        expect(updatedDevice.color, equals(Colors.green));
        expect(updatedDevice.isConnected, isTrue);
      });

      test('synchronizePrinter does nothing if printer not found', () {
        controller.selectedAddress = '192.168.1.100';
        controller.synchronizePrinter('Connected');
        
        expect(controller.selectedAddress, isNull);
      });

      test('synchronizePrinter does nothing if printer already connected', () {
        controller.selectedAddress = '192.168.1.100';
        final device = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          isWifi: true,
          status: 'Found',
          isConnected: true,
        );

        controller.addPrinter(device);
        controller.synchronizePrinter('Connected');

        // Should not change anything
        final updatedDevice = controller.printers.first;
        expect(updatedDevice.isConnected, isTrue);
      });
    });
  });
} 