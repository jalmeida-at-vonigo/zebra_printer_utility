import 'printer_readiness.dart';

/// Result of a printer readiness operation
class ReadinessResult {
  /// Constructor
  const ReadinessResult({
    required this.isReady,
    required this.readiness,
    required this.appliedFixes,
    required this.failedFixes,
    required this.fixErrors,
    required this.totalTime,
    required this.timestamp,
  });

  /// Factory constructor with explicit ready state
  factory ReadinessResult.withReadyState(
    bool isReady,
    PrinterReadiness readiness,
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    Duration totalTime,
  ) =>
      ReadinessResult(
        isReady: isReady,
        readiness: readiness,
        appliedFixes: appliedFixes,
        failedFixes: failedFixes,
        fixErrors: fixErrors,
        totalTime: totalTime,
        timestamp: DateTime.now(),
      );

  /// Factory constructor from readiness status with cached ready state
  factory ReadinessResult.fromReadiness(
    PrinterReadiness readiness,
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    Duration totalTime,
  ) =>
      ReadinessResult(
        isReady:
            false, // Will be updated by the caller with actual cached value
        readiness: readiness,
        appliedFixes: appliedFixes,
        failedFixes: failedFixes,
        fixErrors: fixErrors,
        totalTime: totalTime,
        timestamp: DateTime.now(),
      );

  /// Whether the printer is ready for printing (cached value)
  final bool isReady;
  
  /// Detailed readiness status
  final PrinterReadiness readiness;
  
  /// List of successfully applied fixes
  final List<String> appliedFixes;
  
  /// List of failed fixes
  final List<String> failedFixes;
  
  /// Map of fix errors with their descriptions
  final Map<String, String> fixErrors;
  
  /// Total time taken for the operation
  final Duration totalTime;
  
  /// Timestamp when the operation completed
  final DateTime timestamp;
  
  /// Whether any fixes were applied
  bool get hasFixes => appliedFixes.isNotEmpty;
  
  /// Whether any fixes failed
  bool get hasFailedFixes => failedFixes.isNotEmpty;
  
  /// Summary of the operation
  String get summary =>
      'Ready: $isReady, Fixes: ${appliedFixes.length}, Failed: ${failedFixes.length}';
  
  /// Creates a copy with modified fields
  ReadinessResult copyWith({
    bool? isReady,
    PrinterReadiness? readiness,
    List<String>? appliedFixes,
    List<String>? failedFixes,
    Map<String, String>? fixErrors,
    Duration? totalTime,
    DateTime? timestamp,
  }) => ReadinessResult(
    isReady: isReady ?? this.isReady,
    readiness: readiness ?? this.readiness,
    appliedFixes: appliedFixes ?? this.appliedFixes,
    failedFixes: failedFixes ?? this.failedFixes,
    fixErrors: fixErrors ?? this.fixErrors,
    totalTime: totalTime ?? this.totalTime,
    timestamp: timestamp ?? this.timestamp,
  );
  
  @override
  String toString() {
    return 'ReadinessResult('
        'isReady: $isReady, '
        'appliedFixes: $appliedFixes, '
        'failedFixes: $failedFixes, '
        'totalTime: ${totalTime.inMilliseconds}ms'
        ')';
  }
} 