import '../models/auto_correction_options.dart';
import '../models/printer_readiness.dart';
import '../models/result.dart';
import '../zebra_printer.dart';
import '../zebra_sgd_commands.dart';
import 'parser_util.dart';
import 'state_change_verifier.dart';

/// Handles automatic correction of common printer issues
class AutoCorrector {
  final ZebraPrinter _printer;
  final AutoCorrectionOptions _options;
  final Function(String)? _statusCallback;
  late final StateChangeVerifier _stateVerifier;

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
  }

  void _log(String message) {
    _statusCallback?.call(message);
  }

  /// Attempt to correct printer issues based on readiness status
  Future<Result<CorrectionResult>> attemptCorrection(
      PrinterReadiness readiness) async {
    final actions = <String>[];
    bool anySuccess = false;

    try {
      // Check if printer is paused
      if (_options.enableUnpause &&
          ParserUtil.toBool(readiness.pauseStatus) == true) {
        _log('Printer is paused, attempting to unpause...');

        final unpauseResult = await _unpausePrinter();
        if (unpauseResult.success) {
          actions.add('Unpaused printer');
          anySuccess = true;
        } else {
          actions.add(
              'Failed to unpause printer: ${unpauseResult.error?.message}');
        }
      }

      // Check for errors that can be cleared
      if (_options.enableClearErrors &&
          readiness.errors.isNotEmpty &&
          !ParserUtil.isStatusOk(readiness.hostStatus)) {
        _log('Clearing printer errors...');

        final clearResult = await _clearErrors();
        if (clearResult.success) {
          actions.add('Cleared printer errors');
          anySuccess = true;
        } else {
          actions.add('Failed to clear errors: ${clearResult.error?.message}');
        }
      }

      // Check if calibration is needed (based on media status)
      if (_options.enableCalibration &&
          !ParserUtil.hasMedia(readiness.mediaStatus) &&
          ParserUtil.isHeadClosed(readiness.headStatus)) {
        _log('Media detection issue, attempting calibration...');

        final calibrateResult = await _calibratePrinter();
        if (calibrateResult.success) {
          actions.add('Calibrated printer');
          anySuccess = true;
        } else {
          actions.add('Failed to calibrate: ${calibrateResult.error?.message}');
        }
      }

      // Language switching would be done at print time, not here

      return Result.success(CorrectionResult(
        correctionsMade: anySuccess,
        actions: actions,
        message: anySuccess
            ? 'Applied corrections: ${actions.join(', ')}'
            : 'No corrections applied',
      ));
    } catch (e, stack) {
      return Result.error(
        'Auto-correction failed: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Attempt to unpause the printer
  Future<Result<bool>> _unpausePrinter() async {
    return await _stateVerifier.setBooleanState(
      operationName: 'Unpause printer',
      command: ZebraSGDCommands.unpausePrinter(),
      getSetting: () => _printer.getSetting('device.pause'),
      desiredState: false, // false = not paused
      checkDelay: const Duration(milliseconds: 200),
      maxAttempts: 3,
    );
  }

  /// Clear printer errors
  Future<Result<bool>> _clearErrors() async {
    // Clear errors is a fire-and-forget command with no verifiable state
    final result = await _stateVerifier.executeWithDelay(
      operationName: 'Clear errors',
      command: ZebraSGDCommands.clearAlerts(),
      delay: const Duration(milliseconds: 200),
    );

    return result.success
        ? Result.success(true)
        : Result.error(result.error?.message ?? 'Failed to clear errors');
  }

  /// Calibrate the printer
  Future<Result<bool>> _calibratePrinter() async {
    // Calibration takes longer and we can't easily verify completion
    // TODO: Could potentially verify by checking media.status after calibration
    final result = await _stateVerifier.executeWithDelay(
      operationName: 'Calibrate printer',
      command: '~jc^xa^jus^xz',
      delay: const Duration(milliseconds: 1000), // Calibration takes longer
    );

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

      // TODO: Implement language switching with state verification
      // This would need:
      // 1. Get current language via getSetting
      // 2. Switch if needed using stateVerifier.setStringState
      // 3. Verify the switch worked

      return true;
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
