import 'package:zebrautil/models/print_enums.dart';

/// SGD (Set Get Do) command utility for Zebra printers
///
/// This class contains ONLY utility methods for data format detection,
/// response parsing, and language matching. Command strings are defined
/// in their respective command classes.
class ZebraSGDCommands {
  /// Check if data is ZPL format
  static bool isZPLData(String data) {
    final trimmed = data.trim();
    return trimmed.startsWith('^XA') || trimmed.contains('^XA');
  }

  /// Check if data is CPCL format
  static bool isCPCLData(String data) {
    final trimmed = data.trim();
    return trimmed.startsWith('! 0') ||
        trimmed.startsWith('! U1') ||
        trimmed.startsWith('!');
  }

  /// Determine printer language from data
  static PrintFormat? detectDataLanguage(String data) {
    if (isZPLData(data)) return PrintFormat.zpl;
    if (isCPCLData(data)) return PrintFormat.cpcl;
    return null;
  }

  /// Parse SGD response to extract value
  static String? parseResponse(String response) {
    if (response.isEmpty) return null;

    // Remove common response prefixes/suffixes
    String cleaned = response.trim();

    // Handle responses like "OK" or "ERROR"
    if (cleaned == 'OK' || cleaned == 'ERROR') {
      return cleaned;
    }
    
    // Handle responses in format "key" : "value" - extract just the value
    final keyValueMatch =
        RegExp(r'"[^"]*"\s*:\s*"([^"]*)"').firstMatch(cleaned);
    if (keyValueMatch != null) {
      return keyValueMatch.group(1);
    }
    
    // Handle responses with quotes: "value"
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      return cleaned.substring(1, cleaned.length - 1);
    }
    
    // Handle responses with brackets: [value]
    if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
      return cleaned.substring(1, cleaned.length - 1);
    }
    
    // Handle responses with parentheses: (value)
    if (cleaned.startsWith('(') && cleaned.endsWith(')')) {
      return cleaned.substring(1, cleaned.length - 1);
    }
    
    return cleaned;
  }

  /// Check if current language matches expected language
  static bool isLanguageMatch(String current, String expected) {
    final currentLower = current.toLowerCase();
    final expectedLower = expected.toLowerCase();
    
    if (expectedLower == 'zpl') {
      return currentLower.contains('zpl');
    } else if (expectedLower == 'cpcl') {
      return currentLower.contains('cpcl') ||
          currentLower.contains('line_print');
    }
    
    return false;
  }
}
