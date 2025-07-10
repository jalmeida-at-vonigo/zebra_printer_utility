import 'dart:async';
import 'models/readiness_options.dart';
import 'models/readiness_result.dart';
import 'models/result.dart';
import 'models/printer_readiness.dart';
import 'models/print_enums.dart';
import 'internal/commands/command_factory.dart';
import 'internal/parser_util.dart';
import 'internal/logger.dart';
import 'zebra_printer.dart';
import 'zebra_sgd_commands.dart';

/// Manager for printer readiness operations using command pattern
class PrinterReadinessManager {
  /// The printer instance to manage
  final ZebraPrinter _printer;
  
  /// Logger for this manager
  final Logger _logger = Logger.withPrefix('PrinterReadinessManager');
  
  /// Optional status callback for progress updates
  final void Function(String)? _statusCallback;
  
  /// Constructor
  PrinterReadinessManager({
    required ZebraPrinter printer,
    void Function(String)? statusCallback,
  }) : _printer = printer,
       _statusCallback = statusCallback;
  
  /// Log a message to both callback and logger
  void _log(String message) {
    _statusCallback?.call(message);
    _logger.info(message);
  }
  
  /// Prepare printer for printing with specified options
  Future<Result<ReadinessResult>> prepareForPrint(
    PrintFormat format,
    ReadinessOptions options,
  ) async {
    final stopwatch = Stopwatch()..start();
    _logger.info('PrinterReadinessManager: Starting prepareForPrint operation');
    _logger.info(
        'PrinterReadinessManager: Format: ${format.name}, Options: $options');
    _log('Starting printer preparation for print (format: ${format.name})...');
    
    try {
      final appliedFixes = <String>[];
      final failedFixes = <String>[];
      final fixErrors = <String, String>{};
      
      // 1. Check and fix connection
      if (options.checkConnection) {
        _logger.info('PrinterReadinessManager: Performing connection check');
        await _checkAndFixConnection(appliedFixes, failedFixes, fixErrors);
      } else {
        _logger.info(
            'PrinterReadinessManager: Skipping connection check (disabled)');
      }
      
      // 2. Check and fix media
      if (options.checkMedia) {
        _logger.info('PrinterReadinessManager: Performing media check');
        await _checkAndFixMedia(appliedFixes, failedFixes, fixErrors, options);
      } else {
        _logger
            .info('PrinterReadinessManager: Skipping media check (disabled)');
      }
      
      // 3. Check and fix head
      if (options.checkHead) {
        _logger.info('PrinterReadinessManager: Performing head check');
        await _checkAndFixHead(appliedFixes, failedFixes, fixErrors);
      } else {
        _logger.info('PrinterReadinessManager: Skipping head check (disabled)');
      }
      
      // 4. Check and fix pause
      if (options.checkPause) {
        _logger.info('PrinterReadinessManager: Performing pause check');
        await _checkAndFixPause(appliedFixes, failedFixes, fixErrors, options);
      } else {
        _logger
            .info('PrinterReadinessManager: Skipping pause check (disabled)');
      }
      
      // 5. Check and fix errors (format-specific)
      if (options.checkErrors) {
        _logger.info(
            'PrinterReadinessManager: Performing error check for ${format.name}');
        await _checkAndFixErrors(
            appliedFixes, failedFixes, fixErrors, options, format);
      } else {
        _logger
            .info('PrinterReadinessManager: Skipping error check (disabled)');
      }
      
      // 6. Check and fix language (format-specific)
      if (options.checkLanguage) {
        _logger.info(
            'PrinterReadinessManager: Performing language check for ${format.name}');
        await _checkAndFixLanguage(
            appliedFixes, failedFixes, fixErrors, format, options);
      } else {
        _logger.info(
            'PrinterReadinessManager: Skipping language check (disabled)');
      }
      
      // 7. Handle buffer operations (format-specific)
      if (options.clearBuffer) {
        _logger.info(
            'PrinterReadinessManager: Performing buffer clear for ${format.name}');
        await _checkAndFixBuffer(appliedFixes, failedFixes, fixErrors, format);
      } else {
        _logger
            .info('PrinterReadinessManager: Skipping buffer clear (disabled)');
      }
      
      if (options.flushBuffer) {
        _logger.info(
            'PrinterReadinessManager: Performing buffer flush for ${format.name}');
        await _checkAndFixFlush(appliedFixes, failedFixes, fixErrors, format);
      } else {
        _logger
            .info('PrinterReadinessManager: Skipping buffer flush (disabled)');
      }
      
      // 8. Create readiness result
      _logger.info('PrinterReadinessManager: Building final readiness status');
      final readiness = await _buildReadinessStatus();
      final result = ReadinessResult.fromReadiness(
        readiness,
        appliedFixes,
        failedFixes,
        fixErrors,
        stopwatch.elapsed,
      );
      
      _logger.info(
          'PrinterReadinessManager: PrepareForPrint completed in ${stopwatch.elapsed.inMilliseconds}ms');
      _logger.info('PrinterReadinessManager: Applied fixes: $appliedFixes');
      _logger.info('PrinterReadinessManager: Failed fixes: $failedFixes');
      _logger.info('PrinterReadinessManager: Fix errors: $fixErrors');
      _log('Printer preparation completed: ${result.summary}');
      return Result.success(result);
      
    } catch (e, stack) {
      _logger.error('Error during printer preparation', e);
      return Result.error(
        'Printer preparation failed: $e',
        code: 'OPERATION_ERROR',
        dartStackTrace: stack,
      );
    }
  }
  
