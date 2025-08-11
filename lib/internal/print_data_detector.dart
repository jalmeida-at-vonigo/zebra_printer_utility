import '../models/print_enums.dart';

/// Single-responsibility class for detecting print data formats
/// Focused solely on format detection without mixing with validation or formatting
class PrintDataDetector {
  /// Detect the print data format from the content
  /// Returns PrintFormat if detected, null if unknown
  static PrintFormat? detectFormat(String data) {
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

  /// Get detailed format analysis for debugging
  static Map<String, dynamic> analyzeFormat(String data) {
    final trimmed = data.trim();
    
    return {
      'detectedFormat': detectFormat(data)?.name ?? 'unknown',
      'isEmpty': data.isEmpty,
      'trimmedLength': trimmed.length,
      'startsWithZPL': trimmed.startsWith('^XA'),
      'endsWithZPL': trimmed.endsWith('^XZ'),
      'startsWithCPCL': trimmed.startsWith('!'),
      'containsZPLCommands': _containsZPLCommands(trimmed),
      'containsCPCLCommands': _containsCPCLCommands(trimmed),
      'confidence': _getDetectionConfidence(trimmed),
    };
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

  /// Get confidence level for format detection
  static String _getDetectionConfidence(String data) {
    final format = detectFormat(data);
    
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

  /// Get all supported formats
  static List<PrintFormat> getSupportedFormats() {
    return [PrintFormat.zpl, PrintFormat.cpcl];
  }

  /// Check if a specific format is supported
  static bool isFormatSupported(PrintFormat format) {
    return getSupportedFormats().contains(format);
  }
}
