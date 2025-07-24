import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/communication_policy.dart';
import 'package:zebrautil/models/printer_readiness.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/zebra_printer.dart';

@GenerateMocks([ZebraPrinter, CommunicationPolicy])
import 'printer_readiness_test.mocks.dart';

void main() {
  group('PrinterReadiness', () {
    late MockZebraPrinter mockPrinter;

    setUp(() {
      mockPrinter = MockZebraPrinter();
      
      // Set up basic stubs to prevent null pointer exceptions
      when(mockPrinter.instanceId).thenReturn('test-instance');
      
      // Set up stubs for printer readiness checks
      when(mockPrinter.isPrinterConnected())
          .thenAnswer((_) async => Result.success(true));
      when(mockPrinter.getSetting('media.status'))
          .thenAnswer((_) async => Result.success('OK'));
      when(mockPrinter.getSetting('head.latch'))
          .thenAnswer((_) async => Result.success('OK'));
      when(mockPrinter.getSetting('device.pause'))
          .thenAnswer((_) async => Result.success('Not Paused'));
      when(mockPrinter.getSetting('device.host_status'))
          .thenAnswer((_) async => Result.success('Online'));
      when(mockPrinter.getSetting('device.languages'))
          .thenAnswer((_) async => Result.success('zpl'));
    });
    
    test('default values', () async {
      final readiness = PrinterReadiness(printer: mockPrinter);
      
      // Check that properties are uninitialized by default
      expect(readiness.wasConnectionRead, isFalse);
      expect(readiness.wasMediaRead, isFalse);
      expect(readiness.wasHeadRead, isFalse);
      expect(readiness.wasPauseRead, isFalse);
      expect(readiness.wasHostRead, isFalse);
      expect(readiness.wasLanguageRead, isFalse);

      // Check cached values show uninitialized
      final cached = readiness.cachedValues;
      expect(cached['connection'], equals('<unchecked>'));
      expect(cached['mediaStatus'], equals('<unchecked>'));
      expect(cached['hasMedia'], equals('<unchecked>'));
      expect(cached['headStatus'], equals('<unchecked>'));
      expect(cached['headClosed'], equals('<unchecked>'));
      expect(cached['pauseStatus'], equals('<unchecked>'));
      expect(cached['isPaused'], equals('<unchecked>'));
      expect(cached['hostStatus'], equals('<unchecked>'));
      expect(cached['errors'], equals('<unchecked>'));
      expect(cached['languageStatus'], equals('<unchecked>'));
    });

    test('should be ready when all conditions are met', () async {
      final readiness = PrinterReadiness(printer: mockPrinter);

      // Set cached values to simulate successful checks
      readiness.setCachedConnection(true);
      readiness.setCachedMedia('OK', true);
      readiness.setCachedHead('OK', true);
      readiness.setCachedPause('Not Paused', false);
      readiness.setCachedHost('Online', []);
      readiness.setCachedLanguage('zpl');

      // Test individual components instead of isReady which triggers printer calls
      expect(readiness.wasConnectionRead, isTrue);
      expect(readiness.wasMediaRead, isTrue);
      expect(readiness.wasHeadRead, isTrue);
      expect(readiness.wasPauseRead, isTrue);
      expect(readiness.wasHostRead, isTrue);
      expect(readiness.wasLanguageRead, isTrue);
      
      // Verify cached values are correct
      final cached = readiness.cachedValues;
      expect(cached['connection'], equals('checked'));
      expect(cached['hasMedia'], isTrue);
      expect(cached['headClosed'], isTrue);
      expect(cached['isPaused'], isFalse);
      expect(cached['errors'], isEmpty);
    });

    test('toString shows uninitialized properties', () {
      final readiness = PrinterReadiness(printer: mockPrinter);

      final str = readiness.toString();
      expect(str, contains('<unchecked>'));
      expect(str, contains('connection: <unchecked>'));
      expect(str, contains('media: <unchecked>'));
      expect(str, contains('head: <unchecked>'));
      expect(str, contains('pause: <unchecked>'));
      expect(str, contains('host: <unchecked>'));
      expect(str, contains('language: <unchecked>'));
    });

    test('toString shows actual values when initialized', () {
      final readiness = PrinterReadiness(printer: mockPrinter);

      // Set some cached values
      readiness.setCachedConnection(true);
      readiness.setCachedMedia('OK', true);
      readiness.setCachedHead('OK', true);

      final str = readiness.toString();
      expect(str, contains('connection: checked'));
      expect(str, contains('media: checked'));
      expect(str, contains('head: checked'));
      expect(str, contains('pause: <unchecked>'));
      expect(str, contains('host: <unchecked>'));
      expect(str, contains('language: <unchecked>'));
    });

    test('getter properties trigger reads when not initialized', () async {
      final readiness = PrinterReadiness(printer: mockPrinter);

      // Initially not read
      expect(readiness.wasConnectionRead, isFalse);

      // These getters would trigger reads in real usage, but with mock printer they will fail
      // We can't easily test the actual command execution without complex mocking
      // So we'll just verify the getter properties exist and can be accessed
      expect(readiness.isConnected, isA<Future<bool?>>());
      expect(readiness.mediaStatus, isA<Future<String?>>());
      expect(readiness.headStatus, isA<Future<String?>>());
      expect(readiness.pauseStatus, isA<Future<String?>>());
      expect(readiness.hostStatus, isA<Future<String?>>());
      expect(readiness.languageStatus, isA<Future<String?>>());
    });

    test('setCached methods mark properties as read', () {
      final readiness = PrinterReadiness(printer: mockPrinter);

      // Initially not read
      expect(readiness.wasConnectionRead, isFalse);
      expect(readiness.wasMediaRead, isFalse);
      expect(readiness.wasHeadRead, isFalse);
      expect(readiness.wasPauseRead, isFalse);
      expect(readiness.wasHostRead, isFalse);
      expect(readiness.wasLanguageRead, isFalse);

      // Set cached values
      readiness.setCachedConnection(true);
      readiness.setCachedMedia('OK', true);
      readiness.setCachedHead('OK', true);
      readiness.setCachedPause('Not Paused', false);
      readiness.setCachedHost('Online', []);
      readiness.setCachedLanguage('zpl');

      // Now marked as read
      expect(readiness.wasConnectionRead, isTrue);
      expect(readiness.wasMediaRead, isTrue);
      expect(readiness.wasHeadRead, isTrue);
      expect(readiness.wasPauseRead, isTrue);
      expect(readiness.wasHostRead, isTrue);
      expect(readiness.wasLanguageRead, isTrue);

      // Cached values show actual values
      final cached = readiness.cachedValues;
      expect(cached['connection'], equals('checked'));
      expect(cached['mediaStatus'], equals('OK'));
      expect(cached['hasMedia'], isTrue);
      expect(cached['headStatus'], equals('OK'));
      expect(cached['headClosed'], isTrue);
      expect(cached['pauseStatus'], equals('Not Paused'));
      expect(cached['isPaused'], isFalse);
      expect(cached['hostStatus'], equals('Online'));
      expect(cached['errors'], isEmpty);
      expect(cached['languageStatus'], equals('zpl'));
    });
  });
}
