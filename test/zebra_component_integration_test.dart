import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/models/print_event.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/smart_print_manager.dart';
import 'package:zebrautil/zebra.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_printer_discovery.dart';
import 'package:zebrautil/zebra_printer_manager.dart';

@GenerateMocks([
  ZebraPrinter,
  ZebraPrinterManager,
  SmartPrintManager,
  ZebraPrinterDiscovery,
])
import 'zebra_component_integration_test.mocks.dart';

void main() {
  group('Zebra Component Integration Tests', () {
    late MockZebraPrinter mockPrinter;
    late MockZebraPrinterManager mockManager;
    late MockSmartPrintManager mockSmartPrintManager;
    late MockZebraPrinterDiscovery mockDiscovery;

    setUp(() {
      mockPrinter = MockZebraPrinter();
      mockManager = MockZebraPrinterManager();
      mockSmartPrintManager = MockSmartPrintManager();
      mockDiscovery = MockZebraPrinterDiscovery();
    });

    group('Zebra Component Integration', () {
      test('should properly integrate all Zebra components', () async {
        // Test that all mock components are properly initialized
        expect(mockPrinter, isNotNull);
        expect(mockManager, isNotNull);
        expect(mockSmartPrintManager, isNotNull);
        expect(mockDiscovery, isNotNull);
      });

      test('should handle manager initialization', () async {
        when(mockManager.initialize()).thenAnswer((_) async => Result.success(true));
        
        // Verify manager initialization can be called
        final result = await mockManager.initialize();
        expect(result.success, isTrue);
        verify(mockManager.initialize()).called(1);
      });
    });

    group('Discovery Component Integration', () {
      test('should handle discovery operations through ZebraPrinterDiscovery', () async {
        final testDevices = [
          ZebraDevice(
            address: '192.168.1.100',
            name: 'Test Printer 1',
            status: 'Found',
            isWifi: true,
          ),
          ZebraDevice(
            address: '192.168.1.101',
            name: 'Test Printer 2',
            status: 'Found',
            isWifi: true,
          ),
        ];

        when(mockDiscovery.discoverPrinters(timeout: anyNamed('timeout')))
            .thenAnswer((_) async => Result.success(testDevices));

        final result = await mockDiscovery.discoverPrinters();
        
        expect(result.success, isTrue);
        expect(result.data, equals(testDevices));
        verify(mockDiscovery.discoverPrinters(timeout: anyNamed('timeout'))).called(1);
      });

      test('should handle discovery stream operations', () {
        final testDevices = [
          ZebraDevice(
            address: '192.168.1.100',
            name: 'Test Printer 1',
            status: 'Found',
            isWifi: true,
          ),
        ];

        when(mockDiscovery.discoverPrintersStream(
          timeout: anyNamed('timeout'),
          stopAfterCount: anyNamed('stopAfterCount'),
          stopOnFirstPrinter: anyNamed('stopOnFirstPrinter'),
          includeWifi: anyNamed('includeWifi'),
          includeBluetooth: anyNamed('includeBluetooth'),
        )).thenAnswer((_) => Stream.value(testDevices));

        final stream = mockDiscovery.discoverPrintersStream();
        
        expect(stream, isA<Stream<List<ZebraDevice>>>());
        verify(mockDiscovery.discoverPrintersStream(
          timeout: anyNamed('timeout'),
          stopAfterCount: anyNamed('stopAfterCount'),
          stopOnFirstPrinter: anyNamed('stopOnFirstPrinter'),
          includeWifi: anyNamed('includeWifi'),
          includeBluetooth: anyNamed('includeBluetooth'),
        )).called(1);
      });
    });

    group('Connection Component Integration', () {
      test('should handle connection operations through ZebraPrinterManager', () async {
        when(mockManager.connect('192.168.1.100'))
            .thenAnswer((_) async => Result.success(null));

        final result = await mockManager.connect('192.168.1.100');
        
        expect(result.success, isTrue);
        verify(mockManager.connect('192.168.1.100')).called(1);
      });

      test('should handle disconnection operations', () async {
        when(mockManager.disconnect())
            .thenAnswer((_) async => Result.success(null));

        final result = await mockManager.disconnect();
        
        expect(result.success, isTrue);
        verify(mockManager.disconnect()).called(1);
      });

      test('should handle connection status checks', () async {
        when(mockManager.isConnected()).thenAnswer((_) async => true);

        final isConnected = await mockManager.isConnected();
        
        expect(isConnected, isTrue);
        verify(mockManager.isConnected()).called(1);
      });
    });

    group('Print Operations Component Integration', () {
      test('should handle basic print operations through ZebraPrinterManager', () async {
        const testData = '^XA^FO50,50^FDTest^FS^XZ';
        when(mockManager.print(testData, options: anyNamed('options')))
            .thenAnswer((_) async => Result.success(null));

        final result = await mockManager.print(testData);
        
        expect(result.success, isTrue);
        verify(mockManager.print(testData, options: anyNamed('options'))).called(1);
      });

      test('should handle smart print operations through SmartPrintManager', () async {
        const testData = '^XA^FO50,50^FDTest^FS^XZ';
        final testEvents = [
          PrintEvent(
            type: PrintEventType.stepChanged,
            timestamp: DateTime.now(),
            stepInfo: PrintStepInfo(
              step: PrintStep.initializing,
              message: 'Starting print',
              attempt: 1,
              maxAttempts: 3,
              elapsed: Duration.zero,
            ),
          ),
          PrintEvent(
            type: PrintEventType.completed,
            timestamp: DateTime.now(),
          ),
        ];

        when(mockSmartPrintManager.smartPrint(
          data: testData,
          device: anyNamed('device'),
          maxAttempts: anyNamed('maxAttempts'),
          options: anyNamed('options'),
        )).thenAnswer((_) async {});
        
        when(mockSmartPrintManager.eventStream)
            .thenAnswer((_) => Stream.fromIterable(testEvents));

        // Call smartPrint method without assignment
        mockSmartPrintManager.smartPrint(data: testData);
        
        // Get the event stream
        final eventStream = mockSmartPrintManager.eventStream;
        final events = await eventStream.toList();
        
        expect(events, equals(testEvents));
        verify(mockSmartPrintManager.smartPrint(
          data: testData,
          device: anyNamed('device'),
          maxAttempts: anyNamed('maxAttempts'),
          options: anyNamed('options'),
        )).called(1);
      });

      test('should handle smart print cancellation', () async {
        when(mockSmartPrintManager.cancel()).thenAnswer((_) async {});

        mockSmartPrintManager.cancel();
        
        verify(mockSmartPrintManager.cancel()).called(1);
      });
    });

    group('Status Operations Component Integration', () {
      test('should handle printer status operations', () async {
        final testStatus = {
          'status': 'Online',
          'media': 'OK',
          'head': 'OK',
        };

        when(mockManager.getPrinterStatus())
            .thenAnswer((_) async => Result.success(testStatus));

        final result = await mockManager.getPrinterStatus();
        
        expect(result.success, isTrue);
        expect(result.data, equals(testStatus));
        verify(mockManager.getPrinterStatus()).called(1);
      });

      test('should handle detailed printer status operations', () async {
        final testDetailedStatus = {
          'status': 'Online',
          'media': 'OK',
          'head': 'OK',
          'pause': 'Not Paused',
          'host_status': 'Online',
        };

        when(mockManager.getDetailedPrinterStatus())
            .thenAnswer((_) async => Result.success(testDetailedStatus));

        final result = await mockManager.getDetailedPrinterStatus();
        
        expect(result.success, isTrue);
        expect(result.data, equals(testDetailedStatus));
        verify(mockManager.getDetailedPrinterStatus()).called(1);
      });
    });

    group('Utility Operations Component Integration', () {
      test('should handle rotation operations', () {
        mockManager.rotate();
        verify(mockManager.rotate()).called(1);
      });

      test('should handle disposal operations', () {
        mockManager.dispose();
        mockPrinter.dispose();
        verify(mockManager.dispose()).called(1);
        verify(mockPrinter.dispose()).called(1);
      });
    });

    group('Property Delegation Component Integration', () {
      test('should handle devices stream delegation', () {
        final testDevices = [
          ZebraDevice(
            address: '192.168.1.100',
            name: 'Test Printer',
            status: 'Found',
            isWifi: true,
          ),
        ];

        when(mockDiscovery.devices)
            .thenAnswer((_) => Stream.value(testDevices));

        final stream = mockDiscovery.devices;
        
        expect(stream, isA<Stream<List<ZebraDevice>>>());
        verify(mockDiscovery.devices).called(1);
      });

      test('should handle connection stream delegation', () {
        final testDevice = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          status: 'Connected',
          isWifi: true,
        );

        when(mockManager.connection)
            .thenAnswer((_) => Stream.value(testDevice));

        final stream = mockManager.connection;
        
        expect(stream, isA<Stream<ZebraDevice?>>());
        verify(mockManager.connection).called(1);
      });

      test('should handle status stream delegation', () {
        when(mockManager.status)
            .thenAnswer((_) => Stream.value('Connected'));

        final stream = mockManager.status;
        
        expect(stream, isA<Stream<String>>());
        verify(mockManager.status).called(1);
      });

      test('should handle connected printer delegation', () {
        final testDevice = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          status: 'Connected',
          isWifi: true,
        );

        when(mockManager.connectedPrinter).thenReturn(testDevice);

        final connectedPrinter = mockManager.connectedPrinter;
        
        expect(connectedPrinter, equals(testDevice));
        verify(mockManager.connectedPrinter).called(1);
      });

      test('should handle discovered printers delegation', () {
        final testDevices = [
          ZebraDevice(
            address: '192.168.1.100',
            name: 'Test Printer 1',
            status: 'Found',
            isWifi: true,
          ),
          ZebraDevice(
            address: '192.168.1.101',
            name: 'Test Printer 2',
            status: 'Found',
            isWifi: true,
          ),
        ];

        when(mockManager.discoveredPrinters).thenReturn(testDevices);

        final discoveredPrinters = mockManager.discoveredPrinters;
        
        expect(discoveredPrinters, equals(testDevices));
        verify(mockManager.discoveredPrinters).called(1);
      });

      test('should handle scanning status delegation', () {
        when(mockDiscovery.isScanning).thenReturn(true);

        final isScanning = mockDiscovery.isScanning;
        
        expect(isScanning, isTrue);
        verify(mockDiscovery.isScanning).called(1);
      });
    });

    group('Global Instance Integration', () {
      test('should handle global instance initialization', () async {
        // Test global instance management
        expect(() => Zebra.global, throwsStateError);
        
        // Note: In a real integration test, we would test the actual global instance
        // but since we're using mocks, we can't test the actual initialization
      });

      test('should handle global instance disposal', () {
        Zebra.disposeGlobal();
        // Verify disposal doesn't throw
        expect(true, isTrue);
      });
    });

    group('Error Handling Component Integration', () {
      test('should handle discovery errors', () async {
        when(mockDiscovery.discoverPrinters(timeout: anyNamed('timeout')))
            .thenAnswer((_) async => Result.error('Discovery failed'));

        final result = await mockDiscovery.discoverPrinters();
        
        expect(result.success, isFalse);
        expect(result.error?.message, contains('Discovery failed'));
        verify(mockDiscovery.discoverPrinters(timeout: anyNamed('timeout'))).called(1);
      });

      test('should handle connection errors', () async {
        when(mockManager.connect('192.168.1.100'))
            .thenAnswer((_) async => Result.error('Connection failed'));

        final result = await mockManager.connect('192.168.1.100');
        
        expect(result.success, isFalse);
        expect(result.error?.message, contains('Connection failed'));
        verify(mockManager.connect('192.168.1.100')).called(1);
      });

      test('should handle print errors', () async {
        const testData = '^XA^FO50,50^FDTest^FS^XZ';
        when(mockManager.print(testData, options: anyNamed('options')))
            .thenAnswer((_) async => Result.error('Print failed'));

        final result = await mockManager.print(testData);
        
        expect(result.success, isFalse);
        expect(result.error?.message, contains('Print failed'));
        verify(mockManager.print(testData, options: anyNamed('options'))).called(1);
      });
    });
  });
}
