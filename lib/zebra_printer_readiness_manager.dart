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
    _logger.debug(message);
  }
  
  /// Prepare printer for printing with specified options
  Future<Result<ReadinessResult>> prepareForPrint(
    PrintFormat format,
    ReadinessOptions options,
  ) async {
    final stopwatch = Stopwatch()..start();
    _log('Starting printer preparation for print (format: ${format.name})...');
    
    try {
      final appliedFixes = <String>[];
      final failedFixes = <String>[];
      final fixErrors = <String, String>{};
      
      // 1. Check and fix connection
      if (options.checkConnection) {
        await _checkAndFixConnection(appliedFixes, failedFixes, fixErrors);
      }
      
      // 2. Check and fix media
      if (options.checkMedia) {
        await _checkAndFixMedia(appliedFixes, failedFixes, fixErrors, options);
      }
      
      // 3. Check and fix head
      if (options.checkHead) {
        await _checkAndFixHead(appliedFixes, failedFixes, fixErrors);
      }
      
      // 4. Check and fix pause
      if (options.checkPause) {
        await _checkAndFixPause(appliedFixes, failedFixes, fixErrors, options);
      }
      
      // 5. Check and fix errors (format-specific)
      if (options.checkErrors) {
        await _checkAndFixErrors(
            appliedFixes, failedFixes, fixErrors, options, format);
      }
      
      // 6. Check and fix language (format-specific)
      if (options.checkLanguage) {
        await _checkAndFixLanguage(
            appliedFixes, failedFixes, fixErrors, format);
      }
      
      // 7. Handle buffer operations (format-specific)
      if (options.clearBuffer) {
        await _checkAndFixBuffer(appliedFixes, failedFixes, fixErrors, format);
      }
      
      if (options.flushBuffer) {
        await _checkAndFixFlush(appliedFixes, failedFixes, fixErrors, format);
      }
      
      // 8. Create readiness result
      final readiness = await _buildReadinessStatus();
      final result = ReadinessResult.fromReadiness(
        readiness,
        appliedFixes,
        failedFixes,
        fixErrors,
        stopwatch.elapsed,
      );
      
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
      final connectionResult = await _checkConnection();
      diagnostics['connected'] = connectionResult.success ? connectionResult.data : false;
      
      if (!diagnostics['connected']) {
        diagnostics['errors'].add('Connection lost');
        diagnostics['recommendations'].add('Reconnect to the printer');
        return Result.success(diagnostics);
      }
      
      // Run comprehensive status checks using commands
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
        try {
          final command = CommandFactory.createGetSettingCommand(_printer, setting);
          final result = await command.execute();
          if (result.success && result.data != null) {
            diagnostics['status'][label] = result.data;
          }
        } catch (e) {
          // Continue with other checks
        }
      }
      
      // Analyze and provide recommendations
      _analyzeDiagnostics(diagnostics);
      
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
    final readiness = await _buildReadinessStatus();
    return Result.success(readiness);
  }
  
  /// Validate if the printer state is ready
  Future<Result<bool>> validatePrinterState() async {
    final result = await getDetailedStatus();
    if (!result.success) {
      return Result.failure(result.error!);
    }
    
    final readiness = result.data!;
    return Result.success(readiness.isReady);
  }
  
  // Private check methods - each uses a single command
  Future<Result<bool>> _checkConnection() async {
    final command = CommandFactory.createCheckConnectionCommand(_printer);
    return await command.execute();
  }
  
  // Individual check and fix methods using printer commands
  Future<void> _checkAndFixConnection(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
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
    final command = CommandFactory.createGetMediaStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      final hasMedia = ParserUtil.hasMedia(result.data);
      if (hasMedia == false) {
        // Try to fix media calibration
        if (options.fixMediaCalibration) {
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
    final command = CommandFactory.createGetPauseStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      final isPaused = ParserUtil.toBool(result.data);
      if (isPaused == true) {
        // Try to unpause
        if (options.fixPausedPrinter) {
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
    final command = CommandFactory.createGetHostStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      if (!ParserUtil.isStatusOk(result.data)) {
        // Try to clear errors using format-specific commands
        if (options.fixPrinterErrors) {
          Result clearResult;

          switch (format) {
            case PrintFormat.zpl:
              // Use ZPL-specific clear errors command
              final zplClearCommand =
                  CommandFactory.createSendZplClearErrorsCommand(_printer);
              clearResult = await zplClearCommand.execute();
              break;
            case PrintFormat.cpcl:
              // Use CPCL-specific clear errors command
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
  ) async {
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
        // Note: Language switching would require additional context and careful handling
        // For now, we log the mismatch but don't automatically switch
        // This prevents issues with partial data or incorrect format detection
        failedFixes.add('language');
        fixErrors['language'] =
            'Language mismatch: current=$currentLanguage, expected=$expectedLanguage';
        _log('Language check failed: ${fixErrors['language']}');
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
    Result result;

    switch (format) {
      case PrintFormat.zpl:
        // Use ZPL-specific buffer clear command
        final command =
            CommandFactory.createSendZplClearBufferCommand(_printer);
        result = await command.execute();
        break;
      case PrintFormat.cpcl:
        // For CPCL, use CPCL-specific buffer clear command
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
    Result result;

    switch (format) {
      case PrintFormat.zpl:
        // Use ZPL-specific buffer flush command
        final command =
            CommandFactory.createSendZplFlushBufferCommand(_printer);
        result = await command.execute();
        break;
      case PrintFormat.cpcl:
        // Use CPCL-specific buffer flush command
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
    final readiness = PrinterReadiness();
    
    // Build readiness status from the checks we performed
    // This could be enhanced to store state during the check/fix process
    // For now, we'll do a final status check
    
    final connectionResult = await CommandFactory.createCheckConnectionCommand(_printer).execute();
    readiness.isConnected = connectionResult.success ? connectionResult.data : false;
    
    final mediaResult = await CommandFactory.createGetMediaStatusCommand(_printer).execute();
    if (mediaResult.success && mediaResult.data != null) {
      readiness.mediaStatus = mediaResult.data;
      readiness.hasMedia = ParserUtil.hasMedia(mediaResult.data);
    }
    
    final headResult = await CommandFactory.createGetHeadStatusCommand(_printer).execute();
    if (headResult.success && headResult.data != null) {
      readiness.headStatus = headResult.data;
      readiness.headClosed = ParserUtil.isHeadClosed(headResult.data);
    }
    
    final pauseResult = await CommandFactory.createGetPauseStatusCommand(_printer).execute();
    if (pauseResult.success && pauseResult.data != null) {
      readiness.pauseStatus = pauseResult.data;
      readiness.isPaused = ParserUtil.toBool(pauseResult.data);
    }
    
    final hostResult = await CommandFactory.createGetHostStatusCommand(_printer).execute();
    if (hostResult.success && hostResult.data != null) {
      readiness.hostStatus = hostResult.data;
      if (!ParserUtil.isStatusOk(hostResult.data)) {
        final errorMsg = ParserUtil.parseErrorFromStatus(hostResult.data) ?? 
                        'Printer error: ${hostResult.data}';
        readiness.errors.add(errorMsg);
      }
    }
    
    return readiness;
  }
  
  void _analyzeDiagnostics(Map<String, dynamic> diagnostics) {
    // Analyze diagnostics and add recommendations
    if (diagnostics['status']['Media Status'] == 'no media') {
      diagnostics['recommendations'].add('Load media into the printer');
    }
    
    if (diagnostics['status']['Head Status'] == 'open') {
      diagnostics['recommendations'].add('Close the print head');
    }
    
    if (diagnostics['status']['Pause Status'] == 'true') {
      diagnostics['recommendations'].add('Unpause the printer');
    }
  }
} 