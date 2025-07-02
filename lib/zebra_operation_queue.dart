import 'dart:async';
import 'dart:collection';

/// Types of operations that can be queued
enum OperationType {
  connect,
  disconnect,
  print,
  setSetting,
  getSetting,
  checkStatus,
  setPrinterMode,
}

/// Represents a single operation to be executed
class ZebraOperation {
  final String id;
  final OperationType type;
  final Map<String, dynamic> parameters;
  final Completer<dynamic> completer;
  final Duration timeout;
  DateTime? startTime;

  ZebraOperation({
    required this.id,
    required this.type,
    required this.parameters,
    Duration? timeout,
  })  : completer = Completer<dynamic>(),
        timeout = timeout ?? const Duration(seconds: 30);

  bool get isTimedOut {
    if (startTime == null) return false;
    return DateTime.now().difference(startTime!) > timeout;
  }
}

/// Manages sequential execution of printer operations
class ZebraOperationQueue {
  final Queue<ZebraOperation> _queue = Queue();
  ZebraOperation? _currentOperation;
  bool _isProcessing = false;
  Timer? _timeoutTimer;

  /// Callbacks for operation execution
  final Future<dynamic> Function(ZebraOperation operation) onExecuteOperation;
  final void Function(String error)? onError;

  ZebraOperationQueue({
    required this.onExecuteOperation,
    this.onError,
  });

  /// Adds an operation to the queue and returns a future that completes when done
  Future<T> enqueue<T>(OperationType type, Map<String, dynamic> parameters,
      {Duration? timeout}) async {
    final operation = ZebraOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      parameters: parameters,
      timeout: timeout,
    );

    _queue.add(operation);
    _processQueue();

    return operation.completer.future as Future<T>;
  }

  /// Process the queue
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    _currentOperation = _queue.removeFirst();
    _currentOperation!.startTime = DateTime.now();

    // Set up timeout
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_currentOperation!.timeout, () {
      _handleTimeout();
    });

    try {
      // Execute the operation and wait for completion
      final result = await onExecuteOperation(_currentOperation!);

      // Operation completed successfully
      if (!_currentOperation!.completer.isCompleted) {
        _completeCurrentOperation(result);
      }
    } catch (error) {
      // Operation failed
      if (!_currentOperation!.completer.isCompleted) {
        _failCurrentOperation(error.toString());
      }
    }
  }

  /// Complete the current operation successfully
  void completeOperation(String operationId, dynamic result) {
    if (_currentOperation?.id == operationId) {
      _completeCurrentOperation(result);
    }
  }

  /// Fail the current operation
  void failOperation(String operationId, String error) {
    if (_currentOperation?.id == operationId) {
      _failCurrentOperation(error);
    }
  }

  void _completeCurrentOperation(dynamic result) {
    _timeoutTimer?.cancel();
    _currentOperation?.completer.complete(result);
    _currentOperation = null;
    _isProcessing = false;
    _processQueue();
  }

  void _failCurrentOperation(String error) {
    _timeoutTimer?.cancel();
    _currentOperation?.completer.completeError(error);
    onError?.call(error);
    _currentOperation = null;
    _isProcessing = false;
    _processQueue();
  }

  void _handleTimeout() {
    if (_currentOperation != null &&
        !_currentOperation!.completer.isCompleted) {
      _failCurrentOperation(
          'Operation ${_currentOperation!.type} timed out after ${_currentOperation!.timeout.inSeconds} seconds');
    }
  }

  /// Cancel all pending operations
  void cancelAll() {
    _timeoutTimer?.cancel();

    // Fail current operation
    if (_currentOperation != null &&
        !_currentOperation!.completer.isCompleted) {
      _currentOperation!.completer.completeError('Operation cancelled');
    }

    // Fail all queued operations
    while (_queue.isNotEmpty) {
      final op = _queue.removeFirst();
      op.completer.completeError('Operation cancelled');
    }

    _currentOperation = null;
    _isProcessing = false;
  }

  /// Get the number of pending operations
  int get pendingCount => _queue.length + (_currentOperation != null ? 1 : 0);

  /// Check if queue is processing
  bool get isProcessing => _isProcessing;

  /// Dispose the queue
  void dispose() {
    cancelAll();
    _timeoutTimer?.cancel();
  }
}
