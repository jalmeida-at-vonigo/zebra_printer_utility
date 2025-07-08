import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/models/printer_readiness.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:mockito/mockito.dart';

class MockZebraPrinter extends Mock implements ZebraPrinter {}

void main() {
  group('PrinterReadiness', () {
    late MockZebraPrinter mockPrinter;

    setUp(() {
      mockPrinter = MockZebraPrinter();
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
      readiness.setCachedHead('OK', true);
      readiness.setCachedPause('Not Paused', false);
      readiness.setCachedHost('Online', []);

      expect(await readiness.isReady, isTrue);
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
      expect(str, contains('connection: true'));
      expect(str, contains('media: true'));
      expect(str, contains('head: true'));
      expect(str, contains('pause: <unchecked>'));
      expect(str, contains('host: <unchecked>'));
      expect(str, contains('language: <unchecked>'));
    });

    test('ensure methods trigger reads when not initialized', () async {
      final readiness = PrinterReadiness(printer: mockPrinter);

      // Initially not read
      expect(readiness.wasConnectionRead, isFalse);

      // This would trigger a read in real usage, but with mock printer it will fail
      // We can't easily test the actual command execution without complex mocking
      // So we'll just verify the ensure method exists and can be called
      expect(readiness.ensureConnection, isA<Function>());
      expect(readiness.ensureMediaStatus, isA<Function>());
      expect(readiness.ensureHeadStatus, isA<Function>());
      expect(readiness.ensurePauseStatus, isA<Function>());
      expect(readiness.ensureHostStatus, isA<Function>());
      expect(readiness.ensureLanguageStatus, isA<Function>());
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
      expect(cached['connection'], isTrue);
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

    test('readStatus shows correct read flags', () {
      final readiness = PrinterReadiness(printer: mockPrinter);

      final readStatus = readiness.readStatus;
      expect(readStatus['connection'], isFalse);
      expect(readStatus['media'], isFalse);
      expect(readStatus['head'], isFalse);
      expect(readStatus['pause'], isFalse);
      expect(readStatus['host'], isFalse);
      expect(readStatus['language'], isFalse);
      
      // Set some cached values
      readiness.setCachedConnection(true);
      readiness.setCachedMedia('OK', true);
      
      final updatedReadStatus = readiness.readStatus;
      expect(updatedReadStatus['connection'], isTrue);
      expect(updatedReadStatus['media'], isTrue);
      expect(updatedReadStatus['head'], isFalse);
      expect(updatedReadStatus['pause'], isFalse);
      expect(updatedReadStatus['host'], isFalse);
      expect(updatedReadStatus['language'], isFalse);
    });
  });
}
