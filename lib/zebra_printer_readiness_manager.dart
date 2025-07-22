import 'dart:async';

import 'internal/logger.dart';
import 'zebrautil.dart';

/// Manager for printer readiness operations using command pattern
/// Centralized connection assurance and retry logic
class ZebraPrinterReadinessManager {

  /// Constructor with instantiation count check
  ZebraPrinterReadinessManager({
    required ZebraPrinter printer,
    void Function(ReadinessOperationEvent)? statusCallback,
  })  : _printer = printer,
        _statusCallback = statusCallback {
    _communicationPolicy = CommunicationPolicy(printer);
    _logger.debug('ZebraPrinterReadinessManager instantiated');
  }
  /// The printer instance to manage
  final ZebraPrinter _printer;
  
  /// Logger for this manager
  final Logger _logger = Logger.withPrefix('ZebraPrinterReadinessManager');
  
  /// Optional status callback for progress updates
  final void Function(ReadinessOperationEvent)? _statusCallback;
  
  /// Communication policy for connection assurance and retry logic
  late final CommunicationPolicy _communicationPolicy;
  
  /// Log a message to both callback and logger
  void _log(String message) {
    _logger.info(message);
  }

  /// Send status event with detailed information
  void _sendStatusEvent({
    required PrinterReadiness readiness,
    required String message,
    required ReadinessOperationType operationType,
    required ReadinessOperationKind operationKind,
    required ReadinessOperationResult result,
    String? errorDetails,
  }) {
    final event = ReadinessOperationEvent(
      readiness: readiness,
      message: message,
      operationType: operationType,
      operationKind: operationKind,
      result: result,
      errorDetails: errorDetails,
    );
    _statusCallback?.call(event);
  }

  /// Helper method to report check result
  void _reportCheckResult({
    required PrinterReadiness readiness,
    required ReadinessOperationType operationType,
    required bool passed,
    required String passMessage,
    required String failMessage,
    required List<String> failedFixes,
    required Map<String, String> fixErrors,
    required String fixKey,
  }) {
    if (passed) {
      _log(passMessage);
      _sendStatusEvent(
        readiness: readiness,
        message: passMessage,
        operationType: operationType,
        operationKind: ReadinessOperationKind.check,
        result: ReadinessOperationResult.successful,
      );
    } else {
      failedFixes.add(fixKey);
      fixErrors[fixKey] = failMessage;
      _log(failMessage);
      _sendStatusEvent(
        readiness: readiness,
        message: failMessage,
        operationType: operationType,
        operationKind: ReadinessOperationKind.check,
        result: ReadinessOperationResult.error,
      );
    }
  }

  /// Helper method to execute fix command and report result
  Future<void> _executeFix({
    required Future<Result> Function() commandExecutor,
    required String commandName,
    required String fixKey,
    required ReadinessOperationType operationType,
    required PrinterReadiness readiness,
    required List<String> appliedFixes,
    required List<String> failedFixes,
    required Map<String, String> fixErrors,
    required String successMessage,
    required String failureMessagePrefix,
  }) async {
    final result =
        await executeCommandWithAssurance(commandExecutor, commandName);

    if (result.success) {
      appliedFixes.add(fixKey);
      _log(successMessage);
      _sendStatusEvent(
        readiness: readiness,
        message: successMessage,
        operationType: operationType,
        operationKind: ReadinessOperationKind.fix,
        result: ReadinessOperationResult.successful,
      );
    } else {
      failedFixes.add(fixKey);
      fixErrors[fixKey] =
          result.error?.message ?? '$failureMessagePrefix failed';
      _log('$failureMessagePrefix: ${fixErrors[fixKey]}');
      _sendStatusEvent(
        readiness: readiness,
        message: '$failureMessagePrefix: ${fixErrors[fixKey]}',
        operationType: operationType,
        operationKind: ReadinessOperationKind.fix,
        result: ReadinessOperationResult.error,
        errorDetails: fixErrors[fixKey],
      );
    }
  }
  
  /// Centralized connection assurance method for other managers to use
  /// This is the single point of truth for connection assurance
  Future<Result<bool>> ensureConnection() async {
    return await _communicationPolicy.getConnectionStatus();
  }

