import 'dart:async';
import '../models/auto_correction_options.dart';
import '../models/printer_readiness.dart';
import '../models/result.dart';
import '../models/print_enums.dart';
import '../zebra_printer.dart';
import '../zebra_sgd_commands.dart';
import 'internal/state_change_verifier.dart';
import 'internal/logger.dart';
import 'internal/parser_util.dart';

/// Manages printer state including readiness checks, corrections, and buffer management
class PrinterStateManager {
  final ZebraPrinter _printer;
  final AutoCorrectionOptions _options;
  final Function(String)? _statusCallback;
  late final StateChangeVerifier _stateVerifier;
  late final Logger _logger;

  PrinterStateManager({
    required ZebraPrinter printer,
    required AutoCorrectionOptions options,
    Function(String)? statusCallback,
  })  : _printer = printer,
        _options = options,
        _statusCallback = statusCallback {
    _stateVerifier = StateChangeVerifier(
      printer: _printer,
      logCallback: _log,
    );
    _logger = Logger.withPrefix('PrinterStateManager');
  }

  void _log(String message) {
    _statusCallback?.call(message);
    _logger.debug(message);
  }

  /// Attempt to correct printer issues based on readiness status
  Future<Result<bool>> correctReadiness(PrinterReadiness readiness) async {
    if (!_options.hasAnyEnabled) {
      return Result.success(false); // No corrections enabled
    }

    bool corrected = false;

    // Handle paused state
    if (readiness.isPaused == true && _options.enableUnpause) {
      _log('Printer is paused, attempting to unpause...');
      final result = await _unpausePrinter();
      if (result.success) {
        corrected = true;
        _log('Successfully unpaused printer');
      } else {
        _log('Failed to unpause printer: ${result.error?.message}');
      }
    }

    // Handle errors that can be cleared
    if (readiness.errors.isNotEmpty && _options.enableClearErrors) {
      _log('Attempting to clear errors...');
      final result = await _clearErrors();
      if (result.success) {
        corrected = true;
        _log('Successfully cleared errors');
      } else {
        _log('Failed to clear errors: ${result.error?.message}');
      }
    }

    // Handle calibration needs (if no media detected)
    if (readiness.hasMedia == false && _options.enableCalibration) {
      _log('No media detected, attempting to calibrate...');
      final result = await _calibratePrinter();
      if (result.success) {
        corrected = true;
        _log('Successfully calibrated printer');
      } else {
        _log('Failed to calibrate printer: ${result.error?.message}');
      }
    }

    return Result.success(corrected);
  }

  /// Unpause the printer
  Future<Result<bool>> _unpausePrinter() async {
    return await _stateVerifier.setBooleanState(
      operationName: 'Unpause printer',
      command: '! U1 setvar "device.pause" "false"',
      getSetting: _getPauseStatus,
      desiredState: false,
      checkDelay: const Duration(milliseconds: 200),
      maxAttempts: 3,
    );
  }

  /// Clear printer errors
  Future<Result<bool>> _clearErrors() async {
    // Clearing errors doesn't have a direct state to verify
    // We'll send the command and check if errors are gone
    final result = await _stateVerifier.executeWithDelay(
      operationName: 'Clear errors',
      command: '~JE', // Clear error command
      delay: const Duration(milliseconds: 500),
    );

    return result.success
        ? Result.success(true)
        : Result.error(result.error?.message ?? 'Failed to clear errors');
  }

  /// Calibrate the printer
  Future<Result<bool>> _calibratePrinter() async {
    // Calibration takes longer and we can't easily verify completion
    _logger.info('Starting printer calibration');

    final result = await _stateVerifier.executeWithDelay(
      operationName: 'Calibrate printer',
      command: '~jc^xa^jus^xz',
      delay: const Duration(milliseconds: 1000), // Calibration takes longer
    );

    if (result.success) {
      _logger.info('Calibration command sent successfully');
    } else {
      _logger.error('Failed to send calibration command', result.error);
    }

    return result.success
        ? Result.success(true)
        : Result.error(result.error?.message ?? 'Failed to calibrate');
  }

