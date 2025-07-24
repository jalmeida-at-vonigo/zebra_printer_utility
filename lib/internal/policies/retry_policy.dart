import 'dart:async';
import 'dart:math' as math;
import '../../zebra_printer_manager.dart';
import '../logger.dart';
import 'result.dart';

/// Retry policy configuration
class RetryPolicyConfig {

  const RetryPolicyConfig({
    this.maxAttempts = 3,
    this.delay,
    this.maxDelay,
    this.backoffMultiplier = 2.0,
    this.retryOnTimeout = true,
    this.retryOnException = true,
    this.retryOnExceptionTypes,
  });
  final int maxAttempts;
  final Duration? delay;
  final Duration? maxDelay;
  final double backoffMultiplier;
  final bool retryOnTimeout;
  final bool retryOnException;
  final List<Type>? retryOnExceptionTypes;
}

/// Retry policy result
class RetryPolicyResult<T> {

  const RetryPolicyResult.failure(
    this.errorMessage,
    this.attempts,
    this.totalDuration,
  )   : data = null,
        success = false;

  const RetryPolicyResult.success(
    this.data,
    this.attempts,
    this.totalDuration,
  )   : success = true,
        errorMessage = null;
  final T? data;
  final bool success;
  final int attempts;
  final String? errorMessage;
  final Duration totalDuration;

  bool get isSuccess => success;
  bool get hasData => data != null;
}

/// Polly-like retry policy for Dart
class RetryPolicy {

  RetryPolicy(this.config);
  final RetryPolicyConfig config;
  final Logger _logger = Logger.withPrefix('RetryPolicy');

  /// Create a retry policy with specific attempts
  static RetryPolicy of(int maxAttempts) {
    return RetryPolicy(RetryPolicyConfig(maxAttempts: maxAttempts));
  }

  /// Create a retry policy with delay
  static RetryPolicy ofWithDelay(int maxAttempts, Duration delay) {
    return RetryPolicy(RetryPolicyConfig(
      maxAttempts: maxAttempts,
      delay: delay,
    ));
  }

  /// Create a retry policy with exponential backoff
  static RetryPolicy ofWithBackoff(
    int maxAttempts,
    Duration delay, {
    double backoffMultiplier = 2.0,
    Duration? maxDelay,
  }) {
    return RetryPolicy(RetryPolicyConfig(
      maxAttempts: maxAttempts,
      delay: delay,
      backoffMultiplier: backoffMultiplier,
      maxDelay: maxDelay,
    ));
  }

  /// Create a retry policy that only retries on specific exceptions
  static RetryPolicy ofWithExceptionTypes(
    int maxAttempts,
    List<Type> exceptionTypes,
  ) {
    return RetryPolicy(RetryPolicyConfig(
      maxAttempts: maxAttempts,
      retryOnExceptionTypes: exceptionTypes,
    ));
  }

  /// Execute an operation with retry policy
  Future<RetryPolicyResult<T>> execute<T>(
    Future<T> Function() operation, {
    String? operationName,
    CancellationToken? cancellationToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final operationNameStr = operationName ?? 'Operation';

    _logger.debug(
        '[$operationNameStr] Starting retry policy execution: maxAttempts=${config.maxAttempts}, delay=${config.delay?.inMilliseconds}ms');
    
    Exception? lastException;
    
    for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
      _logger.debug(
          '[$operationNameStr] Attempt $attempt/${config.maxAttempts} starting');

      // Check for cancellation before each attempt
      if (cancellationToken?.isCancelled ?? false) {
        _logger.info(
          'Retry operation cancelled by user at attempt $attempt/${config.maxAttempts} '
          '(elapsed: ${stopwatch.elapsed.inMilliseconds}ms)',
        );
        stopwatch.stop();
        return RetryPolicyResult.failure(
          'Operation cancelled',
          attempt,
          stopwatch.elapsed,
        );
      }
      
      try {
        final result = await operation();
        stopwatch.stop();
        
        _logger.debug(
            '[$operationNameStr] Attempt $attempt succeeded after ${stopwatch.elapsed.inMilliseconds}ms');
        
        return RetryPolicyResult.success(
          result,
          attempt,
          stopwatch.elapsed,
        );
      } on TimeoutException catch (e) {
        lastException = e;
        
        _logger.debug(
            '[$operationNameStr] Attempt $attempt failed with timeout: ${e.message}');
        
        if (!config.retryOnTimeout || attempt >= config.maxAttempts) {
          stopwatch.stop();
          _logger.debug(
              '[$operationNameStr] Not retrying timeout: retryOnTimeout=${config.retryOnTimeout}, attempt=$attempt, maxAttempts=${config.maxAttempts}');
          return RetryPolicyResult.failure(
            e.message ?? 'Operation timed out',
            attempt,
            stopwatch.elapsed,
          );
        }
        
        _logger.debug(
            '[$operationNameStr] Retrying after timeout, waiting before next attempt');
        await _waitBeforeRetry(attempt, cancellationToken);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        _logger.debug(
            '[$operationNameStr] Attempt $attempt failed with exception: ${e.toString()}');
        
        if (!config.retryOnException || 
            !_shouldRetryOnException(e) ||
            attempt >= config.maxAttempts) {
          stopwatch.stop();
          _logger.debug(
              '[$operationNameStr] Not retrying exception: retryOnException=${config.retryOnException}, shouldRetry=${_shouldRetryOnException(e)}, attempt=$attempt, maxAttempts=${config.maxAttempts}');
          return RetryPolicyResult.failure(
            e.toString(),
            attempt,
            stopwatch.elapsed,
          );
        }
        
        _logger.debug(
            '[$operationNameStr] Retrying after exception, waiting before next attempt');
        await _waitBeforeRetry(attempt, cancellationToken);
      }
    }
    
    stopwatch.stop();
    _logger.debug(
        '[$operationNameStr] All ${config.maxAttempts} attempts failed after ${stopwatch.elapsed.inMilliseconds}ms');
    
    return RetryPolicyResult.failure(
      lastException?.toString() ?? 'Operation failed after ${config.maxAttempts} attempts',
      config.maxAttempts,
      stopwatch.elapsed,
    );
  }

