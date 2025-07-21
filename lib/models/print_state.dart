import 'print_enums.dart';
import 'print_event.dart';

/// Immutable state class for print operations
/// 
/// This class represents the complete state of a print operation at any point in time.
/// It is immutable to ensure state changes are explicit and traceable.
class PrintState {
  const PrintState({
    required this.currentStep,
    required this.isRunning,
    required this.currentMessage,
    required this.currentError,
    required this.currentIssues,
    required this.canAutoResume,
    required this.autoResumeAction,
    required this.isWaitingForUserFix,
    required this.currentAttempt,
    required this.maxAttempts,
    required this.progress,
    required this.isCompleted,
    required this.isCancelled,
    required this.realTimeStatus,
    required this.startTime,
    required this.elapsedTime,
  });

  /// Factory constructor for initial state
  factory PrintState.initial() {
    return const PrintState(
      currentStep: PrintStep.initializing,
      isRunning: false,
      currentMessage: null,
      currentError: null,
      currentIssues: [],
      canAutoResume: false,
      autoResumeAction: null,
      isWaitingForUserFix: false,
      currentAttempt: 1,
      maxAttempts: 3,
      progress: 0.0,
      isCompleted: false,
      isCancelled: false,
      realTimeStatus: null,
      startTime: null,
      elapsedTime: Duration.zero,
    );
  }

  // Core state fields
  final PrintStep currentStep;
  final bool isRunning;
  final String? currentMessage;
  final PrintErrorInfo? currentError;
  final List<String> currentIssues;
  final bool canAutoResume;
  final String? autoResumeAction;
  final bool isWaitingForUserFix;
  
  // Progress tracking
  final int currentAttempt;
  final int maxAttempts;
  final double progress;
  
  // Status flags
  final bool isCompleted;
  final bool isCancelled;
  
  // Real-time status from printer
  final Map<String, dynamic>? realTimeStatus;
  
  // Timing
  final DateTime? startTime;
  final Duration elapsedTime;

  /// Create a copy with updated fields
  PrintState copyWith({
    PrintStep? currentStep,
    bool? isRunning,
    String? currentMessage,
    PrintErrorInfo? currentError,
    List<String>? currentIssues,
    bool? canAutoResume,
    String? autoResumeAction,
    bool? isWaitingForUserFix,
    int? currentAttempt,
    int? maxAttempts,
    double? progress,
    bool? isCompleted,
    bool? isCancelled,
    Map<String, dynamic>? realTimeStatus,
    DateTime? startTime,
    Duration? elapsedTime,
  }) {
    return PrintState(
      currentStep: currentStep ?? this.currentStep,
      isRunning: isRunning ?? this.isRunning,
      currentMessage: currentMessage ?? this.currentMessage,
      currentError: currentError ?? this.currentError,
      currentIssues: currentIssues ?? this.currentIssues,
      canAutoResume: canAutoResume ?? this.canAutoResume,
      autoResumeAction: autoResumeAction ?? this.autoResumeAction,
      isWaitingForUserFix: isWaitingForUserFix ?? this.isWaitingForUserFix,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      isCancelled: isCancelled ?? this.isCancelled,
      realTimeStatus: realTimeStatus ?? this.realTimeStatus,
      startTime: startTime ?? this.startTime,
      elapsedTime: elapsedTime ?? this.elapsedTime,
    );
  }

  /// Helper to clear nullable fields
  PrintState clearError() => copyWith(currentError: null);
  PrintState clearMessage() => copyWith(currentMessage: null);
  PrintState clearAutoResumeAction() => copyWith(autoResumeAction: null);
  PrintState clearRealTimeStatus() => copyWith(realTimeStatus: null);

  /// Computed properties
  bool get isPrinting => isRunning && !isCompleted && !isCancelled;
  bool get hasFailed => currentError != null && !isRunning;
  bool get isRetrying => currentAttempt > 1 && isRunning;
  int get retryCount => currentAttempt > 1 ? currentAttempt - 1 : 0;
  bool get hasIssues => currentIssues.isNotEmpty;

  /// Get current status for UI
  PrintStatus get currentStatus {
    if (isCancelled) return PrintStatus.cancelled;
    if (isCompleted) return PrintStatus.done;
    if (hasFailed) return PrintStatus.failed;
    
    switch (currentStep) {
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

  /// Get progress based on current step
  double getProgress() {
    switch (currentStep) {
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
        return progress; // Keep last progress
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintState &&
          runtimeType == other.runtimeType &&
          currentStep == other.currentStep &&
          isRunning == other.isRunning &&
          currentMessage == other.currentMessage &&
          currentError == other.currentError &&
          listEquals(currentIssues, other.currentIssues) &&
          canAutoResume == other.canAutoResume &&
          autoResumeAction == other.autoResumeAction &&
          isWaitingForUserFix == other.isWaitingForUserFix &&
          currentAttempt == other.currentAttempt &&
          maxAttempts == other.maxAttempts &&
          progress == other.progress &&
          isCompleted == other.isCompleted &&
          isCancelled == other.isCancelled &&
          startTime == other.startTime &&
          elapsedTime == other.elapsedTime;

  @override
  int get hashCode =>
      currentStep.hashCode ^
      isRunning.hashCode ^
      currentMessage.hashCode ^
      currentError.hashCode ^
      currentIssues.hashCode ^
      canAutoResume.hashCode ^
      autoResumeAction.hashCode ^
      isWaitingForUserFix.hashCode ^
      currentAttempt.hashCode ^
      maxAttempts.hashCode ^
      progress.hashCode ^
      isCompleted.hashCode ^
      isCancelled.hashCode ^
      startTime.hashCode ^
      elapsedTime.hashCode;

  @override
  String toString() {
    return 'PrintState('
        'step: $currentStep, '
        'running: $isRunning, '
        'message: $currentMessage, '
        'issues: ${currentIssues.length}, '
        'attempt: $currentAttempt/$maxAttempts, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%'
        ')';
  }
}

/// Helper function for list equality
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

 