import 'dart:async';
import 'models/result.dart';
import 'models/readiness_options.dart';
import 'models/zebra_device.dart';
import 'models/print_enums.dart';
import 'models/print_event.dart';
import 'models/print_options.dart';
import 'models/communication_policy_event.dart';
import 'models/communication_policy_options.dart';
import 'zebra_printer_manager.dart';
import 'zebra_sgd_commands.dart';
import 'internal/logger.dart';

/// Smart print manager for handling complex print workflows
class SmartPrintManager {
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
  final bool _isConnected = false;
  DateTime? _startTime;
  Map<String, dynamic>? _lastPrinterStatus;
  PrintStep _currentStep = PrintStep.initializing;
  int _currentAttempt = 1;
  int _maxAttempts = 3;
  String? _lastPrintData;
  PrintFormat? _lastPrintFormat;
  
  // Synchronization lock for thread safety
  bool _isRunning = false;
  
  SmartPrintManager(this._printerManager);

  /// Get the event stream for monitoring print progress
  Stream<PrintEvent> get eventStream {
    _eventController ??= StreamController<PrintEvent>.broadcast();
    return _eventController!.stream;
  }

  /// Smart print operation with comprehensive workflow
  Stream<PrintEvent> smartPrint({
    required String data,
    ZebraDevice? device,
    PrintFormat? format,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 60),
    bool checkStatusBeforePrint = true,
    bool waitForCompletion = true,
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
    _lastPrintData = null;
    _lastPrintFormat = null;
    
    // Create new event controller for this print operation
    await _eventController?.close();
    _eventController = StreamController<PrintEvent>.broadcast();
    
    // Start the print workflow
    yield* eventStream;

    // Run the print workflow in the background
    _runPrintWorkflow(
      data: data,
      device: device,
      format: format,
      timeout: timeout,
      checkStatusBeforePrint: checkStatusBeforePrint,
      waitForCompletion: waitForCompletion,
    );
  }

  /// Execute the smart print workflow
  Future<void> _runPrintWorkflow({
    required String data,
    ZebraDevice? device,
    PrintFormat? format,
    required Duration timeout,
    required bool checkStatusBeforePrint,
    required bool waitForCompletion,
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
      
      // Detect format once at the beginning to avoid redundant detection
      final detectedFormat = format ??
          ZebraSGDCommands.detectDataLanguage(data) ??
          PrintFormat.zpl;

      _logger.info('Smart print format: ${detectedFormat.name}');

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
      
      // Step 4: Check printer status (if enabled)
      if (checkStatusBeforePrint) {
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
        final readinessOptions = ReadinessOptions.quickWithLanguage().copyWith(
          checkConnection: true,
          checkMedia: true,
          checkHead: true,
          checkPause: true,
          checkErrors: true,
          checkLanguage: true,
          fixPausedPrinter: true,
          fixPrinterErrors: true,
          fixLanguageMismatch: true,
          fixMediaCalibration: true,
          clearBuffer: true,
          flushBuffer: true,
        );
        final readinessResult = await readinessManager.prepareForPrint(
          detectedFormat,
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
      final printResult = await _sendPrintData(data, detectedFormat, timeout);
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
      if (waitForCompletion) {
        final completionResult = await _waitForPrintCompletion();
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

      // Step 7: Complete
      await _updateStep(PrintStep.completed, 'Print operation completed successfully');
      _eventController?.add(PrintEvent(
        type: PrintEventType.completed,
        timestamp: DateTime.now(),
        stepInfo: _createStepInfo(PrintStep.completed, 'Print operation completed'),
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

  /// Connect to printer with retry logic (delegated to ZebraPrinterManager)
  Future<Result<void>> _connectToPrinter(ZebraDevice? device) async {
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
      String data, PrintFormat format, Duration timeout) async {
    return await _printerManager.communicationPolicy!.execute(
      () async {
        // Track the data and format for completion logic
        _lastPrintData = data;
        _lastPrintFormat = format;

        // Use simple print options since readiness is already handled
        final printOptions = PrintOptions.withoutCompletion().copyWith(
          format: format,
        );
        return await _printerManager.print(data, options: printOptions);
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

  /// Wait for print completion using the manager's sophisticated logic
  Future<Result<void>> _waitForPrintCompletion() async {
    await _updateStep(
        PrintStep.waitingForCompletion, 'Waiting for print completion');

    try {
      // Use the manager's sophisticated completion logic with format-specific delays
      // This provides better accuracy than a simple 3-second delay
      final completionResult = await _printerManager.waitForPrintCompletion(
        _lastPrintData ?? '', // We need to track the last print data
        _lastPrintFormat, // We need to track the last print format
      );

      if (!completionResult.success) {
        return Result.errorCode(
          ErrorCodes.printError,
          formatArgs: [completionResult.error?.message ?? 'Completion failed'],
        );
      }

      final success = completionResult.data ?? false;
      if (!success) {
        return Result.errorCode(
          ErrorCodes.printError,
          formatArgs: ['Print completion failed - hardware issues detected'],
        );
      }

      return Result.success();
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

  /// Check if currently connected
  bool get isConnected => _isConnected;

  /// Check if operation is cancelled
  bool get isCancelled => _isCancelled;
} 