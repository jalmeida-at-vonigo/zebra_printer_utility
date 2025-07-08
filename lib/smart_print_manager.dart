import 'dart:async';
import 'dart:math' as math;

import 'internal/commands/command_factory.dart';
import 'internal/logger.dart';
import 'models/communication_policy_options.dart';
import 'models/print_enums.dart';
import 'models/print_event.dart';
import 'models/print_options.dart';
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'zebra_printer_manager.dart';
import 'zebra_sgd_commands.dart';

/// Smart print manager for handling complex print workflows
/// 
/// This manager provides:
/// - Comprehensive print workflow with automatic retry logic
/// - Real-time progress events and status updates
/// - Robust cancellation support that can stop any stoppable operation
/// - Automatic error classification and recovery strategies
/// - Format detection and printer readiness management
///
/// ## Cancellation Support
/// The manager supports comprehensive cancellation through the [cancel] method:
/// - Stops stoppable operations immediately (network calls, polling, retries)
/// - Prevents non-stoppable operations from starting the next step
/// - Cleans up all resources and timers
/// - Emits cancellation events with context about what was cancelled
///
/// Use [canCancel] to check if there's an active operation that can be cancelled.
class SmartPrintManager {
  SmartPrintManager(this._printerManager);
  // Private fields
  final ZebraPrinterManager _printerManager;
  final Logger _logger = Logger.withPrefix('SmartPrintManager');

  // Event stream
  StreamController<PrintEvent>? _eventController;

  // Timers
  Timer? _timeoutTimer;
  Timer? _statusCheckTimer;

  // State tracking
  DateTime? _startTime;
  Map<String, dynamic>? _lastPrinterStatus;
  PrintStep _currentStep = PrintStep.initializing;
  int _currentAttempt = 1;
  int _maxAttempts = 3;
  
  // Cancellation management
  CancellationToken? _cancellationToken;
  
  // Enhanced state tracking
  bool _isRunning = false;
  String? _currentMessage;
  PrintErrorInfo? _currentError;
  final List<String> _currentIssues = [];
  final bool _canAutoResumeState = false;
  late final String? _autoResumeAction;
  final bool _isWaitingForUserFix = false;

  /// Get the event stream for monitoring print progress
  Stream<PrintEvent> get eventStream {
    _eventController ??= StreamController<PrintEvent>();
    return _eventController!.stream;
  }

