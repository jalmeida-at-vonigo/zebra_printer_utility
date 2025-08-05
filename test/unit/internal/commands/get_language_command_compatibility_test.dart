import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/commands/get_language_command.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/zebra_printer.dart';

@GenerateMocks([ZebraPrinter])
import 'get_language_command_compatibility_test.mocks.dart';

void main() {
  group('GetLanguageCommand Compatibility with Old Native Enum Approach', () {
    late MockZebraPrinter mockPrinter;
    late GetLanguageCommand command;

    setUp(() {
      mockPrinter = MockZebraPrinter();
      command = GetLanguageCommand(mockPrinter);
      when(mockPrinter.instanceId).thenReturn('test-instance');
    });

    group('ZSDK device.languages SGD Response Mapping', () {
      test('maps "zpl" SGD response to ZPL (equivalent to PRINTER_LANGUAGE_ZPL)', () async {
        // Simulates: old enum PRINTER_LANGUAGE_ZPL -> "ZPL"
        // New: SGD "zpl" -> PrintFormat.zpl
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('zpl'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });

      test('maps "line_print" SGD response to CPCL (equivalent to PRINTER_LANGUAGE_CPCL)', () async {
        // Simulates: old enum PRINTER_LANGUAGE_CPCL -> "CPCL"  
        // New: SGD "line_print" -> PrintFormat.cpcl
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('line_print'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.cpcl));
      });

      test('handles SGD formatted responses (iOS ZSDK format)', () async {
        // Tests the actual SGD response format from iOS ZSDK
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('"device.languages" : "zpl"'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });
    });

    group('Error Handling Compatibility', () {
      test('defaults to ZPL instead of UNKNOWN (behavioral change from old wrapper)', () async {
        // OLD: getPrinterControlLanguage error -> "UNKNOWN"
        // NEW: SGD error or unknown response -> defaults to ZPL
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('unknown_value'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
        // Note: This is a behavioral change - old code returned "UNKNOWN"
      });

      test('propagates connection errors (maintains error behavior)', () async {
        // Both old and new approaches should propagate connection errors
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.error('Connection failed'));

        final result = await command.execute();

        expect(result.success, isFalse);
        expect(result.error?.message, contains('Language retrieval failed'));
      });
    });

    group('Enhanced SGD Response Handling (new capabilities)', () {
      test('handles complex SGD responses that old enum approach could not', () async {
        // NEW capability: Handle complex responses like "zpl,line_print"
        // Old enum approach would only return single enum value
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('zpl,line_print'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl)); // ZPL has priority
      });

      test('handles alternative CPCL responses', () async {
        // NEW capability: Handle "cpcl" in addition to "line_print"
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('cpcl'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.cpcl));
      });
    });

    group('Verification of Core ZSDK Mapping', () {
      test('verifies all ZSDK enum values are properly mapped', () {
        // This test documents the mapping between old and new approaches:
        
        // OLD NATIVE ENUM MAPPING:
        // PRINTER_LANGUAGE_ZPL (0) -> "ZPL"
        // PRINTER_LANGUAGE_CPCL (1) -> "CPCL"  
        // Error/Unknown -> "UNKNOWN"
        
        // NEW SGD STRING MAPPING:
        // "zpl" -> PrintFormat.zpl
        // "line_print" -> PrintFormat.cpcl
        // "cpcl" -> PrintFormat.cpcl
        // Unknown -> PrintFormat.zpl (default)
        
        expect(PrintFormat.values.length, equals(2)); // Matches ZSDK enum size
        expect(PrintFormat.zpl.name, equals('zpl'));
        expect(PrintFormat.cpcl.name, equals('cpcl'));
      });
    });
  });
}