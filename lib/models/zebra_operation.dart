import 'dart:async';

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
