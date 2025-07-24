import 'dart:async';
import '../../zebra_printer_manager.dart';
import '../logger.dart';
import 'result.dart';

/// Polly-like timeout policy for Dart
class TimeoutPolicy {

  TimeoutPolicy({
    required this.timeout,
    this.throwOnTimeout = true,
    this.timeoutMessage,
  });
  final Duration timeout;
  final bool throwOnTimeout;
  final String? timeoutMessage;
  final Logger _logger = Logger.withPrefix('TimeoutPolicy');

  /// Create a timeout policy with specific duration
  static TimeoutPolicy of(Duration timeout) {
    return TimeoutPolicy(timeout: timeout);
  }

  /// Create a timeout policy that returns null on timeout
  static TimeoutPolicy ofReturnNull(Duration timeout) {
    return TimeoutPolicy(
      timeout: timeout,
      throwOnTimeout: false,
    );
  }

  /// Create a timeout policy with custom message
  static TimeoutPolicy ofWithMessage(Duration timeout, String message) {
    return TimeoutPolicy(
      timeout: timeout,
      timeoutMessage: message,
    );
  }

  /// Execute an operation with timeout policy
  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? operationName,
    CancellationToken? cancellationToken,
  }) async {
    final operationNameStr = operationName ?? 'Operation';
    final message = timeoutMessage ?? 
        '$operationNameStr timed out after ${timeout.inMilliseconds}ms';

    // Handle zero timeout specially
    if (timeout == Duration.zero) {
      throw TimeoutException(message);
    }

    try {
      // Check for cancellation before starting
      if (cancellationToken?.isCancelled ?? false) {
        _logger.info(
          'Timeout operation cancelled by user before execution '
          '(timeout: ${timeout.inMilliseconds}ms)',
        );
        throw Exception('Operation cancelled before timeout');
      }
      
      // Use Future.any to race between operation and timeout
      final result = await Future.any([
        operation(),
        Future.delayed(timeout).then((_) => throw TimeoutException(message)),
      ]);
      return result;
    } on TimeoutException catch (e) {
      if (throwOnTimeout) {
        rethrow;
      }
      throw Exception('Operation timed out: ${e.message}');
    }
  }

  /// Execute an operation that returns a Result type
  Future<Result<T>> executeWithResult<T>(
    Future<Result<T>> Function() operation, {
    String? operationName,
    CancellationToken? cancellationToken,
  }) async {
    try {
      final result = await execute<Result<T>>(operation,
          operationName: operationName, cancellationToken: cancellationToken);
      return result;
    } on TimeoutException catch (e) {
      return Result.error(
        e.message ?? 'Operation timed out',
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      return Result.error(
        e.toString(),
        errorCode: 'OPERATION_ERROR',
      );
    }
  }
} 