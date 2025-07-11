import 'package:zebrautil/models/print_enums.dart';

/// SGD (Set Get Do) command builder for Zebra printers - UTILITY ONLY
///
/// This class provides utility methods for data format detection and response parsing.
/// For command generation, use CommandFactory instead.
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
    // SGD responses typically come in format: "setting_name" : "value"
    final match = RegExp(r'"[^"]*"\s*:\s*"([^"]*)"').firstMatch(response);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // Sometimes just the value is returned
    final trimmed = response.trim();
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }

    return trimmed.isEmpty ? null : trimmed;
  }

  /// Check if printer language matches expected
  static bool isLanguageMatch(String currentLanguage, String expectedLanguage) {
    final current = currentLanguage.toLowerCase();
    final expected = expectedLanguage.toLowerCase();

    if (expected == 'zpl') {
      return current.contains('zpl');
    } else if (expected == 'cpcl' || expected == 'line_print') {
      return current.contains('line_print') || current.contains('cpcl');
    }

    return false;
  }
}