  /// Centralized command execution with connection assurance and retry logic
  /// This is the single point of truth for command execution
  Future<Result<T>> executeCommandWithAssurance<T>(
    Future<Result<T>> Function() commandExecutor,
    String operationName,
  ) async {
    return await _communicationPolicy.execute(
      commandExecutor,
      operationName,
      options: const CommunicationPolicyOptions(skipConnectionRetry: true),
    );
  }

  /// Dispose method
  void dispose() {
    _logger.debug('ZebraPrinterReadinessManager disposed');
  }
  
  /// Prepare printer for printing with specified options
  Future<Result<ReadinessResult>> prepareForPrint(
    PrintFormat format,
    ReadinessOptions options, {
    void Function(ReadinessOperationEvent)? onStatus,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logger.info(
        'ZebraPrinterReadinessManager: Starting prepareForPrint operation');
    _logger.info(
        'ZebraPrinterReadinessManager: Format: ${format.name}, Options: $options');
    _log('Starting printer preparation for print (format: ${format.name})...');
    if (onStatus != null) {
      onStatus(ReadinessOperationEvent(
        readiness: PrinterReadiness(printer: _printer, options: options),
        message:
            'Starting printer preparation for print (format: ${format.name})...',
        operationType: ReadinessOperationType.connection,
        operationKind: ReadinessOperationKind.check,
        result: ReadinessOperationResult.successful,
      ));
    }
    
    try {
      // Create lazy readiness object
      final readiness = PrinterReadiness(printer: _printer, options: options);
      final appliedFixes = <String>[];
      final failedFixes = <String>[];
      final fixErrors = <String, String>{};
      
      // 1. Check and fix connection
      if (options.checkConnection) {
        _logger
            .info('ZebraPrinterReadinessManager: Performing connection check');
        await _checkAndFixConnection(
            readiness, appliedFixes, failedFixes, fixErrors, onStatus);
      } else {
        _logger.info(
            'ZebraPrinterReadinessManager: Skipping connection check (disabled)');
      }
      
      // 2. Check and fix media
      if (options.checkMedia) {
        _logger.info('ZebraPrinterReadinessManager: Performing media check');
        await _checkAndFixMedia(
            readiness, appliedFixes, failedFixes, fixErrors, options, onStatus);
      } else {
        _logger
            .info(
            'ZebraPrinterReadinessManager: Skipping media check (disabled)');
      }
      
      // 3. Check and fix head
      if (options.checkHead) {
        _logger.info('ZebraPrinterReadinessManager: Performing head check');
        await _checkAndFixHead(
            readiness, appliedFixes, failedFixes, fixErrors, onStatus);
      } else {
        _logger.info(
            'ZebraPrinterReadinessManager: Skipping head check (disabled)');
      }
      
      // 4. Check and fix pause - ALWAYS check for print operations
      // Pause status is critical for printing, so we check it regardless of options
      _logger.info(
          'ZebraPrinterReadinessManager: Performing pause check (always required for printing)');
      await _checkAndFixPause(
          readiness, appliedFixes, failedFixes, fixErrors, options, onStatus);
      
      // 5. Check and fix errors (format-specific)
      if (options.checkErrors) {
        _logger.info(
            'ZebraPrinterReadinessManager: Performing error check for ${format.name}');
        await _checkAndFixErrors(
            readiness, appliedFixes, failedFixes,
            fixErrors, options, format, onStatus);
      } else {
        _logger
            .info(
            'ZebraPrinterReadinessManager: Skipping error check (disabled)');
      }
      
      // 6. Check and fix language (format-specific)
      if (options.checkLanguage) {
        _logger.info(
            'ZebraPrinterReadinessManager: Performing language check for ${format.name}');
        await _checkAndFixLanguage(
            readiness, appliedFixes, failedFixes,
            fixErrors, format, options, onStatus);
      } else {
        _logger.info(
            'ZebraPrinterReadinessManager: Skipping language check (disabled)');
      }
      
      // 7. Handle buffer operations (format-specific)
      if (options.clearBuffer) {
        _logger.info(
            'ZebraPrinterReadinessManager: Performing buffer clear for ${format.name}');
        await _checkAndFixBuffer(
            appliedFixes, failedFixes, fixErrors, format, onStatus);
      } else {
        _logger
            .info(
            'ZebraPrinterReadinessManager: Skipping buffer clear (disabled)');
      }
      
      if (options.flushBuffer) {
        _logger.info(
            'ZebraPrinterReadinessManager: Performing buffer flush for ${format.name}');
        await _checkAndFixFlush(
            appliedFixes, failedFixes, fixErrors, format, onStatus);
      } else {
        _logger
            .info(
            'ZebraPrinterReadinessManager: Skipping buffer flush (disabled)');
      }
      
      // 8. Get final readiness status (using cached values)
      _logger
          .info('ZebraPrinterReadinessManager: Getting final readiness status');
      final isReady = await readiness.isReady;
      final result = ReadinessResult.withReadyState(
        isReady,
        readiness,
        appliedFixes,
        failedFixes,
        fixErrors,
        stopwatch.elapsed,
      );
      
      _logger.info(
          'ZebraPrinterReadinessManager: PrepareForPrint completed in ${stopwatch.elapsed.inMilliseconds}ms');
      _logger
          .info('ZebraPrinterReadinessManager: Applied fixes: $appliedFixes');
      _logger.info('ZebraPrinterReadinessManager: Failed fixes: $failedFixes');
      _logger.info('ZebraPrinterReadinessManager: Fix errors: $fixErrors');
      _log('Printer preparation completed: ${result.summary}');
      if (onStatus != null) {
        onStatus(ReadinessOperationEvent(
          readiness: readiness,
          message: 'Printer preparation completed: ${result.summary}',
          operationType: ReadinessOperationType.connection,
          operationKind: ReadinessOperationKind.check,
          result: isReady
              ? ReadinessOperationResult.successful
              : ReadinessOperationResult.error,
          errorDetails: isReady ? null : result.summary,
        ));
      }
      return Result.success(result);
      
    } catch (e, stack) {
      _logger.error('Error during printer preparation', e);
      return Result.error(
        'Printer preparation failed: $e',
        code: ErrorCodes.operationError.code,
        dartStackTrace: stack,
      );
    }
  }
  
  /// Run comprehensive diagnostics on the printer
  Future<Result<Map<String, dynamic>>> runDiagnostics() async {
    _logger.info(
        'ZebraPrinterReadinessManager: Starting comprehensive diagnostics');
    _log('Running comprehensive diagnostics...');
    
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'connected': false,
      'printerInfo': {},
      'status': {},
      'settings': {},
      'errors': [],
      'recommendations': [],
    };
    
    try {
      // Check connection using command
      _logger
          .info(
          'ZebraPrinterReadinessManager: Checking connection for diagnostics');
      final connectionResult = await _checkConnection();
      diagnostics['connected'] = connectionResult.success ? connectionResult.data : false;
      _logger.info(
          'ZebraPrinterReadinessManager: Connection check result: ${connectionResult.success}');
      
      if (!diagnostics['connected']) {
        diagnostics['errors'].add('Connection lost');
        diagnostics['recommendations'].add('Reconnect to the printer');
        return Result.success(diagnostics);
      }
      
      // Run comprehensive status checks using commands
      _logger
          .info(
          'ZebraPrinterReadinessManager: Running comprehensive status checks');
      final statusChecks = [
        {'setting': 'media.status', 'label': 'Media Status'},
        {'setting': 'head.latch', 'label': 'Head Status'},
        {'setting': 'device.pause', 'label': 'Pause Status'},
        {'setting': 'device.host_status', 'label': 'Host Status'},
        {'setting': 'device.languages', 'label': 'Printer Language'},
        {'setting': 'device.unique_id', 'label': 'Device ID'},
        {'setting': 'device.product_name', 'label': 'Product Name'},
        {'setting': 'appl.name', 'label': 'Firmware Version'},
      ];
      
      for (final check in statusChecks) {
        final setting = check['setting'] as String;
        final label = check['label'] as String;
        _logger
            .info('ZebraPrinterReadinessManager: Checking $label ($setting)');
        try {
          // Use centralized command execution with assurance
          final result = await executeCommandWithAssurance(
              () => CommandFactory.createGetSettingCommand(_printer, setting)
                  .execute(),
              'Get Setting: $setting');
          
          if (result.success && result.data != null) {
            diagnostics['status'][label] = result.data;
            _logger
                .info('ZebraPrinterReadinessManager: $label = ${result.data}');
          } else {
            _logger.warning(
                'ZebraPrinterReadinessManager: Failed to get $label: ${result.error?.message}');
          }
        } catch (e) {
          _logger
              .error('ZebraPrinterReadinessManager: Error checking $label: $e');
          // Continue with other checks
        }
      }
      
      // Analyze and provide recommendations
      _logger.info(
          'ZebraPrinterReadinessManager: Analyzing diagnostics and generating recommendations');
      _analyzeDiagnostics(diagnostics);
      
      _logger
          .info(
          'ZebraPrinterReadinessManager: Diagnostics completed successfully');
      _log('Diagnostics complete');
      return Result.success(diagnostics);
      
    } catch (e, stack) {
      diagnostics['errors'].add('Diagnostic error: $e');
      return Result.error(
        'Failed to run diagnostics: $e',
        code: ErrorCodes.operationError.code,
        dartStackTrace: stack,
      );
    }
  }
  
