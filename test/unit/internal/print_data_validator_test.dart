import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/print_data_validator.dart';

void main() {
  group('PrintDataValidator', () {
    group('validatePrintData', () {
      test('returns success for valid ZPL data', () {
        const zplData = '^XA^FO50,50^FDHello World^FS^XZ';
        
        final result = PrintDataValidator.validatePrintData(zplData);
        
        expect(result.success, isTrue);
      });

      test('returns success for valid CPCL data', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello World\nFORM\nPRINT';
        
        final result = PrintDataValidator.validatePrintData(cpclData);
        
        expect(result.success, isTrue);
      });

      test('returns success for valid raw data', () {
        const rawData = 'This is raw print data';
        
        final result = PrintDataValidator.validatePrintData(rawData);
        
        expect(result.success, isTrue);
      });

      test('returns error for empty data', () {
        const emptyData = '';
        
        final result = PrintDataValidator.validatePrintData(emptyData);
        
        expect(result.success, isFalse);
        expect(result.error?.code, equals('EMPTY_DATA'));
      });

      test('returns error for data that is too large', () {
        final largeData = 'x' * (PrintDataValidator.maxDataSize + 1);
        
        final result = PrintDataValidator.validatePrintData(largeData);
        
        expect(result.success, isFalse);
        expect(result.error?.code, equals('PRINT_DATA_TOO_LARGE'));
      });

      test('returns error for data with null characters', () {
        const invalidData = 'Hello\x00World';
        
        final result = PrintDataValidator.validatePrintData(invalidData);
        
        expect(result.success, isFalse);
        expect(result.error?.code, equals('PRINT_DATA_INVALID_FORMAT'));
      });

      test('accepts data at the size limit', () {
        final maxSizeData = 'x' * PrintDataValidator.maxDataSize;
        
        final result = PrintDataValidator.validatePrintData(maxSizeData);
        
        expect(result.success, isTrue);
      });
    });

    group('getValidationDetails', () {
      test('returns correct details for empty data', () {
        const emptyData = '';
        
        final details = PrintDataValidator.getValidationDetails(emptyData);
        
        expect(details, equals('Data is empty'));
      });

      test('returns correct details for oversized data', () {
        final largeData = 'x' * (PrintDataValidator.maxDataSize + 1);
        
        final details = PrintDataValidator.getValidationDetails(largeData);
        
        expect(details, contains('Data size (${largeData.length}) exceeds limit'));
      });

      test('returns correct details for valid ZPL data', () {
        const zplData = '^XA^FO50,50^FDHello^FS^XZ';
        
        final details = PrintDataValidator.getValidationDetails(zplData);
        
        expect(details, equals('Valid ZPL format detected'));
      });

      test('returns correct details for valid CPCL data', () {
        const cpclData = '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nFORM';
        
        final details = PrintDataValidator.getValidationDetails(cpclData);
        
        expect(details, equals('Valid CPCL format detected'));
      });

      test('returns correct details for valid raw data', () {
        const rawData = 'Hello World';
        
        final details = PrintDataValidator.getValidationDetails(rawData);
        
        expect(details, equals('Valid raw data detected'));
      });

      test('returns correct details for invalid data', () {
        const invalidData = '\x00invalid';
        
        final details = PrintDataValidator.getValidationDetails(invalidData);
        
        expect(details, equals('Invalid format: does not match ZPL, CPCL, or raw data patterns'));
      });
    });
  });
}
