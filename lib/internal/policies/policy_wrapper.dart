import 'dart:async';
import 'result.dart';
import 'retry_policy.dart';
import 'timeout_policy.dart';
import '../../zebra_printer_manager.dart';

/// Policy wrapper that combines multiple policies
class PolicyWrapper {

  const PolicyWrapper({
    this.timeoutPolicy,
    this.retryPolicy,
  });
  final TimeoutPolicy? timeoutPolicy;
  final RetryPolicy? retryPolicy;

  /// Create a policy wrapper with timeout only
  static PolicyWrapper withTimeout(Duration timeout) {
    return PolicyWrapper(
      timeoutPolicy: TimeoutPolicy.of(timeout),
    );
  }

  /// Create a policy wrapper with retry only
  static PolicyWrapper withRetry(int maxAttempts) {
    return PolicyWrapper(
      retryPolicy: RetryPolicy.of(maxAttempts),
    );
  }

  /// Create a policy wrapper with timeout and retry
  static PolicyWrapper withTimeoutAndRetry(
    Duration timeout,
    int maxAttempts,
  ) {
    return PolicyWrapper(
      timeoutPolicy: TimeoutPolicy.of(timeout),
      retryPolicy: RetryPolicy.of(maxAttempts),
    );
  }

  /// Create a policy wrapper with timeout and retry with delay
  static PolicyWrapper withTimeoutAndRetryWithDelay(
    Duration timeout,
    int maxAttempts,
    Duration retryDelay,
  ) {
    return PolicyWrapper(
      timeoutPolicy: TimeoutPolicy.of(timeout),
      retryPolicy: RetryPolicy.ofWithDelay(maxAttempts, retryDelay),
    );
  }

  /// Create a policy wrapper with timeout and exponential backoff retry
  static PolicyWrapper withTimeoutAndExponentialBackoff(
    Duration timeout,
    int maxAttempts,
    Duration retryDelay, {
    double backoffMultiplier = 2.0,
    Duration? maxDelay,
  }) {
    return PolicyWrapper(
      timeoutPolicy: TimeoutPolicy.of(timeout),
      retryPolicy: RetryPolicy.ofWithBackoff(
        maxAttempts,
        retryDelay,
        backoffMultiplier: backoffMultiplier,
        maxDelay: maxDelay,
      ),
    );
  }

  /// Execute an operation with combined policies
  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? operationName,
    CancellationToken? cancellationToken,
  }) async {
    // Apply retry policy if specified
    if (retryPolicy != null) {
      final retryResult = await retryPolicy!.execute(
        () async {
          // Apply timeout policy if specified
          if (timeoutPolicy != null) {
            return await timeoutPolicy!.execute(
              operation,
              operationName: operationName,
              cancellationToken: cancellationToken,
            );
          }
          // If no timeout policy, execute directly
          return await operation();
        },
        operationName: operationName,
        cancellationToken: cancellationToken,
      );
      
      if (retryResult.success) {
        return retryResult.data as T;
      } else {
        throw Exception(retryResult.errorMessage ?? 'Operation failed after retries');
      }
    }

    // If no retry policy, apply timeout policy if specified
    if (timeoutPolicy != null) {
      return await timeoutPolicy!.execute(
        operation,
        operationName: operationName,
        cancellationToken: cancellationToken,
      );
    }

    // If no policies, execute directly
    return await operation();
  }

  /// Execute an operation that returns a Result type
  Future<Result<T>> executeWithResult<T>(
    Future<Result<T>> Function() operation, {
    String? operationName,
    CancellationToken? cancellationToken,
  }) async {
    // Apply retry policy if specified
    if (retryPolicy != null) {
      final retryResult = await retryPolicy!.executeWithResult(
        () async {
          // Apply timeout policy if specified
          if (timeoutPolicy != null) {
            return await timeoutPolicy!.executeWithResult(
              operation,
              operationName: operationName,
              cancellationToken: cancellationToken,
            );
          }
          // If no timeout policy, execute directly
          return await operation();
        },
        operationName: operationName,
        cancellationToken: cancellationToken,
      );
      
      return retryResult;
    }

    // If no retry policy, apply timeout policy if specified
    if (timeoutPolicy != null) {
      return await timeoutPolicy!.executeWithResult(
        operation,
        operationName: operationName,
        cancellationToken: cancellationToken,
      );
    }

    // If no policies, execute directly
    return await operation();
  }
} 