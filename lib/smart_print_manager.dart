import 'dart:async';
import 'dart:math' as math;

import 'internal/logger.dart';
import 'models/communication_policy_options.dart';
import 'models/print_enums.dart';
import 'models/print_event.dart';
import 'models/print_operation_tracker.dart';
import 'models/print_options.dart';
import 'models/print_state.dart';
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'zebra_printer_manager.dart';
import 'zebra_printer_readiness_manager.dart';
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

  // Immutable state management
  PrintState _currentState = PrintState.initial();
  
  // Cancellation management
  CancellationToken? _cancellationToken;

  /// Get the current immutable print state
  /// Callers cannot modify this state directly
  PrintState get currentState => _currentState;

  /// Get the event stream for monitoring print progress
  /// This returns a broadcast stream that can have multiple listeners
  Stream<PrintEvent> get eventStream {
    _eventController ??= StreamController<PrintEvent>.broadcast();
    return _eventController!.stream;
  }

  /// Emit an event to all listeners
  void _emitEvent(PrintEvent event) {
    if (_eventController != null && !_eventController!.isClosed) {
      _eventController!.add(event);
    }
  }

  /// Smart print operation with comprehensive workflow
  /// This method no longer yields - all events go through eventStream
  Future<void> smartPrint({
    required String data,
    ZebraDevice? device,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 60),
    PrintOptions? options,
  }) async {
    if (_currentState.isRunning) {
      _emitEvent(PrintEvent(
        type: PrintEventType.errorOccurred,
        timestamp: DateTime.now(),
        errorInfo: const PrintErrorInfo(
          message: 'Another print operation is already in progress',
          recoverability: ErrorRecoverability.nonRecoverable,
          errorCode: 'OPERATION_ERROR',
        ),
        printState: _currentState,
      ));
      return;
    }

    // Initialize state for new operation - ensure clean start
    _currentState = PrintState(
      currentStep: PrintStep.initializing,
      isRunning: true,
      currentMessage: 'Initializing print operation',
      currentError: null, // Clear any previous errors
      currentIssues: const [],
      canAutoResume: false,
      autoResumeAction: null,
      isWaitingForUserFix: false,
      currentAttempt: 1,
      maxAttempts: maxAttempts,
      progress: 0.0,
      isCompleted: false,
      isCancelled: false,
      startTime: DateTime.now(),
      elapsedTime: Duration.zero,
    );
    
    // Create and store cancellation token for this operation
    _cancellationToken = CancellationToken();
    
    // Ensure event controller is initialized
    _eventController ??= StreamController<PrintEvent>.broadcast();
    
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
        _emitEvent(PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: const PrintErrorInfo(
            message: 'Unknown or unsupported print format',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: 'PRINT_DATA_INVALID_FORMAT',
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Invalid print format'),
          printState: _currentState,
        ));
        return;
      }
      _logger.info('Smart print format: ${format.name}');

      // Ensure options is always set
      options = options?.copyWith(PrintOptions(format: format)) ??
          PrintOptions(format: format);

      final validationResult = await _validatePrintData(data);
      if (!validationResult.success) {
        _emitEvent(PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: validationResult.error?.message ?? 'Validation failed',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: validationResult.error?.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Validation failed'),
          printState: _currentState,
        ));
        return;
      }

      // Check for cancellation before connection attempt
      if (isCancelled) {
        _emitEvent(PrintEvent(
          type: PrintEventType.cancelled,
          timestamp: DateTime.now(),
          stepInfo:
              _createStepInfo(PrintStep.cancelled, 'Print operation cancelled'),
          printState: _currentState,
        ));
        return;
      }

      final connectResult = await _connectToPrinter(device);
      if (!connectResult.success) {
        // Check if failure was due to cancellation
        if (connectResult.error?.code == 'OPERATION_CANCELLED' || isCancelled) {
          _emitEvent(PrintEvent(
            type: PrintEventType.cancelled,
            timestamp: DateTime.now(),
            stepInfo:
                _createStepInfo(PrintStep.cancelled, 'Connection cancelled'),
            printState: _currentState,
          ));
          return;
        }
        
        _emitEvent(PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: connectResult.error?.message ?? 'Connection failed',
            recoverability: ErrorRecoverability.recoverable,
            errorCode: connectResult.error?.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Connection failed'),
          printState: _currentState,
        ));
        return;
      }
      
      // Use readiness manager for comprehensive status checking and preparation
      final readinessResult = await _preparePrinterForPrint(format, options);
      if (!readinessResult.success) {
        _emitEvent(PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message:
                readinessResult.error?.message ?? 'Printer preparation failed',
            recoverability: ErrorRecoverability.recoverable,
            errorCode: readinessResult.error?.code,
          ),
          stepInfo:
              _createStepInfo(PrintStep.failed, 'Printer preparation failed'),
          printState: _currentState,
        ));
        return;
      }

      // Update options with cancellation token
      options =
          options.copyWith(PrintOptions(cancellationToken: _cancellationToken));

      final printResult = await _sendPrintData(data, timeout);
      if (!printResult.success) {
        // Check if failure was due to cancellation
        if (printResult.error?.code == 'OPERATION_CANCELLED' || isCancelled) {
          _emitEvent(PrintEvent(
            type: PrintEventType.cancelled,
            timestamp: DateTime.now(),
            stepInfo:
                _createStepInfo(PrintStep.cancelled, 'Print sending cancelled'),
            printState: _currentState,
          ));
          return;
        }
        
        _emitEvent(PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: printResult.error?.message ?? 'Print failed',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: printResult.error?.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Print failed'),
          printState: _currentState,
        ));
        return;
      }
      
      // Get the tracker from the print result
      final tracker = printResult.data;

      if (options.waitForPrintCompletionOrDefault && tracker != null) {
        // Check for cancellation before waiting for completion
        if (isCancelled) {
          _emitEvent(PrintEvent(
            type: PrintEventType.cancelled,
            timestamp: DateTime.now(),
            stepInfo: _createStepInfo(
                PrintStep.cancelled, 'Print completion wait cancelled'),
            printState: _currentState,
          ));
          return;
        }
        
        await _updateStep(
            PrintStep.waitingForCompletion, 'Waiting for print completion');

        final completionResult = await tracker.waitForCompletion(
          data: data,
          format: options.formatOrDefault ?? PrintFormat.zpl,
          onStatusUpdate: (status) {
            _emitEvent(PrintEvent(
              type: PrintEventType.statusUpdate,
              timestamp: DateTime.now(),
              printState: _currentState,
              metadata: {
                'message': status,
                'progressHint': status,
                'isReady': false,
                'canAutoResume': false,
                'issueDetails': [],
                'autoResumeAction': null,
                'progress': _currentState.getProgress(),
                'currentStep': _currentState.currentStep.toString(),
                'consecutiveErrors': 0,
                'enhancedMetadata': true,
              },
            ));
          },
        );
        
        if (!completionResult.success) {
          // Check if failure was due to cancellation
          if (completionResult.error?.code == 'OPERATION_CANCELLED' ||
              isCancelled) {
            _emitEvent(PrintEvent(
              type: PrintEventType.cancelled,
              timestamp: DateTime.now(),
              stepInfo: _createStepInfo(
                  PrintStep.cancelled, 'Print completion cancelled'),
              printState: _currentState,
            ));
            return;
          }
          
          _emitEvent(PrintEvent(
            type: PrintEventType.errorOccurred,
            timestamp: DateTime.now(),
            errorInfo: PrintErrorInfo(
              message: completionResult.error?.message ?? 'Completion failed',
              recoverability: ErrorRecoverability.nonRecoverable,
              errorCode: completionResult.error?.code,
            ),
            stepInfo: _createStepInfo(PrintStep.failed, 'Completion failed'),
            printState: _currentState,
          ));
          return;
        }
      }

      await _updateStep(PrintStep.completed, 'Print operation completed successfully');
      _emitEvent(PrintEvent(
        type: PrintEventType.completed,
        timestamp: DateTime.now(),
        stepInfo: _createStepInfo(PrintStep.completed, 'Print operation completed'),
        printState: _currentState.copyWith(isCompleted: true),
      ));
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
    if (!_currentState.isRunning && !isCancelled) {
      _logger.debug('No active print operation to cancel');
      return;
    }

    _logger.info(
        'Cancelling print operation at step: ${_currentState.currentStep}');
    
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
        'Print operation cancelled during step: ${_currentState.currentStep} (attempt ${_currentState.currentAttempt}/${_currentState.maxAttempts})');

    // Update state to cancelled - preserve the error if it exists
    _currentState = _currentState.copyWith(
      currentStep: PrintStep.cancelled,
      currentMessage: 'Print operation cancelled by user',
      isCancelled: true,
      isRunning: false,
      // Keep currentError for UI to display what went wrong before cancellation
    );

    // Emit cancellation event with context about what was cancelled
    _emitEvent(PrintEvent(
      type: PrintEventType.cancelled,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(PrintStep.cancelled, 'Print operation cancelled'),
      printState: _currentState,
      metadata: {
        'cancelledAtStep': _currentState.currentStep.toString(),
        'cancelledAtAttempt': _currentState.currentAttempt,
        'totalAttempts': _currentState.maxAttempts,
        'elapsedMs': DateTime.now()
            .difference(_currentState.startTime ?? DateTime.now())
            .inMilliseconds,
      },
    ));
    
    // Perform cleanup but don't clear the error state
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

    // Reset state but preserve error for UI
    _currentState = _currentState.copyWith(
      isRunning: false,
      // Don't clear currentError - UI may still need to display it
      // Don't clear currentMessage - it contains the final status
      autoResumeAction: null,
      canAutoResume: false,
      isWaitingForUserFix: false,
      currentIssues: [],
    );
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
    while (_currentState.currentAttempt <= _currentState.maxAttempts &&
        !isCancelled) {
      // Start connection with progress indicator
      await _updateStep(PrintStep.connecting, 'Connecting to printer');
      
      // Emit progress event for UI animation
      _emitEvent(PrintEvent(
        type: PrintEventType.stepChanged,
        timestamp: DateTime.now(),
        stepInfo: _createStepInfo(PrintStep.connecting,
            'Connecting to printer'),
        printState: _currentState,
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
          _emitEvent(PrintEvent(
            type: PrintEventType.progressUpdate,
            timestamp: DateTime.now(),
            stepInfo: _createStepInfo(
                PrintStep.connecting, 'Connection completed'),
            printState: _currentState,
          ));

          // Emit the connected step
          _emitEvent(PrintEvent(
            type: PrintEventType.stepChanged,
            timestamp: DateTime.now(),
            stepInfo: _createStepInfo(
                PrintStep.connected, 'Successfully connected to printer'),
            printState: _currentState,
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
      
      if (_currentState.currentAttempt < _currentState.maxAttempts &&
          !isCancelled) {
        await _retryDelay();
        _currentState = _currentState.copyWith(
          currentAttempt: _currentState.currentAttempt + 1,
        );
      } else {
        break;
      }
    }
    
    return Result.errorCode(
      ErrorCodes.connectionRetryFailed,
      formatArgs: [_currentState.maxAttempts],
    );
  }

  /// Emit connection progress updates for UI animation
  Future<void> _emitConnectionProgress(String message) async {
    _emitEvent(PrintEvent(
      type: PrintEventType.stepChanged,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(PrintStep.connecting, message),
      printState: _currentState,
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

  /// Prepare printer for print operation using readiness manager
  Future<Result<void>> _preparePrinterForPrint(
      PrintFormat format, PrintOptions options) async {
    await _updateStep(PrintStep.checkingStatus, 'Preparing printer for print');

    // Check for cancellation before preparation
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

      // Use readiness manager for comprehensive status checking and preparation
      final readinessManager = ZebraPrinterReadinessManager(
        printer: printer,
        statusCallback: (event) {
          // Forward readiness events to our event stream
          _emitEvent(PrintEvent(
            type: PrintEventType.statusUpdate,
            timestamp: DateTime.now(),
            printState: _currentState,
            metadata: {
              'readinessEvent': event,
              'message': event.message,
              'operationType': event.operationType.toString(),
              'operationKind': event.operationKind.toString(),
              'result': event.result.toString(),
              'errorDetails': event.errorDetails,
              'isReady': event.readiness.isReady,
              'canAutoResume':
                  false, // Will be updated by completion monitoring
              'issueDetails': [],
              'progressHint': event.message,
              'autoResumeAction': null,
              'progress': _currentState.getProgress(),
              'currentStep': _currentState.currentStep.toString(),
              'consecutiveErrors': 0,
              'enhancedMetadata': true,
            },
          ));
        },
      );

      // Create readiness options based on print options
      final readinessOptions = options.readinessOptionsOrDefault;

      final prepareResult = await readinessManager.prepareForPrint(
        format,
        readinessOptions,
      );

      if (!prepareResult.success) {
        return Result.errorCode(
          ErrorCodes.statusCheckFailed,
          formatArgs: [
            prepareResult.error?.message ?? 'Printer preparation failed'
          ],
        );
      }

      final readiness = prepareResult.data!;
      if (!readiness.isReady) {
        _logger.warning(
            'Printer not fully ready after preparation: ${readiness.summary}');
        // Continue anyway as some issues might be non-blocking
      } else {
        _logger.info('Printer prepared successfully');
      }

      // Emit final readiness status
      _emitEvent(PrintEvent(
        type: PrintEventType.statusUpdate,
        timestamp: DateTime.now(),
        printState: _currentState,
        metadata: {
          'isReady': readiness.isReady,
          'canAutoResume':
              false, // This will be updated by _waitForPrintCompletion
          'issueDetails': readiness.failedFixes,
          'progressHint': 'Printer ready for print',
          'autoResumeAction': null,
          'progress': _currentState.getProgress(),
          'currentStep': _currentState.currentStep.toString(),
          'consecutiveErrors': 0,
          'enhancedMetadata': true,
          'readinessResult': readiness,
        },
      ));

      return Result.success();
    } catch (e, stack) {
      _logger.error('Exception during printer preparation', e, stack);
      return Result.errorCode(
        ErrorCodes.statusCheckFailed,
        formatArgs: ['Exception: $e'],
        dartStackTrace: stack,
      );
    }
  }

  /// Send print data with retry logic and return tracker
  Future<Result<PrintOperationTracker>> _sendPrintData(
      String data, Duration timeout) async {
    while (_currentState.currentAttempt <= _currentState.maxAttempts &&
        !isCancelled) {
      await _updateStep(PrintStep.sending,
          'Sending print data (attempt ${_currentState.currentAttempt}/${_currentState.maxAttempts})');
      
      try {
        final result = await _printerManager.print(
          data,
          options: PrintOptions(cancellationToken: _cancellationToken),
        );
        if (result.success) {
          final tracker = result.data;
          if (tracker != null) {
            _logger.info(
                'Received tracker from print operation: ${tracker.operationId}');
            return Result.success(tracker);
          } else {
            _logger
                .warning('Print operation succeeded but no tracker returned');
            return Result.errorCode(
              ErrorCodes.printError,
              formatArgs: [
                'Print operation succeeded but no tracker available'
              ],
            );
          }
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
      
      if (_currentState.currentAttempt < _currentState.maxAttempts &&
          !isCancelled) {
        await _retryDelay();
        _currentState = _currentState.copyWith(
          currentAttempt: _currentState.currentAttempt + 1,
        );
      } else {
        break;
      }
    }
    
    return Result.errorCode(
      ErrorCodes.printRetryFailed,
      formatArgs: [_currentState.maxAttempts],
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









  /// Update current step and emit event
  Future<void> _updateStep(PrintStep step, String message) async {
    _currentState = _currentState.copyWith(
      currentStep: step,
      currentMessage: message,
      progress: _currentState.getProgress(),
      elapsedTime:
          DateTime.now().difference(_currentState.startTime ?? DateTime.now()),
    );
    
    _logger.info('Print step: $step - $message');
    
    _emitEvent(PrintEvent(
      type: PrintEventType.stepChanged,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(step, message),
      printState: _currentState,
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

    // Update state with error
    _currentState = _currentState.copyWith(
      currentError: errorInfo,
      currentStep: PrintStep.failed,
    );

    _emitEvent(PrintEvent(
      type: PrintEventType.errorOccurred,
      timestamp: DateTime.now(),
      errorInfo: errorInfo,
      stepInfo: _createStepInfo(PrintStep.failed, errorInfo.message),
      printState: _currentState,
    ));
  }

  /// Create step info for current state
  PrintStepInfo _createStepInfo(PrintStep step, String message) {
    return PrintStepInfo(
      step: step,
      message: message,
        attempt: _currentState.currentAttempt,
        maxAttempts: _currentState.maxAttempts,
        elapsed: DateTime.now()
            .difference(_currentState.startTime ?? DateTime.now())
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
        Duration(
        seconds: math.min(baseDelay * _currentState.currentAttempt, maxDelay));
    
    _logger.info('Waiting ${delay.inSeconds} seconds before retry');
    
    _emitEvent(PrintEvent(
      type: PrintEventType.retryAttempt,
      timestamp: DateTime.now(),
      stepInfo: _createStepInfo(
          _currentState.currentStep, 'Retrying in ${delay.inSeconds} seconds'),
      printState: _currentState,
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
    
    // DO NOT reset the current state - preserve it for UI display
    // The final state (success/failure/cancelled) should remain visible
    // Only mark as not running to indicate operation is complete
    _currentState = _currentState.copyWith(
      isRunning: false,
      // Keep all other state including errors, messages, completion status
      // This allows UI to continue showing the final result
    );
  }

  /// Dispose of the SmartPrintManager and cleanup all resources
  void dispose() {
    _logger.info('Disposing SmartPrintManager');

    // Cancel any ongoing operations
    if (_currentState.isRunning) {
      cancel();
    }

    // Final cleanup
    _cleanup();

    // DO NOT reset state here - let the UI decide when to clear
    // This allows the final print status to persist even after disposal
  }

  /// Get current progress as percentage
  double getProgress() => _currentState.getProgress();

  /// Get current step description
  String getCurrentStepDescription() {
    switch (_currentState.currentStep) {
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




  /// Check if operation is cancelled
  bool get isCancelled => _cancellationToken?.isCancelled ?? false;

  /// Check if there's an active operation that can be cancelled
  bool get canCancel => _currentState.isRunning && !isCancelled;

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