import 'dart:async';
import '../models/result.dart';
import '../models/zebra_device.dart';
import '../zebra_printer_service.dart';
import 'logger.dart';

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

  PrintStepInfo({
    required this.step,
    required this.message,
    required this.attempt,
    required this.maxAttempts,
    required this.elapsed,
    this.metadata = const {},
  });

  /// Whether this is a retry attempt
  bool get isRetry => attempt > 1;
  
  /// Retry count (0 for first attempt, 1+ for retries)
  int get retryCount => attempt > 1 ? attempt - 1 : 0;
  
  /// Whether this is the final attempt
  bool get isFinalAttempt => attempt >= maxAttempts;
  
  /// Progress percentage for this step (0.0 to 1.0)
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

  PrintErrorInfo({
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
  final double progress; // 0.0 to 1.0
  final String currentOperation;
  final Duration elapsed;
  final Duration estimatedRemaining;
  final Map<String, dynamic> metadata;

  PrintProgressInfo({
    required this.progress,
    required this.currentOperation,
    required this.elapsed,
    required this.estimatedRemaining,
    this.metadata = const {},
  });

  @override
  String toString() => 'PrintProgressInfo($progress: $currentOperation)';
}

/// Print event data
class PrintEvent {
  final PrintEventType type;
  final DateTime timestamp;
  final PrintStepInfo? stepInfo;
  final PrintErrorInfo? errorInfo;
  final PrintProgressInfo? progressInfo;
  final Map<String, dynamic> metadata;

  PrintEvent({
    required this.type,
    required this.timestamp,
    this.stepInfo,
    this.errorInfo,
    this.progressInfo,
    this.metadata = const {},
  });

  @override
  String toString() => 'PrintEvent($type at ${timestamp.toIso8601String()})';
}

/// Smart print manager with comprehensive event system
/// Uses ZebraPrinterService and ZebraPrinter for native operations
class SmartPrintManager {
  final Logger _logger = Logger.withPrefix('SmartPrintManager');
  
  // Service dependencies
  final ZebraPrinterService _service;
  
  // Instance-based event stream controller
  final StreamController<PrintEvent> _eventController = 
      StreamController<PrintEvent>.broadcast();
  
  // Current state
  PrintStep _currentStep = PrintStep.initializing;
  int _currentAttempt = 0;
  int _maxAttempts = 3;
  DateTime? _startTime;
  Timer? _progressTimer;
  
  // Configuration
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _printTimeout = Duration(seconds: 30);
  static const Duration _retryDelay = Duration(milliseconds: 500);
  
  SmartPrintManager(this._service);
  
  /// Stream of print events for this instance
  Stream<PrintEvent> get events => _eventController.stream;
  
  /// Current print step
  PrintStep get currentStep => _currentStep;
  
  /// Current attempt number
  int get currentAttempt => _currentAttempt;
  
  /// Maximum attempts
  int get maxAttempts => _maxAttempts;
  
  /// Whether currently printing
  bool get isPrinting => _currentStep != PrintStep.initializing && 
                        _currentStep != PrintStep.completed && 
                        _currentStep != PrintStep.failed && 
                        _currentStep != PrintStep.cancelled;
  
  /// Smart print with comprehensive event system
  Future<Result<void>> smartPrint(
    String data, {
    ZebraDevice? device,
    int maxAttempts = 3,
    Duration? connectionTimeout,
    Duration? printTimeout,
  }) async {
    _logger.info('Starting smart print, data length: ${data.length}');
    
    // Initialize state
    _maxAttempts = maxAttempts;
    _currentAttempt = 0;
    _startTime = DateTime.now();
    
    // Emit initialization event
    _emitEvent(PrintEventType.stepChanged, stepInfo: _createStepInfo(
      PrintStep.initializing,
      'Initializing print operation...',
    ));
    
    try {
      // Attempt print with retry logic
      while (_currentAttempt < _maxAttempts) {
        _currentAttempt++;
        
        final result = await _attemptPrint(data, device, connectionTimeout, printTimeout);
        
        if (result.success) {
          _emitEvent(PrintEventType.completed, stepInfo: _createStepInfo(
            PrintStep.completed,
            'Print completed successfully!',
          ));
          // Reset state after successful completion
          _resetState();
          return Result.success();
        } else {
          // Handle error
          final errorInfo = _analyzeError(result.error);
          
          _emitEvent(PrintEventType.errorOccurred, errorInfo: errorInfo);
          
          // Check if we should retry
          if (_currentAttempt < _maxAttempts && errorInfo.recoverability == ErrorRecoverability.recoverable) {
            final retryCount = _currentAttempt - 1;
            final remainingAttempts = _maxAttempts - _currentAttempt;
            
            _emitEvent(PrintEventType.retryAttempt, stepInfo: _createStepInfo(
              _currentStep,
              'Retry $retryCount of ${_maxAttempts - 1} - ${remainingAttempts > 1 ? '$remainingAttempts attempts remaining' : 'Final attempt'}',
            ));
            
            await Future.delayed(_retryDelay);
            continue;
          } else {
            // Final failure
            _emitEvent(PrintEventType.stepChanged, stepInfo: _createStepInfo(
              PrintStep.failed,
              'Print failed after $_maxAttempts attempts',
            ));
            // Reset state after final failure
            _resetState();
            return result;
          }
        }
      }
      
      return Result.error(
        'Print failed after $_maxAttempts attempts',
        code: ErrorCodes.operationError,
      );
    } catch (e, stack) {
      _logger.error('Unexpected error during smart print', e, stack);
      
      final errorInfo = PrintErrorInfo(
        message: 'Unexpected error: $e',
        recoverability: ErrorRecoverability.unknown,
        stackTrace: stack,
      );
      
      _emitEvent(PrintEventType.errorOccurred, errorInfo: errorInfo);
      _emitEvent(PrintEventType.stepChanged, stepInfo: _createStepInfo(
        PrintStep.failed,
        'Unexpected error occurred',
      ));
      
      // Reset state after unexpected error
      _resetState();
      
      return Result.error(
        'Unexpected error: $e',
        code: ErrorCodes.unknownError,
        dartStackTrace: stack,
      );
    }
  }
  
  /// Cancel current print operation
  Future<void> cancel() async {
    _logger.info('Cancelling print operation');
    
    _progressTimer?.cancel();
    
    _emitEvent(PrintEventType.cancelled, stepInfo: _createStepInfo(
      PrintStep.cancelled,
      'Print operation cancelled',
    ));
    
    // Reset state after cancellation
    _resetState();
    
    // Attempt to disconnect if connected
    try {
      await _service.disconnect();
    } catch (e) {
      _logger.warning('Error disconnecting during cancel: $e');
    }
  }

  /// Reset manager state to initial state
  void reset() {
    _logger.info('Resetting SmartPrintManager state');
    _resetState();
  }

  /// Reset internal state
  void _resetState() {
    _currentStep = PrintStep.initializing;
    _currentAttempt = 0;
    _startTime = null;
    _stopProgressTimer();
  }
  
  /// Attempt a single print operation
  Future<Result<void>> _attemptPrint(
    String data,
    ZebraDevice? device,
    Duration? connectionTimeout,
    Duration? printTimeout,
  ) async {
    final effectiveConnectionTimeout = connectionTimeout ?? _connectionTimeout;
    final effectivePrintTimeout = printTimeout ?? _printTimeout;
    
    try {
      // Step 1: Connect
      _updateStep(PrintStep.connecting, 'Connecting to printer...');
      
      final connectResult = await _connectToPrinter(device, effectiveConnectionTimeout);
      if (!connectResult.success) {
        return connectResult;
      }
      
      _updateStep(PrintStep.connected, 'Connected successfully');
      
      // Step 2: Send print data
      _updateStep(PrintStep.sending, 'Sending print data...');
      
      final printResult = await _sendPrintData(data, effectivePrintTimeout);
      if (!printResult.success) {
        return printResult;
      }
      
      return Result.success();
    } on TimeoutException {
      return Result.error(
        'Operation timed out',
        code: ErrorCodes.operationTimeout,
      );
    } catch (e) {
      return Result.error(
        'Operation failed: $e',
        code: ErrorCodes.operationError,
      );
    }
  }
  
  /// Connect to printer using service
  Future<Result<void>> _connectToPrinter(ZebraDevice? device, Duration timeout) async {
    if (device == null && _service.connectedPrinter == null) {
      return Result.error(
        'No printer device provided and no printer currently connected',
        code: ErrorCodes.notConnected,
      );
    }
    
    try {
      // If we have a specific device and it's different from currently connected
      if (device != null && _service.connectedPrinter?.address != device.address) {
        final result = await _service.connect(device).timeout(timeout);
        return result;
      }
      
      // If no device provided but we have a connected printer, use that
      if (device == null && _service.connectedPrinter != null) {
        return Result.success();
      }
      
      // If device provided and it's the same as currently connected
      if (device != null && _service.connectedPrinter?.address == device.address) {
        return Result.success();
      }
      
      return Result.error(
        'Connection failed',
        code: ErrorCodes.connectionError,
      );
    } on TimeoutException {
      return Result.error(
        'Connection timed out',
        code: ErrorCodes.connectionTimeout,
      );
    } catch (e) {
      return Result.error(
        'Connection failed: $e',
        code: ErrorCodes.connectionError,
      );
    }
  }
  
  /// Send print data using service
  Future<Result<void>> _sendPrintData(String data, Duration timeout) async {
    try {
      final result = await _service.print(data).timeout(timeout);
      return result;
    } on TimeoutException {
      return Result.error(
        'Print timed out',
        code: ErrorCodes.operationTimeout,
      );
    } catch (e) {
      return Result.error(
        'Print failed: $e',
        code: ErrorCodes.printError,
      );
    }
  }
  
  /// Update current step and emit event
  void _updateStep(PrintStep step, String message) {
    _currentStep = step;
    
    _emitEvent(PrintEventType.stepChanged, stepInfo: _createStepInfo(step, message));
    
    // Start progress timer for active steps
    if (step == PrintStep.connecting || step == PrintStep.sending) {
      _startProgressTimer();
    } else {
      _stopProgressTimer();
    }
  }
  
  /// Start progress timer for active operations
  void _startProgressTimer() {
    _stopProgressTimer();
    
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (isPrinting && _startTime != null) {
        final elapsed = DateTime.now().difference(_startTime!);
        final progress = _calculateProgress();
        
        _emitEvent(PrintEventType.progressUpdate, progressInfo: PrintProgressInfo(
          progress: progress,
          currentOperation: _getCurrentOperation(),
          elapsed: elapsed,
          estimatedRemaining: _estimateRemainingTime(progress),
        ));
      } else {
        timer.cancel();
      }
    });
  }
  
  /// Stop progress timer
  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }
  
  /// Calculate current progress (0.0 to 1.0)
  double _calculateProgress() {
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
  
  /// Get current operation description
  String _getCurrentOperation() {
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
  
  /// Estimate remaining time based on progress
  Duration _estimateRemainingTime(double progress) {
    if (progress <= 0 || _startTime == null) return Duration.zero;
    
    final elapsed = DateTime.now().difference(_startTime!);
    final totalEstimated = elapsed.inMilliseconds / progress;
    final remaining = totalEstimated - elapsed.inMilliseconds;
    
    return Duration(milliseconds: remaining.toInt());
  }
  
  /// Create step info
  PrintStepInfo _createStepInfo(PrintStep step, String message) {
    return PrintStepInfo(
      step: step,
      message: message,
      attempt: _currentAttempt,
      maxAttempts: _maxAttempts,
      elapsed: _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero,
      metadata: {
        'step': step.name,
        'attempt': _currentAttempt,
        'maxAttempts': _maxAttempts,
      },
    );
  }
  
  /// Analyze error and determine recoverability
  PrintErrorInfo _analyzeError(ErrorInfo? error) {
    if (error == null) {
      return PrintErrorInfo(
        message: 'Unknown error',
        recoverability: ErrorRecoverability.unknown,
      );
    }
    
    final message = error.message.toLowerCase();
    ErrorRecoverability recoverability;
    
    // Determine recoverability based on error message
    if (message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('not connected') ||
        message.contains('network') ||
        message.contains('bluetooth') ||
        message.contains('temporary') ||
        message.contains('retry')) {
      recoverability = ErrorRecoverability.recoverable;
    } else if (message.contains('head open') ||
               message.contains('out of paper') ||
               message.contains('ribbon') ||
               message.contains('hardware') ||
               message.contains('permanent') ||
               message.contains('fatal')) {
      recoverability = ErrorRecoverability.nonRecoverable;
    } else {
      recoverability = ErrorRecoverability.unknown;
    }
    
    return PrintErrorInfo(
      message: error.message,
      recoverability: recoverability,
      errorCode: error.code,
      nativeError: error.nativeError,
      stackTrace: error.dartStackTrace,
      metadata: {
        'recoverability': recoverability.name,
        'errorCode': error.code,
      },
    );
  }
  
  /// Emit event to stream
  void _emitEvent(PrintEventType type, {
    PrintStepInfo? stepInfo,
    PrintErrorInfo? errorInfo,
    PrintProgressInfo? progressInfo,
    Map<String, dynamic>? metadata,
  }) {
    final event = PrintEvent(
      type: type,
      timestamp: DateTime.now(),
      stepInfo: stepInfo,
      errorInfo: errorInfo,
      progressInfo: progressInfo,
      metadata: metadata ?? {},
    );
    
    _logger.debug('Emitting event: $event');
    _eventController.add(event);
  }
  
  /// Dispose resources
  void dispose() {
    _stopProgressTimer();
    _eventController.close();
  }
} 