/// Represents the readiness state of a printer with detailed status information
class PrinterReadiness {
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

  /// Computed property for overall readiness state
  bool get isReady =>
      (isConnected ?? false) &&
      (headClosed ?? true) &&
      !(isPaused ?? false) &&
      errors.isEmpty;

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

/// Represents printer readiness with correction tracking metadata
class CorrectedReadiness extends PrinterReadiness {
  /// List of correction operations that were attempted
  final List<String> appliedCorrections;

  /// Results of correction attempts (operation -> success)
  final Map<String, bool> correctionResults;

  /// Timestamp when corrections were applied
  final DateTime correctionTimestamp;

  /// Error messages for failed corrections
  final Map<String, String> correctionErrors;

  CorrectedReadiness({
    required bool? isConnected,
    required bool? isPaused,
    required bool? headClosed,
    required bool? hasMedia,
    required List<String> errors,
    required List<String> warnings,
    required String? hostStatus,
    required String? pauseStatus,
    required String? mediaStatus,
    required String? headStatus,
    required bool fullCheckPerformed,
    required this.appliedCorrections,
    required this.correctionResults,
    required this.correctionErrors,
    DateTime? correctionTimestamp,
  }) : correctionTimestamp = correctionTimestamp ?? DateTime.now() {
    this.isConnected = isConnected;
    this.isPaused = isPaused;
    this.headClosed = headClosed;
    this.hasMedia = hasMedia;
    this.errors = errors;
    this.warnings = warnings;
    this.hostStatus = hostStatus;
    this.pauseStatus = pauseStatus;
    this.mediaStatus = mediaStatus;
    this.headStatus = headStatus;
    this.fullCheckPerformed = fullCheckPerformed;
  }

  /// Correction-specific computed properties
  bool get isPausedFixed => correctionResults['unpause'] ?? false;
  bool get isErrorsFixed => correctionResults['clearErrors'] ?? false;
  bool get isMediaFixed => correctionResults['calibrate'] ?? false;
  bool get isLanguageFixed => correctionResults['switchLanguage'] ?? false;
  bool get isBufferCleared => correctionResults['clearBuffer'] ?? false;

  /// Whether any corrections were attempted
  bool get hasCorrections => appliedCorrections.isNotEmpty;

  /// Whether all attempted corrections were successful
  bool get allCorrectionsSuccessful =>
      correctionResults.values.every((success) => success);

  /// Whether any corrections failed
  bool get hasFailedCorrections =>
      correctionResults.values.any((success) => !success);

  /// Summary of correction results
  String get correctionSummary {
    if (appliedCorrections.isEmpty) return 'No corrections applied';

    final successful = correctionResults.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final failed = correctionResults.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    final parts = <String>[];
    if (successful.isNotEmpty) parts.add('Fixed: ${successful.join(', ')}');
    if (failed.isNotEmpty) parts.add('Failed: ${failed.join(', ')}');
    return parts.join('; ');
  }

  /// Detailed correction information for logging
  String get detailedCorrectionInfo {
    if (appliedCorrections.isEmpty) return 'No corrections attempted';

    final buffer = StringBuffer();
    buffer.writeln(
        'Corrections applied at ${correctionTimestamp.toIso8601String()}:');

    for (final correction in appliedCorrections) {
      final success = correctionResults[correction] ?? false;
      final error = correctionErrors[correction];

      buffer.write('  • $correction: ${success ? 'SUCCESS' : 'FAILED'}');
      if (error != null) buffer.write(' ($error)');
      buffer.writeln();
    }

    return buffer.toString();
  }

  @override
  Map<String, dynamic> toMap() {
    final baseMap = super.toMap();
    baseMap.addAll({
      'appliedCorrections': appliedCorrections,
      'correctionResults': correctionResults,
      'correctionErrors': correctionErrors,
      'correctionTimestamp': correctionTimestamp.toIso8601String(),
      'hasCorrections': hasCorrections,
      'allCorrectionsSuccessful': allCorrectionsSuccessful,
      'hasFailedCorrections': hasFailedCorrections,
      'correctionSummary': correctionSummary,
    });
    return baseMap;
  }
}
