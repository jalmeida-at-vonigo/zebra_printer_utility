import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/smart/zebra_printer_smart.dart';
import 'package:zebrautil/smart/options/smart_print_options.dart';
import 'package:zebrautil/smart/options/smart_batch_options.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/smart/models/zebra_printer_smart_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZebraPrinterSmart', () {
    late ZebraPrinterSmart smartPrinter;

    setUp(() {
      smartPrinter = ZebraPrinterSmart.instance;
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = ZebraPrinterSmart.instance;
        final instance2 = ZebraPrinterSmart.instance;
        expect(instance1, same(instance2));
      });
    });

    group('API Structure', () {
      test('should have print method', () {
        expect(smartPrinter.print, isA<Function>());
      });

      test('should have printBatch method', () {
        expect(smartPrinter.printBatch, isA<Function>());
      });

      test('should have connect method', () {
        expect(smartPrinter.connect, isA<Function>());
      });

      test('should have disconnect method', () {
        expect(smartPrinter.disconnect, isA<Function>());
      });

      test('should have discover method', () {
        expect(smartPrinter.discover, isA<Function>());
      });

      test('should have getStatus method', () {
        expect(smartPrinter.getStatus, isA<Function>());
      });
    });

    group('Error Handling', () {
      test('should handle empty data gracefully', () async {
        final result = await smartPrinter.print('');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error?.message, contains('No printer address available'));
      });

      test('should handle null data gracefully', () async {
        final result = await smartPrinter.print('');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });

      test('should handle invalid address gracefully', () async {
        final result =
            await smartPrinter.print('test', address: 'invalid-address');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('Batch Operations', () {
      test('should handle empty batch', () async {
        final result = await smartPrinter.printBatch([]);
        expect(result.success, isFalse);
        expect(result.error?.message, contains('No printer address available'));
      });

      test('should handle batch with empty items', () async {
        final result = await smartPrinter.printBatch(['', 'valid', '']);
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('Status and Metrics', () {
      test('should get status', () async {
        final status = await smartPrinter.getStatus();
        expect(status, isA<ZebraPrinterSmartStatus>());
        expect(status.isConnected, isFalse);
        expect(status.performanceMetrics, isA<Map<String, dynamic>>());
      });
    });

    group('Options Validation', () {
      test('should accept valid print options', () {
        const options = SmartPrintOptions(
          maxRetries: 2,
          retryDelay: Duration(seconds: 1),
          clearBufferBeforePrint: true,
        );
        expect(options.maxRetries, equals(2));
        expect(options.retryDelay, equals(const Duration(seconds: 1)));
        expect(options.clearBufferBeforePrint, isTrue);
      });

      test('should accept valid batch options', () {
        const options = SmartBatchOptions(
          batchSize: 5,
          batchDelay: Duration(milliseconds: 100),
        );
        expect(options.batchSize, equals(5));
        expect(options.batchDelay, equals(const Duration(milliseconds: 100)));
      });
    });

    group('Integration Scenarios', () {
      test('should handle discovery workflow', () async {
        final discovery = await smartPrinter.discover();
        expect(discovery.success, isTrue);
        expect(discovery.data, isA<List<ZebraDevice>>());
      });

      test('should handle status workflow', () async {
        final status = await smartPrinter.getStatus();
        expect(status, isA<ZebraPrinterSmartStatus>());
        expect(status.isConnected, isFalse);
      });
    });
  });
} 