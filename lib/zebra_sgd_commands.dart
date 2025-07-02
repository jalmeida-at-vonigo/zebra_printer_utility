/// SGD (Set Get Do) command builder for Zebra printers
class ZebraSGDCommands {
  /// Get a printer setting value
  static String getCommand(String setting) {
    return '! U1 getvar "$setting"\r\n';
  }

  /// Set a printer setting value
  static String setCommand(String setting, String value) {
    return '! U1 setvar "$setting" "$value"\r\n';
  }

  /// Execute a printer action
  static String doCommand(String action, String value) {
    return '! U1 do "$action" "$value"\r\n';
  }

  /// Common SGD commands
  static const String getPrinterLanguage = '! U1 getvar "device.languages"\r\n';
  static const String getApplName = '! U1 getvar "appl.name"\r\n';
  static const String getPrinterStatus = '! U1 getvar "device.host_status"\r\n';
  static const String getMediaStatus = '! U1 getvar "media.status"\r\n';
  static const String getHeadStatus = '! U1 getvar "head.latch"\r\n';
  static const String getPaused = '! U1 getvar "device.pause"\r\n';

  /// Set printer to ZPL mode
  static String setZPLMode() => setCommand('device.languages', 'zpl');

  /// Set printer to CPCL/Line Print mode
  static String setCPCLMode() => setCommand('device.languages', 'line_print');

  /// Reset the printer
  static String resetPrinter() => doCommand('device.reset', '');

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
  static String? detectDataLanguage(String data) {
    if (isZPLData(data)) return 'zpl';
    if (isCPCLData(data)) return 'cpcl';
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

  /// Unpause/resume commands
  static String unpausePrinter() => setCommand('device.pause', '0');
  
  /// Resume printer - language agnostic using SGD
  static String resumePrinter() => doCommand('device.reset', '');

  /// Clear errors - using SGD commands instead of ZPL
  static String clearAlerts() => setCommand('alerts.clear', 'ALL');

  /// Legacy ZPL-specific commands (use only when in ZPL mode)
  static String zplResume() => '~PS\r\n';
  static String zplClearErrors() => '~JR\r\n';
}