  /// Smart print operation with comprehensive workflow
  Stream<PrintEvent> smartPrint({
    required String data,
    ZebraDevice? device,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 60),
    PrintOptions? options,
  }) async* {
    if (_isRunning) {
      yield PrintEvent(
        type: PrintEventType.errorOccurred,
        timestamp: DateTime.now(),
        errorInfo: const PrintErrorInfo(
          message: 'Another print operation is already in progress',
          recoverability: ErrorRecoverability.nonRecoverable,
          errorCode: 'OPERATION_ERROR',
        ),
      );
      return;
    }

    _isRunning = true;
    _currentAttempt = 1;
    _maxAttempts = maxAttempts;
    _startTime = DateTime.now();
    
    // Create and store cancellation token for this operation
    _cancellationToken = CancellationToken();
    
    _eventController = StreamController<PrintEvent>.broadcast();
    
    _timeoutTimer = Timer(timeout, () {
      if (!isCancelled) {
        _logger.warning('Print operation timed out after ${timeout.inSeconds} seconds');
        _handleError(
          errorCode: ErrorCodes.operationTimeout,
          formatArgs: [timeout.inSeconds],
        );
      }
    });

    try {
      await _updateStep(PrintStep.initializing, 'Initializing print operation');

      final PrintFormat? format = options?.formatOrDefault ?? ZebraSGDCommands.detectDataLanguage(data);
      if (format == null) {
        yield PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: const PrintErrorInfo(
            message: 'Unknown or unsupported print format',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: 'PRINT_DATA_INVALID_FORMAT',
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Invalid print format'),
        );
        return;
      }
      _logger.info('Smart print format: ${format.name}');

      if (options?.format != format) {
        options = options?.copyWith(PrintOptions(format: format)) ?? PrintOptions(format: format);
      }

      final validationResult = await _validatePrintData(data);
      if (!validationResult.success) {
        yield PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: validationResult.error?.message ?? 'Validation failed',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: validationResult.error?.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Validation failed'),
        );
        return;
      }

      // Check for cancellation before connection attempt
      if (isCancelled) {
        yield PrintEvent(
          type: PrintEventType.cancelled,
          timestamp: DateTime.now(),
          stepInfo:
              _createStepInfo(PrintStep.cancelled, 'Print operation cancelled'),
        );
        return;
      }

      final connectResult = await _connectToPrinter(device);
      if (!connectResult.success) {
        // Check if failure was due to cancellation
        if (connectResult.error?.code == 'OPERATION_CANCELLED' || isCancelled) {
          yield PrintEvent(
            type: PrintEventType.cancelled,
            timestamp: DateTime.now(),
            stepInfo:
                _createStepInfo(PrintStep.cancelled, 'Connection cancelled'),
          );
          return;
        }
        
        yield PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: connectResult.error?.message ?? 'Connection failed',
            recoverability: ErrorRecoverability.recoverable,
            errorCode: connectResult.error?.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Connection failed'),
        );
        return;
      }
      
      if (options?.readinessOptionsOrDefault.checkPause ?? true) {
        final statusResult = await _checkPrinterStatus();
        if (!statusResult.success) {
          yield PrintEvent(
            type: PrintEventType.errorOccurred,
            timestamp: DateTime.now(),
            errorInfo: PrintErrorInfo(
              message: statusResult.error?.message ?? 'Status check failed',
              recoverability: ErrorRecoverability.recoverable,
              errorCode: statusResult.error?.code,
            ),
            stepInfo: _createStepInfo(PrintStep.failed, 'Status check failed'),
          );
          return;
        }
      }

      final printer = _printerManager.printer;
      if (printer == null) {
        yield PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: const PrintErrorInfo(
            message: 'No printer instance available',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: 'STATUS_CHECK_FAILED',
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'No printer available'),
        );
        return;
      }
      final languageResult = await CommandFactory.createGetPrinterLanguageCommand(printer).execute();
      if (!languageResult.success || languageResult.data == null) {
        yield PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: const PrintErrorInfo(
            message: 'Failed to get printer language',
            recoverability: ErrorRecoverability.recoverable,
            errorCode: 'STATUS_CHECK_FAILED',
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Language check failed'),
        );
        return;
      }
      final currentLanguage = languageResult.data!.toLowerCase();
      _logger.info('Printer current language: $currentLanguage');

      final String expectedLanguage =
          format == PrintFormat.zpl ? 'zpl' : 'cpcl';
      if ((expectedLanguage == 'zpl' && !currentLanguage.contains('zpl')) ||
          (expectedLanguage == 'cpcl' && !currentLanguage.contains('cpcl') && !currentLanguage.contains('line_print'))) {
        
        // Check for cancellation before language setting
        if (isCancelled) {
          yield PrintEvent(
            type: PrintEventType.cancelled,
            timestamp: DateTime.now(),
            stepInfo: _createStepInfo(
                PrintStep.cancelled, 'Language setup cancelled'),
          );
          return;
        }
        
        _logger.info('Setting printer language to $expectedLanguage');
        Result<void> setLangResult;
        if (expectedLanguage == 'zpl') {
          setLangResult = await CommandFactory.createSendSetZplModeCommand(printer).execute();
        } else {
          setLangResult = await CommandFactory.createSendSetCpclModeCommand(printer).execute();
        }
        if (!setLangResult.success) {
          yield PrintEvent(
            type: PrintEventType.errorOccurred,
            timestamp: DateTime.now(),
            errorInfo: PrintErrorInfo(
              message: 'Failed to set printer language to $expectedLanguage',
              recoverability: ErrorRecoverability.recoverable,
              errorCode: 'STATUS_CHECK_FAILED',
            ),
            stepInfo: _createStepInfo(PrintStep.failed, 'Language set failed'),
          );
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      // Update options with cancellation token
      options = options
              ?.copyWith(PrintOptions(cancellationToken: _cancellationToken)) ??
          PrintOptions(cancellationToken: _cancellationToken);

      final printResult = await _sendPrintData(data, timeout);
      if (!printResult.success) {
        // Check if failure was due to cancellation
        if (printResult.error?.code == 'OPERATION_CANCELLED' || isCancelled) {
          yield PrintEvent(
            type: PrintEventType.cancelled,
            timestamp: DateTime.now(),
            stepInfo:
                _createStepInfo(PrintStep.cancelled, 'Print sending cancelled'),
          );
          return;
        }
        
        yield PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: printResult.error?.message ?? 'Print failed',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: printResult.error?.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Print failed'),
        );
        return;
      }
      
      if (options.waitForPrintCompletionOrDefault) {
        // Check for cancellation before waiting for completion
        if (isCancelled) {
          yield PrintEvent(
            type: PrintEventType.cancelled,
            timestamp: DateTime.now(),
            stepInfo: _createStepInfo(
                PrintStep.cancelled, 'Print completion wait cancelled'),
          );
          return;
        }
        
        final completionResult = await _waitForPrintCompletion();
        if (!completionResult.success) {
          // Check if failure was due to cancellation
          if (completionResult.error?.code == 'OPERATION_CANCELLED' ||
              isCancelled) {
            yield PrintEvent(
              type: PrintEventType.cancelled,
              timestamp: DateTime.now(),
              stepInfo: _createStepInfo(
                  PrintStep.cancelled, 'Print completion cancelled'),
            );
            return;
          }
          
          yield PrintEvent(
            type: PrintEventType.errorOccurred,
            timestamp: DateTime.now(),
            errorInfo: PrintErrorInfo(
              message: completionResult.error?.message ?? 'Completion failed',
              recoverability: ErrorRecoverability.nonRecoverable,
              errorCode: completionResult.error?.code,
            ),
            stepInfo: _createStepInfo(PrintStep.failed, 'Completion failed'),
          );
          return;
        }
      }

      await _updateStep(PrintStep.completed, 'Print operation completed successfully');
      yield PrintEvent(
        type: PrintEventType.completed,
        timestamp: DateTime.now(),
        stepInfo: _createStepInfo(PrintStep.completed, 'Print operation completed'),
      );
    } catch (e, stack) {
      _logger.error('Unexpected error in smart print', e, stack);
      await _handleError(
        errorCode: ErrorCodes.operationError,
        formatArgs: [e.toString()],
        stackTrace: stack,
      );
    } finally {
      _cleanup();
    }
  }

  /// Cancel the current print operation
  /// 
  /// This will:
  /// - Stop any stoppable operations immediately (communication, polling, retries)
  /// - Prevent non-stoppable operations from starting the next step
  /// - Clean up all resources and timers
  /// - Emit a cancellation event to listeners
  void cancel() {
    if (!_isRunning && !isCancelled) {
      _logger.debug('No active print operation to cancel');
      return;
    }

    _logger.info('Cancelling print operation at step: $_currentStep');
    
    // Cancel the cancellation token - this immediately makes isCancelled return true
    // and stops all ongoing operations (CommunicationPolicy, status polling, etc.)
    _cancellationToken?.cancel();
    
    // Cancel timeout timer to prevent timeout-triggered errors
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    // Stop any active status checking
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;

    // Log which step was interrupted for debugging
    _logger.info(
        'Print operation cancelled during step: $_currentStep (attempt $_currentAttempt/$_maxAttempts)');

    // Update step to cancelled state
    _updateStep(PrintStep.cancelled, 'Print operation cancelled by user');

    // Emit cancellation event with context about what was cancelled
    _eventController?.add(PrintEvent(
      type: PrintEventType.cancelled,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(PrintStep.cancelled, 'Print operation cancelled'),
      metadata: {
        'cancelledAtStep': _currentStep.toString(),
        'cancelledAtAttempt': _currentAttempt,
        'totalAttempts': _maxAttempts,
        'elapsedMs': DateTime.now()
            .difference(_startTime ?? DateTime.now())
            .inMilliseconds,
      },
    ));
    
    // Perform cleanup but don't call _updateStep again as it might interfere with the above
    _cleanupWithoutStepUpdate();
  }

  /// Enhanced cleanup that doesn't update step (used by cancel)
  void _cleanupWithoutStepUpdate() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;

    // Cancel and clear cancellation token
    _cancellationToken?.cancel();
    _cancellationToken = null;

    // Safely close event controller
    if (_eventController != null && !_eventController!.isClosed) {
      _eventController!.close();
    }
    _eventController = null;

    _isRunning = false;
    _currentError = null;
    _currentMessage = null;
    _currentIssues.clear();
  }

  /// Validate print data before sending
  Future<Result<void>> _validatePrintData(String data) async {
    await _updateStep(PrintStep.validating, 'Validating print data');

    // Check for cancellation before validation
    if (isCancelled) {
      return Result.errorCode(ErrorCodes.operationCancelled);
    }

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

  /// Connect to printer with retry logic (delegated to CommunicationPolicy)
  Future<Result<void>> _connectToPrinter(ZebraDevice? device) async {
    while (_currentAttempt <= _maxAttempts &&
        !isCancelled) {
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
        final result = await _printerManager.connect(
          device,
          options: CommunicationPolicyOptions(
            cancellationToken: _cancellationToken,
          ),
        );
        
        if (result.success) {
          await _emitConnectionProgress('Connection established successfully');
          await Future.delayed(const Duration(milliseconds: 300));

          // Mark connecting step as completed
          await _updateStep(PrintStep.connected, 'Successfully connected to printer');
          
          // Emit completion event for the connecting step
          _eventController?.add(PrintEvent(
            type: PrintEventType.progressUpdate,
            timestamp: DateTime.now(),
            stepInfo: _createStepInfo(
                PrintStep.connecting, 'Connection completed'),
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
      
      if (_currentAttempt < _maxAttempts && !isCancelled) {
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

    // Check for cancellation before status check
    if (isCancelled) {
      return Result.errorCode(ErrorCodes.operationCancelled);
    }

    try {
      final printer = _printerManager.printer;
      if (printer == null) {
        return Result.errorCode(
          ErrorCodes.statusCheckFailed,
          formatArgs: ['No printer instance available'],
        );
      }
      final statusResult =
          await CommandFactory.createGetDetailedPrinterStatusCommand(printer)
              .execute();
      if (statusResult.success) {
        _lastPrinterStatus = statusResult.data;

        final status = statusResult.data;
        if (status != null) {
          final analysis = status['analysis'] as Map<String, dynamic>?;
          if (analysis != null) {
            final canPrint = analysis['canPrint'] as bool? ?? false;
            final blockingIssues =
                analysis['blockingIssues'] as List<dynamic>? ?? [];

            if (!canPrint && blockingIssues.isNotEmpty) {
              final firstIssue = blockingIssues.first.toString().toLowerCase();
              ErrorCode errorCode;
              if (firstIssue.contains('head open')) {
                errorCode = ErrorCodes.headOpen;
              } else if (firstIssue.contains('out of paper')) {
                errorCode = ErrorCodes.outOfPaper;
              } else if (firstIssue.contains('paused')) {
                errorCode = ErrorCodes.printerPaused;
              } else if (firstIssue.contains('ribbon')) {
                errorCode = ErrorCodes.ribbonError;
              } else if (firstIssue.contains('head too cold')) {
                errorCode = ErrorCodes.printerNotReady;
              } else if (firstIssue.contains('head too hot')) {
                errorCode = ErrorCodes.printerNotReady;
              } else {
                errorCode = ErrorCodes.statusCheckFailed;
              }
              return Result.errorCode(
                errorCode,
                formatArgs: [firstIssue],
              );
            }
          }
        }

        await _updateStep(
            PrintStep.checkingStatus, 'Printer is ready to print');
        return Result.success();
      } else {
        return Result.errorCode(
          ErrorCodes.statusCheckFailed,
          formatArgs: [statusResult.error?.message ?? 'Unknown status error'],
        );
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
    while (_currentAttempt <= _maxAttempts && !isCancelled) {
      await _updateStep(PrintStep.sending, 'Sending print data (attempt $_currentAttempt/$_maxAttempts)');
      
      try {
        final result = await _printerManager.print(
          data,
          options: PrintOptions(cancellationToken: _cancellationToken),
        );
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
      
      if (_currentAttempt < _maxAttempts && !isCancelled) {
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

  /// Wait for print completion with enhanced real-time status updates
  Future<Result<void>> _waitForPrintCompletion() async {
    await _updateStep(
        PrintStep.waitingForCompletion, 'Waiting for print completion');

    try {
      // Use enhanced status polling with better UX
      bool isCompleted = false;
      bool hasAutoResumed = false;
      String? lastProgressHint;

      await for (final status in _printerManager.startStatusPolling(
        interval: const Duration(milliseconds: 500),
        timeout: const Duration(seconds: 30),
        cancellationToken: _cancellationToken,
      )) {
        if (isCancelled) {
          return Result.errorCode(ErrorCodes.operationCancelled);
        }

        // Handle polling errors
        if (status['error'] != null) {
          _logger.warning('Status polling error: ${status['error']}');
          if (status['timeout'] == true) {
            return Result.errorCode(
              ErrorCodes.printError,
              formatArgs: [
                'Print completion timeout after ${status['elapsedSeconds']} seconds'
              ],
            );
          }
          // Continue polling on non-timeout errors
          continue;
        }

        // Store last status for debugging
        _lastPrinterStatus = status;

        // Emit enhanced real-time status update with richer metadata
        _emitEnhancedStatusUpdate(status);

        // Check for completion using enhanced detection
        if (status['isCompleted'] == true) {
          isCompleted = true;
          break;
        }

        // Handle auto-resume with better feedback
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

        // Enhanced issue handling with structured data
        final issueDetails = status['issueDetails'] as List<dynamic>? ?? [];
        if (issueDetails.isNotEmpty) {
          final issues = issueDetails
              .map((issue) => issue['message'] as String? ?? 'Unknown issue')
              .toList();
          
          if (issues.isNotEmpty) {
            await _updateStep(PrintStep.waitingForCompletion,
                'Waiting for user to fix: ${issues.join(', ')}');
          }
        }

        // Enhanced progress updates using progressHint
        final progressHint = status['progressHint'] as String?;
        if (progressHint != null && progressHint != lastProgressHint) {
          await _updateStep(PrintStep.waitingForCompletion, progressHint);
          lastProgressHint = progressHint;
        }
      }

      if (isCompleted) {
        _logger.info('Print completion successful via enhanced status polling');
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
    } finally {
      // No explicit _cancellationToken cleanup needed here
    }
  }

  /// Emit enhanced real-time status update event with richer metadata
  void _emitEnhancedStatusUpdate(Map<String, dynamic> status) {
    final issueDetails = status['issueDetails'] as List<dynamic>? ?? [];
    final progressHint = status['progressHint'] as String?;
    
    _eventController?.add(PrintEvent(
      type: PrintEventType.realTimeStatusUpdate,
      timestamp: DateTime.now(),
      metadata: {
        'status': status,
        'isCompleted': status['isCompleted'] ?? false,
        'hasIssues': status['hasIssues'] ?? false,
        'canAutoResume': status['canAutoResume'] ?? false,
        'issueDetails': issueDetails,
        'progressHint': progressHint,
        'autoResumeAction': _getAutoResumeAction(status),
        'progress': getProgress(),
        'currentStep': _currentStep.toString(),
        'consecutiveErrors': status['consecutiveErrors'],
        'enhancedMetadata': true, // Flag to indicate enhanced status
      },
    ));
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
    _currentMessage = message;
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
    // Check if recovery hint should be removed for auto-handled errors
    final shouldRemoveHint = _shouldRemoveRecoveryHint(errorCode);
    final effectiveRecoveryHint =
        shouldRemoveHint ? null : errorCode.recoveryHint;
    
    final errorInfo = PrintErrorInfo(
      message: errorCode.formatMessage(formatArgs),
      recoverability: _determineRecoverability(errorCode),
      errorCode: errorCode.code,
      stackTrace: stackTrace,
      recoveryHint: effectiveRecoveryHint,
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
        elapsed: DateTime.now().difference(_startTime ?? DateTime.now())
    );
  }

  /// Determine error recoverability
  ErrorRecoverability _determineRecoverability(ErrorCode errorCode) {
    switch (errorCode.category) {
      case ResultCategory.connection:
        return ErrorRecoverability.recoverable;
      case ResultCategory.operation:
        return ErrorRecoverability.recoverable;
      case ResultCategory.print:
        // Some print errors are recoverable (timeouts), others are not (hardware)
        if (errorCode.code == 'PRINT_TIMEOUT' ||
            errorCode.code == 'PRINTER_PAUSED') {
          return ErrorRecoverability.recoverable;
        }
        return ErrorRecoverability.nonRecoverable;
      case ResultCategory.data:
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
    
    // Break delay into smaller chunks to check for cancellation
    const checkInterval = Duration(milliseconds: 500);
    final totalMs = delay.inMilliseconds;
    var elapsedMs = 0;

    while (elapsedMs < totalMs) {
      // Check for cancellation during delay
      if (isCancelled) {
        _logger
            .info('Retry delay cancelled after ${elapsedMs}ms of ${totalMs}ms');
        return;
      }

      final remainingMs = totalMs - elapsedMs;
      final delayMs = math.min(checkInterval.inMilliseconds, remainingMs);

      await Future.delayed(Duration(milliseconds: delayMs));
      elapsedMs += delayMs;
    }
  }

  /// Cleanup resources with enhanced safety
  void _cleanup() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
    
    // Cancel and clear cancellation token
    _cancellationToken?.cancel();
    _cancellationToken = null;
    
    // Safely close event controller
    if (_eventController != null && !_eventController!.isClosed) {
      _eventController!.close();
    }
    _eventController = null;
    
    _isRunning = false;
    _currentError = null;
    _currentMessage = null;
    _currentIssues.clear();
  }

  /// Dispose of the SmartPrintManager and cleanup all resources
  void dispose() {
    _logger.info('Disposing SmartPrintManager');

    // Cancel any ongoing operations
    if (_isRunning) {
      cancel();
    }

    // Final cleanup
    _cleanup();

    // Clear state
    _lastPrinterStatus = null;
    _startTime = null;
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


  /// Check if operation is cancelled
  bool get isCancelled => _cancellationToken?.isCancelled ?? false;

  /// Check if there's an active operation that can be cancelled
  bool get canCancel => _isRunning && !isCancelled;

  /// Get current print status for UI
  PrintStatus get currentStatus {
    if (isCancelled) return PrintStatus.cancelled;
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

  /// Get current cancellation token (for internal use by workflows)
  CancellationToken? get cancellationToken => _cancellationToken;

  /// Force cancel any ongoing operation (alternative to cancel() for external use)
  /// Returns true if an operation was cancelled, false if no operation was running
  bool forceCancel() {
    if (!canCancel) {
      return false;
    }
    cancel();
    return true;
  }

  /// Determine if recovery hint should be removed because SmartPrintManager auto-recovers
  bool _shouldRemoveRecoveryHint(ErrorCode errorCode) {
    // Connection errors that SmartPrintManager auto-retries with exponential backoff
    if (errorCode.category == ResultCategory.connection) {
      if (errorCode == ErrorCodes.connectionError ||
          errorCode == ErrorCodes.connectionTimeout ||
          errorCode == ErrorCodes.connectionLost ||
          errorCode == ErrorCodes.networkError ||
          errorCode == ErrorCodes.connectionFailed ||
          errorCode == ErrorCodes.connectionRetryFailed) {
        return true; // These are auto-retried by _connectToPrinter
      }
    }

    // Print errors that SmartPrintManager auto-retries
    if (errorCode.category == ResultCategory.print) {
      if (errorCode == ErrorCodes.printError ||
          errorCode == ErrorCodes.printTimeout ||
          errorCode == ErrorCodes.printFailed ||
          errorCode == ErrorCodes.printRetryFailed) {
        return true; // These are auto-retried by _sendPrintData
      }
      // Auto-unpause capability
      if (errorCode == ErrorCodes.printerPaused) {
        return true; // SmartPrintManager can auto-unpause via _waitForPrintCompletion
      }
    }

    // Operation errors that SmartPrintManager handles
    if (errorCode.category == ResultCategory.operation) {
      if (errorCode == ErrorCodes.operationTimeout ||
          errorCode == ErrorCodes.operationError ||
          errorCode == ErrorCodes.operationCancelled) {
        return true; // These are handled by the overall workflow
      }
    }

    // Status errors that SmartPrintManager retries
    if (errorCode.category == ResultCategory.status) {
      if (errorCode == ErrorCodes.statusCheckFailed ||
          errorCode == ErrorCodes.statusTimeout ||
          errorCode == ErrorCodes.statusUnknownError ||
          errorCode == ErrorCodes.statusCheckUnknownError ||
          errorCode == ErrorCodes.detailedStatusUnknownError) {
        return true; // Status checks are auto-retried
      }
    }

    // Data validation errors handled by SmartPrintManager
    if (errorCode.category == ResultCategory.data) {
      if (errorCode == ErrorCodes.emptyData ||
          errorCode == ErrorCodes.printDataTooLarge) {
        return true; // These are pre-validated, no user action needed
      }
    }

    // Hardware errors that REQUIRE user intervention - keep recovery hints
    if (errorCode.category == ResultCategory.print) {
      if (errorCode == ErrorCodes.headOpen ||
          errorCode == ErrorCodes.outOfPaper ||
          errorCode == ErrorCodes.ribbonError ||
          errorCode == ErrorCodes.ribbonOut ||
          errorCode == ErrorCodes.printerNotReady ||
          errorCode == ErrorCodes.temperatureError ||
          errorCode == ErrorCodes.printHeadError ||
          errorCode == ErrorCodes.printerJammed ||
          errorCode == ErrorCodes.mediaError ||
          errorCode == ErrorCodes.calibrationRequired) {
        return false; // Keep recovery hints for user intervention
      }
    }

    // Permission/bluetooth errors - only remove if truly auto-recoverable
    if (errorCode.category == ResultCategory.discovery) {
      if (errorCode == ErrorCodes.discoveryError ||
          errorCode == ErrorCodes.discoveryTimeout) {
        return true; // Discovery is auto-retried
      }
      // Keep hints for permission/bluetooth issues as they require user action
      if (errorCode == ErrorCodes.bluetoothDisabled ||
          errorCode == ErrorCodes.noPermission) {
        return false; // User must enable Bluetooth/grant permissions
      }
    }

    // Keep recovery hints for errors that require user intervention
    return false;
  }
} 