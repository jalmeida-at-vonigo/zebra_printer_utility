import 'print_enums.dart';

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

/// Extension to provide display names for PrintStep
extension PrintStepDisplayExtension on PrintStep {
  String get displayName {
    switch (this) {
      case PrintStep.initializing:
        return 'Initializing';
      case PrintStep.validating:
        return 'Validating';
      case PrintStep.connecting:
        return 'Connecting';
      case PrintStep.connected:
        return 'Connected';
      case PrintStep.checkingStatus:
        return 'Checking Status';
      case PrintStep.sending:
        return 'Sending Data';
      case PrintStep.waitingForCompletion:
        return 'Waiting for Completion';
      case PrintStep.completed:
        return 'Completed';
      case PrintStep.failed:
        return 'Failed';
      case PrintStep.cancelled:
        return 'Cancelled';
    }
  }
}

/// Extension to provide progress values for PrintStep
extension PrintStepProgressExtension on PrintStep {
  double get progress {
    switch (this) {
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
}

/// Extension to provide UI grouping for PrintStep
extension PrintStepGroupingExtension on PrintStep {
  /// Get the UI group this step belongs to
  String get uiGroup {
    switch (this) {
      case PrintStep.initializing:
      case PrintStep.validating:
      case PrintStep.connecting:
        return 'Connecting';
      case PrintStep.connected:
      case PrintStep.checkingStatus:
        return 'Configuring';
      case PrintStep.sending:
      case PrintStep.waitingForCompletion:
        return 'Printing';
      case PrintStep.completed:
        return 'Done';
      case PrintStep.failed:
      case PrintStep.cancelled:
        return 'Failed';
    }
  }

  /// Check if this step is in the connecting phase
  bool get isConnectingPhase {
    return this == PrintStep.initializing ||
        this == PrintStep.validating ||
        this == PrintStep.connecting;
  }

  /// Check if this step is in the configuring phase
  bool get isConfiguringPhase {
    return this == PrintStep.connected || this == PrintStep.checkingStatus;
  }

  /// Check if this step is in the printing phase
  bool get isPrintingPhase {
    return this == PrintStep.sending || this == PrintStep.waitingForCompletion;
  }
}

/// Extension to provide status mapping for PrintStep
extension PrintStepStatusMappingExtension on PrintStep {
  /// Map this step to the corresponding PrintStatus
  PrintStatus get status {
    switch (this) {
      case PrintStep.initializing:
      case PrintStep.validating:
      case PrintStep.connecting:
        return PrintStatus.connecting;
      case PrintStep.connected:
      case PrintStep.checkingStatus:
        return PrintStatus.configuring;
      case PrintStep.sending:
      case PrintStep.waitingForCompletion:
        return PrintStatus.printing;
      case PrintStep.completed:
        return PrintStatus.done;
      case PrintStep.failed:
        return PrintStatus.failed;
      case PrintStep.cancelled:
        return PrintStatus.cancelled;
    }
  }
}

/// Extension to provide error recovery information for ErrorRecoverability
extension ErrorRecoverabilityExtension on ErrorRecoverability {
  /// Get a user-friendly title for this error type
  String get userTitle {
    switch (this) {
      case ErrorRecoverability.recoverable:
        return 'Connection Issue';
      case ErrorRecoverability.nonRecoverable:
        return 'Hardware Issue';
      case ErrorRecoverability.possiblyRecoverable:
        return 'May Recover';
      case ErrorRecoverability.unknown:
        return 'Unknown Error';
    }
  }

  /// Check if this error can be automatically recovered
  bool get canAutoRecover {
    switch (this) {
      case ErrorRecoverability.recoverable:
      case ErrorRecoverability.possiblyRecoverable:
        return true;
      case ErrorRecoverability.nonRecoverable:
      case ErrorRecoverability.unknown:
        return false;
    }
  }

  /// Get a recovery hint for the user
  String get recoveryHint {
    switch (this) {
      case ErrorRecoverability.recoverable:
        return 'Retrying automatically...';
      case ErrorRecoverability.nonRecoverable:
        return 'Please check printer hardware and try again';
      case ErrorRecoverability.possiblyRecoverable:
        return 'The operation may recover automatically';
      case ErrorRecoverability.unknown:
        return 'Please try again or check printer status';
    }
  }
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
  double get progress => step.progress;
  
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
    this.printState,
    this.metadata = const {},
  });

  final PrintEventType type;
  final DateTime timestamp;
  final PrintStepInfo? stepInfo;
  final PrintErrorInfo? errorInfo;
  final PrintProgressInfo? progressInfo;
  final dynamic printState; // Using dynamic to avoid circular dependency
  final Map<String, dynamic> metadata;
  
  @override
  String toString() => 'PrintEvent($type at $timestamp)';
} 