  /// Get detailed status of the printer
  Future<Result<PrinterReadiness>> getDetailedStatus() async {
    _logger
        .info('ZebraPrinterReadinessManager: Getting detailed printer status');
    final readiness = PrinterReadiness(printer: _printer);
    await readiness.readAllStatuses();
    _logger.info(
        'ZebraPrinterReadinessManager: Detailed status - Connected: ${await readiness.isConnected}, HasMedia: ${await readiness.hasMedia}, HeadClosed: ${await readiness.headClosed}, IsPaused: ${await readiness.isPaused}');
    return Result.success(readiness);
  }
  
  /// Validate if the printer state is ready
  Future<Result<bool>> validatePrinterState() async {
    _logger.info('ZebraPrinterReadinessManager: Validating printer state');
    final result = await getDetailedStatus();
    if (!result.success) {
      _logger.error(
          'ZebraPrinterReadinessManager: Failed to get detailed status for validation: ${result.error?.message}');
      return Result.errorFromResult(result);
    }
    
    final readiness = result.data!;
    final isReady = await readiness.isReady;
    _logger.info(
        'ZebraPrinterReadinessManager: Printer state validation result: $isReady');
    return Result.success(isReady);
  }
  
  // Private check methods - each uses a single command
  Future<Result<bool>> _checkConnection() async {
    _logger.info('ZebraPrinterReadinessManager: Executing connection check');
    // Use centralized connection assurance
    return await ensureConnection();
  }
  
