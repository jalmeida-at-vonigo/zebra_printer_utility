import '../models/auto_correction_options.dart';
import '../models/printer_readiness.dart';
import '../models/result.dart';
import '../zebra_printer.dart';
import '../zebra_sgd_commands.dart';
import 'parser_util.dart';

/// Internal class that handles automatic printer issue correction
class AutoCorrector {
  final ZebraPrinter _printer;
  final AutoCorrectionOptions _options;
  final void Function(String)? _statusCallback;

  AutoCorrector({
    required ZebraPrinter printer,
    required AutoCorrectionOptions options,
    void Function(String)? statusCallback,
  })  : _printer = printer,
        _options = options,
        _statusCallback = statusCallback;

  /// Attempt to correct printer issues based on readiness state
  Future<Result<CorrectionResult>> attemptCorrection(
      PrinterReadiness readiness) async {
    if (!_options.hasAnyEnabled) {
      return Result.success(CorrectionResult(
        correctionsMade: false,
        actions: [],
        message: 'Auto-correction is disabled',
      ));
    }

    final actions = <String>[];
    bool anySuccess = false;

    try {
      // Check if printer is paused
      if (_options.enableUnpause &&
          ParserUtil.toBool(readiness.pauseStatus) == true) {
        _log('Printer is paused, attempting to unpause...');

        final unpauseResult = await _unpausePrinter();
        if (unpauseResult) {
          actions.add('Unpaused printer');
          anySuccess = true;
        } else {
          actions.add('Failed to unpause printer');
        }
      }

      // Check for errors that can be cleared
      if (_options.enableClearErrors &&
          readiness.errors.isNotEmpty &&
          !ParserUtil.isStatusOk(readiness.hostStatus)) {
        _log('Clearing printer errors...');

        final clearResult = await _clearErrors();
        if (clearResult) {
          actions.add('Cleared printer errors');
          anySuccess = true;
        } else {
          actions.add('Failed to clear errors');
        }
      }

      // Check if calibration is needed (based on media status)
      if (_options.enableCalibration &&
          !ParserUtil.hasMedia(readiness.mediaStatus) &&
          ParserUtil.isHeadClosed(readiness.headStatus)) {
        _log('Media detection issue, attempting calibration...');

        final calibrateResult = await _calibratePrinter();
        if (calibrateResult) {
          actions.add('Calibrated printer');
          anySuccess = true;
        } else {
          actions.add('Failed to calibrate');
        }
      }

      // Language switching would be done at print time, not here

      if (anySuccess) {
        // Wait for corrections to take effect
        await Future.delayed(Duration(milliseconds: _options.attemptDelayMs));
      }

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
  Future<bool> _unpausePrinter() async {
    try {
      // Use SGD command to unpause (works in any mode)
      _printer.sendCommand(ZebraSGDCommands.unpausePrinter());
      await Future.delayed(const Duration(milliseconds: 200));

      return true;
    } catch (e) {
      _log('Failed to unpause: $e');
      return false;
    }
  }

  /// Clear printer errors
  Future<bool> _clearErrors() async {
    try {
      _printer.sendCommand(ZebraSGDCommands.clearAlerts());
      await Future.delayed(const Duration(milliseconds: 200));
      return true;
    } catch (e) {
      _log('Failed to clear errors: $e');
      return false;
    }
  }

  /// Calibrate the printer
  Future<bool> _calibratePrinter() async {
    try {
      _printer.calibratePrinter();
      await Future.delayed(
          const Duration(milliseconds: 1000)); // Calibration takes longer
      return true;
    } catch (e) {
      _log('Failed to calibrate: $e');
      return false;
    }
  }

  /// Attempt to switch printer language based on data format
  Future<bool> switchLanguageForData(String data) async {
    if (!_options.enableLanguageSwitch) return true;

    try {
      final detectedLanguage = ZebraSGDCommands.detectDataLanguage(data);
      if (detectedLanguage == null) return true; // Can't detect, assume OK

      // Get current language
      final currentLanguageResult = await _printer.isPrinterConnected();
      if (!currentLanguageResult) return false;

      // For now, we'll assume the printer accepts the data
      // In a full implementation, we'd query the current language and switch if needed

      return true;
    } catch (e) {
      _log('Failed to check/switch language: $e');
      return false;
    }
  }

  void _log(String message) {
    _statusCallback?.call(message);
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
