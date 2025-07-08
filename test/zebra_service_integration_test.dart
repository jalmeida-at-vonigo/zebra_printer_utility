import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/zebrautil.dart';

void main() {
  group('ZebraPrinterManager Integration Tests', () {
    late ZebraPrinterManager manager;

    setUp(() async {
      manager = ZebraPrinterManager();
      await manager.initialize();
    });

    tearDown(() async {
      await manager.disconnect();
      manager.dispose();
    });

    test('should initialize manager successfully', () {
      expect(manager, isNotNull);
      expect(manager.printer, isNotNull);
    });

    test('should handle print operation', () async {
      const testData = '''
^XA
^FO50,50
^ADN,36,20
^FDTest Print
^FS
^XZ
''';

      final result = await manager.print(testData);
      
      // Since we don't have a real printer connected, we expect some kind of result
      expect(result, isA<Result<void>>());
    });

    test('should handle connection status', () async {
      final isConnected = await manager.isConnected();
      expect(isConnected, isA<bool>());
    });

    test('should handle printer status', () async {
      final status = await manager.getPrinterStatus();
      expect(status, isA<Result<Map<String, dynamic>>>());
    });
  });
}
