import 'dart:async';
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'zebra_printer_manager.dart';
import 'internal/logger.dart';

/// Print step enumeration
enum PrintStep {
  initializing,
  connecting,
  connected,
  sending,
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
      case PrintStep.connecting:
        return 0.2;
      case PrintStep.connected:
        return 0.4;
      case PrintStep.sending:
        return 0.6;
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

  const PrintErrorInfo({
    required this.message,
    required this.recoverability,
    this.errorCode,
    this.nativeError,
    this.stackTrace,
    this.metadata = const {},
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
  
  SmartPrintManager(this._printerManager);

  /// Get the event stream for monitoring print progress
  Stream<PrintEvent> get eventStream {
    _eventStream ??= _eventController?.stream ?? Stream.empty();
    return _eventStream!;
  }

  /// Smart print with automatic retry and error handling
  Future<Result<void>> smartPrint({
    required String data,
    ZebraDevice? device,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    _logger.info('Starting smart print operation');
    _maxAttempts = maxAttempts;
    _currentAttempt = 1;
    _startTime = DateTime.now();
    _isCancelled = false;
    
    _eventController = StreamController<PrintEvent>.broadcast();
    
    try {
      // Step 1: Initialize
      await _updateStep(PrintStep.initializing, 'Initializing print operation');
      
      // Step 2: Connect to printer
      final connectResult = await _connectToPrinter(device);
      if (!connectResult.success) {
        return connectResult;
      }
      
      // Step 3: Send print data
      final printResult = await _sendPrintData(data, timeout);
      if (!printResult.success) {
        return printResult;
      }
      
      // Step 4: Complete
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
      await _eventController?.close();
      _eventController = null;
    }
  }

  /// Cancel the current print operation
  void cancel() {
    _logger.info('Cancelling print operation');
    _isCancelled = true;
    _updateStep(PrintStep.cancelled, 'Print operation cancelled');
    _eventController?.add(PrintEvent(
      type: PrintEventType.cancelled,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(PrintStep.cancelled, 'Print operation cancelled'),
    ));
  }

  /// Connect to printer with retry logic
  Future<Result<void>> _connectToPrinter(ZebraDevice? device) async {
    while (_currentAttempt <= _maxAttempts && !_isCancelled) {
      await _updateStep(PrintStep.connecting, 'Connecting to printer (attempt $_currentAttempt/$_maxAttempts)');
      
      try {
        final result = await _printerManager.connect(device);
        if (result.success) {
          await _updateStep(PrintStep.connected, 'Successfully connected to printer');
          return Result.success();
        } else {
          await _handleError(
            errorCode: ErrorCodes.connectionError,
            formatArgs: [result.error?.message ?? 'Unknown connection error'],
          );
        }
      } catch (e, stack) {
        await _handleError(
          errorCode: ErrorCodes.connectionError,
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
            errorCode: ErrorCodes.printError,
            formatArgs: [result.error?.message ?? 'Unknown print error'],
          );
        }
      } catch (e, stack) {
        await _handleError(
          errorCode: ErrorCodes.printError,
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
    );
    
    _logger.error('Print error: ${errorInfo.message}', null, stackTrace);
    
    _eventController?.add(PrintEvent(
      type: PrintEventType.errorOccurred,
      timestamp: DateTime.now(),
      errorInfo: errorInfo,
      stepInfo: _createStepInfo(PrintStep.failed, errorInfo.message),
    ));
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
      case 'Operation':
        return ErrorRecoverability.recoverable;
      case 'Print':
      case 'Data':
        return ErrorRecoverability.nonRecoverable;
      default:
        return ErrorRecoverability.unknown;
    }
  }

  /// Delay before retry
  Future<void> _retryDelay() async {
    final delay = Duration(seconds: _currentAttempt * 2); // Exponential backoff
    _logger.info('Waiting ${delay.inSeconds} seconds before retry');
    
    _eventController?.add(PrintEvent(
      type: PrintEventType.retryAttempt,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(_currentStep, 'Retrying in ${delay.inSeconds} seconds'),
    ));
    
    await Future.delayed(delay);
  }

  /// Get current progress as percentage
  double getProgress() {
    switch (_currentStep) {
      case PrintStep.initializing:
        return 0.0;
      case PrintStep.connecting:
        return 0.2;
      case PrintStep.connected:
        return 0.4;
      case PrintStep.sending:
        return 0.6;
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
      case PrintStep.connecting:
        return 'Connecting to printer';
      case PrintStep.connected:
        return 'Connected';
      case PrintStep.sending:
        return 'Sending print data';
      case PrintStep.completed:
        return 'Completed';
      case PrintStep.failed:
        return 'Failed';
      case PrintStep.cancelled:
        return 'Cancelled';
    }
  }
} 