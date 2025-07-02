import 'dart:async';
import '../models/auto_correction_options.dart';
import '../models/printer_readiness.dart';
import '../models/result.dart';
import '../zebra_printer.dart';
import '../zebra_sgd_commands.dart';
import 'state_change_verifier.dart';
import 'logger.dart';

/// Handles automatic correction of common printer issues
class AutoCorrector {
  final ZebraPrinter _printer;
  final AutoCorrectionOptions _options;
  final Function(String)? _statusCallback;
  late final StateChangeVerifier _stateVerifier;
  late final Logger _logger;

  AutoCorrector({
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
    _logger = Logger.withPrefix('AutoCorrector');
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
      getSetting: () => _printer.getSetting('device.pause'),
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
      final currentLang = await _printer.getSetting('device.languages');
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
        getSetting: () => _printer.getSetting('device.languages'),
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