  // Individual check and fix methods using cached values from readiness
  Future<void> _checkAndFixConnection(
    PrinterReadiness readiness,
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    void Function(ReadinessOperationEvent)? onStatus,
  ) async {
    _logger.info(
        'ZebraPrinterReadinessManager: Starting connection check and fix');
    
    // Use cached value from readiness (this will trigger read if not cached)
    final connected = await readiness.isConnected;

    _reportCheckResult(
      readiness: readiness,
      operationType: ReadinessOperationType.connection,
      passed: connected,
      passMessage: 'Connection check passed',
      failMessage: 'Connection failed',
      failedFixes: failedFixes,
      fixErrors: fixErrors,
      fixKey: 'connection',
    );
  }
  
  Future<void> _checkAndFixMedia(
    PrinterReadiness readiness,
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    ReadinessOptions options,
    void Function(ReadinessOperationEvent)? onStatus,
  ) async {
    _logger.info('ZebraPrinterReadinessManager: Starting media check and fix');
    
    // Use cached value from readiness (this will trigger read if not cached)
    final hasMedia = await readiness.hasMedia;
    
    if (hasMedia == false) {
      // Try to fix media calibration
      if (options.fixMediaCalibration) {
        _logger
            .info(
            'ZebraPrinterReadinessManager: Attempting media calibration fix');
        
        await _executeFix(
          commandExecutor: () =>
              CommandFactory.createSendCalibrationCommand(_printer).execute(),
          commandName: 'Send Calibration',
          fixKey: 'mediaCalibration',
          operationType: ReadinessOperationType.media,
          readiness: readiness,
          appliedFixes: appliedFixes,
          failedFixes: failedFixes,
          fixErrors: fixErrors,
          successMessage: 'Media calibration applied',
          failureMessagePrefix: 'Media calibration failed',
        );
      } else {
        _reportCheckResult(
          readiness: readiness,
          operationType: ReadinessOperationType.media,
          passed: false,
          passMessage: '',
          failMessage: 'No media detected',
          failedFixes: failedFixes,
          fixErrors: fixErrors,
          fixKey: 'media',
        );
      }
    } else {
      _reportCheckResult(
        readiness: readiness,
        operationType: ReadinessOperationType.media,
        passed: true,
        passMessage: 'Media check passed',
        failMessage: '',
        failedFixes: failedFixes,
        fixErrors: fixErrors,
        fixKey: 'media',
      );
    }
  }
  
