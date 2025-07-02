import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/zebra_sgd_commands.dart';

void main() {
  group('ZebraSGDCommands', () {
    test('getCommand returns correct string', () {
      expect(
          ZebraSGDCommands.getCommand('foo'), equals('! U1 getvar "foo"\r\n'));
    });
    test('setCommand returns correct string', () {
      expect(ZebraSGDCommands.setCommand('foo', 'bar'),
          equals('! U1 setvar "foo" "bar"\r\n'));
    });
    test('doCommand returns correct string', () {
      expect(ZebraSGDCommands.doCommand('action', 'val'),
          equals('! U1 do "action" "val"\r\n'));
    });
    test('setZPLMode returns correct command', () {
      expect(ZebraSGDCommands.setZPLMode(), contains('zpl'));
    });
    test('setCPCLMode returns correct command', () {
      expect(ZebraSGDCommands.setCPCLMode(), contains('line_print'));
    });
    test('resetPrinter returns correct command', () {
      expect(ZebraSGDCommands.resetPrinter(), contains('device.reset'));
    });
    test('isZPLData detects ZPL', () {
      expect(ZebraSGDCommands.isZPLData('^XA'), isTrue);
      expect(ZebraSGDCommands.isZPLData('foo'), isFalse);
    });
    test('isCPCLData detects CPCL', () {
      expect(ZebraSGDCommands.isCPCLData('! 0'), isTrue);
      expect(ZebraSGDCommands.isCPCLData('^XA'), isFalse);
    });
    test('detectDataLanguage returns correct language', () {
      expect(ZebraSGDCommands.detectDataLanguage('^XA'), equals('zpl'));
      expect(ZebraSGDCommands.detectDataLanguage('! 0'), equals('cpcl'));
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
    test('unpausePrinter returns correct command', () {
      expect(ZebraSGDCommands.unpausePrinter(), contains('device.pause'));
    });
    test('resumePrinter returns correct command', () {
      expect(ZebraSGDCommands.resumePrinter(), contains('device.reset'));
    });
    test('clearAlerts returns correct command', () {
      expect(ZebraSGDCommands.clearAlerts(), contains('alerts.clear'));
    });
    test('zplResume returns correct command', () {
      expect(ZebraSGDCommands.zplResume(), contains('~PS'));
    });
    test('zplClearErrors returns correct command', () {
      expect(ZebraSGDCommands.zplClearErrors(), contains('~JR'));
    });
  });
}
