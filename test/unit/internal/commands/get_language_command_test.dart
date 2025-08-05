import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/commands/get_language_command.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/zebra_printer.dart';

@GenerateMocks([ZebraPrinter])
import 'get_language_command_test.mocks.dart';

void main() {
  group('GetLanguageCommand', () {
    late MockZebraPrinter mockPrinter;
    late GetLanguageCommand command;

    setUp(() {
      mockPrinter = MockZebraPrinter();
      command = GetLanguageCommand(mockPrinter);
      
      // Set up basic stubs
      when(mockPrinter.instanceId).thenReturn('test-instance');
    });

    group('execute with exact string matches', () {
      test('returns ZPL for "zpl" response', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('zpl'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });

      test('returns CPCL for "cpcl" response', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('cpcl'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.cpcl));
      });

      test('returns CPCL for "line_print" response', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('line_print'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.cpcl));
      });
    });

    group('execute with SGD formatted responses', () {
      test('returns ZPL for SGD formatted "zpl" response', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('"device.languages" : "zpl"'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });

      test('returns CPCL for SGD formatted "line_print" response', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('"device.languages" : "line_print"'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.cpcl));
      });
    });

    group('execute with contains-based matching for complex responses', () {
      test('returns ZPL for "zpl,line_print" response (ZPL has priority)', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('zpl,line_print'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });

      test('returns ZPL for "line_print,zpl" response (ZPL has priority)', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('line_print,zpl'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });

      test('returns CPCL for "cpcl mode" response', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('cpcl mode'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.cpcl));
      });
    });

    group('execute with case insensitive matching', () {
      test('returns ZPL for "ZPL" response (case insensitive)', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('ZPL'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });

      test('returns CPCL for "LINE_PRINT" response (case insensitive)', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('LINE_PRINT'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.cpcl));
      });
    });

    group('execute with unknown formats defaults to ZPL', () {
      test('returns ZPL for "unknown" response', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success('unknown'));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });

      test('returns ZPL for empty string response', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success(''));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });

      test('returns ZPL for null response', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.success(null));

        final result = await command.execute();

        expect(result.success, isTrue);
        expect(result.data, equals(PrintFormat.zpl));
      });
    });

    group('execute with error handling', () {
      test('propagates error when getSetting fails', () async {
        when(mockPrinter.getSetting('device.languages'))
            .thenAnswer((_) async => Result.error('Connection failed'));

        final result = await command.execute();

        expect(result.success, isFalse);
        expect(result.error?.message, contains('Language retrieval failed'));
      });
    });

    test('has correct operation name', () {
      expect(command.operationName, equals('Get Printer Language'));
    });
  });
}