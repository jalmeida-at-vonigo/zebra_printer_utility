import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/zebra_sgd_commands.dart';

void main() {
  group('ZebraSGDCommands', () {
    test('isZPLData detects ZPL', () {
      expect(ZebraSGDCommands.isZPLData('^XA'), isTrue);
      expect(ZebraSGDCommands.isZPLData('foo'), isFalse);
    });
    test('isCPCLData detects CPCL', () {
      expect(ZebraSGDCommands.isCPCLData('! 0'), isTrue);
      expect(ZebraSGDCommands.isCPCLData('^XA'), isFalse);
    });
    test('detectDataLanguage returns correct language', () {
      expect(
          ZebraSGDCommands.detectDataLanguage('^XA'), equals(PrintFormat.zpl));
      expect(
          ZebraSGDCommands.detectDataLanguage('! 0'), equals(PrintFormat.cpcl));
      expect(ZebraSGDCommands.detectDataLanguage('foo'), isNull);
    });
    test('parseResponse extracts value from SGD response', () {
      expect(ZebraSGDCommands.parseResponse('"foo" : "bar"'), equals('bar'));
      expect(ZebraSGDCommands.parseResponse('"bar"'), equals('bar'));
      expect(ZebraSGDCommands.parseResponse('baz'), equals('baz'));
      expect(ZebraSGDCommands.parseResponse(''), isNull);
    });
    test('isLanguageMatch works for zpl and cpcl', () {
      expect(ZebraSGDCommands.isLanguageMatch('zpl', 'zpl'), isTrue);
      expect(ZebraSGDCommands.isLanguageMatch('line_print', 'cpcl'), isTrue);
      expect(ZebraSGDCommands.isLanguageMatch('foo', 'zpl'), isFalse);
    });
  });
}
