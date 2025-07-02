import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/operation_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OperationManager', () {
    late MethodChannel channel;
    late OperationManager operationManager;
    late List<MethodCall> methodCalls;

    setUp(() {
      channel = const MethodChannel('test_channel');
      operationManager = OperationManager(channel: channel);
      methodCalls = [];

      // Set up method call handler to capture calls
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);

        // Simulate different responses based on method
        switch (methodCall.method) {
          case 'successMethod':
            // Simulate success callback after a short delay
            Future.delayed(const Duration(milliseconds: 50), () {
              operationManager.completeOperation(
                methodCall.arguments['operationId'] as String,
                true,
              );
            });
            return null;

          case 'errorMethod':
            // Simulate error callback
            Future.delayed(const Duration(milliseconds: 50), () {
              operationManager.failOperation(
                methodCall.arguments['operationId'] as String,
                'Test error',
              );
            });
            return null;

          case 'timeoutMethod':
            // Don't complete - let it timeout
            return null;

          case 'immediateMethod':
            // Complete immediately
            operationManager.completeOperation(
              methodCall.arguments['operationId'] as String,
              'immediate result',
            );
            return null;

          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      operationManager.dispose();
    });

    test('execute adds operation ID to arguments', () async {
      final future = operationManager.execute<bool>(
        method: 'successMethod',
        arguments: {'test': 'value'},
      );

      // Wait a bit for the method to be called
      await Future.delayed(const Duration(milliseconds: 10));

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'successMethod');
      expect(methodCalls[0].arguments['test'], 'value');
      expect(methodCalls[0].arguments['operationId'], isNotNull);

      // Clean up
      await future;
    });

    test('execute returns result on success', () async {
      final result = await operationManager.execute<bool>(
        method: 'successMethod',
        arguments: {},
      );

      expect(result, true);
    });

    test('execute throws on error', () async {
      await expectLater(
        operationManager.execute<String>(
          method: 'errorMethod',
          arguments: {},
        ),
        throwsA(equals('Test error')),
      );
    });

    test('execute respects timeout', () async {
      expect(
        () => operationManager.execute<String>(
          method: 'timeoutMethod',
          arguments: {},
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('execute removes operation after completion', () async {
      await operationManager.execute<String>(
        method: 'immediateMethod',
        arguments: {},
      );

      // Check that operation was removed
      expect(operationManager.activeOperationCount, 0);
    });

    test('execute removes operation after timeout', () async {
      try {
        await operationManager.execute<String>(
          method: 'timeoutMethod',
          arguments: {},
          timeout: const Duration(milliseconds: 100),
        );
      } catch (_) {
        // Expected timeout
      }

      // Wait a bit to ensure cleanup
      await Future.delayed(const Duration(milliseconds: 50));

      // Check that operation was removed
      expect(operationManager.activeOperationCount, 0);
    });

    test('multiple concurrent operations have unique IDs', () async {
      final futures = [
        operationManager.execute<bool>(
          method: 'successMethod',
          arguments: {},
        ),
        operationManager.execute<bool>(
          method: 'successMethod',
          arguments: {},
        ),
        operationManager.execute<bool>(
          method: 'successMethod',
          arguments: {},
        ),
      ];

      // Wait for all methods to be called
      await Future.delayed(const Duration(milliseconds: 10));

      // Check that each call has a unique operation ID
      final operationIds = methodCalls
          .map((call) => call.arguments['operationId'] as String)
          .toSet();

      expect(operationIds.length, 3);
      expect(methodCalls.length, 3);

      // Clean up
      await Future.wait(futures);
    });

    test('completeOperation with wrong ID does nothing', () async {
      final future = operationManager.execute<bool>(
        method: 'timeoutMethod',
        arguments: {},
        timeout: const Duration(milliseconds: 200),
      );

      // Try to complete with wrong ID
      operationManager.completeOperation('wrong_id', true);

      // Should still timeout
      expect(
        () => future,
        throwsA(isA<TimeoutException>()),
      );
    });

    test('dispose cancels all pending operations', () async {
      final future1 = operationManager.execute<bool>(
        method: 'timeoutMethod',
        arguments: {},
      );
      final future2 = operationManager.execute<bool>(
        method: 'timeoutMethod',
        arguments: {},
      );

      // Dispose should cancel all operations
      operationManager.dispose();

      // Both should complete with error
      expect(
        () => future1,
        throwsA(anything),
      );
      expect(
        () => future2,
        throwsA(anything),
      );
    });

    test('operation ID format is valid', () async {
      final future = operationManager.execute<bool>(
        method: 'successMethod',
        arguments: {},
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final operationId = methodCalls[0].arguments['operationId'] as String;

      // Should be a timestamp-based ID with counter
      final parts = operationId.split('_');
      expect(parts.length, 2);
      expect(int.tryParse(parts[0]), isNotNull);
      expect(
          parts[0].length, greaterThanOrEqualTo(13)); // Millisecond timestamp
      expect(int.tryParse(parts[1]), isNotNull);

      // Clean up
      await future;
    });

    test('generic type is preserved in result', () async {
      final stringResult = await operationManager.execute<String>(
        method: 'immediateMethod',
        arguments: {},
      );

      expect(stringResult, isA<String>());
      expect(stringResult, 'immediate result');
    });
  });
}