  Future<void> _checkAndFixHead(
    PrinterReadiness readiness,
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    void Function(ReadinessOperationEvent)? onStatus,
  ) async {
    _logger.info('ZebraPrinterReadinessManager: Starting head check and fix');
    
    // Use cached value from readiness (this will trigger read if not cached)
    final headClosed = await readiness.headClosed;

    _reportCheckResult(
      readiness: readiness,
      operationType: ReadinessOperationType.head,
      passed: headClosed ?? false,
      passMessage: 'Head check passed',
      failMessage: 'Print head is open',
      failedFixes: failedFixes,
      fixErrors: fixErrors,
      fixKey: 'head',
    );
  }
  
  Future<void> _checkAndFixPause(
    PrinterReadiness readiness,
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    ReadinessOptions options,
    void Function(ReadinessOperationEvent)? onStatus,
  ) async {
    _logger.info('ZebraPrinterReadinessManager: Starting pause check and fix');
    
    // Use cached value from readiness (this will trigger read if not cached)
    final isPaused = await readiness.isPaused;
    
    if (isPaused == true) {
      // Try to unpause
      if (options.fixPausedPrinter) {
        _logger.info(
            'ZebraPrinterReadinessManager: Attempting to unpause printer');
        
        await _executeFix(
          commandExecutor: () =>
              CommandFactory.createSendUnpauseCommand(_printer).execute(),
          commandName: 'Send Unpause',
          fixKey: 'unpause',
          operationType: ReadinessOperationType.pause,
          readiness: readiness,
          appliedFixes: appliedFixes,
          failedFixes: failedFixes,
          fixErrors: fixErrors,
          successMessage: 'Printer unpaused',
          failureMessagePrefix: 'Unpause failed',
        );
      } else {
        _reportCheckResult(
          readiness: readiness,
          operationType: ReadinessOperationType.pause,
          passed: false,
          passMessage: '',
          failMessage: 'Printer is paused',
          failedFixes: failedFixes,
          fixErrors: fixErrors,
          fixKey: 'pause',
        );
      }
    } else {
      _reportCheckResult(
        readiness: readiness,
        operationType: ReadinessOperationType.pause,
        passed: true,
        passMessage: 'Pause check passed',
        failMessage: '',
        failedFixes: failedFixes,
        fixErrors: fixErrors,
        fixKey: 'pause',
      );
    }
  }
  
