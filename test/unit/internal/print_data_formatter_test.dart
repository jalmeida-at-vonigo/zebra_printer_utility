import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/print_data_formatter.dart';
import 'package:zebrautil/models/print_enums.dart';

void main() {
  group('PrintDataFormatter', () {
    group('formatPrintData', () {
      test('formats CPCL data with proper line endings', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nFORM';
        
        final result = PrintDataFormatter.formatPrintData(cpclData, PrintFormat.cpcl);
        
        expect(result, contains('\r\n'));
        expect(result, endsWith('\r\n\r\n\r\n'));
      });

      test('adds PRINT command to CPCL data ending with FORM', () {
        const cpclData = '! 0 200 200 210 1\r\nTEXT 4 0 30 40 Hello\r\nFORM';
        
        final result = PrintDataFormatter.formatPrintData(cpclData, PrintFormat.cpcl);
        
        expect(result, contains('FORM\r\nPRINT\r\n'));
      });

      test('does not modify CPCL data that already has PRINT command', () {
        const cpclData = '! 0 200 200 210 1\r\nTEXT 4 0 30 40 Hello\r\nFORM\r\nPRINT\r\n';
        
        final result = PrintDataFormatter.formatPrintData(cpclData, PrintFormat.cpcl);
        
        // Should still add buffer flush but not duplicate PRINT
        expect(result.split('PRINT').length - 1, equals(1)); // Only one PRINT command
        expect(result, endsWith('\r\n\r\n\r\n'));
      });

      test('returns ZPL data unchanged', () {
        const zplData = '^XA^FO50,50^FDHello World^FS^XZ';
        
        final result = PrintDataFormatter.formatPrintData(zplData, PrintFormat.zpl);
        
        expect(result, equals(zplData));
      });

      test('detects format when not provided', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nFORM';
        
        final result = PrintDataFormatter.formatPrintData(cpclData, null);
        
        // Should detect CPCL and apply formatting
        expect(result, contains('\r\n'));
        expect(result, endsWith('\r\n\r\n\r\n'));
      });

      test('returns unknown format data unchanged', () {
        const unknownData = 'Some unknown format data';
        
        final result = PrintDataFormatter.formatPrintData(unknownData, null);
        
        expect(result, equals(unknownData));
      });
    });

    group('getFormattingInfo', () {
      test('returns correct formatting info for CPCL changes', () {
        const original = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nFORM';
        final formatted = PrintDataFormatter.formatPrintData(original, PrintFormat.cpcl);
        
        final info = PrintDataFormatter.getFormattingInfo(original, formatted, PrintFormat.cpcl);
        
        expect(info['originalLength'], equals(original.length));
        expect(info['formattedLength'], equals(formatted.length));
        expect(info['format'], equals('cpcl'));
        expect(info['hasChanges'], isTrue);
        expect((info['formattingApplied'] as List), contains('CPCL line ending conversion'));
        expect((info['formattingApplied'] as List), contains('Added missing PRINT command'));
      });

      test('returns correct formatting info for no changes', () {
        const zplData = '^XA^FO50,50^FDHello^FS^XZ';
        final formatted = PrintDataFormatter.formatPrintData(zplData, PrintFormat.zpl);
        
        final info = PrintDataFormatter.getFormattingInfo(zplData, formatted, PrintFormat.zpl);
        
        expect(info['hasChanges'], isFalse);
        expect((info['formattingApplied'] as List), contains('No formatting changes'));
      });
    });

    group('requiresFormatting', () {
      test('returns true for CPCL data that needs formatting', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nFORM';
        
        final requires = PrintDataFormatter.requiresFormatting(cpclData, PrintFormat.cpcl);
        
        expect(requires, isTrue);
      });

      test('returns false for ZPL data', () {
        const zplData = '^XA^FO50,50^FDHello^FS^XZ';
        
        final requires = PrintDataFormatter.requiresFormatting(zplData, PrintFormat.zpl);
        
        expect(requires, isFalse);
      });

      test('returns false for properly formatted CPCL data', () {
        const cpclData = '! 0 200 200 210 1\r\nTEXT 4 0 30 40 Hello\r\nFORM\r\nPRINT\r\n\r\n\r\n';
        
        final requires = PrintDataFormatter.requiresFormatting(cpclData, PrintFormat.cpcl);
        
        expect(requires, isFalse);
      });
    });
  });
}
