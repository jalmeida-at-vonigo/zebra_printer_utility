import 'dart:async';

/// Represents a native method call operation with tracking capabilities
class NativeOperation {
  /// Constructor
  NativeOperation({
    required this.id,
    required this.method,
    required this.arguments,
    required this.timeout,
  })  : completer = Completer<dynamic>(),
        startTime = DateTime.now();

  /// Unique identifier for this operation
  final String id;

  /// The method name to invoke on the native side
  final String method;

  /// Arguments to pass to the native method
  final Map<String, dynamic> arguments;

  /// Completer to signal operation completion
  final Completer<dynamic> completer;

  /// When the operation started
  final DateTime startTime;

  /// Maximum time to wait for operation completion
  final Duration timeout;

  /// Whether this operation has been cancelled
  bool isCancelled = false;

  /// Complete the operation successfully
  void complete(dynamic result) {
    if (!completer.isCompleted && !isCancelled) {
      completer.complete(result);
    }
  }

  /// Complete the operation with an error
  void completeError(dynamic error) {
    if (!completer.isCompleted && !isCancelled) {
      completer.completeError(error);
    }
  }

  /// Cancel the operation
  void cancel() {
    isCancelled = true;
    if (!completer.isCompleted) {
      completer.completeError('Operation cancelled');
    }
  }

  /// Get the elapsed time since operation started
  Duration get elapsed => DateTime.now().difference(startTime);

  /// Check if operation has exceeded timeout
  bool get isTimedOut => elapsed > timeout;
}
