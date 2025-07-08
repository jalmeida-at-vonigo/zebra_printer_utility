import 'dart:async';
import 'dart:math' as math;
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'zebra_printer_manager.dart';
import 'internal/logger.dart';
import 'internal/commands/command_factory.dart';
import 'models/print_enums.dart';
import 'zebra_sgd_commands.dart';

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
  realTimeStatusUpdate, // New event type for real-time status updates
}

/// Print step information
class PrintStepInfo {
  final PrintStep step;
  final String message;
  final int attempt;
  final int maxAttempts;
  final Duration elapsed;
  final Map<String, dynamic> metadata;
  final bool isCompleted;

  const PrintStepInfo({
    required this.step,
    required this.message,
    required this.attempt,
    required this.maxAttempts,
    required this.elapsed,
    this.metadata = const {},
    this.isCompleted = false,
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

      // Step 2.5: Detect print data format (CPCL or ZPL)
      final format = _detectPrintFormat(data);
      if (format == null) {
        return Result.errorCode(
          ErrorCodes.printDataInvalidFormat,
          formatArgs: ['Unknown or unsupported print format'],
        );
      }
      _logger.info('Detected print format: $format');

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

      // Step 4.5: Check the printer's current language/mode
      final printer = _printerManager.printer;
      if (printer == null) {
        return Result.errorCode(
          ErrorCodes.statusCheckFailed,
          formatArgs: ['No printer instance available'],
        );
      }
      final languageResult = await CommandFactory.createGetPrinterLanguageCommand(printer).execute();
      if (!languageResult.success || languageResult.data == null) {
        return Result.errorCode(
          ErrorCodes.statusCheckFailed,
          formatArgs: ['Failed to get printer language'],
        );
      }
      final currentLanguage = languageResult.data!.toLowerCase();
      _logger.info('Printer current language: $currentLanguage');

      // Step 4.6: If the printer's language does not match the data format, set the printer to the correct mode
      String expectedLanguage = format == PrintFormat.zpl ? 'zpl' : 'cpcl';
      if ((expectedLanguage == 'zpl' && !currentLanguage.contains('zpl')) ||
          (expectedLanguage == 'cpcl' && !currentLanguage.contains('cpcl') && !currentLanguage.contains('line_print'))) {
        _logger.info('Setting printer language to $expectedLanguage');
        Result<void> setLangResult;
        if (expectedLanguage == 'zpl') {
          setLangResult = await CommandFactory.createSendSetZplModeCommand(printer).execute();
        } else {
          setLangResult = await CommandFactory.createSendSetCpclModeCommand(printer).execute();
        }
        if (!setLangResult.success) {
          return Result.errorCode(
            ErrorCodes.statusCheckFailed,
            formatArgs: ['Failed to set printer language to $expectedLanguage'],
          );
        }
        // Give the printer a moment to switch modes
        await Future.delayed(const Duration(seconds: 1));
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

  /// Detect print format from data
  PrintFormat? _detectPrintFormat(String data) {
    if (ZebraSGDCommands.isZPLData(data)) {
      return PrintFormat.zpl;
    } else if (ZebraSGDCommands.isCPCLData(data)) {
      return PrintFormat.cpcl;
    } else {
      return null;
    }
  }

  /// Connect to printer with retry logic
  Future<Result<void>> _connectToPrinter(ZebraDevice? device) async {
    while (_currentAttempt <= _maxAttempts && !_isCancelled) {
      // Start connection with progress indicator
      await _updateStep(PrintStep.connecting, 'Connecting to printer (attempt $_currentAttempt/$_maxAttempts)');
      
      // Emit progress event for UI animation
      _eventController?.add(PrintEvent(
        type: PrintEventType.stepChanged,
        timestamp: DateTime.now(),
        stepInfo: _createStepInfo(PrintStep.connecting,
            'Connecting to printer (attempt $_currentAttempt/$_maxAttempts)'),
      ));
      
      try {
        // Simulate connection progress for better UX
        await _emitConnectionProgress('Initializing connection...');
        await Future.delayed(const Duration(milliseconds: 200));

        await _emitConnectionProgress('Establishing connection...');
        final result = await _printerManager.connect(device);
        
        if (result.success) {
          _isConnected = true;
          
          await _emitConnectionProgress('Connection established successfully');
          await Future.delayed(const Duration(milliseconds: 300));

          // Mark connecting step as completed
          await _updateStep(PrintStep.connected, 'Successfully connected to printer');
          
          // Emit completion event for the connecting step
          _eventController?.add(PrintEvent(
            type: PrintEventType.progressUpdate,
            timestamp: DateTime.now(),
            stepInfo: _createStepInfo(
                PrintStep.connecting, 'Connection completed',
                isCompleted: true),
          ));

          // Emit the connected step
          _eventController?.add(PrintEvent(
            type: PrintEventType.stepChanged,
            timestamp: DateTime.now(),
            stepInfo: _createStepInfo(
                PrintStep.connected, 'Successfully connected to printer'),
          ));
          
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

  /// Emit connection progress updates for UI animation
  Future<void> _emitConnectionProgress(String message) async {
    _eventController?.add(PrintEvent(
      type: PrintEventType.stepChanged,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(PrintStep.connecting, message),
    ));
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

  /// Check printer status before printing using smart workflow
  Future<Result<void>> _checkPrinterStatus() async {
    await _updateStep(PrintStep.checkingStatus, 'Checking printer status');

    try {
      // Use the new smart status workflow
      final printer = _printerManager.printer;
      if (printer == null) {
        return Result.errorCode(
          ErrorCodes.statusCheckFailed,
          formatArgs: ['No printer instance available'],
        );
      }
      final statusResult =
          await CommandFactory.createSmartPrinterStatusWorkflow(printer)
              .execute();
      if (statusResult.success) {
        _lastPrinterStatus = statusResult.data;

        // Check for critical issues using the new analysis structure
        final status = statusResult.data;
        if (status != null) {
          final analysis = status['analysis'] as Map<String, dynamic>?;
          if (analysis != null) {
            final canPrint = analysis['canPrint'] as bool? ?? false;
            final blockingIssues =
                analysis['blockingIssues'] as List<dynamic>? ?? [];

            if (!canPrint && blockingIssues.isNotEmpty) {
              // Return specific error based on the first blocking issue
              final firstIssue = blockingIssues.first.toString().toLowerCase();
              if (firstIssue.contains('head open')) {
                return Result.errorCode(ErrorCodes.headOpen);
              } else if (firstIssue.contains('out of paper')) {
                return Result.errorCode(ErrorCodes.outOfPaper);
              } else if (firstIssue.contains('paused')) {
                return Result.errorCode(ErrorCodes.printerPaused);
              } else if (firstIssue.contains('ribbon')) {
                return Result.errorCode(ErrorCodes.ribbonError);
              } else if (firstIssue.contains('head too cold')) {
                return Result.errorCode(
                  ErrorCodes.printerNotReady,
                  formatArgs: ['Print head is cold'],
                );
              } else if (firstIssue.contains('head too hot')) {
                return Result.errorCode(
                  ErrorCodes.printerNotReady,
                  formatArgs: ['Print head is too hot'],
                );
              } else {
                return Result.errorCode(
                  ErrorCodes.statusCheckFailed,
                  formatArgs: [firstIssue],
                );
              }
            }
          }
        }

        await _updateStep(
            PrintStep.checkingStatus, 'Printer is ready to print');
        return Result.success();
      } else {
        // Use the specific error code from the result
        if (statusResult.error?.code != null) {
          return Result.errorCode(
            ErrorCodes.fromCode(statusResult.error!.code!) ??
                ErrorCodes.statusCheckFailed,
            formatArgs: [statusResult.error?.message ?? 'Unknown status error'],
          );
        } else {
          return Result.errorCode(
            ErrorCodes.statusCheckFailed,
            formatArgs: [statusResult.error?.message ?? 'Unknown status error'],
          );
        }
      }
    } catch (e, stack) {
      _logger.error('Exception during status check', e, stack);
      return Result.errorCode(
        ErrorCodes.statusCheckFailed,
        formatArgs: ['Exception: $e'],
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
      // Use the new status polling approach for better UX
      bool isCompleted = false;
      bool hasAutoResumed = false;

      await for (final status in _printerManager.startStatusPolling(
        interval: const Duration(milliseconds: 500),
        timeout: const Duration(seconds: 30),
      )) {
        if (_isCancelled) {
          return Result.errorCode(ErrorCodes.operationCancelled);
        }

        // Emit real-time status update event
        _emitStatusUpdate(status);

        // Check for completion
        if (status['isCompleted'] == true) {
          isCompleted = true;
          break;
        }

        // Check for auto-resume opportunities
        if (status['canAutoResume'] == true && !hasAutoResumed) {
          _logger.info('Auto-resuming paused printer');
          await _updateStep(
              PrintStep.waitingForCompletion, 'Auto-resuming printer...');

          final resumeResult = await _printerManager.autoResumePrinter();
          if (resumeResult.success) {
            hasAutoResumed = true;
            await _updateStep(PrintStep.waitingForCompletion,
                'Printer resumed, waiting for completion...');
          }
        }

        // Check for blocking issues
        if (status['hasIssues'] == true) {
          final issues = <String>[];
          if (status['isHeadOpen'] == true) issues.add('head open');
          if (status['isPaperOut'] == true) issues.add('out of paper');
          if (status['isRibbonOut'] == true) issues.add('ribbon error');
          if (status['isHeadCold'] == true) issues.add('head cold');
          if (status['isHeadTooHot'] == true) issues.add('head too hot');

          if (issues.isNotEmpty) {
            await _updateStep(PrintStep.waitingForCompletion,
                'Waiting for user to fix: ${issues.join(', ')}');
          }
        }

        // Update status message based on current state
        if (status['isPaused'] == true) {
          await _updateStep(PrintStep.waitingForCompletion,
              'Printer paused, waiting for resume...');
        } else if (status['isPartialFormatInProgress'] == true) {
          await _updateStep(
              PrintStep.waitingForCompletion, 'Printing in progress...');
        } else {
          await _updateStep(PrintStep.waitingForCompletion,
              'Waiting for print completion...');
        }
      }

      if (isCompleted) {
        _logger.info('Print completion successful via status polling');
        return Result.success();
      } else {
        return Result.errorCode(
          ErrorCodes.printError,
          formatArgs: ['Print completion timeout or failed'],
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

  /// Emit real-time status update event
  void _emitStatusUpdate(Map<String, dynamic> status) {
    _eventController?.add(PrintEvent(
      type: PrintEventType.realTimeStatusUpdate,
      timestamp: DateTime.now(),
      metadata: {
        'status': status,
        'isCompleted': status['isCompleted'] ?? false,
        'hasIssues': status['hasIssues'] ?? false,
        'canAutoResume': status['canAutoResume'] ?? false,
        'issues': _extractIssues(status),
        'autoResumeAction': _getAutoResumeAction(status),
      },
    ));
  }

  /// Extract issues from status for UI display
  List<String> _extractIssues(Map<String, dynamic> status) {
    final issues = <String>[];
    if (status['isHeadOpen'] == true) issues.add('Printer head is open');
    if (status['isPaperOut'] == true) issues.add('Out of paper');
    if (status['isRibbonOut'] == true) issues.add('Ribbon error');
    if (status['isHeadCold'] == true) issues.add('Print head is cold');
    if (status['isHeadTooHot'] == true) issues.add('Print head is too hot');
    if (status['isPaused'] == true) issues.add('Printer is paused');
    return issues;
  }

  /// Get auto-resume action description
  String? _getAutoResumeAction(Map<String, dynamic> status) {
    if (status['canAutoResume'] == true) {
      return 'Printer can be auto-resumed';
    }
    return null;
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
    // Determine if recovery hint should be removed because SmartPrintManager auto-recovers
    final shouldRemoveRecoveryHint = _shouldRemoveRecoveryHint(errorCode);
    final recoveryHint =
        shouldRemoveRecoveryHint ? null : errorCode.recoveryHint;
    
    final errorInfo = PrintErrorInfo(
      message: errorCode.formatMessage(formatArgs),
      recoverability: _determineRecoverability(errorCode),
      errorCode: errorCode.code,
      stackTrace: stackTrace,
      recoveryHint: recoveryHint,
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
  PrintStepInfo _createStepInfo(PrintStep step, String message,
      {bool isCompleted = false}) {
    return PrintStepInfo(
      step: step,
      message: message,
      attempt: _currentAttempt,
      maxAttempts: _maxAttempts,
      elapsed: DateTime.now().difference(_startTime ?? DateTime.now()),
      isCompleted: isCompleted,
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

  /// Determine if recovery hint should be removed because SmartPrintManager auto-recovers
  bool _shouldRemoveRecoveryHint(ErrorCode errorCode) {
    // Connection errors that SmartPrintManager auto-retries
    if (errorCode.category == 'Connection') {
      if (errorCode == ErrorCodes.connectionError ||
          errorCode == ErrorCodes.connectionTimeout ||
          errorCode == ErrorCodes.connectionLost ||
          errorCode == ErrorCodes.networkError ||
          errorCode == ErrorCodes.bluetoothDisabled ||
          errorCode == ErrorCodes.noPermission ||
          errorCode == ErrorCodes.invalidDeviceAddress) {
        return true;
      }
    }

    // Print errors that SmartPrintManager auto-retries
    if (errorCode.category == 'Print') {
      if (errorCode == ErrorCodes.printError ||
          errorCode == ErrorCodes.printTimeout ||
          errorCode == ErrorCodes.printerPaused) {
        // SmartPrintManager can auto-unpause
        return true;
      }
    }

    // Operation errors that SmartPrintManager handles
    if (errorCode.category == 'Operation') {
      if (errorCode == ErrorCodes.operationTimeout ||
          errorCode == ErrorCodes.operationError) {
        return true;
      }
    }

    // Status errors that SmartPrintManager retries
    if (errorCode.category == 'Status') {
      if (errorCode == ErrorCodes.statusCheckFailed ||
          errorCode == ErrorCodes.statusTimeout ||
          errorCode == ErrorCodes.statusUnknownError ||
          errorCode == ErrorCodes.statusCheckUnknownError ||
          errorCode == ErrorCodes.detailedStatusUnknownError) {
        return true;
      }
    }

    // Discovery errors that SmartPrintManager retries
    if (errorCode.category == 'Discovery') {
      if (errorCode == ErrorCodes.discoveryError ||
          errorCode == ErrorCodes.discoveryTimeout ||
          errorCode == ErrorCodes.networkError ||
          errorCode == ErrorCodes.bluetoothDisabled ||
          errorCode == ErrorCodes.noPermission) {
        return true;
      }
    }

    // Keep recovery hints for errors that require user intervention
    return false;
  }
} 