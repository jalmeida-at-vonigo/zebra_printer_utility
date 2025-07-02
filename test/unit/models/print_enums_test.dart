import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/models/print_enums.dart';

void main() {
  group('EnumMediaType', () {
    test('should have correct values', () {
      expect(EnumMediaType.label.toString(), equals('EnumMediaType.label'));
      expect(EnumMediaType.blackMark.toString(),
          equals('EnumMediaType.blackMark'));
      expect(EnumMediaType.journal.toString(), equals('EnumMediaType.journal'));
    });
  });

  group('Command', () {
    test('should have correct values', () {
      expect(Command.calibrate.toString(), equals('Command.calibrate'));
      expect(Command.mediaType.toString(), equals('Command.mediaType'));
      expect(Command.darkness.toString(), equals('Command.darkness'));
    });
  });

  group('PrintFormat', () {
    test('should have correct values', () {
      expect(PrintFormat.zpl.toString(), equals('PrintFormat.zpl'));
      expect(PrintFormat.cpcl.toString(), equals('PrintFormat.cpcl'));
    });
  });
}
