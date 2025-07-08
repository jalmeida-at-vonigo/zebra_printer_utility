import 'dart:async';
import 'dart:math' as math;
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'zebra_printer_manager.dart';
import 'internal/logger.dart';
import 'internal/commands/command_factory.dart';
import 'internal/commands/printer_command.dart';
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



/// Print event
class PrintEvent {
  final PrintEventType type;
  final DateTime timestamp;
  final PrintStatus status; // Simple status for UI
  final String? message; // Optional message for additional context
  final PrintErrorInfo? errorInfo;
  final Map<String, dynamic> metadata;

  const PrintEvent({
    required this.type,
    required this.timestamp,
    required this.status,
    this.message,
    this.errorInfo,
    this.metadata = const {},
  });
  
  @override
  String toString() => 'PrintEvent($type: $status at $timestamp)';
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
  bool _isCancelled = false;
  
  // Enhanced state tracking
  bool _isConnected = false;
  Map<String, dynamic>? _lastPrinterStatus;
  Timer? _statusCheckTimer;
  Timer? _timeoutTimer;
  String? _currentPrintData; // Store current print data for status checks

  // UI state tracking
  PrintErrorInfo? _currentError;
  String? _currentMessage;
  List<String> _currentIssues = [];
  bool _canAutoResumeState = false;
  String? _autoResumeAction;
  bool _isWaitingForUserFix = false;

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
    _isCancelled = false;
    _isConnected = false;
    _currentPrintData = data; // Store print data for status checks

    // Clear previous state
    _currentError = null;
    _currentMessage = null;
    _currentIssues.clear();
    _canAutoResumeState = false;
    _autoResumeAction = null;
    _isWaitingForUserFix = false;
    
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

      // Step 3: Connect to printer FIRST
      final connectResult = await _connectToPrinter(device);
      if (!connectResult.success) {
        return connectResult;
      }

      // Step 4: Verify and set printer language mode (now that we're connected)
      await _updateStep(
          PrintStep.checkingStatus, 'Configuring printer settings...');
      final languageModeResult = await _verifyAndSetPrinterLanguageMode(format);
      if (!languageModeResult.success) {
        return languageModeResult;
      }

      // Step 5: Perform language-specific status checks (now that language is set)
      await _updateStep(PrintStep.checkingStatus, 'Checking printer status...');
      final languageSpecificResult =
          await _performLanguageSpecificStatusChecks(format);
      if (!languageSpecificResult.success) {
        _logger.warning(
            'Language-specific status checks failed: ${languageSpecificResult.error?.message}');
        // Continue anyway as this is not critical
      }
      
      // Step 6: Check printer status (if enabled)
      if (checkStatusBeforePrint) {
        final statusResult = await _checkPrinterStatus();
        if (!statusResult.success) {
          return statusResult;
        }
      }

      // Step 7: Send print data
      final printResult = await _sendPrintData(data, timeout);
      if (!printResult.success) {
        return printResult;
      }
      
      // Step 8: Wait for completion (if enabled)
      if (waitForCompletion) {
        final completionResult = await _waitForPrintCompletion();
        if (!completionResult.success) {
          return completionResult;
        }
      }

      // Step 9: Complete with artificial delay for better UX
      await _updateStep(PrintStep.completed, 'Print operation completed successfully');
      _currentError = null; // Clear any previous errors
      
      // Add 1-second delay for better UX
      await Future.delayed(const Duration(seconds: 1));
      
