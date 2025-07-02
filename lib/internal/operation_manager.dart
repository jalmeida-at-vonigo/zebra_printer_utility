import 'dart:async';
import 'package:flutter/services.dart';
import 'native_operation.dart';

/// Manages native method call operations with tracking and timeout handling
class OperationManager {
  /// The method channel for native communication
  final MethodChannel channel;

  /// Active operations being tracked
  final Map<String, NativeOperation> _activeOperations = {};

  /// Timer for checking operation timeouts
  Timer? _timeoutChecker;

  /// Callback for logging/debugging
  final void Function(String message)? onLog;

  OperationManager({
    required this.channel,
    this.onLog,
  }) {
    // Start timeout checker
    _timeoutChecker = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkTimeouts();
    });
  }

  /// Execute a native method call with operation tracking
  Future<T> execute<T>({
    required String method,
    Map<String, dynamic>? arguments,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final operationId = _generateOperationId();
    final operation = NativeOperation(
      id: operationId,
      method: method,
      arguments: arguments ?? {},
      timeout: timeout,
    );

    _activeOperations[operationId] = operation;
    onLog?.call('Starting operation $operationId: $method');

    try {
      // Add operation ID to arguments
      final args = Map<String, dynamic>.from(arguments ?? {});
      args['operationId'] = operationId;

      // Invoke the native method
      await channel.invokeMethod(method, args);

      // Wait for completion with timeout
      final result = await operation.completer.future.timeout(
        timeout,
        onTimeout: () {
          _activeOperations.remove(operationId);
          onLog?.call('Operation $operationId timed out');
          throw TimeoutException(
              'Operation $method timed out after ${timeout.inSeconds}s');
        },
      );

      onLog?.call('Operation $operationId completed successfully');
      return result as T;
    } catch (e) {
      onLog?.call('Operation $operationId failed: $e');
      rethrow;
    } finally {
      _activeOperations.remove(operationId);
    }
  }

  /// Complete an operation successfully
  void completeOperation(String operationId, dynamic result) {
    final operation = _activeOperations[operationId];
    if (operation != null) {
      onLog?.call('Completing operation $operationId with result');
      operation.complete(result);
    } else {
      onLog?.call(
          'Warning: Attempted to complete unknown operation $operationId');
    }
  }

  /// Fail an operation with an error
  void failOperation(String operationId, String error) {
    final operation = _activeOperations[operationId];
    if (operation != null) {
      onLog?.call('Failing operation $operationId with error: $error');
      operation.completeError(error);
    } else {
      onLog?.call('Warning: Attempted to fail unknown operation $operationId');
    }
  }

  /// Cancel all active operations
  void cancelAll() {
    onLog?.call('Cancelling all ${_activeOperations.length} active operations');
    for (final operation in _activeOperations.values) {
      operation.cancel();
    }
    _activeOperations.clear();
  }

  /// Get the number of active operations
  int get activeOperationCount => _activeOperations.length;

  /// Get active operation IDs for debugging
  List<String> get activeOperationIds => _activeOperations.keys.toList();

  /// Dispose the manager and clean up resources
  void dispose() {
    _timeoutChecker?.cancel();
    cancelAll();
  }

  /// Generate a unique operation ID
  String _generateOperationId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_activeOperations.length}';
  }

  /// Check for timed out operations
  void _checkTimeouts() {
    final timedOutOperations = <String>[];

    for (final entry in _activeOperations.entries) {
      if (entry.value.isTimedOut && !entry.value.completer.isCompleted) {
        timedOutOperations.add(entry.key);
      }
    }

    for (final operationId in timedOutOperations) {
      onLog?.call('Operation $operationId has timed out, cancelling');
      failOperation(operationId, 'Operation timed out');
      _activeOperations.remove(operationId);
    }
  }
}
