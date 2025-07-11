/// Event types for smart print operations
enum PrintEventType {
  discovery,
  connected,
  disconnected,
  stepChanged,
  progressUpdate,
  errorOccurred,
  retryAttempt,
  statusUpdate,
  completed,
  cancelled,
}

/// Print steps in the workflow
enum PrintStep {
  initializing,
  validating,
  connecting,
  connected,
  checkingStatus,
  sending,
  waitingForCompletion,
  completed,
  failed,
  cancelled,
}

/// Error recoverability levels
enum ErrorRecoverability {
  recoverable,
  nonRecoverable,
  possiblyRecoverable,
  unknown,
}

/// Print step information
class PrintStepInfo {
  const PrintStepInfo({
    required this.step,
    required this.message,
    required this.attempt,
    required this.maxAttempts,
    required this.elapsed,
    this.metadata = const {},
  });

  final PrintStep step;
  final String message;
  final int attempt;
  final int maxAttempts;
  final Duration elapsed;
  final Map<String, dynamic> metadata;

  bool get isRetry => attempt > 1;
  int get retryCount => attempt > 1 ? attempt - 1 : 0;
  bool get isFinalAttempt => attempt >= maxAttempts;
  double get progress {
    switch (step) {
      case PrintStep.initializing:
        return 0.0;
      case PrintStep.validating:
        return 0.1;
      case PrintStep.connecting:
        return 0.2;
      case PrintStep.connected:
        return 0.3;
      case PrintStep.checkingStatus:
        return 0.4;
      case PrintStep.sending:
        return 0.6;
      case PrintStep.waitingForCompletion:
        return 0.8;
      case PrintStep.completed:
        return 1.0;
      case PrintStep.failed:
      case PrintStep.cancelled:
        return 0.0;
    }
  }
  
  @override
  String toString() => 'PrintStepInfo($step: $message, attempt $attempt/$maxAttempts)';
}

/// Print error information
class PrintErrorInfo {
  const PrintErrorInfo({
    required this.message,
    required this.recoverability,
    this.errorCode,
    this.nativeError,
    this.stackTrace,
    this.metadata = const {},
    this.recoveryHint,
  });

  final String message;
  final ErrorRecoverability recoverability;
  final String? errorCode;
  final dynamic nativeError;
  final StackTrace? stackTrace;
  final Map<String, dynamic> metadata;
  final String? recoveryHint;
  
  @override
  String toString() => 'PrintErrorInfo($recoverability: $message)';
}

/// Print progress information
class PrintProgressInfo {
  const PrintProgressInfo({
    required this.progress,
    required this.currentOperation,
    required this.elapsed,
    required this.estimatedRemaining,
    this.metadata = const {},
  });

  final double progress;
  final String currentOperation;
  final Duration elapsed;
  final Duration estimatedRemaining;
  final Map<String, dynamic> metadata;
  
  @override
  String toString() => 'PrintProgressInfo($progress: $currentOperation)';
}

/// Print event
class PrintEvent {
  const PrintEvent({
    required this.type,
    required this.timestamp,
    this.stepInfo,
    this.errorInfo,
    this.progressInfo,
    this.metadata = const {},
  });

  final PrintEventType type;
  final DateTime timestamp;
  final PrintStepInfo? stepInfo;
  final PrintErrorInfo? errorInfo;
  final PrintProgressInfo? progressInfo;
  final Map<String, dynamic> metadata;
  
  @override
  String toString() => 'PrintEvent($type at $timestamp)';
} 