import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/print_data_detector.dart';
import 'package:zebrautil/models/print_enums.dart';

void main() {
  group('PrintDataDetector', () {
    group('detectFormat', () {
      test('returns null for empty data', () {
        const emptyData = '';
        
        final result = PrintDataDetector.detectFormat(emptyData);
        
        expect(result, isNull);
      });

      test('detects ZPL format with ^XA start', () {
        const zplData = '^XA^FO50,50^FDHello World^FS^XZ';
        
        final result = PrintDataDetector.detectFormat(zplData);
        
        expect(result, equals(PrintFormat.zpl));
      });

      test('detects ZPL format with ZPL commands', () {
        const zplData = '^FO100,100^FDTest^FS';
        
        final result = PrintDataDetector.detectFormat(zplData);
        
        expect(result, equals(PrintFormat.zpl));
      });

      test('detects CPCL format with ! start', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello World\nFORM\nPRINT';
        
        final result = PrintDataDetector.detectFormat(cpclData);
        
        expect(result, equals(PrintFormat.cpcl));
      });

      test('detects CPCL format with CPCL commands', () {
        const cpclData = 'TEXT 4 0 30 40 Hello World\nFORM\nPRINT';
        
        final result = PrintDataDetector.detectFormat(cpclData);
        
        expect(result, equals(PrintFormat.cpcl));
      });

      test('returns null for unknown format', () {
        const unknownData = 'This is some unknown print data';
        
        final result = PrintDataDetector.detectFormat(unknownData);
        
        expect(result, isNull);
      });

      test('handles data with whitespace correctly', () {
        const zplDataWithSpaces = '  ^XA^FO50,50^FDHello^FS^XZ  ';
        
        final result = PrintDataDetector.detectFormat(zplDataWithSpaces);
        
        expect(result, equals(PrintFormat.zpl));
      });
    });

    group('analyzeFormat', () {
      test('provides detailed analysis for ZPL data', () {
        const zplData = '^XA^FO50,50^FDHello^FS^XZ';
        
        final analysis = PrintDataDetector.analyzeFormat(zplData);
        
        expect(analysis['detectedFormat'], equals('zpl'));
        expect(analysis['isEmpty'], isFalse);
        expect(analysis['startsWithZPL'], isTrue);
        expect(analysis['endsWithZPL'], isTrue);
        expect(analysis['containsZPLCommands'], isTrue);
        expect(analysis['containsCPCLCommands'], isFalse);
        expect(analysis['confidence'], equals('high'));
      });

      test('provides detailed analysis for CPCL data', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nFORM';
        
        final analysis = PrintDataDetector.analyzeFormat(cpclData);
        
        expect(analysis['detectedFormat'], equals('cpcl'));
        expect(analysis['isEmpty'], isFalse);
        expect(analysis['startsWithZPL'], isFalse);
        expect(analysis['startsWithCPCL'], isTrue);
        expect(analysis['containsZPLCommands'], isFalse);
        expect(analysis['containsCPCLCommands'], isTrue);
        expect(analysis['confidence'], equals('high'));
      });

      test('provides detailed analysis for unknown data', () {
        const unknownData = 'Some random text';
        
        final analysis = PrintDataDetector.analyzeFormat(unknownData);
        
        expect(analysis['detectedFormat'], equals('unknown'));
        expect(analysis['isEmpty'], isFalse);
        expect(analysis['startsWithZPL'], isFalse);
        expect(analysis['startsWithCPCL'], isFalse);
        expect(analysis['containsZPLCommands'], isFalse);
        expect(analysis['containsCPCLCommands'], isFalse);
        expect(analysis['confidence'], equals('none'));
      });

      test('handles empty data correctly', () {
        const emptyData = '';
        
        final analysis = PrintDataDetector.analyzeFormat(emptyData);
        
        expect(analysis['detectedFormat'], equals('unknown'));
        expect(analysis['isEmpty'], isTrue);
        expect(analysis['confidence'], equals('none'));
      });
    });

    group('getSupportedFormats', () {
      test('returns list of supported formats', () {
        final formats = PrintDataDetector.getSupportedFormats();
        
        expect(formats, contains(PrintFormat.zpl));
        expect(formats, contains(PrintFormat.cpcl));
        expect(formats.length, equals(2));
      });
    });

    group('isFormatSupported', () {
      test('returns true for supported formats', () {
        expect(PrintDataDetector.isFormatSupported(PrintFormat.zpl), isTrue);
        expect(PrintDataDetector.isFormatSupported(PrintFormat.cpcl), isTrue);
      });
    });

    group('confidence levels', () {
      test('returns high confidence for complete ZPL', () {
        const zplData = '^XA^FO50,50^FDHello^FS^XZ';
        
        final analysis = PrintDataDetector.analyzeFormat(zplData);
        
        expect(analysis['confidence'], equals('high'));
      });

      test('returns medium confidence for partial ZPL', () {
        const zplData = '^FO50,50^FDHello^FS';
        
        final analysis = PrintDataDetector.analyzeFormat(zplData);
        
        expect(analysis['confidence'], equals('medium'));
      });

      test('returns high confidence for complete CPCL', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nFORM';
        
        final analysis = PrintDataDetector.analyzeFormat(cpclData);
        
        expect(analysis['confidence'], equals('high'));
      });

      test('returns medium confidence for partial CPCL', () {
        const cpclData = 'TEXT 4 0 30 40 Hello\nFORM';
        
        final analysis = PrintDataDetector.analyzeFormat(cpclData);
        
        expect(analysis['confidence'], equals('medium'));
      });
    });

    group('edge cases', () {
      test('handles null-like data', () {
        const nullData = '\x00\x00\x00';
        
        final result = PrintDataDetector.detectFormat(nullData);
        
        expect(result, isNull);
      });

      test('handles mixed format data (should detect first)', () {
        const mixedData = '^XA^FO50,50^FDHello^FS^XZ\n! 0 200 200 210 1\nTEXT';
        
        final result = PrintDataDetector.detectFormat(mixedData);
        
        expect(result, equals(PrintFormat.zpl));
      });

      test('handles very long data efficiently', () {
        final longZplData = '^XA${'^FO50,50^FDHello^FS' * 1000}^XZ';
        
        final result = PrintDataDetector.detectFormat(longZplData);
        
        expect(result, equals(PrintFormat.zpl));
      });
    });
  });
}