  /// Run comprehensive diagnostics on the printer
  Future<Result<Map<String, dynamic>>> runDiagnostics() async {
    _logger.info('PrinterReadinessManager: Starting comprehensive diagnostics');
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
          .info('PrinterReadinessManager: Checking connection for diagnostics');
      final connectionResult = await _checkConnection();
      diagnostics['connected'] = connectionResult.success ? connectionResult.data : false;
      _logger.info(
          'PrinterReadinessManager: Connection check result: ${connectionResult.success}');
      
      if (!diagnostics['connected']) {
        diagnostics['errors'].add('Connection lost');
        diagnostics['recommendations'].add('Reconnect to the printer');
        return Result.success(diagnostics);
      }
      
      // Run comprehensive status checks using commands
      _logger
          .info('PrinterReadinessManager: Running comprehensive status checks');
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
        _logger.info('PrinterReadinessManager: Checking $label ($setting)');
        try {
          final command = CommandFactory.createGetSettingCommand(_printer, setting);
          final result = await command.execute();
          if (result.success && result.data != null) {
            diagnostics['status'][label] = result.data;
            _logger.info('PrinterReadinessManager: $label = ${result.data}');
          } else {
            _logger.warning(
                'PrinterReadinessManager: Failed to get $label: ${result.error?.message}');
          }
        } catch (e) {
          _logger.error('PrinterReadinessManager: Error checking $label: $e');
          // Continue with other checks
        }
      }
      
      // Analyze and provide recommendations
      _logger.info(
          'PrinterReadinessManager: Analyzing diagnostics and generating recommendations');
      _analyzeDiagnostics(diagnostics);
      
