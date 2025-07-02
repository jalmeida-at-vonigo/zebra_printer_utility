/// Represents the readiness state of a printer with detailed status information
class PrinterReadiness {
  /// Overall readiness state
  bool isReady = false;

  /// Connection status - null if not checked
  bool? isConnected;

  /// Media presence - null if not checked
  bool? hasMedia;

  /// Print head status - null if not checked
  bool? headClosed;

  /// Pause status - null if not checked
  bool? isPaused;

  /// Raw status values from printer
  String? mediaStatus;
  String? headStatus;
  String? pauseStatus;
  String? hostStatus;

  /// Errors and warnings collected during checks
  List<String> errors = [];
  List<String> warnings = [];

  /// Timestamp of the readiness check
  DateTime timestamp = DateTime.now();

  /// Whether full status check was performed
  bool fullCheckPerformed = false;

  String get summary {
    if (isReady) return 'Printer is ready';
    if (errors.isNotEmpty) return errors.join(', ');
    if (isConnected == false) return 'Not connected';
    if (hasMedia == false) return 'No media';
    if (headClosed == false) return 'Head open';
    if (isPaused == true) return 'Printer paused';
    return 'Not ready';
  }

  Map<String, dynamic> toMap() {
    return {
      'isReady': isReady,
      'isConnected': isConnected,
      'hasMedia': hasMedia,
      'headClosed': headClosed,
      'isPaused': isPaused,
      'mediaStatus': mediaStatus,
      'headStatus': headStatus,
      'pauseStatus': pauseStatus,
      'hostStatus': hostStatus,
      'errors': errors,
      'warnings': warnings,
      'timestamp': timestamp.toIso8601String(),
      'fullCheckPerformed': fullCheckPerformed,
      'summary': summary,
    };
  }
}
