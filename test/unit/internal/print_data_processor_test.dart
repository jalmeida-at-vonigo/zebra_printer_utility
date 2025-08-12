import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/print_data_processor.dart';
import 'package:zebrautil/models/print_enums.dart';

void main() {
  group('PrintDataProcessor', () {
    group('process()', () {
      test('should process ZPL data successfully', () {
        const zplData = '^XA^FO50,50^FDHello World^FS^XZ';
        
        final result = PrintDataProcessor.process(zplData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.format, equals(PrintFormat.zpl));
        expect(result.data!.originalData, equals(zplData));
        expect(result.data!.data, equals(zplData)); // ZPL doesn't require formatting
        expect(result.data!.analysis['detectedFormat'], equals('zpl'));
        expect(result.data!.analysis['confidence'], equals('high'));
      });

      test('should process CPCL data with formatting', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello World\nFORM\n';
        
        final result = PrintDataProcessor.process(cpclData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.format, equals(PrintFormat.cpcl));
        expect(result.data!.originalData, equals(cpclData));
        expect(result.data!.data, isNot(equals(cpclData))); // CPCL should be formatted
        expect(result.data!.data.contains('PRINT'), isTrue); // Should add PRINT command
        expect(result.data!.data.endsWith('\r\n\r\n'), isTrue); // Should add buffer flush
        expect(result.data!.analysis['detectedFormat'], equals('cpcl'));
        expect(result.data!.analysis['requiresFormatting'], isTrue);
      });

      test('should use provided format when specified', () {
        const rawData = 'Hello World';
        
        final result = PrintDataProcessor.process(rawData, PrintFormat.zpl);
        
        expect(result.success, isTrue);
        expect(result.data!.format, equals(PrintFormat.zpl));
        expect(result.data!.originalData, equals(rawData));
        expect(result.data!.data, equals(rawData));
      });

      test('should default to ZPL for unknown format', () {
        const unknownData = 'Some random text';
        
        final result = PrintDataProcessor.process(unknownData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.format, equals(PrintFormat.zpl));
        expect(result.data!.originalData, equals(unknownData));
        expect(result.data!.data, equals(unknownData));
        expect(result.data!.analysis['detectedFormat'], equals('zpl'));
      });

      test('should fail for empty data', () {
        final result = PrintDataProcessor.process('', null);
        
        expect(result.success, isFalse);
        expect(result.error!.code, equals('EMPTY_DATA'));
      });

      test('should fail for data too large', () {
        final largeData = 'x' * (PrintDataProcessor.maxDataSize + 1);
        
        final result = PrintDataProcessor.process(largeData, null);
        
        expect(result.success, isFalse);
        expect(result.error!.code, equals('PRINT_DATA_TOO_LARGE'));
      });

      test('should fail for data with null characters', () {
        const dataWithNull = 'Hello\x00World';
        
        final result = PrintDataProcessor.process(dataWithNull, null);
        
        expect(result.success, isFalse);
        expect(result.error!.code, equals('INVALID_FORMAT'));
      });

      test('should generate comprehensive analysis', () {
        const zplData = '^XA^FO50,50^FDTest^FS^XZ';
        
        final result = PrintDataProcessor.process(zplData, null);
        
        expect(result.success, isTrue);
        final analysis = result.data!.analysis;
        
        expect(analysis['detectedFormat'], equals('zpl'));
        expect(analysis['isEmpty'], isFalse);
        expect(analysis['dataLength'], equals(zplData.length));
        expect(analysis['trimmedLength'], equals(zplData.trim().length));
        expect(analysis['maxSizeExceeded'], isFalse);
        expect(analysis['hasNullCharacters'], isFalse);
        expect(analysis['isValidFormat'], isTrue);
        expect(analysis['startsWithZPL'], isTrue);
        expect(analysis['endsWithZPL'], isTrue);
        expect(analysis['startsWithCPCL'], isFalse);
        expect(analysis['containsZPLCommands'], isTrue);
        expect(analysis['containsCPCLCommands'], isFalse);
        expect(analysis['confidence'], equals('high'));
        expect(analysis['requiresFormatting'], isFalse);
        expect(analysis['formattingApplied'], isA<List<String>>());
      });
    });

    group('Format Detection', () {
      test('should detect ZPL format with ^XA start', () {
        const zplData = '^XA^FO50,50^FDHello^FS^XZ';
        
        final result = PrintDataProcessor.process(zplData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.format, equals(PrintFormat.zpl));
        expect(result.data!.analysis['confidence'], equals('high'));
      });

      test('should detect ZPL format with commands only', () {
        const zplData = '^FO50,50^FDHello^FS';
        
        final result = PrintDataProcessor.process(zplData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.format, equals(PrintFormat.zpl));
        expect(result.data!.analysis['confidence'], equals('medium'));
      });

      test('should detect CPCL format with ! start', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nPRINT';
        
        final result = PrintDataProcessor.process(cpclData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.format, equals(PrintFormat.cpcl));
        expect(result.data!.analysis['confidence'], equals('high'));
      });

      test('should detect CPCL format with commands only', () {
        const cpclData = 'TEXT 4 0 30 40 Hello\nPRINT';
        
        final result = PrintDataProcessor.process(cpclData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.format, equals(PrintFormat.cpcl));
        expect(result.data!.analysis['confidence'], equals('medium'));
      });

      test('should default to ZPL for unknown format', () {
        const unknownData = 'Hello World';
        
        final result = PrintDataProcessor.process(unknownData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.format, equals(PrintFormat.zpl));
        expect(result.data!.analysis['confidence'], equals('low'));
      });
    });

    group('Data Validation', () {
      test('should validate proper ZPL data', () {
        const validZpl = '^XA^FO50,50^FDTest^FS^XZ';
        
        final result = PrintDataProcessor.process(validZpl, null);
        
        expect(result.success, isTrue);
        expect(result.data!.analysis['isValidFormat'], isTrue);
      });

      test('should validate proper CPCL data', () {
        const validCpcl = '! 0 200 200 210 1\nTEXT 4 0 30 40 Test\nPRINT';
        
        final result = PrintDataProcessor.process(validCpcl, null);
        
        expect(result.success, isTrue);
        expect(result.data!.analysis['isValidFormat'], isTrue);
      });

      test('should validate raw data', () {
        const rawData = 'Simple text data';
        
        final result = PrintDataProcessor.process(rawData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.analysis['isValidFormat'], isTrue);
      });

      test('should reject data at size limit', () {
        final maxSizeData = 'x' * PrintDataProcessor.maxDataSize;
        
        final result = PrintDataProcessor.process(maxSizeData, null);
        
        expect(result.success, isTrue); // Should accept exactly at limit
        expect(result.data!.analysis['maxSizeExceeded'], isFalse);
      });

      test('should reject data over size limit', () {
        final oversizeData = 'x' * (PrintDataProcessor.maxDataSize + 1);
        
        final result = PrintDataProcessor.process(oversizeData, null);
        
        expect(result.success, isFalse);
        expect(result.error!.code, equals('PRINT_DATA_TOO_LARGE'));
      });

      test('should detect null characters', () {
        const dataWithNull = 'Hello\x00World';
        
        final result = PrintDataProcessor.process(dataWithNull, null);
        
        expect(result.success, isFalse);
        expect(result.error!.code, equals('INVALID_FORMAT'));
      });
    });

    group('CPCL Formatting', () {
      test('should add PRINT command to FORM-ending CPCL', () {
        const cpclWithForm = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nFORM';
        
        final result = PrintDataProcessor.process(cpclWithForm, PrintFormat.cpcl);
        
        expect(result.success, isTrue);
        expect(result.data!.data.contains('PRINT'), isTrue);
        expect(result.data!.analysis['requiresFormatting'], isTrue);
        final applied = result.data!.analysis['formattingApplied'] as List<String>;
        expect(applied.any((f) => f.contains('Added missing PRINT command')), isTrue);
      });

      test('should convert line endings for CPCL', () {
        const cpclWithLf = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nPRINT';
        
        final result = PrintDataProcessor.process(cpclWithLf, PrintFormat.cpcl);
        
        expect(result.success, isTrue);
        expect(result.data!.data.contains('\r\n'), isTrue);
        // Note: Some \n might remain as part of \r\n sequences, so we check for standalone \n
        expect(result.data!.data.contains(RegExp(r'(?<!\r)\n')), isFalse); // No standalone \n
        expect(result.data!.analysis['requiresFormatting'], isTrue);
      });

      test('should add buffer flush line endings', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nPRINT';
        
        final result = PrintDataProcessor.process(cpclData, PrintFormat.cpcl);
        
        expect(result.success, isTrue);
        expect(result.data!.data.endsWith('\r\n\r\n'), isTrue);
        expect(result.data!.analysis['requiresFormatting'], isTrue);
        final applied = result.data!.analysis['formattingApplied'] as List<String>;
        expect(applied.any((f) => f.contains('buffer flush')), isTrue);
      });

      test('should not add redundant formatting', () {
        const alreadyFormatted = '! 0 200 200 210 1\r\nTEXT 4 0 30 40 Hello\r\nPRINT\r\n\r\n';
        
        final result = PrintDataProcessor.process(alreadyFormatted, PrintFormat.cpcl);
        
        expect(result.success, isTrue);
        expect(result.data!.data, equals(alreadyFormatted));
        expect(result.data!.analysis['requiresFormatting'], isFalse);
        final applied = result.data!.analysis['formattingApplied'] as List<String>;
        expect(applied, contains('No formatting changes'));
      });

      test('should preserve existing PRINT command', () {
        const cpclWithPrint = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nPRINT\nFORM';
        
        final result = PrintDataProcessor.process(cpclWithPrint, PrintFormat.cpcl);
        
        expect(result.success, isTrue);
        expect(result.data!.data.split('PRINT').length, equals(2)); // Should only have one PRINT
      });
    });

    group('ZPL Formatting', () {
      test('should not modify ZPL data', () {
        const zplData = '^XA^FO50,50^FDHello World^FS^XZ';
        
        final result = PrintDataProcessor.process(zplData, PrintFormat.zpl);
        
        expect(result.success, isTrue);
        expect(result.data!.data, equals(zplData));
        expect(result.data!.analysis['requiresFormatting'], isFalse);
        final applied = result.data!.analysis['formattingApplied'] as List<String>;
        expect(applied, contains('No formatting changes'));
      });

      test('should handle ZPL without ^XA/^XZ', () {
        const zplCommands = '^FO50,50^FDHello^FS';
        
        final result = PrintDataProcessor.process(zplCommands, PrintFormat.zpl);
        
        expect(result.success, isTrue);
        expect(result.data!.data, equals(zplCommands));
        expect(result.data!.format, equals(PrintFormat.zpl));
      });
    });

    group('Analysis Generation', () {
      test('should generate correct confidence levels', () {
        // High confidence ZPL
        final highZpl = PrintDataProcessor.process('^XA^FO50,50^FDTest^FS^XZ', null);
        expect(highZpl.data!.analysis['confidence'], equals('high'));

        // Medium confidence ZPL
        final mediumZpl = PrintDataProcessor.process('^FO50,50^FDTest^FS', null);
        expect(mediumZpl.data!.analysis['confidence'], equals('medium'));

        // High confidence CPCL
        final highCpcl = PrintDataProcessor.process('! 0 200 200 210 1\nTEXT 4 0 30 40 Test\nPRINT', null);
        expect(highCpcl.data!.analysis['confidence'], equals('high'));

        // Medium confidence CPCL
        final mediumCpcl = PrintDataProcessor.process('TEXT 4 0 30 40 Test\nPRINT', null);
        expect(mediumCpcl.data!.analysis['confidence'], equals('medium'));

        // Low confidence (unknown format defaulting to ZPL)
        final lowConfidence = PrintDataProcessor.process('Hello World', null);
        expect(lowConfidence.data!.analysis['confidence'], equals('low'));
      });

      test('should detect ZPL commands correctly', () {
        const zplWithCommands = '^FO50,50^FDTest^FS^CF0,30^CI0^GB100,5,5';
        
        final result = PrintDataProcessor.process(zplWithCommands, null);
        
        expect(result.success, isTrue);
        expect(result.data!.analysis['containsZPLCommands'], isTrue);
        expect(result.data!.analysis['containsCPCLCommands'], isFalse);
      });

      test('should detect CPCL commands correctly', () {
        const cpclWithCommands = 'TEXT 4 0 30 40 Test\nLINE 10 10 100 10 2\nBOX 20 20 80 80 2\nPRINT';
        
        final result = PrintDataProcessor.process(cpclWithCommands, null);
        
        expect(result.success, isTrue);
        expect(result.data!.analysis['containsCPCLCommands'], isTrue);
        expect(result.data!.analysis['containsZPLCommands'], isFalse);
      });

      test('should track formatting applications', () {
        const cpclNeedsFormatting = '! 0 200 200 210 1\nTEXT 4 0 30 40 Test\nFORM';
        
        final result = PrintDataProcessor.process(cpclNeedsFormatting, PrintFormat.cpcl);
        
        expect(result.success, isTrue);
        final applied = result.data!.analysis['formattingApplied'] as List<String>;
        expect(applied.length, greaterThan(1)); // Should have multiple formatting operations
        expect(applied.any((f) => f.contains('line ending')), isTrue);
        expect(applied.any((f) => f.contains('PRINT command')), isTrue);
        expect(applied.any((f) => f.contains('buffer flush')), isTrue);
      });
    });

    group('Utility Methods', () {
      test('getSupportedFormats should return ZPL and CPCL', () {
        final formats = PrintDataProcessor.getSupportedFormats();
        
        expect(formats, contains(PrintFormat.zpl));
        expect(formats, contains(PrintFormat.cpcl));
        expect(formats.length, equals(2));
      });

      test('isFormatSupported should work correctly', () {
        expect(PrintDataProcessor.isFormatSupported(PrintFormat.zpl), isTrue);
        expect(PrintDataProcessor.isFormatSupported(PrintFormat.cpcl), isTrue);
      });

      test('getValidationDetails should provide helpful messages', () {
        expect(PrintDataProcessor.getValidationDetails(''), equals('Data is empty'));
        
        final largeData = 'x' * (PrintDataProcessor.maxDataSize + 1);
        final largeDetails = PrintDataProcessor.getValidationDetails(largeData);
        expect(largeDetails, contains('exceeds limit'));
        
        const nullData = 'Hello\x00World';
        expect(PrintDataProcessor.getValidationDetails(nullData), contains('null characters'));
        
        const validZpl = '^XA^FO50,50^FDTest^FS^XZ';
        expect(PrintDataProcessor.getValidationDetails(validZpl), contains('Valid ZPL'));
        
        const validCpcl = '! 0 200 200 210 1\nTEXT 4 0 30 40 Test\nPRINT';
        expect(PrintDataProcessor.getValidationDetails(validCpcl), contains('Valid CPCL'));
        
        const rawData = 'Simple text';
        expect(PrintDataProcessor.getValidationDetails(rawData), contains('Valid raw data'));
      });
    });

    group('ProcessedPrintData', () {
      test('should create with all required fields', () {
        const testData = ProcessedPrintData(
          originalData: 'original',
          data: 'formatted',
          format: PrintFormat.zpl,
          analysis: {'test': 'value'},
        );
        
        expect(testData.originalData, equals('original'));
        expect(testData.data, equals('formatted'));
        expect(testData.format, equals(PrintFormat.zpl));
        expect(testData.analysis['test'], equals('value'));
        expect(testData.printData, equals('formatted')); // getter should return data
      });
    });

    group('Edge Cases', () {
      test('should handle whitespace-only data', () {
        const whitespaceData = '   \n\t\r\n   ';
        
        final result = PrintDataProcessor.process(whitespaceData, null);
        
        expect(result.success, isFalse); // Should fail validation for whitespace-only data
        expect(result.error!.code, equals('PRINT_DATA_INVALID_FORMAT'));
      });

      test('should handle mixed format indicators', () {
        const mixedData = '^XA! 0 200 200 210 1\nTEXT 4 0 30 40 Test^FS^XZ';
        
        final result = PrintDataProcessor.process(mixedData, null);
        
        expect(result.success, isTrue);
        // Should detect as ZPL since it starts with ^XA
        expect(result.data!.format, equals(PrintFormat.zpl));
      });

      test('should handle very small data', () {
        const smallData = 'X';
        
        final result = PrintDataProcessor.process(smallData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.analysis['dataLength'], equals(1));
        expect(result.data!.analysis['isValidFormat'], isTrue);
      });

      test('should handle data with special characters', () {
        const specialData = 'åäö测试 emoji😀 symbols!@#\$%^&*()';
        
        final result = PrintDataProcessor.process(specialData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.originalData, equals(specialData));
        expect(result.data!.data, equals(specialData));
      });

      test('should handle data exactly at max size', () {
        final maxData = 'x' * PrintDataProcessor.maxDataSize;
        
        final result = PrintDataProcessor.process(maxData, null);
        
        expect(result.success, isTrue);
        expect(result.data!.analysis['maxSizeExceeded'], isFalse);
        expect(result.data!.analysis['dataLength'], equals(PrintDataProcessor.maxDataSize));
      });
    });
  });
}