      _logger
          .info('PrinterReadinessManager: Diagnostics completed successfully');
      _log('Diagnostics complete');
      return Result.success(diagnostics);
      
    } catch (e, stack) {
      diagnostics['errors'].add('Diagnostic error: $e');
      return Result.error(
        'Failed to run diagnostics: $e',
        code: 'OPERATION_ERROR',
        dartStackTrace: stack,
      );
    }
  }
  
  /// Get detailed status of the printer
  Future<Result<PrinterReadiness>> getDetailedStatus() async {
    _logger.info('PrinterReadinessManager: Getting detailed printer status');
    final readiness = await _buildReadinessStatus();
    _logger.info(
        'PrinterReadinessManager: Detailed status - Connected: ${readiness.isConnected}, HasMedia: ${readiness.hasMedia}, HeadClosed: ${readiness.headClosed}, IsPaused: ${readiness.isPaused}');
    return Result.success(readiness);
  }
  
  /// Validate if the printer state is ready
  Future<Result<bool>> validatePrinterState() async {
    _logger.info('PrinterReadinessManager: Validating printer state');
    final result = await getDetailedStatus();
    if (!result.success) {
      _logger.error(
          'PrinterReadinessManager: Failed to get detailed status for validation: ${result.error?.message}');
      return Result.failure(result.error!);
    }
    
    final readiness = result.data!;
    final isReady = readiness.isReady;
    _logger.info(
        'PrinterReadinessManager: Printer state validation result: $isReady');
    return Result.success(isReady);
  }
  
  // Private check methods - each uses a single command
  Future<Result<bool>> _checkConnection() async {
    _logger.info('PrinterReadinessManager: Executing connection check command');
    final command = CommandFactory.createCheckConnectionCommand(_printer);
    final result = await command.execute();
    _logger.info(
        'PrinterReadinessManager: Connection check result: ${result.success}, data: ${result.data}');
    return result;
  }
  
  // Individual check and fix methods using printer commands
  Future<void> _checkAndFixConnection(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    _logger.info('PrinterReadinessManager: Starting connection check and fix');
    final command = CommandFactory.createCheckConnectionCommand(_printer);
    final result = await command.execute();
    
    if (!result.success || result.data == false) {
      failedFixes.add('connection');
      fixErrors['connection'] = result.error?.message ?? 'Connection failed';
      _log('Connection check failed: ${fixErrors['connection']}');
    } else {
      _log('Connection check passed');
    }
  }
  
  Future<void> _checkAndFixMedia(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    ReadinessOptions options,
  ) async {
    _logger.info('PrinterReadinessManager: Starting media check and fix');
    final command = CommandFactory.createGetMediaStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      final hasMedia = ParserUtil.hasMedia(result.data);
      if (hasMedia == false) {
        // Try to fix media calibration
        if (options.fixMediaCalibration) {
          _logger.info(
              'PrinterReadinessManager: Attempting media calibration fix');
          final calibrateCommand = CommandFactory.createSendCalibrationCommand(_printer);
          final calibrateResult = await calibrateCommand.execute();
          
          if (calibrateResult.success) {
            appliedFixes.add('mediaCalibration');
            _log('Media calibration applied');
          } else {
            failedFixes.add('mediaCalibration');
            fixErrors['mediaCalibration'] = calibrateResult.error?.message ?? 'Calibration failed';
            _log('Media calibration failed: ${fixErrors['mediaCalibration']}');
          }
        } else {
          failedFixes.add('media');
          fixErrors['media'] = 'No media detected';
          _log('No media detected');
        }
      } else {
        _log('Media check passed');
      }
    } else {
      failedFixes.add('media');
      fixErrors['media'] = result.error?.message ?? 'Media status check failed';
      _log('Media status check failed: ${fixErrors['media']}');
    }
  }
  
  Future<void> _checkAndFixHead(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    _logger.info('PrinterReadinessManager: Starting head check and fix');
    final command = CommandFactory.createGetHeadStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      final headClosed = ParserUtil.isHeadClosed(result.data);
      if (headClosed == false) {
        failedFixes.add('head');
        fixErrors['head'] = 'Print head is open';
        _log('Print head is open');
      } else {
        _log('Head check passed');
      }
    } else {
      failedFixes.add('head');
      fixErrors['head'] = result.error?.message ?? 'Head status check failed';
      _log('Head status check failed: ${fixErrors['head']}');
    }
  }
  
  Future<void> _checkAndFixPause(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    ReadinessOptions options,
  ) async {
    _logger.info('PrinterReadinessManager: Starting pause check and fix');
    final command = CommandFactory.createGetPauseStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      final isPaused = ParserUtil.toBool(result.data);
      if (isPaused == true) {
        // Try to unpause
        if (options.fixPausedPrinter) {
          _logger
              .info('PrinterReadinessManager: Attempting to unpause printer');
          final unpauseCommand = CommandFactory.createSendUnpauseCommand(_printer);
          final unpauseResult = await unpauseCommand.execute();
          
          if (unpauseResult.success) {
            appliedFixes.add('unpause');
            _log('Printer unpaused');
          } else {
            failedFixes.add('unpause');
            fixErrors['unpause'] = unpauseResult.error?.message ?? 'Unpause failed';
            _log('Unpause failed: ${fixErrors['unpause']}');
          }
        } else {
          failedFixes.add('pause');
          fixErrors['pause'] = 'Printer is paused';
          _log('Printer is paused');
        }
      } else {
        _log('Pause check passed');
      }
    } else {
      failedFixes.add('pause');
      fixErrors['pause'] = result.error?.message ?? 'Pause status check failed';
      _log('Pause status check failed: ${fixErrors['pause']}');
    }
  }
  
  Future<void> _checkAndFixErrors(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    ReadinessOptions options,
    PrintFormat format,
  ) async {
    _logger.info(
        'PrinterReadinessManager: Starting error check and fix for ${format.name}');
    final command = CommandFactory.createGetHostStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      if (!ParserUtil.isStatusOk(result.data)) {
        // Try to clear errors using format-specific commands
        if (options.fixPrinterErrors) {
          _logger.info(
              'PrinterReadinessManager: Attempting to clear errors using ${format.name} command');
          Result clearResult;

          switch (format) {
            case PrintFormat.zpl:
              // Use ZPL-specific clear errors command
              _logger.info(
                  'PrinterReadinessManager: Using ZPL clear errors command');
              final zplClearCommand =
                  CommandFactory.createSendZplClearErrorsCommand(_printer);
              clearResult = await zplClearCommand.execute();
              break;
            case PrintFormat.cpcl:
              // Use CPCL-specific clear errors command
              _logger.info(
                  'PrinterReadinessManager: Using CPCL clear errors command');
              final cpclClearCommand =
                  CommandFactory.createSendCpclClearErrorsCommand(_printer);
              clearResult = await cpclClearCommand.execute();
              break;
          }
          
          if (clearResult.success) {
            appliedFixes.add('clearErrors');
            _log('Printer errors cleared using ${format.name} command');
          } else {
            failedFixes.add('clearErrors');
            fixErrors['clearErrors'] =
                clearResult.error?.message ?? 'Error clearing failed';
            _log('Error clearing failed: ${fixErrors['clearErrors']}');
          }
        } else {
          final errorMsg = ParserUtil.parseErrorFromStatus(result.data) ?? 'Printer error';
          failedFixes.add('errors');
          fixErrors['errors'] = errorMsg;
          _log('Printer has errors: $errorMsg');
        }
      } else {
        _log('Error check passed');
      }
    } else {
      failedFixes.add('errors');
      fixErrors['errors'] = result.error?.message ?? 'Error status check failed';
      _log('Error status check failed: ${fixErrors['errors']}');
    }
  }
  
  Future<void> _checkAndFixLanguage(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    PrintFormat format,
    ReadinessOptions options,
  ) async {
    _logger.info(
        'PrinterReadinessManager: Starting language check and fix for ${format.name}');
    final command = CommandFactory.createGetLanguageCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      final currentLanguage = result.data!;
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
              'PrinterReadinessManager: Language mismatch detected, attempting to switch');
          _log(
              'Switching printer language from $currentLanguage to $expectedLanguage');

          final switchCommand = format == PrintFormat.zpl
              ? CommandFactory.createSendSetZplModeCommand(_printer)
              : CommandFactory.createSendSetCpclModeCommand(_printer);

          _logger.info(
              'PrinterReadinessManager: Executing ${format.name} language switch command');
          final switchResult = await switchCommand.execute();

          if (switchResult.success) {
            appliedFixes.add('switchLanguage');
            _log('Successfully switched printer to ${format.name} mode');
          } else {
            failedFixes.add('switchLanguage');
            fixErrors['switchLanguage'] =
                switchResult.error?.message ?? 'Language switch failed';
            _log('Language switch failed: ${fixErrors['switchLanguage']}');
          }
        } else {
          // Only log the mismatch without switching
          failedFixes.add('language');
          fixErrors['language'] =
              'Language mismatch: current=$currentLanguage, expected=$expectedLanguage';
          _log('Language check failed: ${fixErrors['language']}');
        }
      } else {
        _log('Language check passed for ${format.name}');
      }
    } else {
      failedFixes.add('language');
      fixErrors['language'] = result.error?.message ?? 'Language check failed';
      _log('Language check failed: ${fixErrors['language']}');
    }
  }
  
  Future<void> _checkAndFixBuffer(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    PrintFormat format,
  ) async {
    _logger.info(
        'PrinterReadinessManager: Starting buffer clear for ${format.name}');
    Result result;

    switch (format) {
      case PrintFormat.zpl:
        // Use ZPL-specific buffer clear command
        _logger.info('PrinterReadinessManager: Using ZPL buffer clear command');
        final command =
            CommandFactory.createSendZplClearBufferCommand(_printer);
        result = await command.execute();
        break;
      case PrintFormat.cpcl:
        // For CPCL, use CPCL-specific buffer clear command
        _logger
            .info('PrinterReadinessManager: Using CPCL buffer clear command');
        final cpclCommand =
            CommandFactory.createSendCpclClearBufferCommand(_printer);
        result = await cpclCommand.execute();
        break;
    }
    
    if (result.success) {
      appliedFixes.add('clearBuffer');
      _log('Buffer cleared using ${format.name} command');
    } else {
      failedFixes.add('clearBuffer');
      fixErrors['clearBuffer'] = result.error?.message ?? 'Buffer clear failed';
      _log('Buffer clear failed: ${fixErrors['clearBuffer']}');
    }
  }
  
  Future<void> _checkAndFixFlush(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
    PrintFormat format,
  ) async {
    _logger.info(
        'PrinterReadinessManager: Starting buffer flush for ${format.name}');
    Result result;

    switch (format) {
      case PrintFormat.zpl:
        // Use ZPL-specific buffer flush command
        _logger.info('PrinterReadinessManager: Using ZPL buffer flush command');
        final command =
            CommandFactory.createSendZplFlushBufferCommand(_printer);
        result = await command.execute();
        break;
      case PrintFormat.cpcl:
        // Use CPCL-specific buffer flush command
        _logger
            .info('PrinterReadinessManager: Using CPCL buffer flush command');
        final cpclCommand =
            CommandFactory.createSendCpclFlushBufferCommand(_printer);
        result = await cpclCommand.execute();
        break;
    }
    
    if (result.success) {
      appliedFixes.add('flushBuffer');
      _log('Buffer flushed using ${format.name} command');
    } else {
      failedFixes.add('flushBuffer');
      fixErrors['flushBuffer'] = result.error?.message ?? 'Buffer flush failed';
      _log('Buffer flush failed: ${fixErrors['flushBuffer']}');
    }
  }
  
  Future<PrinterReadiness> _buildReadinessStatus() async {
    _logger.info('PrinterReadinessManager: Building readiness status');
    final readiness = PrinterReadiness();
    
    // Build readiness status from the checks we performed
    // This could be enhanced to store state during the check/fix process
    // For now, we'll do a final status check
    
    _logger.info('PrinterReadinessManager: Checking final connection status');
    final connectionResult = await CommandFactory.createCheckConnectionCommand(_printer).execute();
    readiness.isConnected = connectionResult.success ? connectionResult.data : false;
    
    _logger.info('PrinterReadinessManager: Checking final media status');
    final mediaResult = await CommandFactory.createGetMediaStatusCommand(_printer).execute();
    if (mediaResult.success && mediaResult.data != null) {
      readiness.mediaStatus = mediaResult.data;
      readiness.hasMedia = ParserUtil.hasMedia(mediaResult.data);
      _logger.info(
          'PrinterReadinessManager: Media status: ${mediaResult.data}, hasMedia: ${readiness.hasMedia}');
    }
    
    _logger.info('PrinterReadinessManager: Checking final head status');
    final headResult = await CommandFactory.createGetHeadStatusCommand(_printer).execute();
    if (headResult.success && headResult.data != null) {
      readiness.headStatus = headResult.data;
      readiness.headClosed = ParserUtil.isHeadClosed(headResult.data);
      _logger.info(
          'PrinterReadinessManager: Head status: ${headResult.data}, headClosed: ${readiness.headClosed}');
    }
    
    _logger.info('PrinterReadinessManager: Checking final pause status');
    final pauseResult = await CommandFactory.createGetPauseStatusCommand(_printer).execute();
    if (pauseResult.success && pauseResult.data != null) {
      readiness.pauseStatus = pauseResult.data;
      readiness.isPaused = ParserUtil.toBool(pauseResult.data);
      _logger.info(
          'PrinterReadinessManager: Pause status: ${pauseResult.data}, isPaused: ${readiness.isPaused}');
    }
    
    _logger.info('PrinterReadinessManager: Checking final host status');
    final hostResult = await CommandFactory.createGetHostStatusCommand(_printer).execute();
    if (hostResult.success && hostResult.data != null) {
      readiness.hostStatus = hostResult.data;
      _logger.info('PrinterReadinessManager: Host status: ${hostResult.data}');
      if (!ParserUtil.isStatusOk(hostResult.data)) {
        final errorMsg = ParserUtil.parseErrorFromStatus(hostResult.data) ?? 
                        'Printer error: ${hostResult.data}';
        readiness.errors.add(errorMsg);
        _logger.warning(
            'PrinterReadinessManager: Host status indicates error: $errorMsg');
      }
    }
    
    _logger
        .info('PrinterReadinessManager: Readiness status built successfully');
    _logger.info(
        'PrinterReadinessManager: Final readiness - Connected: ${readiness.isConnected}, Ready: ${readiness.isReady}, Errors: ${readiness.errors.length}');
    return readiness;
  }
  
  void _analyzeDiagnostics(Map<String, dynamic> diagnostics) {
    _logger.info('PrinterReadinessManager: Analyzing diagnostics data');
    // Analyze diagnostics and add recommendations
    if (diagnostics['status']['Media Status'] == 'no media') {
      diagnostics['recommendations'].add('Load media into the printer');
      _logger.info(
          'PrinterReadinessManager: Added recommendation: Load media into the printer');
    }
    
    if (diagnostics['status']['Head Status'] == 'open') {
      diagnostics['recommendations'].add('Close the print head');
      _logger.info(
          'PrinterReadinessManager: Added recommendation: Close the print head');
    }
    
    if (diagnostics['status']['Pause Status'] == 'true') {
      diagnostics['recommendations'].add('Unpause the printer');
      _logger.info(
          'PrinterReadinessManager: Added recommendation: Unpause the printer');
    }
    
    _logger.info(
        'PrinterReadinessManager: Diagnostics analysis completed with ${diagnostics['recommendations'].length} recommendations');
  }
} 