import 'dart:async';


import 'internal/logger.dart';
import 'models/communication_policy_event.dart';
import 'models/communication_policy_options.dart';
import 'models/print_enums.dart';
import 'models/print_event.dart';
import 'models/print_options.dart';
import 'models/result.dart';
import 'models/zebra_device.dart';
import 'zebra_printer_manager.dart';
import 'zebra_sgd_commands.dart';

/// Smart print manager for handling complex print workflows
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
  bool _isCancelled = false;
  DateTime? _startTime;
  Map<String, dynamic>? _lastPrinterStatus;
  PrintStep _currentStep = PrintStep.initializing;
  int _currentAttempt = 1;
  int _maxAttempts = 3;

  // Synchronization lock for thread safety
  bool _isRunning = false;

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
    // Prevent concurrent smart print operations
    if (_isRunning) {
      yield PrintEvent(
        type: PrintEventType.errorOccurred,
        timestamp: DateTime.now(),
        errorInfo: PrintErrorInfo(
          message: 'Another print operation is already in progress',
          recoverability: ErrorRecoverability.nonRecoverable,
          errorCode: ErrorCodes.operationError.code,
        ),
      );
      return;
    }

    _isRunning = true;
    _isCancelled = false;
    _currentAttempt = 1;
    _maxAttempts = maxAttempts;
    _startTime = DateTime.now();

    // Create new event controller for this print operation
    await _eventController?.close();
    _eventController = StreamController<PrintEvent>();

    // Convert null options to empty instance to avoid ?? operators throughout
    options ??= const PrintOptions();

    // Run the print workflow in the background FIRST (this produces the events)
    _runPrintWorkflow(
      data: data,
      device: device,
      timeout: timeout,
      options: options,
    );

    // Then yield the event stream (this consumes the events)
    yield* eventStream;
  }

  /// Execute the smart print workflow
  Future<void> _runPrintWorkflow({
    required String data,
    ZebraDevice? device,
    required Duration timeout,
    required PrintOptions options,
  }) async {

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
      // Step 1: Initialize and detect format
      await _updateStep(PrintStep.initializing, 'Initializing print operation');

      // Detect format from PrintOptions or data
      final PrintFormat? format =
          options.formatOrDefault ?? ZebraSGDCommands.detectDataLanguage(data);
      if (format == null) {
        _eventController?.add(PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: 'Unknown or unsupported print format',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: ErrorCodes.printDataInvalidFormat.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Invalid print format'),
        ));
        return;
      }
      _logger.info('Smart print format: ${format.name}');

      // Update printOptions with the detected format
      if (options.format != format) {
        options = options.copyWith(PrintOptions(format: format));
      }

      // Step 2: Validate data
      final validationResult = await _validatePrintData(data);
      if (!validationResult.success) {
        _eventController?.add(PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: validationResult.error?.message ?? 'Validation failed',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: validationResult.error?.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Validation failed'),
        ));
        return;
      }

      // Step 3: Connect to printer
      final connectResult = await _connectToPrinter(device);
      if (!connectResult.success) {
        _eventController?.add(PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: connectResult.error?.message ?? 'Connection failed',
            recoverability: ErrorRecoverability.recoverable,
            errorCode: connectResult.error?.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Connection failed'),
        ));
        return;
      }

      // Step 4: Check printer status using ReadinessOptions from PrintOptions
      final readinessOptions = options.readinessOptionsOrDefault;

      // Only perform status checks if any check flags are enabled
      if (readinessOptions.hasAnyCheckEnabled) {
        final readinessManager = _printerManager.readinessManager;
        if (readinessManager == null) {
          _eventController?.add(PrintEvent(
            type: PrintEventType.errorOccurred,
            timestamp: DateTime.now(),
            errorInfo: PrintErrorInfo(
              message: 'Readiness manager not available',
              recoverability: ErrorRecoverability.nonRecoverable,
              errorCode: ErrorCodes.statusCheckFailed.code,
            ),
            stepInfo: _createStepInfo(PrintStep.failed, 'Status check failed'),
          ));
          return;
        }
        
        final readinessResult = await readinessManager.prepareForPrint(
          format,
          readinessOptions,
          onStatus: (event) {
            _eventController?.add(PrintEvent(
              type: PrintEventType.statusUpdate,
              timestamp: DateTime.now(),
              stepInfo:
                  _createStepInfo(PrintStep.checkingStatus, event.message),
            ));
          },
        );
        if (!readinessResult.success) {
          _eventController?.add(PrintEvent(
            type: PrintEventType.errorOccurred,
            timestamp: DateTime.now(),
            errorInfo: PrintErrorInfo(
              message: readinessResult.error?.message ?? 'Status check failed',
              recoverability: ErrorRecoverability.nonRecoverable,
              errorCode: readinessResult.error?.code,
            ),
            stepInfo: _createStepInfo(PrintStep.failed, 'Status check failed'),
          ));
          return;
        }
        final result = readinessResult.data!;
        _lastPrinterStatus = result.readiness.cachedValues;
        if (!result.isReady) {
          _eventController?.add(PrintEvent(
            type: PrintEventType.errorOccurred,
            timestamp: DateTime.now(),
            errorInfo: PrintErrorInfo(
              message: result.summary,
              recoverability: ErrorRecoverability.nonRecoverable,
              errorCode: ErrorCodes.printerNotReady.code,
            ),
            stepInfo: _createStepInfo(PrintStep.failed, 'Printer not ready'),
          ));
          return;
        }
      }

      // Step 5: Send print data
      final printResult = await _sendPrintData(data, timeout, options);
      if (!printResult.success) {
        _eventController?.add(PrintEvent(
          type: PrintEventType.errorOccurred,
          timestamp: DateTime.now(),
          errorInfo: PrintErrorInfo(
            message: printResult.error?.message ?? 'Print failed',
            recoverability: ErrorRecoverability.nonRecoverable,
            errorCode: printResult.error?.code,
          ),
          stepInfo: _createStepInfo(PrintStep.failed, 'Print failed'),
        ));
        return;
      }

      // Step 6: Wait for completion (if enabled)
      if (options.waitForPrintCompletionOrDefault) {
        await _updateStep(
            PrintStep.waitingForCompletion, 'Waiting for print completion');
        final completionResult =
            await _printerManager.waitForPrintCompletion(data, format);
        if (!completionResult.success) {
          _eventController?.add(PrintEvent(
            type: PrintEventType.errorOccurred,
            timestamp: DateTime.now(),
            errorInfo: PrintErrorInfo(
              message: completionResult.error?.message ?? 'Completion failed',
              recoverability: ErrorRecoverability.nonRecoverable,
              errorCode: completionResult.error?.code,
            ),
            stepInfo: _createStepInfo(PrintStep.failed, 'Completion failed'),
          ));
          return;
        }
      }

      // Step 6.5: Complete
      await _updateStep(
          PrintStep.completed, 'Print operation completed successfully');
      _eventController?.add(PrintEvent(
        type: PrintEventType.completed,
        timestamp: DateTime.now(),
        stepInfo:
            _createStepInfo(PrintStep.completed, 'Print operation completed'),
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
  void cancel() {
    _logger.info('Cancelling print operation');
    _isCancelled = true;
    _cleanup();
    _updateStep(PrintStep.cancelled, 'Print operation cancelled');
    _eventController?.add(PrintEvent(
      type: PrintEventType.cancelled,
      timestamp: DateTime.now(),
      stepInfo:
          _createStepInfo(PrintStep.cancelled, 'Print operation cancelled'),
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

  /// Connect to printer with retry logic (delegated to CommunicationPolicy)
  Future<Result<void>> _connectToPrinter(ZebraDevice? device) async {
    await _updateStep(PrintStep.connecting, 'Connecting to printer...');

    return await _printerManager.connect(
      device,
      options: CommunicationPolicyOptions(
        skipConnectionCheck: true,
        skipConnectionRetry: false,
        maxAttempts: _maxAttempts,
        onEvent: (event) {
          // Forward retry/status events as PrintEventType.retryAttempt or statusUpdate
          if (event.type == CommunicationPolicyEventType.retry) {
            _eventController?.add(PrintEvent(
              type: PrintEventType.retryAttempt,
              timestamp: DateTime.now(),
              stepInfo: _createStepInfo(
                PrintStep.connecting,
                event.message,
              ),
            ));
          } else if (event.type == CommunicationPolicyEventType.attempt) {
            _eventController?.add(PrintEvent(
              type: PrintEventType.statusUpdate,
              timestamp: DateTime.now(),
              stepInfo: _createStepInfo(
                PrintStep.connecting,
                event.message,
              ),
            ));
          } else if (event.type == CommunicationPolicyEventType.error) {
            _eventController?.add(PrintEvent(
              type: PrintEventType.errorOccurred,
              timestamp: DateTime.now(),
              errorInfo: PrintErrorInfo(
                message: event.message,
                recoverability: ErrorRecoverability.recoverable,
                nativeError: event.error,
              ),
              stepInfo: _createStepInfo(PrintStep.failed, event.message),
            ));
          }
        },
      ),
    );
  }

  /// Send print data with retry logic (delegated to CommunicationPolicy)
  Future<Result<void>> _sendPrintData(
      String data, Duration timeout, PrintOptions options) async {
    await _updateStep(PrintStep.sending, 'Sending print data...');

    return await _printerManager.communicationPolicy!.execute(
      () async {
        // Use the provided options which already contain the format and other settings
        return await _printerManager.print(data, options: options);
      },
      'Send Print Data',
      options: CommunicationPolicyOptions(
        maxAttempts: _maxAttempts,
        timeout: timeout,
        skipConnectionCheck: false,
        skipConnectionRetry: false,
        onEvent: (event) {
          if (event.type == CommunicationPolicyEventType.retry) {
            _eventController?.add(PrintEvent(
              type: PrintEventType.retryAttempt,
              timestamp: DateTime.now(),
              stepInfo: _createStepInfo(
                PrintStep.sending,
                event.message,
              ),
            ));
          } else if (event.type == CommunicationPolicyEventType.attempt) {
            _eventController?.add(PrintEvent(
              type: PrintEventType.statusUpdate,
              timestamp: DateTime.now(),
              stepInfo: _createStepInfo(
                PrintStep.sending,
                event.message,
              ),
            ));
          } else if (event.type == CommunicationPolicyEventType.error) {
            _eventController?.add(PrintEvent(
              type: PrintEventType.errorOccurred,
              timestamp: DateTime.now(),
              errorInfo: PrintErrorInfo(
                message: event.message,
                recoverability: ErrorRecoverability.recoverable,
                nativeError: event.error,
              ),
              stepInfo: _createStepInfo(PrintStep.failed, event.message),
            ));
          }
        },
      ),
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
      recoverability: _mapCategoryToRecoverability(errorCode.category),
      errorCode: errorCode.code,
      stackTrace: stackTrace,
      recoveryHint: errorCode.recoveryHint,
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

  /// Cleanup resources
  void _cleanup() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
    _eventController?.close();
    _eventController = null;
    _isRunning = false;
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


  /// Check if operation is cancelled
  bool get isCancelled => _isCancelled;

  /// Map ErrorCode category to ErrorRecoverability
  ErrorRecoverability _mapCategoryToRecoverability(ResultCategory category) {
    switch (category) {
      case ResultCategory.connection:
        return ErrorRecoverability.recoverable;
      case ResultCategory.operation:
        return ErrorRecoverability.recoverable;
      case ResultCategory.print:
        return ErrorRecoverability.possiblyRecoverable;
      case ResultCategory.data:
        return ErrorRecoverability.nonRecoverable;
      case ResultCategory.discovery:
        return ErrorRecoverability.recoverable;
      case ResultCategory.status:
        return ErrorRecoverability.recoverable;
      case ResultCategory.configuration:
        return ErrorRecoverability.possiblyRecoverable;
      case ResultCategory.command:
        return ErrorRecoverability.recoverable;
      case ResultCategory.platform:
        return ErrorRecoverability.possiblyRecoverable;
      case ResultCategory.system:
        return ErrorRecoverability.possiblyRecoverable;
      case ResultCategory.validation:
        return ErrorRecoverability.nonRecoverable;
    }
  }
}
