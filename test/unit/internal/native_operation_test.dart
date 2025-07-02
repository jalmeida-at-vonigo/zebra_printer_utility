import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/native_operation.dart';
import 'dart:async';

void main() {
  group('NativeOperation', () {
    test('completes successfully', () async {
      final op = NativeOperation(
        id: '1',
        method: 'test',
        arguments: {},
        timeout: Duration(seconds: 1),
      );
      op.complete('result');
      expect(await op.completer.future, equals('result'));
    });

    test('completes with error', () async {
      final op = NativeOperation(
        id: '2',
        method: 'test',
        arguments: {},
        timeout: Duration(seconds: 1),
      );
      op.completeError('error');
      expect(op.completer.future, throwsA('error'));
    });

    test('cancel completes with error', () async {
      final op = NativeOperation(
        id: '3',
        method: 'test',
        arguments: {},
        timeout: Duration(seconds: 1),
      );
      op.cancel();
      expect(op.completer.future, throwsA('Operation cancelled'));
      expect(op.isCancelled, isTrue);
    });

    test('elapsed returns correct duration', () async {
      final op = NativeOperation(
        id: '4',
        method: 'test',
        arguments: {},
        timeout: Duration(milliseconds: 10),
      );
      await Future.delayed(Duration(milliseconds: 20));
      expect(op.elapsed.inMilliseconds, greaterThanOrEqualTo(20));
    });

    test('isTimedOut returns true if elapsed > timeout', () async {
      final op = NativeOperation(
        id: '5',
        method: 'test',
        arguments: {},
        timeout: Duration(milliseconds: 10),
      );
      await Future.delayed(Duration(milliseconds: 20));
      expect(op.isTimedOut, isTrue);
    });

    test('does not complete if already completed or cancelled', () async {
      final op = NativeOperation(
        id: '6',
        method: 'test',
        arguments: {},
        timeout: Duration(seconds: 1),
      );
      op.complete('first');
      op.complete('second');
      expect(await op.completer.future, equals('first'));
      // Cancel after complete should not throw
      op.cancel();
      expect(op.isCancelled, isTrue);
    });
  });
}
