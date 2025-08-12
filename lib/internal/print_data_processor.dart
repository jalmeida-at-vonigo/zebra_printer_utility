import '../models/print_enums.dart';
import '../models/result.dart';

/// Processed print data containing all analysis and formatted data
class ProcessedPrintData {
  const ProcessedPrintData({
    required this.originalData,
    required this.data,
    required this.format,
    required this.analysis,
  });

  final String originalData;
  final String data;
  final PrintFormat format;
  final Map<String, dynamic> analysis;

  /// Get formatted data ready for printing
  String get printData => data;
}

/// Comprehensive print data processing utility
/// Handles detection, validation, and formatting in one cohesive class
class PrintDataProcessor {
  /// Maximum allowed print data size (1MB)
  static const int maxDataSize = 1000000;

  /// MAIN ENTRY POINT: Process print data in one operation
  /// Performs detection, validation, and formatting in a single pass
  /// Returns Result&lt;ProcessedPrintData&gt; with all information cached
  static Result<ProcessedPrintData> process(String data, PrintFormat? format) {
    // Step 1: Detect format (only once) - ensure non-null format
    final detectedFormat = format ?? _detectFormat(data) ?? PrintFormat.zpl;
    
    // Step 2: Validate data - return error if validation fails
    final validationResult = _validatePrintData(data);
    if (!validationResult.success) {
      return Result.failure(validationResult.error!);
    }
    
    // Step 3: Format data (using already detected format)
    final formattedData = _formatForDetectedFormat(data, detectedFormat);
    
    // Step 4: Generate analysis (reuse detection results)
    final analysis = _generateAnalysis(data, detectedFormat, formattedData);
    
    final processedData = ProcessedPrintData(
      originalData: data,
      data: formattedData,
      format: detectedFormat,
      analysis: analysis,
    );
    
    return Result.success(processedData);
  }

  /// Validate print data before processing
  /// Returns Result.success() if valid, Result.error() with specific error if invalid
  static Result<void> _validatePrintData(String data) {
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

    // Check for null characters
    if (data.contains('\x00')) {
      return Result.errorCode(ErrorCodes.invalidFormat);
    }

    // Check for basic format validation
    if (!_isValidPrintFormat(data)) {
      return Result.errorCode(ErrorCodes.printDataInvalidFormat);
    }

    return Result.success();
  }

  /// Detect the print data format from the content
  /// Returns PrintFormat if detected, null if unknown
  static PrintFormat? _detectFormat(String data) {
    if (data.isEmpty) {
      return null;
    }

    final trimmed = data.trim();

    // Check for ZPL format
    if (_isZPLFormat(trimmed)) {
      return PrintFormat.zpl;
    }

    // Check for CPCL format
    if (_isCPCLFormat(trimmed)) {
      return PrintFormat.cpcl;
    }

    // Unknown format
    return null;
  }

  // === Format Detection Logic ===

  /// Check if data is ZPL format
  static bool _isZPLFormat(String data) {
    // ZPL starts with ^XA and typically ends with ^XZ
    if (data.startsWith('^XA')) {
      return true;
    }

    // Also check for common ZPL commands
    if (data.contains('^FO') || data.contains('^FD') || data.contains('^FS')) {
      return true;
    }

    return false;
  }

  /// Check if data is CPCL format
  static bool _isCPCLFormat(String data) {
    // CPCL typically starts with ! and contains specific commands
    if (data.startsWith('!')) {
      return true;
    }

    // Check for common CPCL commands
    if (data.contains('TEXT') || data.contains('FORM') || 
        data.contains('PRINT') || data.contains('LABEL')) {
      return true;
    }

    return false;
  }

  /// Check if data contains ZPL commands
  static bool _containsZPLCommands(String data) {
    final zplCommands = ['^FO', '^FD', '^FS', '^CF', '^CI', '^GB', '^GF'];
    return zplCommands.any((cmd) => data.contains(cmd));
  }

  /// Check if data contains CPCL commands
  static bool _containsCPCLCommands(String data) {
    final cpclCommands = ['TEXT', 'FORM', 'PRINT', 'LABEL', 'LINE', 'BOX'];
    return cpclCommands.any((cmd) => data.contains(cmd));
  }

  // === Validation Logic ===

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

  // === Internal Helper Methods ===