  Future<void> _checkAndFixErrors(
    PrinterReadiness readiness,
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    ReadinessOptions options,
    PrintFormat format,
    void Function(ReadinessOperationEvent)? onStatus,
  ) async {
    _logger.info(
        'ZebraPrinterReadinessManager: Starting error check and fix for ${format.name}');
    
    // Use cached value from readiness (this will trigger read if not cached)
    final errors = await readiness.errors;

    if (errors.isNotEmpty) {
      // Try to clear errors using format-specific commands
      if (options.fixPrinterErrors) {
        _logger.info(
            'ZebraPrinterReadinessManager: Attempting to clear errors using ${format.name} command');
        Result clearResult;

        switch (format) {
          case PrintFormat.zpl:
            // Use ZPL-specific clear errors command
            _logger.info(
                'ZebraPrinterReadinessManager: Using ZPL clear errors command');
            clearResult = await executeCommandWithAssurance(
                () => CommandFactory.createSendZplClearErrorsCommand(_printer)
                    .execute(),
                'Send ZPL Clear Errors');
            break;
          case PrintFormat.cpcl:
            // Use CPCL-specific clear errors command
            _logger.info(
                'ZebraPrinterReadinessManager: Using CPCL clear errors command');
            clearResult = await executeCommandWithAssurance(
                () => CommandFactory.createSendCpclClearErrorsCommand(_printer)
                    .execute(),
                'Send CPCL Clear Errors');
            break;
        }

        if (clearResult.success) {
          appliedFixes.add('clearErrors');
          _log('Printer errors cleared using ${format.name} command');
          _sendStatusEvent(
            readiness: readiness,
            message: 'Printer errors cleared using ${format.name} command',
            operationType: ReadinessOperationType.errors,
            operationKind: ReadinessOperationKind.fix,
            result: ReadinessOperationResult.successful,
          );
        } else {
          failedFixes.add('clearErrors');
          fixErrors['clearErrors'] =
              clearResult.error?.message ?? 'Error clearing failed';
          _log('Error clearing failed: ${fixErrors['clearErrors']}');
          _sendStatusEvent(
            readiness: readiness,
            message: 'Error clearing failed: ${fixErrors['clearErrors']}',
            operationType: ReadinessOperationType.errors,
            operationKind: ReadinessOperationKind.fix,
            result: ReadinessOperationResult.error,
            errorDetails: fixErrors['clearErrors'],
          );
        }
      } else {
        final errorMsg = errors.join('; ');
        failedFixes.add('errors');
        fixErrors['errors'] = errorMsg;
        _log('Printer has errors: $errorMsg');
        _sendStatusEvent(
          readiness: readiness,
          message: 'Printer has errors: $errorMsg',
          operationType: ReadinessOperationType.errors,
          operationKind: ReadinessOperationKind.check,
          result: ReadinessOperationResult.error,
        );
      }
    } else {
      _log('Error check passed');
      _sendStatusEvent(
        readiness: readiness,
        message: 'Error check passed',
        operationType: ReadinessOperationType.errors,
        operationKind: ReadinessOperationKind.check,
        result: ReadinessOperationResult.successful,
      );
    }
  }
  
