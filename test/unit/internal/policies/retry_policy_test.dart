import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/policies/result.dart';
import 'package:zebrautil/internal/policies/retry_policy.dart';

void main() {
  group('RetryPolicy', () {
    group('constructor', () {
      test('should create with default configuration', () {
        final policy = RetryPolicy(RetryPolicyConfig());
        expect(policy.config.maxAttempts, 3);
        expect(policy.config.delay, isNull);
        expect(policy.config.maxDelay, isNull);
        expect(policy.config.backoffMultiplier, 2.0);
        expect(policy.config.retryOnTimeout, isTrue);
        expect(policy.config.retryOnException, isTrue);
        expect(policy.config.retryOnExceptionTypes, isNull);
      });

      test('should create with custom configuration', () {
        final policy = RetryPolicy(RetryPolicyConfig(
          maxAttempts: 5,
          delay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 10),
          backoffMultiplier: 1.5,
          retryOnTimeout: false,
          retryOnException: false,
          retryOnExceptionTypes: [Exception],
        ));
        expect(policy.config.maxAttempts, 5);
        expect(policy.config.delay, const Duration(seconds: 1));
        expect(policy.config.maxDelay, const Duration(seconds: 10));
        expect(policy.config.backoffMultiplier, 1.5);
        expect(policy.config.retryOnTimeout, isFalse);
        expect(policy.config.retryOnException, isFalse);
        expect(policy.config.retryOnExceptionTypes, [Exception]);
      });
    });

    group('static factory methods', () {
      test('of() should create policy with default config', () {
        final policy = RetryPolicy.of(3);
        expect(policy.config.maxAttempts, 3);
        expect(policy.config.delay, isNull);
        expect(policy.config.retryOnTimeout, isTrue);
        expect(policy.config.retryOnException, isTrue);
      });

      test('ofWithDelay() should create policy with delay', () {
        final policy = RetryPolicy.ofWithDelay(5, const Duration(seconds: 2));
        expect(policy.config.maxAttempts, 5);
        expect(policy.config.delay, const Duration(seconds: 2));
        expect(policy.config.maxDelay, isNull);
        expect(policy.config.backoffMultiplier, 2.0);
      });

      test('ofWithBackoff() should create policy with exponential backoff', () {
        final policy = RetryPolicy.ofWithBackoff(
          4,
          const Duration(seconds: 1),
          backoffMultiplier: 3.0,
          maxDelay: const Duration(seconds: 8),
        );
        expect(policy.config.maxAttempts, 4);
        expect(policy.config.delay, const Duration(seconds: 1));
        expect(policy.config.maxDelay, const Duration(seconds: 8));
        expect(policy.config.backoffMultiplier, 3.0);
      });

      test('ofWithExceptionTypes() should create policy with specific exceptions', () {
        final policy = RetryPolicy.ofWithExceptionTypes(3, [Exception, ArgumentError]);
        expect(policy.config.maxAttempts, 3);
        expect(policy.config.retryOnExceptionTypes, [Exception, ArgumentError]);
        expect(policy.config.retryOnException, isTrue);
      });
    });

    group('execute()', () {
      test('should succeed on first attempt', () async {
        final policy = RetryPolicy.of(3);
        int attempts = 0;

        final result = await policy.execute(
          () {
            attempts++;
            return Future.value('success');
          },
          operationName: 'First Try Success',
        );

        expect(result.success, isTrue);
        expect(result.data, 'success');
        expect(result.attempts, 1);
        expect(attempts, 1);
      });

      test('should succeed after retries', () async {
        final policy = RetryPolicy.of(3);
        int attempts = 0;

        final result = await policy.execute(
          () {
            attempts++;
            if (attempts < 3) {
              throw Exception('attempt $attempts failed');
            }
            return Future.value('success on attempt $attempts');
          },
          operationName: 'Retry Success',
        );

        expect(result.success, isTrue);
        expect(result.data, 'success on attempt 3');
        expect(result.attempts, 3);
        expect(attempts, 3);
      });

      test('should fail after max attempts', () async {
        final policy = RetryPolicy.of(3);
        int attempts = 0;

        final result = await policy.execute(
          () {
            attempts++;
            throw Exception('attempt $attempts failed');
          },
          operationName: 'Max Attempts Failure',
        );

        expect(result.success, isFalse);
        expect(result.data, isNull);
        expect(result.attempts, 3);
        expect(result.errorMessage, contains('attempt 3 failed'));
        expect(attempts, 3);
      });

      test('should not retry on timeout when retryOnTimeout is false', () async {
        final policy = RetryPolicy(RetryPolicyConfig(
          maxAttempts: 3,
          retryOnTimeout: false,
        ));
        int attempts = 0;

        final result = await policy.execute(
          () {
            attempts++;
            throw TimeoutException('timeout on attempt $attempts');
          },
          operationName: 'No Retry on Timeout',
        );

        expect(result.success, isFalse);
        expect(result.attempts, 1);
        expect(result.errorMessage, contains('timeout on attempt 1'));
        expect(attempts, 1);
      });

      test('should not retry on exception when retryOnException is false', () async {
        final policy = RetryPolicy(RetryPolicyConfig(
          maxAttempts: 3,
          retryOnException: false,
        ));
        int attempts = 0;

        final result = await policy.execute(
          () {
            attempts++;
            throw Exception('exception on attempt $attempts');
          },
          operationName: 'No Retry on Exception',
        );

        expect(result.success, isFalse);
        expect(result.attempts, 1);
        expect(result.errorMessage, contains('exception on attempt 1'));
        expect(attempts, 1);
      });

      test('should retry only on specific exception types', () async {
        final policy = RetryPolicy(RetryPolicyConfig(
          maxAttempts: 3,
          retryOnExceptionTypes: [ArgumentError],
        ));
        int attempts = 0;

        final result = await policy.execute(
          () {
            attempts++;
            if (attempts == 1) {
              throw ArgumentError('retry this');
            } else {
              throw Exception('don\'t retry this');
            }
          },
          operationName: 'Specific Exception Retry',
        );

        expect(result.success, isFalse);
        expect(result.attempts, 2);
        expect(result.errorMessage, contains('don\'t retry this'));
        expect(attempts, 2);
      });

      test('should calculate total duration correctly', () async {
        final policy = RetryPolicy.ofWithDelay(3, const Duration(milliseconds: 50));
        final stopwatch = Stopwatch()..start();

        final result = await policy.execute(
          () {
            throw Exception('always fail');
          },
          operationName: 'Duration Test',
        );

        stopwatch.stop();
        expect(result.success, isFalse);
        expect(result.attempts, 3);
        expect(result.totalDuration.inMilliseconds, greaterThanOrEqualTo(100)); // 2 delays of 50ms each
        expect(stopwatch.elapsed.inMilliseconds, greaterThanOrEqualTo(100));
      });
    });

    group('exponential backoff', () {
      test('should apply exponential backoff correctly', () async {
        final policy = RetryPolicy.ofWithBackoff(
          3,
          const Duration(milliseconds: 100),
          backoffMultiplier: 2.0,
        );
        final delays = <Duration>[];
        final stopwatch = Stopwatch()..start();

        final result = await policy.execute(
          () {
            delays.add(stopwatch.elapsed);
            throw Exception('fail');
          },
          operationName: 'Exponential Backoff',
        );

        stopwatch.stop();
        expect(result.success, isFalse);
        expect(result.attempts, 3);

        // Should have delays between attempts
        expect(delays.length, 3);
        expect(delays[1].inMilliseconds - delays[0].inMilliseconds, greaterThanOrEqualTo(100));
        expect(delays[2].inMilliseconds - delays[1].inMilliseconds, greaterThanOrEqualTo(200));
      });

      test('should respect max delay', () async {
        final policy = RetryPolicy.ofWithBackoff(
          4,
          const Duration(milliseconds: 100),
          backoffMultiplier: 2.0,
          maxDelay: const Duration(milliseconds: 150),
        );
        final delays = <Duration>[];
        final stopwatch = Stopwatch()..start();

        final result = await policy.execute(
          () {
            delays.add(stopwatch.elapsed);
            throw Exception('fail');
          },
          operationName: 'Max Delay Test',
        );

        stopwatch.stop();
        expect(result.success, isFalse);
        expect(result.attempts, 4);

        // Third delay should be capped at 150ms (not 400ms)
        expect(delays[2].inMilliseconds - delays[1].inMilliseconds, lessThan(200));
      });

      test('should work without delay', () async {
        final policy = RetryPolicy.of(3); // No delay configured
        final stopwatch = Stopwatch()..start();

        final result = await policy.execute(
          () {
            throw Exception('fail');
          },
          operationName: 'No Delay Test',
        );

        stopwatch.stop();
        expect(result.success, isFalse);
        expect(result.attempts, 3);
        expect(stopwatch.elapsed.inMilliseconds, lessThan(100)); // Should be very fast
      });
    });

    group('executeWithResult()', () {
      test('should return success result when operation succeeds', () async {
        final policy = RetryPolicy.of(3);
        final expectedResult = Result.success('test data');

        final result = await policy.executeWithResult(
          () => Future.value(expectedResult),
          operationName: 'Success Result',
        );

        expect(result.isSuccess, isTrue);
        expect(result.data, 'test data');
        expect(result.error, isNull);
        expect(result.errorCode, isNull);
      });

      test('should return error result when operation fails after retries', () async {
        final policy = RetryPolicy.of(2);
        int attempts = 0;

        final result = await policy.executeWithResult(
          () {
            attempts++;
            return Future.value(Result.error('attempt $attempts failed'));
          },
          operationName: 'Failure Result',
        );

        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(result.error, 'attempt 2 failed');
        expect(attempts, 2);
      });

      test('should return null result error when operation returns null', () async {
        final policy = RetryPolicy.of(3);

        final result = await policy.executeWithResult<String>(
          () => Future.value(Result.error('Operation failed')),
          operationName: 'Failed Result',
        );

        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(result.error, 'Operation failed');
      });
    });

    group('edge cases', () {
      test('should handle zero max attempts', () async {
        final policy = RetryPolicy.of(0);
        int attempts = 0;

        final result = await policy.execute(
          () {
            attempts++;
            return Future.value('success');
          },
          operationName: 'Zero Attempts',
        );

        expect(result.success, isFalse);
        expect(result.attempts, 0);
        expect(attempts, 0);
      });

      test('should handle single attempt', () async {
        final policy = RetryPolicy.of(1);
        int attempts = 0;

        final result = await policy.execute(
          () {
            attempts++;
            throw Exception('fail');
          },
          operationName: 'Single Attempt',
        );

        expect(result.success, isFalse);
        expect(result.attempts, 1);
        expect(attempts, 1);
      });

      test('should handle operation that succeeds on last attempt', () async {
        final policy = RetryPolicy.of(3);
        int attempts = 0;

        final result = await policy.execute(
          () {
            attempts++;
            if (attempts == 3) {
              return Future.value('success on last attempt');
            }
            throw Exception('fail');
          },
          operationName: 'Last Attempt Success',
        );

        expect(result.success, isTrue);
        expect(result.data, 'success on last attempt');
        expect(result.attempts, 3);
        expect(attempts, 3);
      });

      test('should handle complex return types', () async {
        final policy = RetryPolicy.of(3);
        final complexData = {'key': 'value', 'list': [1, 2, 3]};

        final result = await policy.execute(
          () => Future.value(complexData),
          operationName: 'Complex Data',
        );

        expect(result.success, isTrue);
        expect(result.data, complexData);
        expect(result.attempts, 1);
      });

      test('should handle null return values', () async {
        final policy = RetryPolicy.of(3);

        final result = await policy.execute(
          () => Future.value(null),
          operationName: 'Null Data',
        );

        expect(result.success, isTrue);
        expect(result.data, isNull);
        expect(result.attempts, 1);
      });

      test('should handle multiple concurrent operations', () async {
        final policy = RetryPolicy.of(2);
        final futures = <Future<RetryPolicyResult<String>>>[];

        for (int i = 0; i < 3; i++) {
          futures.add(policy.execute(
            () => Future.value('result $i'),
            operationName: 'Concurrent $i',
          ));
        }

        final results = await Future.wait(futures);
        expect(results, hasLength(3));
        expect(results.every((r) => r.success), isTrue);
        expect(results.every((r) => r.attempts == 1), isTrue);
      });
    });
  });
} 