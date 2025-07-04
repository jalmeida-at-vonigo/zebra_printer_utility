import 'dart:async';
import 'package:zebrautil/models/result.dart';
import '../../internal/logger.dart';

/// Retry manager for the smart API
class RetryManager {
  final Logger _logger;

  RetryManager(this._logger);

  /// Execute function with retry logic
  Future<Result<T>> executeWithRetry<T>(
    Future<Result<T>> Function() operation, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 100),
    double retryBackoff = 2.0,
  }) async {
    int attempts = 0;
    Duration currentDelay = retryDelay;

    while (attempts <= maxRetries) {
      try {
        final result = await operation();
        
        if (result.success) {
          return result;
        }

        attempts++;
        if (attempts > maxRetries) {
          return result;
        }

        _logger.warning('Retry attempt $attempts of $maxRetries');
        await Future.delayed(currentDelay);
        currentDelay = Duration(milliseconds: (currentDelay.inMilliseconds * retryBackoff).round());
      } catch (e) {
        attempts++;
        if (attempts > maxRetries) {
          return Result.error('Operation failed after $maxRetries attempts: $e', 
              code: ErrorCodes.operationError);
        }

        _logger.warning('Retry attempt $attempts of $maxRetries after error: $e');
        await Future.delayed(currentDelay);
        currentDelay = Duration(milliseconds: (currentDelay.inMilliseconds * retryBackoff).round());
      }
    }

    return Result.error('Operation failed after $maxRetries attempts', 
        code: ErrorCodes.operationError);
  }
} 