  /// Execute an operation that returns a Result type
  Future<Result<T>> executeWithResult<T>(
    Future<Result<T>> Function() operation, {
    String? operationName,
    CancellationToken? cancellationToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    Exception? lastException;
    
    for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        final operationResult = await operation();
        
        if (operationResult.isSuccess) {
          stopwatch.stop();
          return operationResult;
        }
        
        // If operation returned failed result, treat as failure
        final errorMessage = operationResult.error ?? 'Operation failed';
        lastException = Exception(errorMessage);
        
        if (attempt >= config.maxAttempts) {
          stopwatch.stop();
          return operationResult;
        }
        
        await _waitBeforeRetry(attempt, cancellationToken);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        if (attempt >= config.maxAttempts) {
          stopwatch.stop();
          return Result.error(
            lastException.toString(),
            errorCode: 'RETRY_FAILED',
          );
        }
        
        await _waitBeforeRetry(attempt, cancellationToken);
      }
    }
    
    stopwatch.stop();
    return Result.error(
      lastException?.toString() ?? 'Operation failed after ${config.maxAttempts} attempts',
      errorCode: 'RETRY_FAILED',
    );
  }

  /// Wait before retry with exponential backoff
  Future<void> _waitBeforeRetry(
      int attempt, CancellationToken? cancellationToken) async {
    final delay = _calculateDelay(attempt);

    _logger.debug(
        'Waiting ${delay.inMilliseconds}ms before retry attempt ${attempt + 1}');

    // Break delay into smaller chunks to check for cancellation
    const checkInterval = Duration(milliseconds: 500);
    final totalMs = delay.inMilliseconds;
    var elapsedMs = 0;

    while (elapsedMs < totalMs) {
      // Check for cancellation during delay
      if (cancellationToken?.isCancelled ?? false) {
        _logger.info(
          'Retry delay cancelled by user at attempt $attempt '
          '(elapsed: ${elapsedMs}ms of ${totalMs}ms)',
        );
        return;
      }

      final remainingMs = totalMs - elapsedMs;
      final delayMs =
          math.min(checkInterval.inMilliseconds, remainingMs).round();

      await Future.delayed(Duration(milliseconds: delayMs));
      elapsedMs += delayMs;
    }
    
    _logger
        .debug('Retry delay completed, proceeding to attempt ${attempt + 1}');
  }

  /// Calculate delay with exponential backoff
  Duration _calculateDelay(int attempt) {
    if (config.delay == null) return Duration.zero;
    
    final baseDelay = config.delay!;
    final backoffDelay =
        baseDelay * math.pow(config.backoffMultiplier, attempt - 1).toInt();
    
    if (config.maxDelay != null && backoffDelay > config.maxDelay!) {
      return config.maxDelay!;
    }
    
    return backoffDelay;
  }

  /// Check if exception should trigger retry
  bool _shouldRetryOnException(dynamic exception) {
    if (config.retryOnExceptionTypes == null) {
      return true;
    }
    
    return config.retryOnExceptionTypes!.any((type) => exception.runtimeType == type);
  }
} 