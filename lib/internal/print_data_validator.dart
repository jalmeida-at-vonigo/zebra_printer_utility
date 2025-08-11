import '../models/result.dart';

/// Single-responsibility class for validating print data
/// Handles all validation concerns for print data without mixing with formatting
class PrintDataValidator {
  /// Maximum allowed print data size (1MB)
  static const int maxDataSize = 1000000;

  /// Validate print data before sending to printer
  /// Returns Result.success() if valid, Result.error() with specific error if invalid
  static Result<void> validatePrintData(String data) {
    // Check for empty data
    if (data.isEmpty) {
      return Result.errorCode(ErrorCodes.emptyData);
    }

    // Check data size limit
    if (data.length > maxDataSize) {
      return Result.errorCode(
        ErrorCodes.printDataTooLarge,
        formatArgs: [data.length],
      );
    }

    // Check for basic format validation
    if (!_isValidPrintFormat(data)) {
      return Result.errorCode(ErrorCodes.printDataInvalidFormat);
    }

    return Result.success();
  }

  /// Check if data has a valid print format structure
  /// Returns true if data appears to be valid ZPL, CPCL, or raw data
  static bool _isValidPrintFormat(String data) {
    final trimmed = data.trim();

    // ZPL format check
    if (_isValidZPL(trimmed)) {
      return true;
    }

    // CPCL format check
    if (_isValidCPCL(trimmed)) {
      return true;
    }

    // Raw data (allow any non-empty data that passes basic checks)
    return _isValidRawData(trimmed);
  }

  /// Check if data is valid ZPL format
  static bool _isValidZPL(String data) {
    return data.startsWith('^XA') && data.endsWith('^XZ');
  }

  /// Check if data is valid CPCL format
  static bool _isValidCPCL(String data) {
    return data.startsWith('!') && 
           (data.contains('TEXT') || data.contains('FORM') || data.contains('PRINT'));
  }

  /// Check if data is valid raw print data
  static bool _isValidRawData(String data) {
    // Allow any non-empty data that doesn't contain obviously invalid characters
    return data.isNotEmpty && 
           !data.contains('\x00') && // No null characters
           data.trim().isNotEmpty;
  }

  /// Get validation error details for debugging
  static String getValidationDetails(String data) {
    if (data.isEmpty) {
      return 'Data is empty';
    }
    
    if (data.length > maxDataSize) {
      return 'Data size (${data.length}) exceeds limit ($maxDataSize)';
    }
    
    final trimmed = data.trim();
    if (_isValidZPL(trimmed)) {
      return 'Valid ZPL format detected';
    }
    
    if (_isValidCPCL(trimmed)) {
      return 'Valid CPCL format detected';
    }
    
    if (_isValidRawData(trimmed)) {
      return 'Valid raw data detected';
    }
    
    return 'Invalid format: does not match ZPL, CPCL, or raw data patterns';
  }
}