  Future<void> _checkAndFixLanguage(
    PrinterReadiness readiness,
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    PrintFormat format,
    ReadinessOptions options,
    void Function(ReadinessOperationEvent)? onStatus,
  ) async {
    _logger.info(
        'ZebraPrinterReadinessManager: Starting language check and fix for ${format.name}');
    
    // Use cached value from readiness (this will trigger read if not cached)
    final currentLanguage = await readiness.languageStatus;
    
    if (currentLanguage != null) {
      _log('Current printer language: $currentLanguage');

      // Check if current language matches expected format
      bool languageMatches = false;
      String expectedLanguage = '';

      switch (format) {
        case PrintFormat.zpl:
          expectedLanguage = 'zpl';
          languageMatches = ZebraSGDCommands.isLanguageMatch(
              currentLanguage, expectedLanguage);
          break;
        case PrintFormat.cpcl:
          expectedLanguage = 'line_print';
          languageMatches = ZebraSGDCommands.isLanguageMatch(
              currentLanguage, expectedLanguage);
          break;
      }

      if (!languageMatches) {
        _log(
            'Language mismatch: current=$currentLanguage, expected=$expectedLanguage');
        
        if (options.fixLanguageMismatch) {
          // Switch to correct language mode
          _logger.info(
              'ZebraPrinterReadinessManager: Language mismatch detected, attempting to switch');
          _log(
              'Switching printer language from $currentLanguage to $expectedLanguage');

          final switchCommand = format == PrintFormat.zpl
              ? CommandFactory.createSendSetZplModeCommand(_printer)
              : CommandFactory.createSendSetCpclModeCommand(_printer);

          _logger.info(
              'ZebraPrinterReadinessManager: Executing ${format.name} language switch command');
          
          // Use centralized command execution with assurance
          final switchResult = await executeCommandWithAssurance(
              () => switchCommand.execute(),
              'Send ${format.name} Language Switch');

          if (switchResult.success) {
            appliedFixes.add('switchLanguage');
            _log('Successfully switched printer to ${format.name} mode');
            _sendStatusEvent(
              readiness: readiness,
              message: 'Successfully switched printer to ${format.name} mode',
              operationType: ReadinessOperationType.language,
              operationKind: ReadinessOperationKind.fix,
              result: ReadinessOperationResult.successful,
            );
          } else {
            failedFixes.add('switchLanguage');
            fixErrors['switchLanguage'] =
                switchResult.error?.message ?? 'Language switch failed';
            _log('Language switch failed: ${fixErrors['switchLanguage']}');
            _sendStatusEvent(
              readiness: readiness,
              message: 'Language switch failed: ${fixErrors['switchLanguage']}',
              operationType: ReadinessOperationType.language,
              operationKind: ReadinessOperationKind.fix,
              result: ReadinessOperationResult.error,
              errorDetails: fixErrors['switchLanguage'],
            );
          }
        } else {
          // Only log the mismatch without switching
          failedFixes.add('language');
          fixErrors['language'] =
              'Language mismatch: current=$currentLanguage, expected=$expectedLanguage';
          _log('Language check failed: ${fixErrors['language']}');
          _sendStatusEvent(
            readiness: readiness,
            message: 'Language check failed: ${fixErrors['language']}',
            operationType: ReadinessOperationType.language,
            operationKind: ReadinessOperationKind.check,
            result: ReadinessOperationResult.error,
          );
        }
      } else {
        _log('Language check passed for ${format.name}');
        _sendStatusEvent(
          readiness: readiness,
          message: 'Language check passed for ${format.name}',
          operationType: ReadinessOperationType.language,
          operationKind: ReadinessOperationKind.check,
          result: ReadinessOperationResult.successful,
        );
      }
    } else {
      failedFixes.add('language');
      fixErrors['language'] = 'Language check failed';
      _log('Language check failed: Unable to read language status');
      _sendStatusEvent(
        readiness: readiness,
        message: 'Language check failed: Unable to read language status',
        operationType: ReadinessOperationType.language,
        operationKind: ReadinessOperationKind.check,
        result: ReadinessOperationResult.error,
      );
    }
  }
  
  Future<void> _checkAndFixBuffer(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    PrintFormat format,
    void Function(ReadinessOperationEvent)? onStatus,
  ) async {
    _logger.info(
        'ZebraPrinterReadinessManager: Starting buffer clear for ${format.name}');
    Result result;

    switch (format) {
      case PrintFormat.zpl:
        // Use ZPL-specific buffer clear command
        _logger.info(
            'ZebraPrinterReadinessManager: Using ZPL buffer clear command');
        result = await executeCommandWithAssurance(
            () => CommandFactory.createSendZplClearBufferCommand(_printer)
                .execute(),
            'Send ZPL Clear Buffer');
        break;
      case PrintFormat.cpcl:
        // For CPCL, use CPCL-specific buffer clear command
        _logger
            .info(
            'ZebraPrinterReadinessManager: Using CPCL buffer clear command');
        result = await executeCommandWithAssurance(
            () => CommandFactory.createSendCpclClearBufferCommand(_printer)
                .execute(),
            'Send CPCL Clear Buffer');
        break;
    }
    
    if (result.success) {
      appliedFixes.add('clearBuffer');
      _log('Buffer cleared using ${format.name} command');
      _sendStatusEvent(
        readiness: PrinterReadiness(
            printer: _printer), // Pass a dummy readiness for status event
        message: 'Buffer cleared using ${format.name} command',
        operationType: ReadinessOperationType.buffer,
        operationKind: ReadinessOperationKind.fix,
        result: ReadinessOperationResult.successful,
      );
    } else {
      failedFixes.add('clearBuffer');
      fixErrors['clearBuffer'] = result.error?.message ?? 'Buffer clear failed';
      _log('Buffer clear failed: ${fixErrors['clearBuffer']}');
      _sendStatusEvent(
        readiness: PrinterReadiness(
            printer: _printer), // Pass a dummy readiness for status event
        message: 'Buffer clear failed: ${fixErrors['clearBuffer']}',
        operationType: ReadinessOperationType.buffer,
        operationKind: ReadinessOperationKind.fix,
        result: ReadinessOperationResult.error,
        errorDetails: fixErrors['clearBuffer'],
      );
    }
  }
  
