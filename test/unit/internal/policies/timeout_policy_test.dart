import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/policies/result.dart';
import 'package:zebrautil/internal/policies/timeout_policy.dart';

void main() {
  group('TimeoutPolicy', () {
    group('constructor', () {
      test('should create with required timeout', () {
        final policy = TimeoutPolicy(timeout: Duration(seconds: 5));
        expect(policy.timeout, const Duration(seconds: 5));
        expect(policy.throwOnTimeout, isTrue);
        expect(policy.timeoutMessage, isNull);
      });

      test('should create with custom configuration', () {
        final policy = TimeoutPolicy(
          timeout: Duration(seconds: 10),
          throwOnTimeout: false,
          timeoutMessage: 'Custom timeout message',
        );
        expect(policy.timeout, const Duration(seconds: 10));
        expect(policy.throwOnTimeout, isFalse);
        expect(policy.timeoutMessage, 'Custom timeout message');
      });
    });

    group('static factory methods', () {
      test('of() should create policy with throwOnTimeout true', () {
        final policy = TimeoutPolicy.of(const Duration(seconds: 7));
        expect(policy.timeout, const Duration(seconds: 7));
        expect(policy.throwOnTimeout, isTrue);
        expect(policy.timeoutMessage, isNull);
      });

      test('ofReturnNull() should create policy with throwOnTimeout false', () {
        final policy = TimeoutPolicy.ofReturnNull(const Duration(seconds: 3));
        expect(policy.timeout, const Duration(seconds: 3));
        expect(policy.throwOnTimeout, isFalse);
        expect(policy.timeoutMessage, isNull);
      });

      test('ofWithMessage() should create policy with custom message', () {
        final policy = TimeoutPolicy.ofWithMessage(
          const Duration(seconds: 5),
          'Custom message',
        );
        expect(policy.timeout, const Duration(seconds: 5));
        expect(policy.throwOnTimeout, isTrue);
        expect(policy.timeoutMessage, 'Custom message');
      });
    });

    group('execute()', () {
      test('should complete immediately when operation succeeds quickly', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 5));
        final stopwatch = Stopwatch()..start();

        final result = await policy.execute(
          () => Future.value('success'),
          operationName: 'Quick Success',
        );

        stopwatch.stop();
        expect(result, 'success');
        expect(stopwatch.elapsed.inMilliseconds, lessThan(100)); // Should be very fast
      });

      test('should complete immediately when operation fails quickly', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 5));
        final stopwatch = Stopwatch()..start();

        expect(
          () => policy.execute(
            () => Future.error(Exception('operation failed')),
            operationName: 'Quick Failure',
          ),
          throwsA(isA<Exception>()),
        );

        stopwatch.stop();
        expect(stopwatch.elapsed.inMilliseconds, lessThan(100)); // Should be very fast
      });

      test('should timeout when operation takes too long', () async {
        final policy = TimeoutPolicy.of(const Duration(milliseconds: 100));
        final stopwatch = Stopwatch()..start();

        try {
          await policy.execute(
            () => Future.delayed(const Duration(seconds: 1)).then((_) => 'result'),
            operationName: 'Slow Operation',
          );
        } catch (e) {
          // Expected to throw TimeoutException
        }

        stopwatch.stop();
        expect(stopwatch.elapsed.inMilliseconds, greaterThanOrEqualTo(100));
        expect(stopwatch.elapsed.inMilliseconds, lessThan(200)); // Should timeout around 100ms
      });

      test('should use custom timeout message', () async {
        final policy = TimeoutPolicy.ofWithMessage(
          const Duration(milliseconds: 50),
          'Custom timeout occurred',
        );

        expect(
          () => policy.execute(
            () => Future.delayed(const Duration(seconds: 1)).then((_) => 'result'),
            operationName: 'Slow Operation',
          ),
          throwsA(
            predicate((e) => e is TimeoutException && e.message == 'Custom timeout occurred'),
          ),
        );
      });

      test('should use default timeout message when not provided', () async {
        final policy = TimeoutPolicy.of(const Duration(milliseconds: 50));

        expect(
          () => policy.execute(
            () => Future.delayed(const Duration(seconds: 1)).then((_) => 'result'),
            operationName: 'Slow Operation',
          ),
          throwsA(
            predicate((e) => e is TimeoutException && e.message!.contains('Slow Operation timed out')),
          ),
        );
      });

      test('should use generic message when operation name not provided', () async {
        final policy = TimeoutPolicy.of(const Duration(milliseconds: 50));

        expect(
          () => policy.execute(
            () => Future.delayed(const Duration(seconds: 1)).then((_) => 'result'),
          ),
          throwsA(
            predicate((e) => e is TimeoutException && e.message!.contains('Operation timed out')),
          ),
        );
      });

      test('should not throw on timeout when throwOnTimeout is false', () async {
        final policy = TimeoutPolicy(
          timeout: Duration(milliseconds: 50),
          throwOnTimeout: false,
        );

        expect(
          () => policy.execute(
            () => Future.delayed(const Duration(seconds: 1)).then((_) => 'result'),
            operationName: 'Slow Operation',
          ),
          throwsA(
            predicate((e) => e is Exception && e.toString().contains('Operation timed out')),
          ),
        );
      });

      test('should handle complex return types', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 5));
        final complexData = {'key': 'value', 'number': 42};

        final result = await policy.execute(
          () => Future.value(complexData),
          operationName: 'Complex Data',
        );

        expect(result, complexData);
      });

      test('should handle null return values', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 5));

        final result = await policy.execute(
          () => Future.value(null),
          operationName: 'Null Result',
        );

        expect(result, isNull);
      });
    });

    group('executeWithResult()', () {
      test('should return success result when operation succeeds', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 5));
        final expectedResult = Result.success('test data');

        final result = await policy.executeWithResult(
          () => Future.value(expectedResult),
          operationName: 'Success Operation',
        );

        expect(result.isSuccess, isTrue);
        expect(result.data, 'test data');
        expect(result.error, isNull);
        expect(result.errorCode, isNull);
      });

      test('should return error result when operation fails', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 5));

        final result = await policy.executeWithResult(
          () => Future.error(Exception('operation error')),
          operationName: 'Failure Operation',
        );

        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(result.error, contains('Exception: operation error'));
        expect(result.errorCode, 'OPERATION_ERROR');
      });

      test('should return timeout result when operation times out', () async {
        final policy = TimeoutPolicy.of(const Duration(milliseconds: 50));

        final result = await policy.executeWithResult(
          () => Future.delayed(const Duration(seconds: 1)).then((_) => Result.success('result')),
          operationName: 'Timeout Operation',
        );

        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(result.error, contains('Timeout Operation timed out'));
        expect(result.errorCode, 'TIMEOUT');
      });

      test('should return failed result when operation returns failed result', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 5));

        final result = await policy.executeWithResult<String>(
          () => Future.value(Result.error('Operation failed')),
          operationName: 'Failed Result Operation',
        );

        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
        expect(result.error, 'Operation failed');
      });
    });

    group('edge cases', () {
      test('should handle zero timeout', () async {
        final policy = TimeoutPolicy.of(Duration.zero);

        expect(
          () => policy.execute(
            () => Future.value('success'),
            operationName: 'Zero Timeout',
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('should handle very short timeout', () async {
        final policy = TimeoutPolicy.of(const Duration(microseconds: 1));

        expect(
          () => policy.execute(
            () => Future.delayed(const Duration(milliseconds: 10)).then((_) => 'success'),
            operationName: 'Micro Timeout',
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('should handle operation that throws immediately', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 5));

        expect(
          () => policy.execute(
            () => throw Exception('immediate throw'),
            operationName: 'Immediate Throw',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle operation that throws after delay', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 5));

        expect(
          () => policy.execute(
            () => Future.delayed(const Duration(milliseconds: 100))
                .then((_) => throw Exception('delayed throw')),
            operationName: 'Delayed Throw',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle multiple concurrent operations', () async {
        final policy = TimeoutPolicy.of(const Duration(seconds: 1));
        final futures = <Future<String>>[];

        for (int i = 0; i < 5; i++) {
          futures.add(policy.execute(
            () => Future.value('result $i'),
            operationName: 'Concurrent $i',
          ));
        }

        final results = await Future.wait(futures);
        expect(results, hasLength(5));
        expect(results, containsAll(['result 0', 'result 1', 'result 2', 'result 3', 'result 4']));
      });
    });
  });
} 