      _eventController?.add(PrintEvent(
        type: PrintEventType.completed,
        timestamp: DateTime.now(),
        status: PrintStatus.done,
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
      status: PrintStatus.cancelled,
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
      String connectionMessage = 'Connecting to printer';
      if (_currentAttempt > 1) {
        // Only show retry info on second attempt and beyond
        final retryCount = _currentAttempt - 1;
        final maxRetries = _maxAttempts - 1;
        connectionMessage =
            'Connecting to printer (Retry $retryCount/$maxRetries)';
      }

      await _updateStep(PrintStep.connecting, connectionMessage);
      
      // Emit progress event for UI animation
      _eventController?.add(PrintEvent(
        type: PrintEventType.stepChanged,
        timestamp: DateTime.now(),
        status: PrintStatus.connecting,
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
            status: PrintStatus.configuring,
          ));

          // Emit the connected step
          _eventController?.add(PrintEvent(
            type: PrintEventType.stepChanged,
            timestamp: DateTime.now(),
            status: PrintStatus.configuring,
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
      status: PrintStatus.connecting,
      message: message,
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
          await CommandFactory.createSmartPrinterStatusWorkflow(
        printer,
        printData: _currentPrintData, // Pass print data for language detection
      ).execute();
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
            PrintStep.checkingStatus, 'Printer ready');
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
      String sendingMessage = 'Sending print data';
      if (_currentAttempt > 1) {
        // Only show retry info on second attempt and beyond
        final retryCount = _currentAttempt - 1;
        final maxRetries = _maxAttempts - 1;
        sendingMessage = 'Sending print data (Retry $retryCount/$maxRetries)';
      }

      await _updateStep(PrintStep.sending, sendingMessage);
      
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
      // Simple status polling for completion
      bool isCompleted = false;
      bool hasAutoResumed = false;
      final startTime = DateTime.now();
      const timeout = Duration(seconds: 30);
      const interval = Duration(milliseconds: 500);

      while (!isCompleted && DateTime.now().difference(startTime) < timeout) {
        if (_isCancelled) {
          return Result.errorCode(ErrorCodes.operationCancelled);
        }

        try {
          final statusResult = await _printerManager.getPrinterStatus();
          if (statusResult.success && statusResult.data != null) {
            final status = statusResult.data!;
            
            // Emit real-time status update event
            _emitStatusUpdate(status);

            // Check for completion
            final isReadyToPrint = status['isReadyToPrint'] == true;
            final isPartialFormatInProgress =
                status['isPartialFormatInProgress'] == true;
            final hasBlockingIssues = _hasPrintIssues(status);

            if (isReadyToPrint &&
                !isPartialFormatInProgress &&
                !hasBlockingIssues) {
              isCompleted = true;
              break;
            }

            // Check for auto-resume opportunities
            if (_canAutoResumeState && !hasAutoResumed) {
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
            if (_hasPrintIssues(status)) {
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
        } catch (e) {
          _logger.error('Error during status polling', e);
        }

        // Wait before next poll
        await Future.delayed(interval);
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
    // Update internal state
    _currentIssues = _extractIssues(status);
    _canAutoResumeState = _canAutoResume(status);
    _autoResumeAction = _getAutoResumeAction(status);
    _isWaitingForUserFix = _currentIssues.isNotEmpty;
    
    _eventController?.add(PrintEvent(
      type: PrintEventType.realTimeStatusUpdate,
      timestamp: DateTime.now(),
      status: PrintStatus.printing,
      metadata: {
        'status': status,
        'isCompleted': status['isCompleted'] ?? false,
        'hasIssues': status['hasIssues'] ?? false,
        'canAutoResume': _canAutoResumeState,
        'issues': _currentIssues,
        'autoResumeAction': _autoResumeAction,
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

  /// Check if there are any print issues that need attention
  bool _hasPrintIssues(Map<String, dynamic> status) {
    return status['isHeadOpen'] == true ||
        status['isPaperOut'] == true ||
        status['isRibbonOut'] == true ||
        status['isHeadCold'] == true ||
        status['isHeadTooHot'] == true;
  }

  /// Check if the printer can auto-resume (e.g., was paused but can be unpaused)
  bool _canAutoResume(Map<String, dynamic> status) {
    // Can auto-resume if only paused (no hardware issues)
    final isPaused = status['isPaused'] == true;
    final hasHardwareIssues = status['isHeadOpen'] == true ||
        status['isPaperOut'] == true ||
        status['isRibbonOut'] == true ||
        status['isHeadCold'] == true ||
        status['isHeadTooHot'] == true;

    return isPaused && !hasHardwareIssues;
  }

  /// Update current step and emit event
  Future<void> _updateStep(PrintStep step, String message) async {
    _currentStep = step;
    _currentMessage = message;
    _logger.info('Print step: $step - $message');
    
    // Map PrintStep to PrintStatus for UI
    PrintStatus uiStatus;
    switch (step) {
      case PrintStep.initializing:
      case PrintStep.validating:
        uiStatus = PrintStatus.connecting;
        break;
      case PrintStep.connecting:
        uiStatus = PrintStatus.connecting;
        break;
      case PrintStep.connected:
      case PrintStep.checkingStatus:
        uiStatus = PrintStatus.configuring;
        break;
      case PrintStep.sending:
      case PrintStep.waitingForCompletion:
        uiStatus = PrintStatus.printing;
        break;
      case PrintStep.completed:
        uiStatus = PrintStatus.done;
        break;
      case PrintStep.failed:
        uiStatus = PrintStatus.failed;
        break;
      case PrintStep.cancelled:
        uiStatus = PrintStatus.cancelled;
        break;
    }
    
    _eventController?.add(PrintEvent(
      type: PrintEventType.stepChanged,
      timestamp: DateTime.now(),
      status: uiStatus,
      message: message,
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
    
    _currentError = errorInfo;
    _logger.error('Print error: ${errorInfo.message}', null, stackTrace);
    
    _eventController?.add(PrintEvent(
      type: PrintEventType.errorOccurred,
      timestamp: DateTime.now(),
      status: PrintStatus.failed,
      errorInfo: errorInfo,
      message: errorInfo.message,
    ));
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
      status: PrintStatus.connecting, // Retry goes back to connecting
      message: 'Retrying in ${delay.inSeconds} seconds',
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
        return 'Configuring printer';
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

  /// Get current print status for UI
  PrintStatus get currentStatus {
    if (_isCancelled) return PrintStatus.cancelled;
    if (_currentStep == PrintStep.completed) return PrintStatus.done;
    if (_currentStep == PrintStep.failed) return PrintStatus.failed;
    
    switch (_currentStep) {
      case PrintStep.initializing:
      case PrintStep.validating:
        return PrintStatus.connecting;
      case PrintStep.connecting:
        return PrintStatus.connecting;
      case PrintStep.connected:
      case PrintStep.checkingStatus:
        return PrintStatus.configuring;
      case PrintStep.sending:
      case PrintStep.waitingForCompletion:
        return PrintStatus.printing;
      default:
        return PrintStatus.connecting;
    }
  }

  /// Check if currently printing
  bool get isPrinting => currentStatus.isInProgress;

  /// Check if print was successful
  bool get isCompleted => currentStatus == PrintStatus.done;

  /// Check if print failed
  bool get hasFailed => currentStatus == PrintStatus.failed;

  /// Check if print was cancelled
  bool get wasCancelled => currentStatus == PrintStatus.cancelled;

  /// Get current error info
  PrintErrorInfo? get currentError => _currentError;

  /// Get current status message
  String get currentMessage => _currentMessage ?? currentStatus.displayName;

  /// Get real-time status info
  Map<String, dynamic>? get realTimeStatus => _lastPrinterStatus;

  /// Get current issues list
  List<String> get currentIssues => _currentIssues;

  /// Check if can auto-resume
  bool get canAutoResume => _canAutoResumeState;

  /// Get auto-resume action message
  String? get autoResumeAction => _autoResumeAction;

  /// Check if waiting for user to fix issues
  bool get isWaitingForUserFix => _isWaitingForUserFix;

  /// Get retry information
  bool get isRetrying => _currentAttempt > 1;
  int get retryCount => _currentAttempt > 1 ? _currentAttempt - 1 : 0;
  int get maxAttempts => _maxAttempts;

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

  /// Create language-specific buffer clear command based on print format
  PrinterCommand<void> _createLanguageSpecificClearBufferCommand(
      PrintFormat format) {
    switch (format) {
      case PrintFormat.zpl:
        return CommandFactory.createSendZplClearBufferCommand(
            _printerManager.printer!);
      case PrintFormat.cpcl:
        return CommandFactory.createSendCpclClearBufferCommand(
            _printerManager.printer!);
    }
  }

  /// Create language-specific clear errors command based on print format
  PrinterCommand<void> _createLanguageSpecificClearErrorsCommand(
      PrintFormat format) {
    switch (format) {
      case PrintFormat.zpl:
        return CommandFactory.createSendZplClearErrorsCommand(
            _printerManager.printer!);
      case PrintFormat.cpcl:
        return CommandFactory.createSendCpclClearErrorsCommand(
            _printerManager.printer!);
    }
  }

  /// Perform language-specific status checks and buffer operations
  Future<Result<void>> _performLanguageSpecificStatusChecks(
      PrintFormat format) async {
    try {
      _logger.debug(
          'Performing language-specific status checks for ${format.name}');

      // Safety check: Verify printer is in correct mode before sending language-specific commands
      final printer = _printerManager.printer;
      if (printer == null) {
        return Result.error('No printer instance available');
      }

      final languageResult =
          await CommandFactory.createGetPrinterLanguageCommand(printer)
              .execute();
      if (languageResult.success && languageResult.data != null) {
        final currentLanguage = languageResult.data!.toLowerCase();
        bool languageMatches = false;

        switch (format) {
          case PrintFormat.zpl:
            languageMatches = currentLanguage.contains('zpl');
            break;
          case PrintFormat.cpcl:
            languageMatches = currentLanguage.contains('cpcl') ||
                currentLanguage.contains('line_print');
            break;
        }

        if (!languageMatches) {
          _logger.warning(
              'Printer not in correct mode for ${format.name} commands. Current: $currentLanguage');
          return Result
              .success(); // Skip language-specific commands if mode doesn't match
        }
      }

      // Clear buffer using language-specific command
      final clearBufferCommand =
          _createLanguageSpecificClearBufferCommand(format);
      final clearResult = await clearBufferCommand.execute();
      if (clearResult.success) {
        _logger.debug('Buffer cleared using ${format.name} command');
      } else {
        _logger.warning(
            'Failed to clear buffer with ${format.name} command: ${clearResult.error?.message}');
      }

      // Clear errors using language-specific command
      final clearErrorsCommand =
          _createLanguageSpecificClearErrorsCommand(format);
      final errorsResult = await clearErrorsCommand.execute();
      if (errorsResult.success) {
        _logger.debug('Errors cleared using ${format.name} command');
      } else {
        _logger.warning(
            'Failed to clear errors with ${format.name} command: ${errorsResult.error?.message}');
      }

      return Result.success();
    } catch (e, stack) {
      _logger.error('Error during language-specific status checks', e, stack);
      return Result.error('Language-specific status checks failed: $e');
    }
  }

  /// Verify and set printer language mode to match the expected format
  Future<Result<void>> _verifyAndSetPrinterLanguageMode(
      PrintFormat expectedFormat) async {
    try {
      _logger
          .info('Verifying printer language mode for ${expectedFormat.name}');

      final printer = _printerManager.printer;
      if (printer == null) {
        return Result.errorCode(
          ErrorCodes.statusCheckFailed,
          formatArgs: ['No printer instance available'],
        );
      }

      // Step 1: Get current printer language
      final languageResult =
          await CommandFactory.createGetPrinterLanguageCommand(printer)
              .execute();
      if (!languageResult.success || languageResult.data == null) {
        return Result.errorCode(
          ErrorCodes.statusCheckFailed,
          formatArgs: ['Failed to get printer language'],
        );
      }

      final currentLanguage = languageResult.data!.toLowerCase();
      _logger.info('Current printer language: $currentLanguage');

      // Step 2: Check if current language matches expected format
      bool languageMatches = false;
      String expectedLanguage = '';

      switch (expectedFormat) {
        case PrintFormat.zpl:
          expectedLanguage = 'zpl';
          languageMatches = currentLanguage.contains('zpl');
          break;
        case PrintFormat.cpcl:
          expectedLanguage = 'cpcl';
          languageMatches = currentLanguage.contains('cpcl') ||
              currentLanguage.contains('line_print');
          break;
      }

      _logger.info(
          'Expected language: $expectedLanguage, matches: $languageMatches');

      // Step 3: If language doesn't match, set the printer to the correct mode
      if (!languageMatches) {
        _logger.info('Setting printer language to $expectedLanguage');
        await _updateStep(PrintStep.checkingStatus,
            'Setting printer language mode...');

        Result<void> setLangResult;
        switch (expectedFormat) {
          case PrintFormat.zpl:
            setLangResult =
                await CommandFactory.createSendSetZplModeCommand(printer)
                    .execute();
            break;
          case PrintFormat.cpcl:
            setLangResult =
                await CommandFactory.createSendSetCpclModeCommand(printer)
                    .execute();
            break;
        }

        if (!setLangResult.success) {
          return Result.errorCode(
            ErrorCodes.statusCheckFailed,
            formatArgs: [
              'Failed to set printer language to $expectedLanguage: ${setLangResult.error?.message}'
            ],
          );
        }

        // Step 4: Wait for the printer to switch modes and verify
        _logger
            .info('Waiting for printer to switch to $expectedLanguage mode...');
        await Future.delayed(
            const Duration(seconds: 2)); // Give printer time to switch

        // Step 5: Verify the language switch was successful
        final verifyResult =
            await CommandFactory.createGetPrinterLanguageCommand(printer)
                .execute();
        if (!verifyResult.success || verifyResult.data == null) {
          return Result.errorCode(
            ErrorCodes.statusCheckFailed,
            formatArgs: ['Failed to verify printer language after switch'],
          );
        }

        final newLanguage = verifyResult.data!.toLowerCase();
        bool switchSuccessful = false;

        switch (expectedFormat) {
          case PrintFormat.zpl:
            switchSuccessful = newLanguage.contains('zpl');
            break;
          case PrintFormat.cpcl:
            switchSuccessful = newLanguage.contains('cpcl') ||
                newLanguage.contains('line_print');
            break;
        }

        if (!switchSuccessful) {
          return Result.errorCode(
            ErrorCodes.statusCheckFailed,
            formatArgs: [
              'Printer language switch failed. Current: $newLanguage, Expected: $expectedLanguage'
            ],
          );
        }

        _logger.info('Printer successfully switched to $expectedLanguage mode');
        await _updateStep(PrintStep.checkingStatus,
            'Printer configured successfully');
      } else {
        _logger.info('Printer already in correct $expectedLanguage mode');
        await _updateStep(PrintStep.checkingStatus,
            'Printer already configured');
      }

      return Result.success();
    } catch (e, stack) {
      _logger.error('Error verifying/setting printer language mode', e, stack);
      return Result.errorCode(
        ErrorCodes.statusCheckFailed,
        formatArgs: ['Language mode verification failed: $e'],
        dartStackTrace: stack,
      );
    }
  }
} 