import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/zebra_printer_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ZebraPrinterManager Integration Tests', () {
    late ZebraPrinterManager manager;

    setUp(() async {
      manager = ZebraPrinterManager();
      try {
        await manager.initialize();
      } catch (e) {
        // Skip tests if native platform is not available
        if (e.toString().contains('MissingPluginException')) {
          return;
        }
        rethrow;
      }
    });

    tearDown(() async {
      try {
        await manager.disconnect();
        manager.dispose();
      } catch (e) {
        // Ignore errors during cleanup
      }
    });

    test('should initialize manager successfully', () {
      // Skip test if native platform is not available
      if (manager.printer == null) {
        return;
      }
      expect(manager, isNotNull);
      expect(manager.printer, isNotNull);
    }, skip: 'Requires native platform support');

    test('should handle print operation', () async {
      // Skip test if native platform is not available
      if (manager.printer == null) {
        return;
      }
      
      const testData = '''
^XA
^FO50,50
^ADN,36,20
^FDTest Print
^FS
^XZ
''';

      try {
        final result = await manager.print(testData);
        expect(result, isA<Result<void>>());
      } on MissingPluginException {
        // Expected in unit test environment
        return;
      }
    }, skip: 'Requires native platform support');

    test('should handle connection status', () async {
      // Skip test if native platform is not available
      if (manager.printer == null) {
        return;
      }

      try {
        final isConnected = await manager.isConnected();
        expect(isConnected, isA<bool>());
      } on MissingPluginException {
        // Expected in unit test environment
        return;
      }
    }, skip: 'Requires native platform support');

    test('should handle printer status', () async {
      // Skip test if native platform is not available
      if (manager.printer == null) {
        return;
      }

      try {
        final status = await manager.getPrinterStatus();
        expect(status, isA<Result<Map<String, dynamic>>>());
      } on MissingPluginException {
        // Expected in unit test environment
        return;
      }
    }, skip: 'Requires native platform support');
  });
}
