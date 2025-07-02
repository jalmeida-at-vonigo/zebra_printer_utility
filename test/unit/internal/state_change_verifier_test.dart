import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:zebrautil/internal/state_change_verifier.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/zebra_printer.dart';

class MockPrinter extends ZebraPrinter {
  List<String> sentCommands = [];
  dynamic printResult;
  dynamic getSettingResult;
  int getSettingCallCount = 0;

  MockPrinter() : super('mock');

  @override
  Future<Result<void>> print({required String data}) async {
    sentCommands.add(data);
    if (printResult is Exception) throw printResult;
    if (printResult is Result) return printResult;
    return Result.success();
  }

  @override
  Future<String?> getSetting(String key) async {
    getSettingCallCount++;
    if (getSettingResult is Exception) throw getSettingResult;
    return getSettingResult;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('StateChangeVerifier', () {
    late MockPrinter printer;
    late StateChangeVerifier verifier;

    setUp(() {
      printer = MockPrinter();
      verifier = StateChangeVerifier(printer: printer);
    });

    test('executeAndVerify returns early if already valid', () async {
      final result = await verifier.executeAndVerify<bool>(
        operationName: 'Test',
        command: 'CMD',
        checkState: () async => true,
        isStateValid: (s) => s == true,
      );
      expect(result.success, isTrue);
      expect(printer.sentCommands, isEmpty);
    });

    test('executeAndVerify sends command and verifies state', () async {
      int state = 0;
      printer.printResult = Result.success();
      final result = await verifier.executeAndVerify<int>(
        operationName: 'Test',
        command: 'CMD',
        checkState: () async => ++state,
        isStateValid: (s) => s == 2,
        maxAttempts: 3,
        checkDelay: const Duration(milliseconds: 1),
      );
      expect(result.success, isTrue);
      expect(result.data, equals(2));
      expect(printer.sentCommands, contains('CMD'));
    });

    test('executeAndVerify fails if command send fails', () async {
      printer.printResult = Result.error('fail');
      final result = await verifier.executeAndVerify<bool>(
        operationName: 'Test',
        command: 'CMD',
        checkState: () async => false,
        isStateValid: (s) => s == true,
      );
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    test('executeAndVerify fails after max attempts', () async {
      printer.printResult = Result.success();
      final result = await verifier.executeAndVerify<int>(
        operationName: 'Test',
        command: 'CMD',
        checkState: () async => 0,
        isStateValid: (s) => s == 1,
        maxAttempts: 2,
        checkDelay: const Duration(milliseconds: 1),
      );
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    test('executeAndVerify catches exceptions', () async {
      printer.printResult = Exception('fail');
      final result = await verifier.executeAndVerify<bool>(
        operationName: 'Test',
        command: 'CMD',
        checkState: () async => throw Exception('fail'),
        isStateValid: (s) => false,
      );
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    test('setBooleanState works for true/false', () async {
      printer.printResult = Result.success();
      printer.getSettingResult = 'true';
      final result = await verifier.setBooleanState(
        operationName: 'Pause',
        command: 'CMD',
        getSetting: () async => 'true',
        desiredState: true,
      );
      expect(result.success, isTrue);
    });

    test('setStringState works for string', () async {
      printer.printResult = Result.success();
      final result = await verifier.setStringState(
        operationName: 'Mode',
        command: 'CMD',
        getSetting: () async => 'zpl',
        validator: (s) => s == 'zpl',
      );
      expect(result.success, isTrue);
    });

    test('executeWithDelay returns success if command sent', () async {
      printer.printResult = Result.success();
      final result = await verifier.executeWithDelay(
        operationName: 'Delay',
        command: 'CMD',
        delay: const Duration(milliseconds: 1),
      );
      expect(result.success, isTrue);
    });

    test('executeWithDelay returns error if command fails', () async {
      printer.printResult = Result.error('fail');
      final result = await verifier.executeWithDelay(
        operationName: 'Delay',
        command: 'CMD',
        delay: const Duration(milliseconds: 1),
      );
      expect(result.success, isFalse);
    });

    group('timeout scenarios', () {
      test('executeAndVerify respects checkDelay timing', () async {
        printer.printResult = Result.success();
        int checkCount = 0;
        final stopwatch = Stopwatch()..start();
        
        await verifier.executeAndVerify<int>(
          operationName: 'Test',
          command: 'CMD',
          checkState: () async {
            checkCount++;
            return checkCount;
          },
          isStateValid: (s) => s == 3,
          maxAttempts: 3,
          checkDelay: const Duration(milliseconds: 50),
        );
        
        stopwatch.stop();
        expect(checkCount, equals(3));
        // Should take at least 100ms (2 delays of 50ms each)
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
      });
    });

    group('error code handling', () {
      test('executeAndVerify uses custom error code on failure', () async {
        printer.printResult = Result.success();
        final result = await verifier.executeAndVerify<bool>(
          operationName: 'Test',
          command: 'CMD',
          checkState: () async => false,
          isStateValid: (s) => s == true,
          maxAttempts: 1,
          checkDelay: const Duration(milliseconds: 1),
          errorCode: 'CUSTOM_ERROR',
        );
        
        expect(result.success, isFalse);
        expect(result.error?.code, equals('CUSTOM_ERROR'));
      });

      test('executeWithDelay handles exceptions properly', () async {
        printer.printResult = Exception('Network error');
        final result = await verifier.executeWithDelay(
          operationName: 'Test',
          command: 'CMD',
          delay: const Duration(milliseconds: 1),
        );
        
        expect(result.success, isFalse);
        expect(result.error?.code, equals('OPERATION_ERROR'));
        expect(result.error?.message, contains('Network error'));
      });
    });

    group('boolean state parsing', () {
      test('setBooleanState parses various boolean representations', () async {
        printer.printResult = Result.success();
        
        // Test "1" as true
        printer.getSettingResult = '1';
        var result = await verifier.setBooleanState(
          operationName: 'Test',
          command: 'CMD',
          getSetting: () => printer.getSetting('test'),
          desiredState: true,
        );
        expect(result.success, isTrue);
        
        // Test "on" as true
        printer.getSettingResult = 'on';
        result = await verifier.setBooleanState(
          operationName: 'Test',
          command: 'CMD',
          getSetting: () => printer.getSetting('test'),
          desiredState: true,
        );
        expect(result.success, isTrue);
        
        // Test "0" as false
        printer.getSettingResult = '0';
        result = await verifier.setBooleanState(
          operationName: 'Test',
          command: 'CMD',
          getSetting: () => printer.getSetting('test'),
          desiredState: false,
        );
        expect(result.success, isTrue);
      });
    });

    group('string state validation', () {
      test('setStringState handles null values correctly', () async {
        printer.printResult = Result.success();
        printer.getSettingResult = null;
        
        final result = await verifier.setStringState(
          operationName: 'Test',
          command: 'CMD',
          getSetting: () => printer.getSetting('test'),
          validator: (s) => s == '',  // null becomes empty string
        );
        
        expect(result.success, isTrue);
        expect(result.data, equals(''));
      });

      test('setStringState validates with custom logic', () async {
        printer.printResult = Result.success();
        int callCount = 0;
        
        final result = await verifier.setStringState(
          operationName: 'Test',
          command: 'CMD',
          getSetting: () async {
            callCount++;
            return callCount < 3 ? 'pending' : 'complete';
          },
          validator: (s) => s == 'complete',
          maxAttempts: 5,
          checkDelay: const Duration(milliseconds: 1),
        );
        
        expect(result.success, isTrue);
        expect(result.data, equals('complete'));
        expect(callCount, greaterThanOrEqualTo(3));
      });
    });

    group('edge cases', () {
      test('handles rapid state changes', () async {
        printer.printResult = Result.success();
        final states = ['starting', 'processing', 'complete'];
        int stateIndex = 0;
        
        final result = await verifier.executeAndVerify<String>(
          operationName: 'Test',
          command: 'CMD',
          checkState: () async {
            if (stateIndex < states.length) {
              return states[stateIndex++];
            }
            return states.last;
          },
          isStateValid: (s) => s == 'complete',
          maxAttempts: 5,
          checkDelay: const Duration(milliseconds: 1),
        );
        
        expect(result.success, isTrue);
        expect(result.data, equals('complete'));
      });

      test('handles concurrent operations', () async {
        printer.printResult = Result.success();
        
        // Start multiple operations simultaneously
        final futures = List.generate(3, (index) {
          return verifier.executeWithDelay(
            operationName: 'Concurrent$index',
            command: 'CMD$index',
            delay: const Duration(milliseconds: 10),
          );
        });
        
        final results = await Future.wait(futures);
        
        expect(results.every((r) => r.success), isTrue);
        expect(printer.sentCommands.length, equals(3));
      });
    });
  });
}