  /// Attempt to switch printer language based on data format
  Future<bool> switchLanguageForData(String data) async {
    if (!_options.enableLanguageSwitch) return true;

    try {
      final detectedLanguage = ZebraSGDCommands.detectDataLanguage(data);
      if (detectedLanguage == null) return true; // Can't detect, assume OK

      _logger.info(
          'Detected language: $detectedLanguage, attempting to switch if needed');

      // Get current language
      final currentLang = await _getPrinterLanguage();
      if (currentLang == null) {
        _logger.warning('Could not get current printer language');
        return true; // Can't verify, assume OK
      }

      // Check if we need to switch
      final needsZPL = detectedLanguage == 'zpl' &&
          !currentLang.toLowerCase().contains('zpl');
      final needsCPCL = detectedLanguage == 'cpcl' &&
          !currentLang.toLowerCase().contains('line_print');

      if (!needsZPL && !needsCPCL) {
        _logger.debug('Language already correct');
        return true;
      }

      // Switch language
      final targetMode = needsZPL ? PrinterMode.zpl : PrinterMode.cpcl;
      final command = needsZPL
          ? ZebraSGDCommands.setZPLMode()
          : ZebraSGDCommands.setCPCLMode();
      final expectedValue = needsZPL ? 'zpl' : 'line_print';

      _logger.info('Switching printer to ${targetMode.name} mode');

      final result = await _stateVerifier.setStringState(
        operationName: 'Switch language to ${targetMode.name}',
        command: command,
        getSetting: _getPrinterLanguage,
        validator: (value) =>
            value?.toLowerCase().contains(expectedValue) ?? false,
        checkDelay: const Duration(milliseconds: 500),
        maxAttempts: 3,
      );

      if (result.success) {
        _logger.info('Successfully switched to ${targetMode.name} mode');
        return true;
      } else {
        _logger.error('Failed to switch language', result.error);
        return false;
      }
    } catch (e) {
      _log('Failed to check/switch language: $e');
      return false;
    }
  }

