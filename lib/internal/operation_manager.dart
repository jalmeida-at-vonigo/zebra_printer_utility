import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_operation.dart';
import '../models/result.dart';

/// Operation log entry for tracking and display
class OperationLogEntry {
  final String operationId;
  final String method;
  final String status; // 'started', 'completed', 'failed', 'timeout'
  final DateTime timestamp;
  final Map<String, dynamic>? arguments;
  final dynamic result;
  final String? error;
  final Duration? duration;
  final String? channelName;
  final StackTrace? stackTrace;

  OperationLogEntry({
    required this.operationId,
    required this.method,
    required this.status,
    required this.timestamp,
    this.arguments,
    this.result,
    this.error,
    this.duration,
    this.channelName,
    this.stackTrace,
  });

  Color get statusColor {
    switch (status) {
      case 'started':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'timeout':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String get statusIcon {
    switch (status) {
      case 'started':
        return '▶️';
      case 'completed':
        return '✅';
      case 'failed':
        return '❌';
      case 'timeout':
        return '⏰';
      default:
        return '❓';
    }
  }
}

/// Result-based OperationManager with logging capabilities
class OperationManager {
  /// The method channel for native communication
  final MethodChannel channel;

  /// Active operations being tracked
  final Map<String, NativeOperation> _activeOperations = {};

  /// Timer for checking operation timeouts
  Timer? _timeoutChecker;

  /// Callback for logging/debugging
  final void Function(String message)? onLog;

  /// Callback for operation log entries
  final void Function(OperationLogEntry entry)? onOperationLog;

  /// Operation log entries
  final List<OperationLogEntry> _operationLog = [];

  OperationManager({
    required this.channel,
    this.onLog,
    this.onOperationLog,
  }) {
    // Start timeout checker
    _timeoutChecker = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkTimeouts();
    });
  }

  /// Get all operation log entries
  List<OperationLogEntry> get operationLog => List.unmodifiable(_operationLog);

  /// Clear operation log
  void clearLog() {
    _operationLog.clear();
    // Notify listeners that log was cleared
    onOperationLog?.call(OperationLogEntry(
      operationId: 'clear',
      method: 'clear',
      status: 'cleared',
      timestamp: DateTime.now(),
      channelName: channel.name,
    ));
  }

  /// Execute a native method call with operation tracking
  Future<Result<T>> execute<T>({
    required String method,
    Map<String, dynamic>? arguments,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final operationId = _generateOperationId();
    final startTime = DateTime.now();
    final operation = NativeOperation(
      id: operationId,
      method: method,
      arguments: arguments ?? {},
      timeout: timeout,
    );

    _activeOperations[operationId] = operation;
    
    // Log operation start
    final startEntry = OperationLogEntry(
      operationId: operationId,
      method: method,
      status: 'started',
      timestamp: startTime,
      arguments: arguments,
      channelName: channel.name,
    );
    _addLogEntry(startEntry);
    
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
          
          final duration = DateTime.now().difference(startTime);
          final timeoutEntry = OperationLogEntry(
            operationId: operationId,
            method: method,
            status: 'timeout',
            timestamp: DateTime.now(),
            arguments: arguments,
            error: 'Operation timed out after ${timeout.inSeconds}s',
            duration: duration,
            channelName: channel.name,
            stackTrace: StackTrace.current,
          );
          _addLogEntry(timeoutEntry);
          
          throw TimeoutException(
            'Operation "$method" (ID: $operationId) timed out after ${timeout.inSeconds}s on channel "${channel.name}". '
            'Arguments: ${arguments.toString()}',
            timeout,
          );
        },
      );

      final duration = DateTime.now().difference(startTime);
      final successEntry = OperationLogEntry(
        operationId: operationId,
        method: method,
        status: 'completed',
        timestamp: DateTime.now(),
        arguments: arguments,
        result: result,
        duration: duration,
        channelName: channel.name,
      );
      _addLogEntry(successEntry);
      
      onLog?.call('Operation $operationId completed successfully');
      return Result<T>.success(result as T);
    } on TimeoutException catch (e) {
      final duration = DateTime.now().difference(startTime);
      final timeoutEntry = OperationLogEntry(
        operationId: operationId,
        method: method,
        status: 'timeout',
        timestamp: DateTime.now(),
        arguments: arguments,
        error: e.message,
        duration: duration,
        channelName: channel.name,
        stackTrace: StackTrace.current,
      );
      _addLogEntry(timeoutEntry);
      onLog?.call('Operation $operationId timed out: ${e.message}');
      return Result<T>.error(
        'Operation "$method" (ID: $operationId) timed out after ${timeout.inSeconds}s on channel "${channel.name}". '
        'Arguments: ${arguments.toString()}',
        code: ErrorCodes.operationTimeout,
        dartStackTrace: StackTrace.current,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      final errorEntry = OperationLogEntry(
        operationId: operationId,
        method: method,
        status: 'failed',
        timestamp: DateTime.now(),
        arguments: arguments,
        error: e.toString(),
        duration: duration,
        channelName: channel.name,
        stackTrace: StackTrace.current,
      );
      _addLogEntry(errorEntry);
      
      onLog?.call('Operation $operationId failed: $e');
      return Result<T>.error(
        'Operation "$method" (ID: $operationId) failed on channel "${channel.name}". '
        'Arguments: ${arguments.toString()}. '
        'Error: ${e.toString()}',
        code: ErrorCodes.operationError,
        dartStackTrace: StackTrace.current,
      );
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

  /// Dispose of the manager and cancel all pending operations
  void dispose() {
    _timeoutChecker?.cancel();
    for (final operation in _activeOperations.values) {
      if (!operation.completer.isCompleted) {
        operation.completer.completeError('Operation cancelled');
      }
    }
    _activeOperations.clear();
  }

  /// Generate a unique operation ID
  String _generateOperationId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_activeOperations.length}';
  }

  /// Add log entry and notify listeners
  void _addLogEntry(OperationLogEntry entry) {
    _operationLog.add(entry);
    onOperationLog?.call(entry);
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
      final operation = _activeOperations[operationId];
      onLog?.call('Operation $operationId has timed out, cancelling');
      
      final errorMessage =
          'Operation "${operation?.method}" (ID: $operationId) timed out after ${operation?.timeout.inSeconds}s on channel "${channel.name}". '
          'Arguments: ${operation?.arguments.toString() ?? "{}"}';
      failOperation(operationId, errorMessage);
      _activeOperations.remove(operationId);
    }
  }
}
