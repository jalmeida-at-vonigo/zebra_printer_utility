import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/smart/managers/retry_manager.dart';
import 'package:zebrautil/models/result.dart';

import '../../../mocks/mock_logger.mocks.dart';

void main() {
  group('RetryManager', () {
    late RetryManager retryManager;
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
      retryManager = RetryManager(mockLogger);
    });

    group('Basic Retry Logic', () {
      test('should execute successful operation without retries', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          return Result.success('success');
        }

        final result = await retryManager.executeWithRetry(operation);
        
        expect(result.success, isTrue);
        expect(result.data, equals('success'));
        expect(callCount, equals(1));
      });

      test('should retry failed operation', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          if (callCount < 3) {
            return Result.error('Temporary failure');
          }
          return Result.success('success');
        }

        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 3,
          retryDelay: const Duration(milliseconds: 10),
        );
        
        expect(result.success, isTrue);
        expect(result.data, equals('success'));
        expect(callCount, equals(3));
      });

      test('should fail after max retries', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          return Result.error('Persistent failure');
        }

        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 2,
          retryDelay: const Duration(milliseconds: 10),
        );
        
        expect(result.success, isFalse);
        expect(callCount, equals(3)); // Initial + 2 retries
      });
    });

    group('Exponential Backoff', () {
      test('should use exponential backoff', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          return Result.error('Failure');
        }

        final startTime = DateTime.now();
        
        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 2,
          retryDelay: const Duration(milliseconds: 100),
          retryBackoff: 2.0,
        );
        
        final duration = DateTime.now().difference(startTime);
        
        // Should have delays: 100ms + 200ms = 300ms minimum
        expect(duration.inMilliseconds, greaterThanOrEqualTo(300));
        expect(callCount, equals(3));
        expect(result.success, isFalse);
      });

      test('should respect retry backoff multiplier', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          return Result.error('Failure');
        }

        final startTime = DateTime.now();
        
        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 2,
          retryDelay: const Duration(milliseconds: 50),
          retryBackoff: 1.5,
        );
        
        final duration = DateTime.now().difference(startTime);
        
        // Should have delays: 50ms + 75ms = 125ms minimum
        expect(duration.inMilliseconds, greaterThanOrEqualTo(125));
        expect(callCount, equals(3));
        expect(result.success, isFalse);
      });
    });

    group('Exception Handling', () {
      test('should retry on exceptions', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          if (callCount < 3) {
            throw Exception('Temporary failure');
          }
          return Result.success('success');
        }

        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 3,
          retryDelay: const Duration(milliseconds: 10),
        );
        
        expect(result.success, isTrue);
        expect(result.data, equals('success'));
        expect(callCount, equals(3));
      });

      test('should fail after max retries on exceptions', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          throw Exception('Persistent failure');
        }

        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 2,
          retryDelay: const Duration(milliseconds: 10),
        );
        
        expect(result.success, isFalse);
        expect(result.error?.message, contains('Operation failed after 2 attempts'));
        expect(callCount, equals(3));
      });

      test('should preserve original exception message', () async {
        Future<Result<String>> operation() async {
          throw Exception('Original error');
        }

        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 1,
          retryDelay: const Duration(milliseconds: 10),
        );
        
        expect(result.success, isFalse);
        expect(result.error?.message, contains('Original error'));
      });
    });

    group('Error Handling', () {
      test('should handle async operations that throw', () async {
        Future<Result<String>> operation() async {
          await Future.delayed(const Duration(milliseconds: 10));
          throw Exception('Async failure');
        }

        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 1,
          retryDelay: const Duration(milliseconds: 10),
        );
        
        expect(result.success, isFalse);
        expect(result.error?.message, contains('Async failure'));
      });
    });

    group('Performance', () {
      test('should not add unnecessary delays for successful operations', () async {
        Future<Result<String>> operation() async => Result.success('success');
        
        final startTime = DateTime.now();
        final result = await retryManager.executeWithRetry(operation);
        final duration = DateTime.now().difference(startTime);
        
        expect(result.success, isTrue);
        expect(result.data, equals('success'));
        expect(duration.inMilliseconds, lessThan(100)); // Should be fast
      });

      test('should handle large number of retries efficiently', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          return Result.error('Failure');
        }

        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 10,
          retryDelay: const Duration(milliseconds: 1),
        );
        
        expect(result.success, isFalse);
        expect(callCount, equals(11)); // Initial + 10 retries
      });
    });

    group('Edge Cases', () {
      test('should handle zero retries', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          return Result.error('Failure');
        }

        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 0,
          retryDelay: const Duration(milliseconds: 10),
        );
        
        expect(result.success, isFalse);
        expect(callCount, equals(1)); // Only initial call
      });

      test('should handle zero delay', () async {
        int callCount = 0;
        Future<Result<String>> operation() async {
          callCount++;
          if (callCount < 3) {
            return Result.error('Failure');
          }
          return Result.success('success');
        }

        final startTime = DateTime.now();
        final result = await retryManager.executeWithRetry(
          operation,
          maxRetries: 3,
          retryDelay: Duration.zero,
        );
        final duration = DateTime.now().difference(startTime);
        
        expect(result.success, isTrue);
        expect(result.data, equals('success'));
        expect(callCount, equals(3));
        expect(duration.inMilliseconds, lessThan(100)); // Should be very fast
      });
    });
  });
} 