  /// Correct any issues that might prevent successful printing
  /// This is a pre-print check that ensures the printer is in a good state
  Future<Result<bool>> correctForPrinting({
    required String data,
    PrintFormat? format,
  }) async {
    try {
      bool madeCorrections = false;

      // Detect format if not specified
      if (format == null) {
        if (ZebraSGDCommands.isZPLData(data)) {
          format = PrintFormat.zpl;
        } else if (ZebraSGDCommands.isCPCLData(data)) {
          format = PrintFormat.cpcl;
        }
      }

      // 1. Clear buffer if enabled (always recommended for CPCL)
      if (_options.enableBufferClear || format == PrintFormat.cpcl) {
        final bufferResult = await clearPrinterBuffer(format);
        if (bufferResult.success) {
          madeCorrections = true;
        }
      }

      // 2. Switch language if needed and enabled
      if (_options.enableLanguageSwitch && format != null) {
        final switched = await switchLanguageForData(data);
        if (switched) {
          madeCorrections = true;
        }
      }

      // 3. Check and correct printer readiness if enabled
      if (_options.enableUnpause || _options.enableClearErrors) {
        // Get current printer status
        final hostStatus = await _getHostStatus();
        final pauseStatus = await _getPauseStatus();

        // Unpause if needed
        if (_options.enableUnpause && ParserUtil.toBool(pauseStatus) == true) {
          _log('Printer is paused, attempting to unpause...');
          _printer.sendCommand(ZebraSGDCommands.unpausePrinter());
          await Future.delayed(const Duration(milliseconds: 500));
          madeCorrections = true;
        }

        // Clear errors if needed
        if (_options.enableClearErrors &&
            hostStatus != null &&
            !ParserUtil.isStatusOk(hostStatus)) {
          _log('Clearing printer errors...');
          _printer.sendCommand(ZebraSGDCommands.clearAlerts());
          await Future.delayed(const Duration(milliseconds: 500));
          madeCorrections = true;
        }
      }

      return Result.success(madeCorrections);
    } catch (e, stack) {
      _logger.error('Error during pre-print correction', e);
      return Result.error(
        'Pre-print correction failed: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Clear printer buffer and reset print engine state
  /// This helps prevent issues where the printer is waiting for more data
  Future<Result<void>> clearPrinterBuffer(PrintFormat? format) async {
    try {
      _log('Clearing printer buffer...');

      // Use sendCommand for control sequences to avoid printing them
      // 1. Send ESC to reset CPCL parser
      _printer.sendCommand('\x1B'); // ESC character
      await Future.delayed(const Duration(milliseconds: 50));

      // 2. Send CAN to cancel any pending operations
      _printer.sendCommand('\x18'); // CAN character
      await Future.delayed(const Duration(milliseconds: 50));

      // 3. Send cancel all for ZPL
      if (format == PrintFormat.zpl) {
        _printer.sendCommand('~JA');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _log('Printer buffer cleared');
      return Result.success();
    } catch (e, stack) {
      _logger.error('Buffer clear error', e);
      return Result.error(
        'Failed to clear printer buffer: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Flush the printer's buffer to ensure all data is processed
  /// This is especially important for CPCL printing
  Future<Result<void>> flushPrintBuffer() async {
    try {
      _log('Flushing print buffer...');

      // Send ETX character as a command to signal end of transmission
      // This ensures any buffered CPCL data is processed
      _printer.sendCommand('\x03'); // ETX character

      // Small delay to ensure buffer is flushed
      await Future.delayed(const Duration(milliseconds: 100));

      _log('Print buffer flushed');
      return Result.success();
    } catch (e, stack) {
      _logger.error('Buffer flush error', e);
      return Result.error(
        'Failed to flush print buffer: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Check if printer is ready to print
  /// Always returns success, with isReady flag indicating readiness
  /// Only fails if status information cannot be retrieved
  Future<Result<PrinterReadiness>> checkPrinterReadiness() async {
    final readiness = PrinterReadiness();

    try {
      // Check connection first
      final isConnected = await _printer.isPrinterConnected();
      readiness.isConnected = isConnected;
      
      if (!isConnected) {
        readiness.isReady = false;
        readiness.errors.add('Printer connection lost');
        return Result.success(readiness);
      }

      // Implement full printer readiness checks
      try {
        readiness.fullCheckPerformed = true;

        // Check media status
        readiness.mediaStatus = await _doGetSetting('media.status');
        if (readiness.mediaStatus != null) {
          readiness.hasMedia = ParserUtil.hasMedia(readiness.mediaStatus);
          if (readiness.hasMedia == false) {
            readiness.warnings.add('Media not ready: ${readiness.mediaStatus}');
          }
        }

        // Check head latch
        readiness.headStatus = await _doGetSetting('head.latch');
        if (readiness.headStatus != null) {
          readiness.headClosed = ParserUtil.isHeadClosed(readiness.headStatus);
          if (readiness.headClosed == false) {
            readiness.errors.add('Print head is open');
          }
        }

        // Check pause status
        readiness.pauseStatus = await _getPauseStatus();
        if (readiness.pauseStatus != null) {
          readiness.isPaused = ParserUtil.toBool(readiness.pauseStatus);
          if (readiness.isPaused == true) {
            readiness.warnings.add('Printer is paused');
          }
        }

        // Check for errors
        readiness.hostStatus = await _getHostStatus();
        if (readiness.hostStatus != null) {
          if (!ParserUtil.isStatusOk(readiness.hostStatus)) {
            final errorMsg =
                ParserUtil.parseErrorFromStatus(readiness.hostStatus) ??
                    'Printer error: ${readiness.hostStatus}';
            readiness.errors.add(errorMsg);
          }
        }

        // Determine overall readiness based on collected status
        readiness.isReady = (readiness.isConnected ?? false) &&
            (readiness.headClosed ?? true) &&
            !(readiness.isPaused ?? false) &&
            readiness.errors.isEmpty;

        if (readiness.isReady) {
          _log('Printer is ready');
        } else {
          _log('Printer not ready: ${readiness.summary}');
        }

        return Result.success(readiness);
      } catch (e) {
        // If we can't get status information, this is a failure
        readiness.fullCheckPerformed = false;
        readiness.isReady = false;
        readiness.errors.add('Failed to retrieve printer status: $e');
        return Result.error(
          'Failed to retrieve printer status: $e',
          code: ErrorCodes.operationError,
        );
      }
    } catch (e, stack) {
      // Only fail if there's an actual error in the checking process
      readiness.isReady = false;
      readiness.errors.add('Error checking printer status: $e');
      return Result.error(
        'Error checking printer status: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Run comprehensive diagnostics on the printer
  Future<Result<Map<String, dynamic>>> runDiagnostics() async {
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
      // Check connection first
      final isConnected = await _printer.isPrinterConnected();
      diagnostics['connected'] = isConnected;

      if (!isConnected) {
        diagnostics['errors'].add('Connection lost');
        diagnostics['recommendations'].add('Reconnect to the printer');
        return Result.success(diagnostics);
      }

      // Get comprehensive status
      _log('Running comprehensive diagnostics...');

      // Get host status separately using our dedicated method
      final hostStatus = await _getHostStatus();
      if (hostStatus != null) {
        diagnostics['status']['Host Status'] = hostStatus;
      }

      // Basic status checks
      final statusChecks = {
        'media.status': 'Media Status',
        'head.latch': 'Head Status',
        'device.pause': 'Pause Status',
        'odometer.total_print_length': 'Total Print Length',
        'sensor.peeler': 'Peeler Status',
        'device.languages': 'Printer Language',
        'device.unique_id': 'Device ID',
        'device.product_name': 'Product Name',
        'appl.name': 'Firmware Version',
        'media.type': 'Media Type',
        'print.tone': 'Print Darkness',
        'ezpl.print_width': 'Print Width',
        'zpl.label_length': 'Label Length',
      };

      for (final entry in statusChecks.entries) {
        try {
          final value = await _doGetSetting(entry.key);
          if (value != null) {
            diagnostics['status'][entry.value] = value;
          }
        } catch (e) {
          // Continue with other checks
        }
      }

      // Analyze results and provide recommendations
      _analyzeDiagnostics(diagnostics);

      _log('Diagnostics complete');
      return Result.success(diagnostics);
    } catch (e, stack) {
      diagnostics['errors'].add('Diagnostic error: $e');
      return Result.error(
        'Failed to run diagnostics: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  void _analyzeDiagnostics(Map<String, dynamic> diagnostics) {
    final status = diagnostics['status'] as Map<String, dynamic>;
    final recommendations = diagnostics['recommendations'] as List;
    final errors = diagnostics['errors'] as List;

    // Check host status
    final hostStatus = status['Host Status']?.toString().toLowerCase();
    if (hostStatus != null && !hostStatus.contains('ok')) {
      errors.add('Printer reports error: $hostStatus');
      recommendations.add('Check printer display for error details');
    }

    // Check media
    final mediaStatus = status['Media Status']?.toString().toLowerCase();
    if (mediaStatus != null &&
        !mediaStatus.contains('ok') &&
        !mediaStatus.contains('ready')) {
      errors.add('Media issue: $mediaStatus');
      recommendations.add('Check paper/labels are loaded correctly');
    }

    // Check head
    final headStatus = status['Head Status']?.toString().toLowerCase();
    if (headStatus != null &&
        !headStatus.contains('ok') &&
        !headStatus.contains('closed')) {
      errors.add('Print head is open');
      recommendations.add('Close the print head');
    }

    // Check pause
    final pauseStatus = status['Pause Status']?.toString().toLowerCase();
    if (pauseStatus == 'true' || pauseStatus == '1' || pauseStatus == 'on') {
      errors.add('Printer is paused');
      recommendations.add('Unpause the printer (can be auto-corrected)');
    }

    // Check language
    final language = status['Printer Language']?.toString().toLowerCase();
    if (language != null) {
      if (language.contains('zpl')) {
        status['Language Mode'] = 'ZPL';
      } else if (language.contains('line_print') || language.contains('cpcl')) {
        status['Language Mode'] = 'CPCL/Line Print';
      }
    }

    // If no specific errors found but printer won't print
    if (errors.isEmpty && diagnostics['connected'] == true) {
      recommendations.add('Try power cycling the printer');
      recommendations.add('Check printer queue on the device');
      recommendations.add('Verify print data format matches printer language');
      recommendations.add('Try a factory reset if issues persist');
    }
  }

  /// Helper method to get and parse printer settings (private)
  Future<String?> _doGetSetting(String setting) async {
    try {
      // Use the getSetting method from ZebraPrinter
      final value = await _printer.getSetting(setting);
      if (value != null && value.isNotEmpty) {
        // Parse the response using our SGD parser
        return ZebraSGDCommands.parseResponse(value);
      }
      return null;
    } catch (e) {
      _logger.warning('Failed to get setting $setting: $e');
      return null;
    }
  }

  /// Helper method to get host status (private)
  Future<String?> _getHostStatus() async {
    return _doGetSetting('device.host_status');
  }

  /// Helper method to get pause status (private)
  Future<String?> _getPauseStatus() async {
    try {
      final value = await _printer.getSetting('device.pause');
      if (value != null && value.isNotEmpty) {
        return ZebraSGDCommands.parseResponse(value);
      }
      return null;
    } catch (e) {
      // Re-throw to preserve original exception behavior
      rethrow;
    }
  }

  /// Helper method to get printer language (private)
  Future<String?> _getPrinterLanguage() async {
    try {
      final value = await _printer.getSetting('device.languages');
      if (value != null && value.isNotEmpty) {
        return ZebraSGDCommands.parseResponse(value);
      }
      return null;
    } catch (e) {
      // Re-throw to preserve original exception behavior
      rethrow;
    }
  }
}

/// Result of auto-correction attempt
class CorrectionResult {
  final bool correctionsMade;
  final List<String> actions;
  final String message;

  CorrectionResult({
    required this.correctionsMade,
    required this.actions,
    required this.message,
  });
}
