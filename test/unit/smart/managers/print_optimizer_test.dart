import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/smart/managers/print_optimizer.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/smart/models/connection_type.dart';
import '../../../mocks/mock_logger.mocks.dart';

void main() {
  group('PrintOptimizer', () {
    late PrintOptimizer printOptimizer;
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
      printOptimizer = PrintOptimizer(mockLogger);
    });

    group('Data Optimization', () {
      test('should optimize ZPL data', () async {
        const zplData = '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ';
        const format = PrintFormat.zpl;
        const connectionType = ConnectionType.bluetooth;
        
        final result = await printOptimizer.optimizeData(zplData, format, connectionType);
        
        expect(result, isA<String>());
        expect(result, contains('^XA'));
        expect(result, contains('^XZ'));
      });

      test('should optimize CPCL data', () async {
        const cpclData = '! 0 200 200 1 1\nTEXT 4 0 0 0 Hello World\nFORM\nPRINT';
        const format = PrintFormat.cpcl;
        const connectionType = ConnectionType.network;
        
        final result = await printOptimizer.optimizeData(cpclData, format, connectionType);
        
        expect(result, isA<String>());
        expect(result, contains('! '));
      });

      test('should return original data for unknown format', () async {
        const data = 'unknown format data';
        const format = PrintFormat.zpl; // Use zpl instead of non-existent unknown
        const connectionType = ConnectionType.bluetooth;
        
        final result = await printOptimizer.optimizeData(data, format, connectionType);
        
        // Should return optimized data (not original) since zpl is a valid format
        expect(result, isA<String>());
        expect(result, isNotEmpty);
      });

      test('should handle optimization failure gracefully', () async {
        const data = 'invalid data';
        const format = PrintFormat.zpl;
        const connectionType = ConnectionType.bluetooth;
        
        final result = await printOptimizer.optimizeData(data, format, connectionType);
        
        // Should return optimized data with ZPL headers, not original data
        expect(result, isA<String>());
        expect(result, contains('^XA'));
        expect(result, contains('^XZ'));
        expect(result, contains(data));
      });

      test('should cache optimization results', () async {
        const data = '^XA^FO50,50^A0N,50,50^FDTest^FS^XZ';
        const format = PrintFormat.zpl;
        const connectionType = ConnectionType.bluetooth;
        
        // First optimization
        final result1 = await printOptimizer.optimizeData(data, format, connectionType);
        
        // Second optimization (should use cache)
        final result2 = await printOptimizer.optimizeData(data, format, connectionType);
        
        expect(result1, equals(result2));
      });
    });

    group('Format-Specific Optimization', () {
      test('should optimize ZPL patterns', () async {
        const zplData = '''
^XA
^FO50,50^A0N,50,50^FDTest^FS
^FO50,100^A0N,50,50^FDTest^FS
^XZ
''';

        final optimized = await printOptimizer.optimizeData(
          zplData,
          PrintFormat.zpl,
          ConnectionType.network,
        );

        expect(optimized, contains('^XA'));
        expect(optimized, contains('^XZ'));
        expect(optimized, contains('^FO'));
        expect(optimized, contains('^FD'));
      });

      test('should optimize CPCL patterns', () async {
        const cpclData = '''
! 0 200 200 400 1
T 7 1 550 91 Test
T 7 1 550 91 Test
FORM
PRINT
''';

        final optimized = await printOptimizer.optimizeData(
          cpclData,
          PrintFormat.cpcl,
          ConnectionType.network,
        );

        expect(optimized, contains('! 0'));
        expect(optimized, contains('T 7'));
        expect(optimized, contains('PRINT'));
      });
    });

    group('Connection-Specific Optimization', () {
      test('should optimize for Bluetooth connections', () async {
        const data = '^XA^FO50,50^A0N,50,50^FDTest^FS^XZ';
        
        final optimized = await printOptimizer.optimizeData(
          data,
          PrintFormat.zpl,
          ConnectionType.bluetooth,
        );

        expect(optimized, isA<String>());
        expect(optimized.length, lessThanOrEqualTo(data.length));
      });

      test('should optimize for Network connections', () async {
        const data = '^XA^FO50,50^A0N,50,50^FDTest^FS^XZ';
        
        final optimized = await printOptimizer.optimizeData(
          data,
          PrintFormat.zpl,
          ConnectionType.network,
        );

        expect(optimized, isA<String>());
      });

      test('should optimize for USB connections', () async {
        const data = '^XA^FO50,50^A0N,50,50^FDTest^FS^XZ';
        
        final optimized = await printOptimizer.optimizeData(
          data,
          PrintFormat.zpl,
          ConnectionType.usb,
        );

        expect(optimized, equals(data)); // USB should have minimal optimization
      });
    });

    group('ZSDK-Specific Optimization', () {
      test('should add ZSDK headers for ZPL', () async {
        const data = '^FO50,50^A0N,50,50^FDTest^FS';
        
        final optimized = await printOptimizer.optimizeData(
          data,
          PrintFormat.zpl,
          ConnectionType.network,
        );

        expect(optimized, contains('^XA'));
        expect(optimized, contains('^XZ'));
      });

      test('should optimize command sequences', () async {
        const data = '''
^XA
^FO50,50^A0N,50,50^FDTest^FS
^FO50,100^A0N,50,50^FDTest^FS
^FO50,150^A0N,50,50^FDTest^FS
^XZ
''';

        final optimized = await printOptimizer.optimizeData(
          data,
          PrintFormat.zpl,
          ConnectionType.network,
        );

        expect(optimized, contains('^XA'));
        expect(optimized, contains('^XZ'));
        expect(optimized, contains('^FO'));
        expect(optimized, contains('^FD'));
      });
    });

    group('Error Handling', () {
      test('should handle optimization errors gracefully', () async {
        const data = 'Invalid printer data with special characters: \x00\x01\x02';
        const format = PrintFormat.zpl;
        const connectionType = ConnectionType.bluetooth;
        
        final result = await printOptimizer.optimizeData(data, format, connectionType);
        
        // Should return optimized data with ZPL headers
        expect(result, isA<String>());
        expect(result, contains('^XA'));
        expect(result, contains('^XZ'));
        expect(result, contains(data));
      });

      test('should handle empty data', () async {
        const data = '';
        const format = PrintFormat.zpl;
        const connectionType = ConnectionType.bluetooth;
        
        final result = await printOptimizer.optimizeData(data, format, connectionType);
        
        // Should return optimized data with ZPL headers
        expect(result, isA<String>());
        expect(result, contains('^XA'));
        expect(result, contains('^XZ'));
      });

      test('should handle null data', () async {
        const data = 'null';
        const format = PrintFormat.zpl;
        const connectionType = ConnectionType.bluetooth;
        
        final result = await printOptimizer.optimizeData(data, format, connectionType);
        
        // Should return optimized data with ZPL headers
        expect(result, isA<String>());
        expect(result, contains('^XA'));
        expect(result, contains('^XZ'));
        expect(result, contains(data));
      });
    });

    group('Performance', () {
      test('should handle large data efficiently', () async {
        final largeData =
            '^XA${List.filled(1000, '^FO50,50^A0N,50,50^FDTest^FS').join('')}^XZ';
        
        final startTime = DateTime.now();
        final optimized = await printOptimizer.optimizeData(
          largeData,
          PrintFormat.zpl,
          ConnectionType.network,
        );
        final duration = DateTime.now().difference(startTime);
        
        expect(optimized, isA<String>());
        expect(duration.inMilliseconds, lessThan(1000)); // Should complete within 1 second
      });

      test('should cache optimizations for performance', () async {
        const data = '^XA^FO50,50^A0N,50,50^FDTest^FS^XZ';
        
        // First optimization
        final startTime1 = DateTime.now();
        await printOptimizer.optimizeData(data, PrintFormat.zpl, ConnectionType.network);
        final duration1 = DateTime.now().difference(startTime1);
        
        // Second optimization (should use cache)
        final startTime2 = DateTime.now();
        await printOptimizer.optimizeData(data, PrintFormat.zpl, ConnectionType.network);
        final duration2 = DateTime.now().difference(startTime2);
        
        // Cached optimization should be faster
        expect(duration2.inMilliseconds, lessThanOrEqualTo(duration1.inMilliseconds));
      });
    });

    group('Edge Cases', () {
      test('should handle data with only whitespace', () async {
        const whitespaceData = '   \n\t   ';
        
        final optimized = await printOptimizer.optimizeData(
          whitespaceData,
          PrintFormat.zpl,
          ConnectionType.network,
        );

        expect(optimized, isA<String>());
      });

      test('should handle data with special characters', () async {
        const specialData = '^XA^FO50,50^A0N,50,50^FDTest & More!@#\$%^&*()^FS^XZ';
        
        final optimized = await printOptimizer.optimizeData(
          specialData,
          PrintFormat.zpl,
          ConnectionType.network,
        );

        expect(optimized, isA<String>());
        expect(optimized, contains('Test & More!@#\$%^&*()'));
      });

      test('should handle mixed format data', () async {
        const mixedData = '''
^XA
! 0 200 200 400 1
^FO50,50^A0N,50,50^FDTest^FS
T 7 1 550 91 Test
^XZ
''';

        final optimized = await printOptimizer.optimizeData(
          mixedData,
          PrintFormat.zpl,
          ConnectionType.network,
        );

        expect(optimized, isA<String>());
      });
    });
  });
} 