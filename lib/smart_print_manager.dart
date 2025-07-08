import 'dart:async';
import 'dart:math' as math;
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'zebra_printer_manager.dart';
import 'internal/logger.dart';

/// Print step enumeration
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

/// Error recoverability classification
enum ErrorRecoverability {
  recoverable,    // Connection issues, timeouts - will auto-retry
  nonRecoverable, // Hardware issues - requires manual intervention
  unknown,        // Unknown error type
}

/// Print event types
enum PrintEventType {
  stepChanged,
  errorOccurred,
  retryAttempt,
  progressUpdate,
  statusUpdate,
  completed,
  cancelled,
}

/// Print step information
class PrintStepInfo {
  final PrintStep step;
  final String message;
  final int attempt;
  final int maxAttempts;
  final Duration elapsed;
  final Map<String, dynamic> metadata;

  const PrintStepInfo({
    required this.step,
    required this.message,
    required this.attempt,
    required this.maxAttempts,
    required this.elapsed,
    this.metadata = const {},
  });

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
  final String message;
  final ErrorRecoverability recoverability;
  final String? errorCode;
  final dynamic nativeError;
  final StackTrace? stackTrace;
  final Map<String, dynamic> metadata;
  final String? recoveryHint;

  const PrintErrorInfo({
    required this.message,
    required this.recoverability,
    this.errorCode,
    this.nativeError,
    this.stackTrace,
    this.metadata = const {},
    this.recoveryHint,
  });
  
  @override
  String toString() => 'PrintErrorInfo($recoverability: $message)';
}

/// Print progress information
class PrintProgressInfo {
  final double progress;
  final String currentOperation;
  final Duration elapsed;
  final Duration estimatedRemaining;
  final Map<String, dynamic> metadata;

  const PrintProgressInfo({
    required this.progress,
    required this.currentOperation,
    required this.elapsed,
    required this.estimatedRemaining,
    this.metadata = const {},
  });
  
  @override
  String toString() => 'PrintProgressInfo($progress: $currentOperation)';
}

/// Print event
class PrintEvent {
  final PrintEventType type;
  final DateTime timestamp;
  final PrintStepInfo? stepInfo;
  final PrintErrorInfo? errorInfo;
  final PrintProgressInfo? progressInfo;
  final Map<String, dynamic> metadata;

  const PrintEvent({
    required this.type,
    required this.timestamp,
    this.stepInfo,
    this.errorInfo,
    this.progressInfo,
    this.metadata = const {},
  });
  
  @override
  String toString() => 'PrintEvent($type at $timestamp)';
}

/// Smart print manager for handling complex print workflows
class SmartPrintManager {
  final ZebraPrinterManager _printerManager;
  final Logger _logger = Logger(prefix: 'SmartPrintManager');
  
  StreamController<PrintEvent>? _eventController;
  Stream<PrintEvent>? _eventStream;
  
  PrintStep _currentStep = PrintStep.initializing;
  int _currentAttempt = 1;
  int _maxAttempts = 3;
  DateTime? _startTime;
  bool _isCancelled = false;
  
  // Enhanced state tracking
  bool _isConnected = false;
  Map<String, dynamic>? _lastPrinterStatus;
  Timer? _statusCheckTimer;
  Timer? _timeoutTimer;
  
  SmartPrintManager(this._printerManager);

  /// Get the event stream for monitoring print progress
  Stream<PrintEvent> get eventStream {
    _eventStream ??= _eventController?.stream ?? const Stream.empty();
    return _eventStream!;
  }

