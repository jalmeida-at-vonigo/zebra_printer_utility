import '../../models/host_status_info.dart';

/// Utility class for parsing Zebra printer responses
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

  /// Parse printer status to determine if busy
  static bool isStatusBusy(String? status) {
    if (status == null) return false;

    final lower = status.toLowerCase();

    // Check for busy indicators
    return lower.contains('busy') ||
        lower.contains('printing') ||
        lower.contains('processing') ||
        lower.contains('receiving') ||
        lower.contains('buffering') ||
        lower.contains('warming') ||
        lower.contains('initializing');
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

  /// Parse host status response and extract detailed information
  /// Handles comma-separated format like "159,0,0,2030,000,0,0,0,000,0,0,0"
  static HostStatusInfo parseHostStatus(String? status) {
    try {
      if (status == null || status.isEmpty) {
        return HostStatusInfo(
          isOk: false,
          errorCode: null,
          errorMessage: 'No status response',
          details: {},
        );
      }

      // Clean the status string
      final cleanedStatus = normalizeStatus(status);

      // Check if it's a simple text status
      if (!cleanedStatus.contains(',')) {
        return _parseTextHostStatus(cleanedStatus);
      }

      // Parse comma-separated format
      return _parseCommaSeparatedHostStatus(cleanedStatus);
    } catch (e) {
      // If anything fails, return a best-effort object
      return HostStatusInfo(
        isOk: false,
        errorCode: null,
        errorMessage: 'Failed to parse host status: $e',
        details: {'rawStatus': status ?? ''},
      );
    }
  }

  /// Parse text-based host status (e.g., "OK", "ERROR", etc.)
  static HostStatusInfo _parseTextHostStatus(String status) {
    try {
      final isOk = isStatusOk(status);
      String? errorMessage;
      if (!isOk) {
        // Use direct text parsing to avoid recursion
        errorMessage =
            _parseTextErrorFromStatus(status) ?? 'Printer error: $status';
      }
      return HostStatusInfo(
        isOk: isOk,
        errorCode: null,
        errorMessage: errorMessage,
        details: {
          'rawStatus': status,
          'statusType': 'text',
        },
      );
    } catch (e) {
      return HostStatusInfo(
        isOk: false,
        errorCode: null,
        errorMessage: 'Failed to parse text host status: $e',
        details: {'rawStatus': status},
      );
    }
  }

  /// Parse error from text status (internal method to avoid recursion)
  static String? _parseTextErrorFromStatus(String? status) {
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

  /// Parse comma-separated host status format
  /// Format: "errorCode,field1,field2,field3,field4,field5,field6,field7,field8,field9,field10,field11"
  static HostStatusInfo _parseCommaSeparatedHostStatus(String status) {
    try {
      final parts = status.split(',');
      // If all parts are empty or only one part, treat as invalid
      if (parts.isEmpty ||
          parts.every((p) => p.trim().isEmpty) ||
          (parts.length == 1 && parts[0].trim().isEmpty)) {
        return HostStatusInfo(
          isOk: false,
          errorCode: null,
          errorMessage: 'Invalid status format',
          details: {'rawStatus': status},
        );
      }

      // Extract error code (first field)
      final errorCode = toInt(parts[0]);
      final isOk = errorCode == 0;

      // Parse error message based on error code
      String? errorMessage;
      if (!isOk && errorCode != null) {
        errorMessage = _getHostStatusErrorMessage(errorCode);
      } else if (isOk) {
        errorMessage = null; // No error message for OK status
      }

      // Build details map with all fields, using safe conversion
      final details = <String, dynamic>{
        'rawStatus': status,
        'statusType': 'comma_separated',
        'errorCode': errorCode,
        'fieldCount': parts.length,
      };

      // Add individual fields if we have them, always safe
      for (int i = 1; i < parts.length; i++) {
        // field1 is parts[1], field2 is parts[2], etc.
        // For field4 and field8, keep as string, others as int
        if (i == 4 || i == 8) {
          details['field$i'] = safeToString(parts[i]);
        } else {
          details['field$i'] = toInt(parts[i]);
        }
      }

      return HostStatusInfo(
        isOk: isOk,
        errorCode: errorCode,
        errorMessage: errorMessage,
        details: details,
      );
    } catch (e) {
      return HostStatusInfo(
        isOk: false,
        errorCode: null,
        errorMessage: 'Failed to parse comma-separated host status: $e',
        details: {'rawStatus': status},
      );
    }
  }

  /// Get human-readable error message for host status error codes
  static String? _getHostStatusErrorMessage(int errorCode) {
    switch (errorCode) {
      case 0:
        return null; // No error message for OK status
      case 1:
        return 'Printer is paused';
      case 2:
        return 'Printer is processing';
      case 3:
        return 'Printer is receiving data';
      case 4:
        return 'Printer is warming up';
      case 5:
        return 'Printer is cooling down';
      case 6:
        return 'Printer is calibrating';
      case 7:
        return 'Printer is initializing';
      case 8:
        return 'Printer is shutting down';
      case 9:
        return 'Printer is rebooting';
      case 10:
        return 'Printer is updating firmware';
      case 11:
        return 'Printer is performing maintenance';
      case 12:
        return 'Printer is performing diagnostics';
      case 13:
        return 'Printer is performing self-test';
      case 14:
        return 'Printer is performing calibration';
      case 15:
        return 'Printer is performing alignment';
      case 16:
        return 'Printer is performing cleaning';
      case 17:
        return 'Printer is performing head cleaning';
      case 18:
        return 'Printer is performing ribbon cleaning';
      case 19:
        return 'Printer is performing media cleaning';
      case 20:
        return 'Printer is performing sensor cleaning';
      case 21:
        return 'Printer is performing head adjustment';
      case 22:
        return 'Printer is performing media adjustment';
      case 23:
        return 'Printer is performing ribbon adjustment';
      case 24:
        return 'Printer is performing sensor adjustment';
      case 25:
        return 'Printer is performing print head adjustment';
      case 26:
        return 'Printer is performing platen adjustment';
      case 27:
        return 'Printer is performing media sensor adjustment';
      case 28:
        return 'Printer is performing ribbon sensor adjustment';
      case 29:
        return 'Printer is performing print head sensor adjustment';
      case 30:
        return 'Printer is performing platen sensor adjustment';
      case 100:
        return 'Out of paper/media';
      case 101:
        return 'Out of ribbon';
      case 102:
        return 'Print head is open';
      case 103:
        return 'Print head is cold';
      case 104:
        return 'Print head is too hot';
      case 105:
        return 'Print head is dirty';
      case 106:
        return 'Print head is damaged';
      case 107:
        return 'Print head is misaligned';
      case 108:
        return 'Print head is not installed';
      case 109:
        return 'Print head is incompatible';
      case 110:
        return 'Print head is worn out';
      case 111:
        return 'Print head is defective';
      case 112:
        return 'Print head is not responding';
      case 113:
        return 'Print head is not detected';
      case 114:
        return 'Print head is not calibrated';
      case 115:
        return 'Print head is not aligned';
      case 116:
        return 'Print head is not cleaned';
      case 117:
        return 'Print head is not adjusted';
      case 118:
        return 'Print head is not ready';
      case 119:
        return 'Print head is not available';
      case 120:
        return 'Print head is not supported';
      case 121:
        return 'Print head is not authorized';
      case 122:
        return 'Print head is not licensed';
      case 123:
        return 'Print head is not registered';
      case 124:
        return 'Print head is not validated';
      case 125:
        return 'Print head is not verified';
      case 126:
        return 'Print head is not authenticated';
      case 127:
        return 'Print head is not certified';
      case 128:
        return 'Print head is not approved';
      case 129:
        return 'Print head is not compliant';
      case 130:
        return 'Print head is not compatible';
      case 150:
        return 'Media sensor error';
      case 151:
        return 'Ribbon sensor error';
      case 152:
        return 'Print head sensor error';
      case 153:
        return 'Platen sensor error';
      case 154:
        return 'Temperature sensor error';
      case 155:
        return 'Pressure sensor error';
      case 156:
        return 'Position sensor error';
      case 157:
        return 'Speed sensor error';
      case 158:
        return 'Tension sensor error';
      case 159:
        return 'Hardware error detected';
      case 160:
        return 'Firmware error';
      case 161:
        return 'Software error';
      case 162:
        return 'Configuration error';
      case 163:
        return 'Communication error';
      case 164:
        return 'Network error';
      case 165:
        return 'Protocol error';
      case 166:
        return 'Format error';
      case 167:
        return 'Data error';
      case 168:
        return 'Memory error';
      case 169:
        return 'Buffer error';
      case 170:
        return 'Queue error';
      case 171:
        return 'Job error';
      case 172:
        return 'Print job error';
      case 173:
        return 'Format job error';
      case 174:
        return 'Download job error';
      case 175:
        return 'Upload job error';
      case 176:
        return 'Delete job error';
      case 177:
        return 'List job error';
      case 178:
        return 'Cancel job error';
      case 179:
        return 'Pause job error';
      case 180:
        return 'Resume job error';
      case 200:
        return 'Media type mismatch';
      case 201:
        return 'Ribbon type mismatch';
      case 202:
        return 'Print head type mismatch';
      case 203:
        return 'Platen type mismatch';
      case 204:
        return 'Sensor type mismatch';
      case 205:
        return 'Firmware version mismatch';
      case 206:
        return 'Software version mismatch';
      case 207:
        return 'Hardware version mismatch';
      case 208:
        return 'Configuration mismatch';
      case 209:
        return 'Protocol version mismatch';
      case 210:
        return 'Format version mismatch';
      case 211:
        return 'Data format mismatch';
      case 212:
        return 'Encoding mismatch';
      case 213:
        return 'Character set mismatch';
      case 214:
        return 'Language mismatch';
      case 215:
        return 'Country mismatch';
      case 216:
        return 'Time zone mismatch';
      case 217:
        return 'Date format mismatch';
      case 218:
        return 'Time format mismatch';
      case 219:
        return 'Number format mismatch';
      case 220:
        return 'Currency format mismatch';
      case 221:
        return 'Measurement unit mismatch';
      case 222:
        return 'Temperature unit mismatch';
      case 223:
        return 'Pressure unit mismatch';
      case 224:
        return 'Speed unit mismatch';
      case 225:
        return 'Distance unit mismatch';
      case 226:
        return 'Weight unit mismatch';
      case 227:
        return 'Volume unit mismatch';
      case 228:
        return 'Area unit mismatch';
      case 229:
        return 'Angle unit mismatch';
      case 230:
        return 'Frequency unit mismatch';
      case 231:
        return 'Power unit mismatch';
      case 232:
        return 'Energy unit mismatch';
      case 233:
        return 'Force unit mismatch';
      case 234:
        return 'Torque unit mismatch';
      case 235:
        return 'Momentum unit mismatch';
      case 236:
        return 'Impulse unit mismatch';
      case 237:
        return 'Work unit mismatch';
      case 238:
        return 'Heat unit mismatch';
      case 239:
        return 'Entropy unit mismatch';
      case 240:
        return 'Information unit mismatch';
      case 241:
        return 'Data rate unit mismatch';
      case 242:
        return 'Bandwidth unit mismatch';
      case 243:
        return 'Latency unit mismatch';
      case 244:
        return 'Jitter unit mismatch';
      case 245:
        return 'Packet loss unit mismatch';
      case 246:
        return 'Error rate unit mismatch';
      case 247:
        return 'Signal strength unit mismatch';
      case 248:
        return 'Signal quality unit mismatch';
      case 249:
        return 'Signal to noise ratio unit mismatch';
      case 250:
        return 'Carrier to noise ratio unit mismatch';
      case 251:
        return 'Bit error rate unit mismatch';
      case 252:
        return 'Frame error rate unit mismatch';
      case 253:
        return 'Symbol error rate unit mismatch';
      case 254:
        return 'Block error rate unit mismatch';
      case 255:
        return 'Word error rate unit mismatch';
      default:
        return 'Unknown error code: $errorCode';
    }
  }

  /// Parse error status from host status (legacy method for backward compatibility)
  static String? parseErrorFromStatus(String? status) {
    if (status == null || status.isEmpty) return null;

    // Try to parse as host status first
    final hostStatusInfo = parseHostStatus(status);
    if (!hostStatusInfo.isOk && hostStatusInfo.errorMessage != null) {
      return hostStatusInfo.errorMessage;
    }

    // Fallback to text-based parsing
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