  /// Format data for already detected format (no redundant detection)
  static String _formatForDetectedFormat(String data, PrintFormat? format) {
    switch (format) {
      case PrintFormat.cpcl:
        return _formatCPCLData(data);
      case PrintFormat.zpl:
        return _formatZPLData(data);
      case null:
        // Return data as-is for unknown formats
        return data;
    }
  }

  /// Generate analysis using already detected format
  static Map<String, dynamic> _generateAnalysis(String data, PrintFormat detectedFormat, String formattedData) {
    final trimmed = data.trim();
    
    return {
      'detectedFormat': detectedFormat.name,
      'isEmpty': data.isEmpty,
      'dataLength': data.length,
      'trimmedLength': trimmed.length,
      'maxSizeExceeded': data.length > maxDataSize,
      'hasNullCharacters': data.contains('\x00'),
      'isValidFormat': _isValidPrintFormat(data),
      'startsWithZPL': trimmed.startsWith('^XA'),
      'endsWithZPL': trimmed.endsWith('^XZ'),
      'startsWithCPCL': trimmed.startsWith('!'),
      'containsZPLCommands': _containsZPLCommands(trimmed),
      'containsCPCLCommands': _containsCPCLCommands(trimmed),
      'confidence': _getDetectionConfidenceForFormat(trimmed, detectedFormat),
      'requiresFormatting': data != formattedData,
      'formattingApplied': _getAppliedFormatting(data, formattedData, detectedFormat),
    };
  }

  /// Get confidence for already detected format (avoids re-detection)
  static String _getDetectionConfidenceForFormat(String data, PrintFormat? format) {
    if (format == null) {
      return 'none';
    }
    
    if (format == PrintFormat.zpl) {
      if (data.startsWith('^XA') && data.endsWith('^XZ')) {
        return 'high';
      } else if (_containsZPLCommands(data)) {
        return 'medium';
      } else {
        return 'low';
      }
    }
    
    if (format == PrintFormat.cpcl) {
      if (data.startsWith('!') && _containsCPCLCommands(data)) {
        return 'high';
      } else if (_containsCPCLCommands(data)) {
        return 'medium';
      } else {
        return 'low';
      }
    }
    
    return 'unknown';
  }

  // === Formatting Logic ===

  /// Format CPCL data with proper line endings and commands
  static String _formatCPCLData(String data) {
    // 1. Ensure proper line endings - convert any \n to \r\n for CPCL
    String formatted = data.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n').trim();

    // 2. Check if CPCL data ends with FORM but missing PRINT command
    if (formatted.endsWith('FORM') && !formatted.contains('PRINT')) {
      formatted = '$formatted\r\nPRINT\r\n\r\n';
    }

    // 3. Ensure proper CPCL termination with buffer flush
    // CPCL standard: end with two CRLFs for proper paper advancement
    while (!formatted.endsWith('\r\n\r\n')) {
      // Remove any trailing whitespace and add exactly two CRLFs
      formatted = '$formatted\r\n';
    }

    return formatted;
  }

  /// Format ZPL data (currently no special formatting required)
  static String _formatZPLData(String data) {
    // ZPL typically doesn't require special formatting
    // Return data as-is
    return data;
  }

  /// Get details about what formatting was applied
  static List<String> _getAppliedFormatting(String original, String formatted, PrintFormat? format) {
    final applied = <String>[];
    
    if (format == PrintFormat.cpcl) {
      if (original != formatted) {
        applied.add('CPCL line ending conversion');
        
        if (formatted.contains('PRINT\r\n') && !original.contains('PRINT')) {
          applied.add('Added missing PRINT command');
        }
        
        if (formatted.endsWith('\r\n\r\n') && !original.endsWith('\r\n\r\n')) {
          applied.add('Added buffer flush line endings');
        }
      }
    }
    
    if (applied.isEmpty) {
      applied.add('No formatting changes');
    }
    
    return applied;
  }

  // === Utility Methods ===

  /// Get all supported formats
  static List<PrintFormat> getSupportedFormats() {
    return [PrintFormat.zpl, PrintFormat.cpcl];
  }

  /// Check if a specific format is supported
  static bool isFormatSupported(PrintFormat format) {
    return getSupportedFormats().contains(format);
  }

  /// Get validation details for debugging
  static String getValidationDetails(String data) {
    if (data.isEmpty) {
      return 'Data is empty';
    }
    
    if (data.length > maxDataSize) {
      return 'Data size (${data.length}) exceeds limit ($maxDataSize)';
    }
    
    if (data.contains('\x00')) {
      return 'Data contains null characters';
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
