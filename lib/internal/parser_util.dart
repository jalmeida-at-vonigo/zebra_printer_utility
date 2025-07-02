/// Internal utility class for parsing various printer response formats
/// This class ensures parsing never fails and provides sensible defaults
class ParserUtil {
  /// Convert various representations to boolean
  /// Returns null if value cannot be determined
  static bool? toBool(dynamic value) {
    if (value == null) return null;

    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final lower = value.trim().toLowerCase();

      // True values
      if (lower == 'true' ||
          lower == 'on' ||
          lower == '1' ||
          lower == 'yes' ||
          lower == 'y' ||
          lower == 'enabled' ||
          lower == 'active') {
        return true;
      }

      // False values
      if (lower == 'false' ||
          lower == 'off' ||
          lower == '0' ||
          lower == 'no' ||
          lower == 'n' ||
          lower == 'disabled' ||
          lower == 'inactive') {
        return false;
      }
    }

    return null;
  }

  /// Convert to integer with fallback
  static int? toInt(dynamic value, {int? fallback}) {
    if (value == null) return fallback;

    if (value is int) return value;

    if (value is num) return value.toInt();

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return fallback;

      // Try parsing as int
      final parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed;

      // Try parsing as double then convert
      final doubleVal = double.tryParse(trimmed);
      if (doubleVal != null) return doubleVal.toInt();

      // Try extracting number from string (e.g., "30 degrees" -> 30)
      final match = RegExp(r'^(-?\d+)').firstMatch(trimmed);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? fallback;
      }
    }

    return fallback;
  }

  /// Convert to double with fallback
  static double? toDouble(dynamic value, {double? fallback}) {
    if (value == null) return fallback;

    if (value is double) return value;

    if (value is num) return value.toDouble();

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return fallback;

      // Try parsing as double
      final parsed = double.tryParse(trimmed);
      if (parsed != null) return parsed;

      // Try extracting number from string
      final match = RegExp(r'^(-?\d+\.?\d*)').firstMatch(trimmed);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? fallback;
      }
    }

    return fallback;
  }

  /// Safely convert to string
  static String safeToString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  /// Parse printer status to determine if OK
  static bool isStatusOk(String? status) {
    if (status == null) return false;

    final lower = status.toLowerCase();
    return lower.contains('ok') ||
        lower.contains('ready') ||
        lower.contains('normal') ||
        lower.contains('idle');
  }

  /// Parse media status
  static bool hasMedia(String? status) {
    if (status == null) return false;

    final lower = status.toLowerCase();

    // Check for positive indicators
    if (lower.contains('ok') ||
        lower.contains('ready') ||
        lower.contains('loaded') ||
        lower.contains('present')) {
      return true;
    }

    // Check for negative indicators
    if (lower.contains('out') ||
        lower.contains('empty') ||
        lower.contains('missing') ||
        lower.contains('absent')) {
      return false;
    }

    // Default to false if uncertain
    return false;
  }

  /// Parse head status
  static bool isHeadClosed(String? status) {
    if (status == null) return false;

    final lower = status.toLowerCase();

    // Check for open status first (more specific)
    if (lower.contains('open') || lower.contains('unlocked')) {
      return false;
    }

    // Check for closed/ok status
    if (lower.contains('closed') ||
        lower.contains('ok') ||
        lower.contains('locked')) {
      return true;
    }

    // Default to false for safety
    return false;
  }

  /// Parse error status from host status
  static String? parseErrorFromStatus(String? status) {
    if (status == null || status.isEmpty) return null;

    final lower = status.toLowerCase();

    // Common error patterns
    if (lower.contains('paper out')) return 'Out of paper';
    if (lower.contains('ribbon out')) return 'Out of ribbon';
    if (lower.contains('head open')) return 'Print head open';
    if (lower.contains('head cold')) return 'Print head cold';
    if (lower.contains('head over temp')) return 'Print head overheated';
    if (lower.contains('pause')) return 'Printer paused';
    if (lower.contains('error')) {
      return status; // Return original if generic error
    }

    return null;
  }

  /// Extract numeric value from string (e.g., "203 dpi" -> 203)
  static num? extractNumber(String? value) {
    if (value == null || value.isEmpty) return null;

    final match = RegExp(r'(-?\d+\.?\d*)').firstMatch(value);
    if (match != null) {
      final numStr = match.group(1)!;
      return num.tryParse(numStr);
    }

    return null;
  }

  /// Clean and normalize status strings
  static String normalizeStatus(String? status) {
    if (status == null || status.isEmpty) return '';

    // Remove quotes if present
    var cleaned = status.trim();
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }

    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }
}
