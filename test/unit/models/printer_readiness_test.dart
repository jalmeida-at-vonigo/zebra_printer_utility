import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/models/printer_readiness.dart';

void main() {
  group('PrinterReadiness', () {
    test('default values', () {
      final readiness = PrinterReadiness();
      expect(readiness.isReady, isFalse);
      expect(readiness.isConnected, isNull);
      expect(readiness.hasMedia, isNull);
      expect(readiness.headClosed, isNull);
      expect(readiness.isPaused, isNull);
      expect(readiness.mediaStatus, isNull);
      expect(readiness.headStatus, isNull);
      expect(readiness.pauseStatus, isNull);
      expect(readiness.hostStatus, isNull);
      expect(readiness.errors, isEmpty);
      expect(readiness.warnings, isEmpty);
      expect(readiness.fullCheckPerformed, isFalse);
      expect(readiness.timestamp, isA<DateTime>());
    });

    test('summary returns "Printer is ready" if isReady', () {
      final readiness = PrinterReadiness();
      readiness.isReady = true;
      expect(readiness.summary, equals('Printer is ready'));
    });

    test('summary returns errors if present', () {
      final readiness = PrinterReadiness();
      readiness.errors.addAll(['Error 1', 'Error 2']);
      expect(readiness.summary, equals('Error 1, Error 2'));
    });

    test('summary returns "Not connected" if not connected', () {
      final readiness = PrinterReadiness();
      readiness.isConnected = false;
      expect(readiness.summary, equals('Not connected'));
    });

    test('summary returns "No media" if hasMedia is false', () {
      final readiness = PrinterReadiness();
      readiness.hasMedia = false;
      expect(readiness.summary, equals('No media'));
    });

    test('summary returns "Head open" if headClosed is false', () {
      final readiness = PrinterReadiness();
      readiness.headClosed = false;
      expect(readiness.summary, equals('Head open'));
    });

    test('summary returns "Printer paused" if isPaused is true', () {
      final readiness = PrinterReadiness();
      readiness.isPaused = true;
      expect(readiness.summary, equals('Printer paused'));
    });

    test('summary returns "Not ready" if no other status', () {
      final readiness = PrinterReadiness();
      expect(readiness.summary, equals('Not ready'));
    });

    test('toMap returns correct structure', () {
      final readiness = PrinterReadiness();
      readiness.isReady = true;
      readiness.isConnected = true;
      readiness.hasMedia = true;
      readiness.headClosed = true;
      readiness.isPaused = false;
      readiness.mediaStatus = 'OK';
      readiness.headStatus = 'OK';
      readiness.pauseStatus = 'Not Paused';
      readiness.hostStatus = 'Online';
      readiness.errors.add('No errors');
      readiness.warnings.add('Low media');
      readiness.fullCheckPerformed = true;
      final map = readiness.toMap();
      expect(map['isReady'], isTrue);
      expect(map['isConnected'], isTrue);
      expect(map['hasMedia'], isTrue);
      expect(map['headClosed'], isTrue);
      expect(map['isPaused'], isFalse);
      expect(map['mediaStatus'], equals('OK'));
      expect(map['headStatus'], equals('OK'));
      expect(map['pauseStatus'], equals('Not Paused'));
      expect(map['hostStatus'], equals('Online'));
      expect(map['errors'], contains('No errors'));
      expect(map['warnings'], contains('Low media'));
      expect(map['timestamp'], isA<String>());
      expect(map['fullCheckPerformed'], isTrue);
      expect(map['summary'], equals('Printer is ready'));
    });
  });
}
