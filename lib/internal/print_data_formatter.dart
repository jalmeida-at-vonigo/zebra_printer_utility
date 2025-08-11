import '../models/print_enums.dart';
import 'print_data_detector.dart';

/// Single-responsibility class for formatting print data
/// Handles format-specific data preparation without mixing with validation or detection
class PrintDataFormatter {
  /// Format print data for the specified format
  /// Returns formatted data ready for sending to printer
  static String formatPrintData(String data, PrintFormat? format) {
    // Use provided format or detect from data
    final detectedFormat = format ?? PrintDataDetector.detectFormat(data);
    
    switch (detectedFormat) {
      case PrintFormat.cpcl:
        return _formatCPCLData(data);
      case PrintFormat.zpl:
        return _formatZPLData(data);
      case null:
        // Return data as-is for unknown formats
        return data;
    }
  }

  /// Format CPCL data with proper line endings and commands
  static String _formatCPCLData(String data) {
    // 1. Ensure proper line endings - convert any \n to \r\n for CPCL
    String formatted = data.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n');

    // 2. Check if CPCL data ends with FORM but missing PRINT command
    if (formatted.trim().endsWith('FORM') && !formatted.contains('PRINT')) {
      formatted = '${formatted.trim()}\r\nPRINT\r\n';
    }

    // 3. Ensure CPCL ends with proper line endings for buffer flush
    if (!formatted.endsWith('\r\n')) {
      formatted += '\r\n';
    }

    // 4. Add extra line feeds to ensure complete transmission (if not already present)
    if (!formatted.endsWith('\r\n\r\n\r\n')) {
      formatted += '\r\n\r\n';
    }

    return formatted;
  }

  /// Format ZPL data (currently no special formatting required)
  static String _formatZPLData(String data) {
    // ZPL typically doesn't require special formatting
    // Return data as-is
    return data;
  }

  /// Get formatting details for debugging
  static Map<String, dynamic> getFormattingInfo(String originalData, String formattedData, PrintFormat? format) {
    return {
      'originalLength': originalData.length,
      'formattedLength': formattedData.length,
      'format': format?.name ?? 'unknown',
      'hasChanges': originalData != formattedData,
      'formattingApplied': _getAppliedFormatting(originalData, formattedData, format),
    };
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
        
        if (formatted.endsWith('\r\n\r\n\r\n') && !original.endsWith('\r\n\r\n\r\n')) {
          applied.add('Added buffer flush line endings');
        }
      }
    }
    
    if (applied.isEmpty) {
      applied.add('No formatting changes');
    }
    
    return applied;
  }

  /// Check if data requires formatting for the given format
  static bool requiresFormatting(String data, PrintFormat? format) {
    if (format == PrintFormat.cpcl) {
      // Check if CPCL formatting would make changes
      final formatted = _formatCPCLData(data);
      return data != formatted;
    }
    
    // ZPL and unknown formats don't require formatting
    return false;
  }
}
