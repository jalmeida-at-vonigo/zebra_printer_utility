/// Media types supported by Zebra printers
enum EnumMediaType { label, blackMark, journal }

/// Printer commands
enum Command { calibrate, mediaType, darkness }

/// Print format enumeration
enum PrintFormat {
  zpl,
  cpcl,
}

/// Simple print status for UI workflow
enum PrintStatus {
  connecting, // Connecting to printer
  configuring, // Configuring printer (language mode, status checks)
  printing, // Actually printing data
  done, // Print completed successfully
  failed, // Print failed
  cancelled, // Print was cancelled
}

/// Extension to provide UI-friendly names
extension PrintStatusExtension on PrintStatus {
  String get displayName {
    switch (this) {
      case PrintStatus.connecting:
        return 'Connecting';
      case PrintStatus.configuring:
        return 'Configuring Printer';
      case PrintStatus.printing:
        return 'Printing';
      case PrintStatus.done:
        return 'Done';
      case PrintStatus.failed:
        return 'Failed';
      case PrintStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isCompleted {
    switch (this) {
      case PrintStatus.done:
      case PrintStatus.failed:
      case PrintStatus.cancelled:
        return true;
      default:
        return false;
    }
  }

  bool get isInProgress {
    switch (this) {
      case PrintStatus.connecting:
      case PrintStatus.configuring:
      case PrintStatus.printing:
        return true;
      default:
        return false;
    }
  }
}
