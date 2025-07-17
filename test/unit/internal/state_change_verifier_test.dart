import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/state_change_verifier.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/zebra_printer.dart';

@GenerateMocks([ZebraPrinter])
import 'state_change_verifier_test.mocks.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('StateChangeVerifier', () {
    late MockZebraPrinter printer;
    late StateChangeVerifier verifier;
    late List<String> sentCommands;

    setUp(() {
      printer = MockZebraPrinter();
      verifier = StateChangeVerifier(printer: printer);
      sentCommands = [];

      // Default stub for print to capture commands
      when(printer.print(data: anyNamed('data')))
          .thenAnswer((invocation) async {
        final data = invocation.namedArguments[#data] as String;
        sentCommands.add(data);
        return Result.success();
      });
    });

    test('executeAndVerify returns early if already valid', () async {
      final result = await verifier.executeAndVerify<bool>(
        operationName: 'Test',
        command: 'CMD',
        checkState: () async => true,
        isStateValid: (s) => s == true,
      );
      expect(result.success, isTrue);
      expect(sentCommands, isEmpty);
      verifyNever(printer.print(data: anyNamed('data')));
    });

    test('executeAndVerify sends command and verifies state', () async {
      int state = 0;
      
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
      expect(sentCommands, contains('CMD'));
      verify(printer.print(data: 'CMD')).called(1);
    });

    test('executeAndVerify fails if command send fails', () async {
      when(printer.print(data: anyNamed('data')))
          .thenAnswer((_) async => Result.error('fail'));
          
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
      when(printer.print(data: anyNamed('data'))).thenThrow(Exception('fail'));
          
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
      when(printer.getSetting(any))
          .thenAnswer((_) async => Result.success('true'));
      
      final result = await verifier.setBooleanState(
        operationName: 'Pause',
        command: 'CMD',
        getSetting: () async {
          final result = await printer.getSetting('test');
          return result.success ? result.data : null;
        },
        desiredState: true,
      );
      expect(result.success, isTrue);
    });

    test('setStringState works for string', () async {
      final result = await verifier.setStringState(
        operationName: 'Mode',
        command: 'CMD',
        getSetting: () async => 'zpl',
        validator: (s) => s == 'zpl',
      );
      expect(result.success, isTrue);
    });

    test('executeWithDelay returns success if command sent', () async {
      final result = await verifier.executeWithDelay(
        operationName: 'Delay',
        command: 'CMD',
        delay: const Duration(milliseconds: 1),
      );
      expect(result.success, isTrue);
      verify(printer.print(data: 'CMD')).called(1);
    });

    test('executeWithDelay returns error if command fails', () async {
      when(printer.print(data: anyNamed('data')))
          .thenAnswer((_) async => Result.error('fail'));
          
      final result = await verifier.executeWithDelay(
        operationName: 'Delay',
        command: 'CMD',
        delay: const Duration(milliseconds: 1),
      );
      expect(result.success, isFalse);
    });

    group('timeout scenarios', () {
      test('executeAndVerify respects checkDelay timing', () async {
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
        final result = await verifier.executeAndVerify<bool>(
          operationName: 'Test',
          command: 'CMD',
          checkState: () async => false,
          isStateValid: (s) => s == true,
          maxAttempts: 1,
          checkDelay: const Duration(milliseconds: 1),
          errorCode: ErrorCodes.operationError,
        );
        
        expect(result.success, isFalse);
        expect(result.error?.code, equals('OPERATION_ERROR'));
      });

      test('executeWithDelay handles exceptions properly', () async {
        when(printer.print(data: anyNamed('data')))
            .thenThrow(Exception('Network error'));
            
        final result = await verifier.executeWithDelay(
          operationName: 'Test',
          command: 'CMD',
          delay: const Duration(milliseconds: 1),
        );
        
        expect(result.success, isFalse);
        expect(result.error?.code, equals('OPERATION_ERROR'));
        expect(result.error?.message,
            equals('Operation failed: Test error: Exception: Network error'));
      });
    });

    group('boolean state parsing', () {
      test('setBooleanState parses various boolean representations', () async {
        // Test "1" as true
        when(printer.getSetting(any))
            .thenAnswer((_) async => Result.success('1'));
        var result = await verifier.setBooleanState(
          operationName: 'Test',
          command: 'CMD',
          getSetting: () async {
            final result = await printer.getSetting('test');
            return result.success ? result.data : null;
          },
          desiredState: true,
        );
        expect(result.success, isTrue);
        
        // Test "on" as true
        when(printer.getSetting(any))
            .thenAnswer((_) async => Result.success('on'));
        result = await verifier.setBooleanState(
          operationName: 'Test',
          command: 'CMD',
          getSetting: () async {
            final result = await printer.getSetting('test');
            return result.success ? result.data : null;
          },
          desiredState: true,
        );
        expect(result.success, isTrue);
        
        // Test "0" as false
        when(printer.getSetting(any))
            .thenAnswer((_) async => Result.success('0'));
        result = await verifier.setBooleanState(
          operationName: 'Test',
          command: 'CMD',
          getSetting: () async {
            final result = await printer.getSetting('test');
            return result.success ? result.data : null;
          },
          desiredState: false,
        );
        expect(result.success, isTrue);
      });
    });

    group('string state validation', () {
      test('setStringState handles null values correctly', () async {
        when(printer.getSetting(any))
            .thenAnswer((_) async => Result.success(null));
        
        final result = await verifier.setStringState(
          operationName: 'Test',
          command: 'CMD',
          getSetting: () async {
            final getResult = await printer.getSetting('test');
            return getResult.success ? getResult.data : null;
          },
          validator: (s) => s == '',  // null becomes empty string
        );
        
        expect(result.success, isTrue);
        expect(result.data, equals(''));
      });

      test('setStringState validates with custom logic', () async {
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
        expect(sentCommands.length, equals(3));
        verify(printer.print(data: anyNamed('data'))).called(3);
      });
    });
  });
}