  /// Smart print with automatic retry and error handling
  Future<Result<void>> smartPrint({
    required String data,
    ZebraDevice? device,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 60),
    bool validateData = true,
    bool checkStatusBeforePrint = true,
    bool waitForCompletion = true,
  }) async {
    _logger.info('Starting smart print operation');
    _maxAttempts = maxAttempts;
    _currentAttempt = 1;
    _startTime = DateTime.now();
    _isCancelled = false;
    _isConnected = false;
    
    _eventController = StreamController<PrintEvent>.broadcast();
    
    // Set up timeout timer
    _timeoutTimer = Timer(timeout, () {
      if (!_isCancelled) {
        _logger.warning(
            'Print operation timed out after ${timeout.inSeconds} seconds');
        _handleError(
          errorCode: ErrorCodes.operationTimeout,
          formatArgs: [timeout.inSeconds],
        );
      }
    });
    
    try {
      // Step 1: Initialize
      await _updateStep(PrintStep.initializing, 'Initializing print operation');
      
      // Step 2: Validate data (if enabled)
      if (validateData) {
        final validationResult = await _validatePrintData(data);
        if (!validationResult.success) {
          return validationResult;
        }
      }

      // Step 3: Connect to printer
      final connectResult = await _connectToPrinter(device);
      if (!connectResult.success) {
        return connectResult;
      }
      
      // Step 4: Check printer status (if enabled)
      if (checkStatusBeforePrint) {
        final statusResult = await _checkPrinterStatus();
        if (!statusResult.success) {
          return statusResult;
        }
      }

      // Step 5: Send print data
      final printResult = await _sendPrintData(data, timeout);
      if (!printResult.success) {
        return printResult;
      }
      
      // Step 6: Wait for completion (if enabled)
      if (waitForCompletion) {
        final completionResult = await _waitForPrintCompletion();
        if (!completionResult.success) {
          return completionResult;
        }
      }

      // Step 7: Complete
      await _updateStep(PrintStep.completed, 'Print operation completed successfully');
      _eventController?.add(PrintEvent(
        type: PrintEventType.completed,
        timestamp: DateTime.now(),
        stepInfo: _createStepInfo(PrintStep.completed, 'Print operation completed'),
      ));
      
      return Result.success();
      
    } catch (e, stack) {
      _logger.error('Unexpected error in smart print', e, stack);
      await _handleError(
        errorCode: ErrorCodes.operationError,
        formatArgs: [e.toString()],
        stackTrace: stack,
      );
      return Result.errorCode(
        ErrorCodes.operationError,
        formatArgs: [e.toString()],
        dartStackTrace: stack,
      );
    } finally {
      _cleanup();
    }
  }

  /// Cancel the current print operation
  void cancel() {
    _logger.info('Cancelling print operation');
    _isCancelled = true;
    _cleanup();
    _updateStep(PrintStep.cancelled, 'Print operation cancelled');
    _eventController?.add(PrintEvent(
      type: PrintEventType.cancelled,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(PrintStep.cancelled, 'Print operation cancelled'),
    ));
  }

  /// Validate print data before sending
  Future<Result<void>> _validatePrintData(String data) async {
    await _updateStep(PrintStep.validating, 'Validating print data');

    // Check for empty data
    if (data.isEmpty) {
      return Result.errorCode(
        ErrorCodes.emptyData,
      );
    }

    // Check for basic format validation
    if (!_isValidPrintData(data)) {
      return Result.errorCode(
        ErrorCodes.printDataInvalidFormat,
      );
    }

    // Check data size (basic validation)
    if (data.length > 1000000) {
      // 1MB limit
      return Result.errorCode(
        ErrorCodes.printDataTooLarge,
        formatArgs: [data.length],
      );
    }

    return Result.success();
  }

  /// Basic print data validation
  bool _isValidPrintData(String data) {
    // Check for common print formats
    final trimmed = data.trim();

    // ZPL format check
    if (trimmed.startsWith('^XA') && trimmed.endsWith('^XZ')) {
      return true;
    }

    // CPCL format check
    if (trimmed.startsWith('!') &&
        (trimmed.contains('TEXT') || trimmed.contains('FORM'))) {
      return true;
    }

    // Raw data (allow any non-empty data)
    return trimmed.isNotEmpty;
  }

  /// Connect to printer with retry logic
  Future<Result<void>> _connectToPrinter(ZebraDevice? device) async {
    while (_currentAttempt <= _maxAttempts && !_isCancelled) {
      await _updateStep(PrintStep.connecting, 'Connecting to printer (attempt $_currentAttempt/$_maxAttempts)');
      
      try {
        final result = await _printerManager.connect(device);
        if (result.success) {
          _isConnected = true;
          await _updateStep(PrintStep.connected, 'Successfully connected to printer');
          return Result.success();
        } else {
          await _handleError(
            errorCode: _classifyConnectionError(
                result.error?.message ?? 'Unknown connection error'),
            formatArgs: [result.error?.message ?? 'Unknown connection error'],
          );
        }
      } catch (e, stack) {
        await _handleError(
          errorCode: _classifyConnectionError(e.toString()),
          formatArgs: [e.toString()],
          stackTrace: stack,
        );
      }
      
      if (_currentAttempt < _maxAttempts && !_isCancelled) {
        await _retryDelay();
        _currentAttempt++;
      } else {
        break;
      }
    }
    
    return Result.errorCode(
      ErrorCodes.connectionRetryFailed,
      formatArgs: [_maxAttempts],
    );
  }

  /// Classify connection errors for better recovery
  ErrorCode _classifyConnectionError(String errorMessage) {
    final message = errorMessage.toLowerCase();

    if (message.contains('timeout')) {
      return ErrorCodes.connectionTimeout;
    } else if (message.contains('permission') || message.contains('denied')) {
      return ErrorCodes.noPermission;
    } else if (message.contains('bluetooth') && message.contains('disabled')) {
      return ErrorCodes.bluetoothDisabled;
    } else if (message.contains('network') || message.contains('wifi')) {
      return ErrorCodes.networkError;
    } else if (message.contains('not found') ||
        message.contains('unavailable')) {
      return ErrorCodes.invalidDeviceAddress;
    } else {
      return ErrorCodes.connectionError;
    }
  }

  /// Check printer status before printing
  Future<Result<void>> _checkPrinterStatus() async {
    await _updateStep(PrintStep.checkingStatus, 'Checking printer status');

    try {
      final statusResult = await _printerManager.getDetailedPrinterStatus();
      if (statusResult.success) {
        _lastPrinterStatus = statusResult.data;

        // Check for critical issues
        final status = statusResult.data;
        if (status != null) {
          if (status['headOpen'] == true) {
            return Result.errorCode(
              ErrorCodes.headOpen,
            );
          }

          if (status['outOfPaper'] == true) {
            return Result.errorCode(
              ErrorCodes.outOfPaper,
            );
          }

          if (status['paused'] == true) {
            return Result.errorCode(
              ErrorCodes.printerPaused,
            );
          }

          if (status['ribbonError'] == true) {
            return Result.errorCode(
              ErrorCodes.ribbonError,
              formatArgs: ['Ribbon error detected'],
            );
          }
        }

        return Result.success();
      } else {
        return Result.errorCode(
          ErrorCodes.statusCheckFailed,
          formatArgs: [statusResult.error?.message ?? 'Unknown status error'],
        );
      }
    } catch (e, stack) {
      return Result.errorCode(
        ErrorCodes.statusCheckFailed,
        formatArgs: [e.toString()],
        dartStackTrace: stack,
      );
    }
  }

  /// Send print data with retry logic
  Future<Result<void>> _sendPrintData(String data, Duration timeout) async {
    while (_currentAttempt <= _maxAttempts && !_isCancelled) {
      await _updateStep(PrintStep.sending, 'Sending print data (attempt $_currentAttempt/$_maxAttempts)');
      
      try {
        final result = await _printerManager.print(data);
        if (result.success) {
          return Result.success();
        } else {
          await _handleError(
            errorCode: _classifyPrintError(
                result.error?.message ?? 'Unknown print error'),
            formatArgs: [result.error?.message ?? 'Unknown print error'],
          );
        }
      } catch (e, stack) {
        await _handleError(
          errorCode: _classifyPrintError(e.toString()),
          formatArgs: [e.toString()],
          stackTrace: stack,
        );
      }
      
      if (_currentAttempt < _maxAttempts && !_isCancelled) {
        await _retryDelay();
        _currentAttempt++;
      } else {
        break;
      }
    }
    
    return Result.errorCode(
      ErrorCodes.printRetryFailed,
      formatArgs: [_maxAttempts],
    );
  }

  /// Classify print errors for better recovery
  ErrorCode _classifyPrintError(String errorMessage) {
    final message = errorMessage.toLowerCase();

    if (message.contains('timeout')) {
      return ErrorCodes.printTimeout;
    } else if (message.contains('head open')) {
      return ErrorCodes.headOpen;
    } else if (message.contains('out of paper')) {
      return ErrorCodes.outOfPaper;
    } else if (message.contains('paused')) {
      return ErrorCodes.printerPaused;
    } else if (message.contains('ribbon')) {
      return ErrorCodes.ribbonError;
    } else if (message.contains('not ready')) {
      return ErrorCodes.printerNotReady;
    } else {
      return ErrorCodes.printError;
    }
  }

  /// Wait for print completion
  Future<Result<void>> _waitForPrintCompletion() async {
    await _updateStep(
        PrintStep.waitingForCompletion, 'Waiting for print completion');

    try {
      final completionResult =
          await _printerManager.waitForPrintCompletion(timeoutSeconds: 30);
      if (completionResult.success) {
        final success = completionResult.data ?? false;
        if (success) {
          return Result.success();
        } else {
          return Result.errorCode(
            ErrorCodes.printError,
            formatArgs: ['Print completion failed - hardware issues detected'],
          );
        }
      } else {
        return Result.errorCode(
          ErrorCodes.printError,
          formatArgs: [
            completionResult.error?.message ?? 'Unknown completion error'
          ],
        );
      }
    } catch (e, stack) {
      return Result.errorCode(
        ErrorCodes.printError,
        formatArgs: [e.toString()],
        dartStackTrace: stack,
      );
    }
  }

  /// Update current step and emit event
  Future<void> _updateStep(PrintStep step, String message) async {
    _currentStep = step;
    _logger.info('Print step: $step - $message');
    
    _eventController?.add(PrintEvent(
      type: PrintEventType.stepChanged,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(step, message),
    ));
  }

  /// Handle error and emit error event
  Future<void> _handleError({
    required ErrorCode errorCode,
    List<Object>? formatArgs,
    StackTrace? stackTrace,
  }) async {
    final errorInfo = PrintErrorInfo(
      message: errorCode.formatMessage(formatArgs),
      recoverability: _determineRecoverability(errorCode),
      errorCode: errorCode.code,
      stackTrace: stackTrace,
      recoveryHint: _getRecoveryHint(errorCode),
    );
    
    _logger.error('Print error: ${errorInfo.message}', null, stackTrace);
    
    _eventController?.add(PrintEvent(
      type: PrintEventType.errorOccurred,
      timestamp: DateTime.now(),
      errorInfo: errorInfo,
      stepInfo: _createStepInfo(PrintStep.failed, errorInfo.message),
    ));
  }

  /// Get recovery hint for error
  String? _getRecoveryHint(ErrorCode errorCode) {
    switch (errorCode.code) {
      case 'HEAD_OPEN':
        return 'Close the printer head and try again';
      case 'OUT_OF_PAPER':
        return 'Add paper to the printer and try again';
      case 'PRINTER_PAUSED':
        return 'Resume the printer and try again';
      case 'RIBBON_ERROR':
        return 'Check the ribbon and try again';
      case 'BLUETOOTH_DISABLED':
        return 'Enable Bluetooth in device settings';
      case 'NO_PERMISSION':
        return 'Grant Bluetooth permissions in app settings';
      case 'CONNECTION_TIMEOUT':
        return 'Check network connection and printer power';
      default:
        return null;
    }
  }

  /// Create step info for current state
  PrintStepInfo _createStepInfo(PrintStep step, String message) {
    return PrintStepInfo(
      step: step,
      message: message,
      attempt: _currentAttempt,
      maxAttempts: _maxAttempts,
      elapsed: DateTime.now().difference(_startTime ?? DateTime.now()),
    );
  }

  /// Determine error recoverability
  ErrorRecoverability _determineRecoverability(ErrorCode errorCode) {
    switch (errorCode.category) {
      case 'Connection':
        return ErrorRecoverability.recoverable;
      case 'Operation':
        return ErrorRecoverability.recoverable;
      case 'Print':
        // Some print errors are recoverable (timeouts), others are not (hardware)
        if (errorCode.code == 'PRINT_TIMEOUT' ||
            errorCode.code == 'PRINTER_PAUSED') {
          return ErrorRecoverability.recoverable;
        }
        return ErrorRecoverability.nonRecoverable;
      case 'Data':
        return ErrorRecoverability.nonRecoverable;
      default:
        return ErrorRecoverability.unknown;
    }
  }

  /// Delay before retry with exponential backoff
  Future<void> _retryDelay() async {
    const baseDelay = 2;
    const maxDelay = 30;
    final delay =
        Duration(seconds: math.min(baseDelay * _currentAttempt, maxDelay));
    
    _logger.info('Waiting ${delay.inSeconds} seconds before retry');
    
    _eventController?.add(PrintEvent(
      type: PrintEventType.retryAttempt,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(_currentStep, 'Retrying in ${delay.inSeconds} seconds'),
    ));
    
    await Future.delayed(delay);
  }

  /// Cleanup resources
  void _cleanup() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
    _eventController?.close();
    _eventController = null;
  }

  /// Get current progress as percentage
  double getProgress() {
    switch (_currentStep) {
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

  /// Get current step description
  String getCurrentStepDescription() {
    switch (_currentStep) {
      case PrintStep.initializing:
        return 'Initializing';
      case PrintStep.validating:
        return 'Validating data';
      case PrintStep.connecting:
        return 'Connecting to printer';
      case PrintStep.connected:
        return 'Connected';
      case PrintStep.checkingStatus:
        return 'Checking printer status';
      case PrintStep.sending:
        return 'Sending print data';
      case PrintStep.waitingForCompletion:
        return 'Waiting for completion';
      case PrintStep.completed:
        return 'Completed';
      case PrintStep.failed:
        return 'Failed';
      case PrintStep.cancelled:
        return 'Cancelled';
    }
  }

  /// Get last known printer status
  Map<String, dynamic>? get lastPrinterStatus => _lastPrinterStatus;

  /// Check if currently connected
  bool get isConnected => _isConnected;

  /// Check if operation is cancelled
  bool get isCancelled => _isCancelled;
} 