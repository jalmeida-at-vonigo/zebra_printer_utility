import 'printer_readiness.dart';

/// Enum for readiness operation types
enum ReadinessOperationType {
  connection,
  media,
  head,
  pause,
  errors,
  language,
  buffer,
}

/// Enum for operation kind
enum ReadinessOperationKind {
  check,
  fix,
}

/// Enum for operation result
enum ReadinessOperationResult {
  successful,
  error,
}

/// Event that occurs during readiness operations
class ReadinessOperationEvent {
  ReadinessOperationEvent({
    required this.readiness,
    required this.message,
    required this.operationType,
    required this.operationKind,
    required this.result,
    this.errorDetails,
  });

  final PrinterReadiness readiness;
  final String message;
  final ReadinessOperationType operationType;
  final ReadinessOperationKind operationKind;
  final ReadinessOperationResult result;
  final String? errorDetails;

  @override
  String toString() =>
      'ReadinessOperationEvent($operationType.$operationKind: $result - $message)';
} 