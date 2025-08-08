import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/zebra_printer_operation_manager.dart';
import 'package:zebrautil/models/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZebraPrinterOperationManager - streaming and lifecycle', () {
    late MethodChannel channel;
    late ZebraPrinterOperationManager manager;

    setUp(() {
      channel = const MethodChannel('test.zebrautil');
      // Ensure channel invocations do not throw during tests
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        return null;
      });

      manager = ZebraPrinterOperationManager(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      manager.dispose();
    });

    test('operationEvents emits per-operation and closes on complete', () async {
      final received = <Map<String, dynamic>>[];
      String? opId;

      final resultFuture = manager.execute<Map<String, dynamic>>(
        method: 'dummyMethod',
        arguments: {'foo': 'bar'},
        timeout: const Duration(seconds: 2),
        onOperationStart: (id) {
          opId = id;
          manager.operationEvents(id).listen(received.add);
        },
      );

      // Emit a couple of events before completion
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(opId, isNotNull);
      manager.emitEvent(opId!, {'event': 1});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      manager.emitEvent(opId!, {'event': 2});
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Complete the operation
      manager.completeOperation(opId!, {'ok': true});
      final result = await resultFuture;

      expect(result.success, isTrue);
      expect(result.data, equals({'ok': true}));
      expect(received, containsAll([{'event': 1}, {'event': 2}]));

      // Stream should be closed; emitting after completion should have no effect
      final countBefore = received.length;
      manager.emitEvent(opId!, {'late': true});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received.length, equals(countBefore));
      expect(manager.activeOperationCount, equals(0));
    });

    test('failOperation closes stream and returns error result', () async {
      final received = <Map<String, dynamic>>[];
      String? opId;

      final resultFuture = manager.execute<void>(
        method: 'failingMethod',
        timeout: const Duration(seconds: 2),
        onOperationStart: (id) {
          opId = id;
          manager.operationEvents(id).listen(received.add);
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      manager.emitEvent(opId!, {'beforeFail': true});
      manager.failOperation(opId!, 'boom');

      final result = await resultFuture;
      expect(result.success, isFalse);
      expect(result.error?.code, equals(ErrorCodes.operationError.code));

      final countBefore = received.length;
      manager.emitEvent(opId!, {'late': true});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received.length, equals(countBefore));
    });

    test('timeout closes stream and returns timeout error', () async {
      String? opId;
      // Start an operation we will not complete
      final result = await manager.execute<void>(
        method: 'timeoutMethod',
        timeout: const Duration(milliseconds: 50),
        onOperationStart: (id) {
          opId = id;
          manager.operationEvents(id).listen((_) {});
        },
      );

      expect(result.success, isFalse);
      expect(result.error?.code, equals(ErrorCodes.operationTimeout.code));

      // Emitting after timeout should do nothing
      if (opId != null) {
        manager.emitEvent(opId!, {'late': true});
      }
    });

    test('cancelAll cancels operations and closes all streams', () async {
      final opIds = <String>[];
      final futures = <Future<Result<void>>>[];

      for (int i = 0; i < 2; i++) {
        futures.add(manager.execute<void>(
          method: 'method_$i',
          timeout: const Duration(seconds: 2),
          onOperationStart: (id) {
            opIds.add(id);
            manager.operationEvents(id).listen((_) {});
          },
        ));
      }

      await Future<void>.delayed(const Duration(milliseconds: 10));
      manager.cancelAll();

      final results = await Future.wait(futures);
      // All should be failures due to cancellation
      expect(results.every((r) => !r.success), isTrue);
      expect(manager.activeOperationCount, equals(0));
    });

    test('dispose completes pending operations and clears streams', () async {
      String? opId;
      final future = manager.execute<void>(
        method: 'toDispose',
        timeout: const Duration(seconds: 2),
        onOperationStart: (id) {
          opId = id;
          manager.operationEvents(id).listen((_) {});
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      manager.dispose();
      final result = await future;
      expect(result.success, isFalse);
      expect(manager.activeOperationCount, equals(0));

      if (opId != null) {
        // Emitting after dispose should have no effect and not throw
        manager.emitEvent(opId!, {'late': true});
      }
    });
  });
}


