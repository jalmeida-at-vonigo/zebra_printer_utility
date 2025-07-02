import 'dart:async';
import '../models/result.dart';
import '../zebra_printer.dart';
import 'logger.dart';

/// Verifies state changes for operations that don't provide callbacks
///
/// This utility handles operations like mode switching, calibration, and
/// settings changes that execute on the printer but don't report completion.
/// It uses a verify-retry pattern to ensure operations actually completed.
class StateChangeVerifier {
  final ZebraPrinter printer;
  final Logger _logger;

  StateChangeVerifier({
    required this.printer,
    void Function(String)? logCallback,
  }) : _logger = Logger.withPrefix('StateChangeVerifier');

  void _log(String message) {
    _logger.debug(message);
  }

  /// Executes a command and verifies the state changed as expected
  ///
  /// First checks if the state is already correct (no-op if it is).
  /// If not, sends the command and polls to verify the change.
  ///
  /// Returns the final state value on success.
  Future<Result<T>> executeAndVerify<T>({
    required String operationName,
    required String command,
    required Future<T?> Function() checkState,
    required bool Function(T?) isStateValid,
    Duration checkDelay = const Duration(milliseconds: 200),
    int maxAttempts = 3,
    String? errorCode,
  }) async {
    try {
      _log('Starting $operationName verification');

      // First check if already in desired state
      final initialState = await checkState();
      if (isStateValid(initialState)) {
        _log('$operationName: Already in desired state');
        return Result.success(initialState as T);
      }

      _log('$operationName: Current state invalid, sending command');

      // Send the command
      final sendResult = await printer.print(data: command);
      if (!sendResult.success) {
        _log('$operationName: Failed to send command');
        return Result.error(
          'Failed to send $operationName command',
          code: errorCode ?? ErrorCodes.operationError,
        );
      }

      // Poll for state change
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        _log('$operationName: Checking state (attempt $attempt/$maxAttempts)');

        // Wait before checking (except on first attempt if specified)
        if (attempt > 1 || checkDelay.inMilliseconds > 0) {
          await Future.delayed(checkDelay);
        }

        final currentState = await checkState();
        if (isStateValid(currentState)) {
          _log('$operationName: State changed successfully');
          return Result.success(currentState as T);
        }

        _log('$operationName: State not yet valid: $currentState');
      }

      // All attempts exhausted
      final finalState = await checkState();
      _log(
          '$operationName: Failed after $maxAttempts attempts. Final state: $finalState');

      return Result.error(
        '$operationName failed - state did not change after $maxAttempts attempts',
        code: errorCode ?? ErrorCodes.operationTimeout,
      );
    } catch (e, stack) {
      _log('$operationName: Exception occurred: $e');
      return Result.error(
        '$operationName error: $e',
        code: errorCode ?? ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Convenience method for boolean state changes (like pause/unpause)
  Future<Result<bool>> setBooleanState({
    required String operationName,
    required String command,
    required Future<String?> Function() getSetting,
    required bool desiredState,
    Duration checkDelay = const Duration(milliseconds: 200),
    int maxAttempts = 3,
  }) async {
    return executeAndVerify<bool>(
      operationName: operationName,
      command: command,
      checkState: () async {
        final value = await getSetting();
        return _parseBool(value);
      },
      isStateValid: (state) => state == desiredState,
      checkDelay: checkDelay,
      maxAttempts: maxAttempts,
    );
  }

  /// Convenience method for string state changes (like mode switching)
  Future<Result<String>> setStringState({
    required String operationName,
    required String command,
    required Future<String?> Function() getSetting,
    required bool Function(String?) validator,
    Duration checkDelay = const Duration(milliseconds: 200),
    int maxAttempts = 3,
  }) async {
    return executeAndVerify<String>(
      operationName: operationName,
      command: command,
      checkState: () async => await getSetting() ?? '',
      isStateValid: validator,
      checkDelay: checkDelay,
      maxAttempts: maxAttempts,
    );
  }

  /// Execute a command without verification (fire-and-forget with delay)
  /// Use this for operations where we can't verify the result
  Future<Result<void>> executeWithDelay({
    required String operationName,
    required String command,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    try {
      _log('$operationName: Sending command (no verification available)');

      final sendResult = await printer.print(data: command);
      if (!sendResult.success) {
        return Result.error(
          'Failed to send $operationName command',
          code: ErrorCodes.operationError,
        );
      }

      await Future.delayed(delay);
      _log('$operationName: Command sent and delay completed');

      return Result.success();
    } catch (e, stack) {
      return Result.error(
        '$operationName error: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }

  /// Parse various boolean representations from printer responses
  bool _parseBool(String? value) {
    if (value == null) return false;
    final lower = value.toLowerCase().trim();
    return lower == 'true' ||
        lower == '1' ||
        lower == 'on' ||
        lower == 'yes' ||
        lower == 'y';
  }
}