  Future<void> _checkAndFixFlush(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    PrintFormat format,
    void Function(ReadinessOperationEvent)? onStatus,
  ) async {
    _logger.info(
        'ZebraPrinterReadinessManager: Starting buffer flush for ${format.name}');
    Result result;

    switch (format) {
      case PrintFormat.zpl:
        // Use ZPL-specific buffer flush command
        _logger.info(
            'ZebraPrinterReadinessManager: Using ZPL buffer flush command');
        result = await executeCommandWithAssurance(
            () => CommandFactory.createSendZplFlushBufferCommand(_printer)
                .execute(),
            'Send ZPL Flush Buffer');
        break;
      case PrintFormat.cpcl:
        // Use CPCL-specific buffer flush command
        _logger
            .info(
            'ZebraPrinterReadinessManager: Using CPCL buffer flush command');
        result = await executeCommandWithAssurance(
            () => CommandFactory.createSendCpclFlushBufferCommand(_printer)
                .execute(),
            'Send CPCL Flush Buffer');
        break;
    }
    
    if (result.success) {
      appliedFixes.add('flushBuffer');
      _log('Buffer flushed using ${format.name} command');
      _sendStatusEvent(
        readiness: PrinterReadiness(
            printer: _printer), // Pass a dummy readiness for status event
        message: 'Buffer flushed using ${format.name} command',
        operationType: ReadinessOperationType.buffer,
        operationKind: ReadinessOperationKind.fix,
        result: ReadinessOperationResult.successful,
      );
    } else {
      failedFixes.add('flushBuffer');
      fixErrors['flushBuffer'] = result.error?.message ?? 'Buffer flush failed';
      _log('Buffer flush failed: ${fixErrors['flushBuffer']}');
      _sendStatusEvent(
        readiness: PrinterReadiness(
            printer: _printer), // Pass a dummy readiness for status event
        message: 'Buffer flush failed: ${fixErrors['flushBuffer']}',
        operationType: ReadinessOperationType.buffer,
        operationKind: ReadinessOperationKind.fix,
        result: ReadinessOperationResult.error,
        errorDetails: fixErrors['flushBuffer'],
      );
    }
  }
  
  void _analyzeDiagnostics(Map<String, dynamic> diagnostics) {
    _logger.info('ZebraPrinterReadinessManager: Analyzing diagnostics data');
    // Analyze diagnostics and add recommendations
    if (diagnostics['status']['Media Status'] == 'no media') {
      diagnostics['recommendations'].add('Load media into the printer');
      _logger.info(
          'ZebraPrinterReadinessManager: Added recommendation: Load media into the printer');
    }
    
    if (diagnostics['status']['Head Status'] == 'open') {
      diagnostics['recommendations'].add('Close the print head');
      _logger.info(
          'ZebraPrinterReadinessManager: Added recommendation: Close the print head');
    }
    
    if (diagnostics['status']['Pause Status'] == 'true') {
      diagnostics['recommendations'].add('Unpause the printer');
      _logger.info(
          'ZebraPrinterReadinessManager: Added recommendation: Unpause the printer');
    }
    
    _logger.info(
        'ZebraPrinterReadinessManager: Diagnostics analysis completed with ${diagnostics['recommendations'].length} recommendations');
  }
} 