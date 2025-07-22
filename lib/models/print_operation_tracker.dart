import 'dart:async';

import 'print_enums.dart';
import 'result.dart';

/// Print operation tracking for completion detection
class PrintOperationTracker {
  DateTime? _printStartTime;
  String? _currentPrintData;
  PrintFormat? _currentFormat;
  bool _isPrinting = false;
  final String _operationId = DateTime.now().millisecondsSinceEpoch.toString();

  /// Unique identifier for this print operation
  String get operationId => _operationId;

  /// Start tracking a print operation
  void startPrint(String data, PrintFormat format) {
    _printStartTime = DateTime.now();
    _currentPrintData = data;
    _currentFormat = format;
    _isPrinting = true;
  }

  /// Stop tracking the current print operation
  void stopPrint() {
    _isPrinting = false;
    _printStartTime = null;
    _currentPrintData = null;
    _currentFormat = null;
  }

  /// Get the elapsed time since print started
  Duration? get elapsedTime {
    if (_printStartTime == null) return null;
    return DateTime.now().difference(_printStartTime!);
  }

  /// Check if currently tracking a print operation
  bool get isPrinting => _isPrinting;

  /// Get the current print data being tracked
  String? get currentPrintData => _currentPrintData;

  /// Get the current print format being tracked
  PrintFormat? get currentFormat => _currentFormat;

  /// Get the print start time
  DateTime? get printStartTime => _printStartTime;

  /// Wait for print completion based on tracked print start time
  Future<Result<bool>> waitForCompletion({
    required String data,
    required PrintFormat format,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      // If we're not tracking a print operation, don't wait
      if (!_isPrinting) {
        return Result.success(true);
      }

      // Verify we're tracking the same print operation
      if (_currentPrintData != data || _currentFormat != format) {
        return Result.success(true);
      }

      // Calculate required wait time based on data size and format
      final dataLength = data.length;
      final baseDelay = format == PrintFormat.cpcl ? 2500 : 2000;
      final sizeMultiplier = (dataLength / 1000).ceil(); // Extra 1s per KB
      final requiredWaitTime = Duration(milliseconds: baseDelay + (sizeMultiplier * 1000));

      // Calculate how much time has already elapsed since print started
      final elapsedTime = this.elapsedTime;
      if (elapsedTime == null) {
        return Result.success(true);
      }

      // Calculate remaining wait time
      final remainingWaitTime = requiredWaitTime - elapsedTime;
      
      if (remainingWaitTime.isNegative) {
        stopPrint();
        return Result.success(true);
      }

      onStatusUpdate?.call('Waiting for print completion...');

      // Wait for the remaining time
      await Future.delayed(remainingWaitTime);
      
      // Stop tracking the print operation
      stopPrint();
      
      return Result.success(true);
    } catch (e, stack) {
      stopPrint();
      return Result.errorCode(
        ErrorCodes.operationError,
        formatArgs: ['Print completion verification error: $e'],
        dartStackTrace: stack,
      );
    }
  }

  /// Create a copy of this tracker
  PrintOperationTracker copy() {
    final tracker = PrintOperationTracker();
    tracker._printStartTime = _printStartTime;
    tracker._currentPrintData = _currentPrintData;
    tracker._currentFormat = _currentFormat;
    tracker._isPrinting = _isPrinting;
    return tracker;
  }
} 