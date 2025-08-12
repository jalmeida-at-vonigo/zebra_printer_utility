import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/models/print_operation_tracker.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';

@GenerateMocks([ZebraPrinter])
import 'zebra_printer_test.mocks.dart';

void main() {
  group('ZebraPrinter', () {
    late MockZebraPrinter printer;

    setUp(() {
      printer = MockZebraPrinter();
    });

    group('utility methods', () {
      test('rotate toggles rotation state', () {
        when(printer.isRotated).thenReturn(false);
        expect(printer.isRotated, isFalse);

        printer.rotate();
        verify(printer.rotate()).called(1);
      });

      test('dispose calls dispose method', () {
        printer.dispose();
        verify(printer.dispose()).called(1);
      });
    });

    group('discovery operations', () {
      test('discoverBTClassicStream returns device stream', () async {
        when(printer.discoverBTClassicStream(timeout: anyNamed('timeout')))
            .thenAnswer((_) => const Stream<ZebraDevice>.empty());

        final stream = printer.discoverBTClassicStream();
        expect(stream, isA<Stream<ZebraDevice>>());
        verify(printer.discoverBTClassicStream(timeout: anyNamed('timeout')))
            .called(1);
      });

      test('discoverLocalBroadcastStream returns device stream', () async {
        when(printer.discoverLocalBroadcastStream(timeout: anyNamed('timeout')))
            .thenAnswer((_) => const Stream<ZebraDevice>.empty());

        final stream = printer.discoverLocalBroadcastStream();
        expect(stream, isA<Stream<ZebraDevice>>());
        verify(printer.discoverLocalBroadcastStream(
                timeout: anyNamed('timeout')))
            .called(1);
      });

      test('discoverSubnetStream returns device stream', () async {
        when(printer.discoverSubnetStream(
          subnet: anyNamed('subnet'),
          timeout: anyNamed('timeout'),
        )).thenAnswer((_) => const Stream<ZebraDevice>.empty());

        final stream = printer.discoverSubnetStream(subnet: '192.168.1');
        expect(stream, isA<Stream<ZebraDevice>>());
        verify(printer.discoverSubnetStream(
          subnet: anyNamed('subnet'),
          timeout: anyNamed('timeout'),
        )).called(1);
      });

      test('stopDiscovery returns success result', () async {
        when(printer.stopDiscovery()).thenAnswer(
          (_) async => Result.success(null),
        );

        final result = await printer.stopDiscovery();
        expect(result.success, isTrue);
        verify(printer.stopDiscovery()).called(1);
      });
    });

    group('connection operations', () {
      test('connectToPrinter returns success result', () async {
        when(printer.connectToPrinter('192.168.1.100')).thenAnswer(
          (_) async => Result.success(null),
        );

        final result = await printer.connectToPrinter('192.168.1.100');
        expect(result.success, isTrue);
        verify(printer.connectToPrinter('192.168.1.100')).called(1);
      });

      test('disconnect returns success result', () async {
        when(printer.disconnect()).thenAnswer(
          (_) async => Result.success(null),
        );

        final result = await printer.disconnect();
        expect(result.success, isTrue);
        verify(printer.disconnect()).called(1);
      });

      test('isPrinterConnected returns true when connected', () async {
        when(printer.isPrinterConnected()).thenAnswer(
          (_) async => Result.success(true),
        );

        final result = await printer.isPrinterConnected();
        expect(result.success, isTrue);
        expect(result.data, isTrue);
        verify(printer.isPrinterConnected()).called(1);
      });

      test('isPrinterConnected returns false when not connected', () async {
        when(printer.isPrinterConnected()).thenAnswer(
          (_) async => Result.success(false),
        );

        final result = await printer.isPrinterConnected();
        expect(result.success, isTrue);
        expect(result.data, isFalse);
        verify(printer.isPrinterConnected()).called(1);
      });
    });

    group('printing operations', () {
      test('print returns success result', () async {
        when(printer.print(data: '^XA^FO50,50^FDTest^FS^XZ')).thenAnswer(
          (_) async => Result.success(PrintOperationTracker()),
        );

        final result = await printer.print(data: '^XA^FO50,50^FDTest^FS^XZ');
        expect(result.success, isTrue);
        expect(result.data, isA<PrintOperationTracker>());
        verify(printer.print(data: '^XA^FO50,50^FDTest^FS^XZ')).called(1);
      });

      test('print returns error result', () async {
        when(printer.print(data: '^XA^FO50,50^FDTest^FS^XZ')).thenAnswer(
          (_) async => Result.error('Print operation failed'),
        );

        final result = await printer.print(data: '^XA^FO50,50^FDTest^FS^XZ');
        expect(result.success, isFalse);
        expect(result.error?.message, contains('Print operation failed'));
        verify(printer.print(data: '^XA^FO50,50^FDTest^FS^XZ')).called(1);
      });
    });

    group('status operations', () {
      test('getPrinterStatus returns status map', () async {
        final statusMap = {
          'status': 'Online',
          'media': 'OK',
          'head': 'OK',
        };
        when(printer.getPrinterStatus()).thenAnswer(
          (_) async => Result.success(statusMap),
        );

        final result = await printer.getPrinterStatus();
        expect(result.success, isTrue);
        expect(result.data, equals(statusMap));
        verify(printer.getPrinterStatus()).called(1);
      });

      test('getDetailedPrinterStatus returns detailed status', () async {
        final detailedStatus = {
          'status': 'Online',
          'media': 'OK',
          'head': 'OK',
          'pause': 'Not Paused',
          'host_status': 'Online',
        };
        when(printer.getDetailedPrinterStatus()).thenAnswer(
          (_) async => Result.success(detailedStatus),
        );

        final result = await printer.getDetailedPrinterStatus();
        expect(result.success, isTrue);
        expect(result.data, equals(detailedStatus));
        verify(printer.getDetailedPrinterStatus()).called(1);
      });
    });

    group('settings operations', () {
      test('getSetting returns setting value', () async {
        when(printer.getSetting('media.status')).thenAnswer(
          (_) async => Result.success('OK'),
        );

        final result = await printer.getSetting('media.status');
        expect(result.success, isTrue);
        expect(result.data, equals('OK'));
        verify(printer.getSetting('media.status')).called(1);
      });

      test('getSetting returns null when setting not found', () async {
        when(printer.getSetting('nonexistent.setting')).thenAnswer(
          (_) async => Result.success(null),
        );

        final result = await printer.getSetting('nonexistent.setting');
        expect(result.success, isTrue);
        expect(result.data, isNull);
        verify(printer.getSetting('nonexistent.setting')).called(1);
      });
    });

    group('discovery operations', () {
      test('discoverLocalBroadcastStream returns device stream', () async {
        when(printer.discoverLocalBroadcastStream(timeout: anyNamed('timeout')))
            .thenAnswer((_) => const Stream<ZebraDevice>.empty());

        final stream = printer.discoverLocalBroadcastStream();
        expect(stream, isA<Stream<ZebraDevice>>());
        verify(printer.discoverLocalBroadcastStream(
                timeout: anyNamed('timeout')))
            .called(1);
      });
    });

    group('instance operations', () {
      test('getInstanceId returns instance ID', () async {
        when(printer.getInstanceId()).thenAnswer(
          (_) async => Result.success('test-instance-123'),
        );

        final result = await printer.getInstanceId();
        expect(result.success, isTrue);
        expect(result.data, equals('test-instance-123'));
        verify(printer.getInstanceId()).called(1);
      });
    });

    group('native method handling', () {
      test('nativeMethodCallHandler processes method calls', () async {
        final methodCall = const MethodCall('testMethod', {'param': 'value'});
        
        // Mock the nativeMethodCallHandler to not throw
        when(printer.nativeMethodCallHandler(methodCall)).thenAnswer(
          (_) async {},
        );

        await printer.nativeMethodCallHandler(methodCall);
        verify(printer.nativeMethodCallHandler(methodCall)).called(1);
      });
    });
  });
}
