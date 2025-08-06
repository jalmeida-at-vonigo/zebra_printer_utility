import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/models/print_enums.dart';

void main() {
  group('PrintFormat', () {
    test('should have correct values', () {
      expect(PrintFormat.zpl.toString(), equals('PrintFormat.zpl'));
      expect(PrintFormat.cpcl.toString(), equals('PrintFormat.cpcl'));
    });
  });

  group('PrintStatus', () {
    test('should have correct display names', () {
      expect(PrintStatus.connecting.displayName, equals('Connecting'));
      expect(
          PrintStatus.configuring.displayName, equals('Configuring Printer'));
      expect(PrintStatus.printing.displayName, equals('Printing'));
      expect(PrintStatus.done.displayName, equals('Done'));
      expect(PrintStatus.failed.displayName, equals('Failed'));
      expect(PrintStatus.cancelled.displayName, equals('Cancelled'));
    });

    test('should correctly identify completed statuses', () {
      expect(PrintStatus.done.isCompleted, isTrue);
      expect(PrintStatus.failed.isCompleted, isTrue);
      expect(PrintStatus.cancelled.isCompleted, isTrue);
      expect(PrintStatus.connecting.isCompleted, isFalse);
      expect(PrintStatus.configuring.isCompleted, isFalse);
      expect(PrintStatus.printing.isCompleted, isFalse);
    });

    test('should correctly identify in-progress statuses', () {
      expect(PrintStatus.connecting.isInProgress, isTrue);
      expect(PrintStatus.configuring.isInProgress, isTrue);
      expect(PrintStatus.printing.isInProgress, isTrue);
      expect(PrintStatus.done.isInProgress, isFalse);
      expect(PrintStatus.failed.isInProgress, isFalse);
      expect(PrintStatus.cancelled.isInProgress, isFalse);
    });
  });
}
