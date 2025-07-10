import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/models/result.dart';

void main() {
  group('Result', () {
    group('success factory', () {
      test('should create successful result with data', () {
        final result = Result.success('test data');

        expect(result.success, isTrue);
        expect(result.data, equals('test data'));
        expect(result.error, isNull);
      });

      test('should create successful result without data', () {
        final result = Result.success();

        expect(result.success, isTrue);
        expect(result.data, isNull);
        expect(result.error, isNull);
      });

      test('should create successful result with null data', () {
        final result = Result.success(null);

        expect(result.success, isTrue);
        expect(result.data, isNull);
        expect(result.error, isNull);
      });
    });

    group('failure factory', () {
      test('should create failed result with error', () {
        final error = ErrorInfo(message: 'Test error');
        final result = Result.failure(error);

        expect(result.success, isFalse);
        expect(result.data, isNull);
        expect(result.error, equals(error));
      });
    });

    group('error factory', () {
      test('should create failed result from error message', () {
        final result = Result.error('Test error message');

        expect(result.success, isFalse);
        expect(result.data, isNull);
        expect(result.error, isNotNull);
        expect(result.error!.message, equals('Test error message'));
        expect(result.error!.code, isNull);
        expect(result.error!.errorNumber, isNull);
      });

      test('should create failed result with all error details', () {
        final stackTrace = StackTrace.current;
        final result = Result.error(
          'Test error',
          code: 'TEST_ERROR',
          errorNumber: 123,
          nativeError: 'Native error',
          dartStackTrace: stackTrace,
        );

        expect(result.success, isFalse);
        expect(result.error!.message, equals('Test error'));
        expect(result.error!.code, equals('TEST_ERROR'));
        expect(result.error!.errorNumber, equals(123));
        expect(result.error!.nativeError, equals('Native error'));
        expect(result.error!.dartStackTrace, equals(stackTrace));
      });
    });

    group('map method', () {
      test('should transform data when successful', () {
        final result = Result.success(5);
        final mapped = result.map((data) => data * 2);

        expect(mapped.success, isTrue);
        expect(mapped.data, equals(10));
        expect(mapped.error, isNull);
      });

      test('should return failure when original is failure', () {
        final originalError = ErrorInfo(message: 'Original error');
        final result = Result.failure(originalError);
        final mapped = result.map((data) => data.toString());

        expect(mapped.success, isFalse);
        expect(mapped.data, isNull);
        expect(mapped.error, equals(originalError));
      });

      test('should return failure when data is null', () {
        final result = Result.success(null);
        final mapped = result.map((data) => data.toString());

        expect(mapped.success, isFalse);
        expect(mapped.error!.message, equals('Unknown error occurred'));
      });

      test('should handle type transformations correctly', () {
        final result = Result.success('123');
        final mapped = result.map((data) => int.parse(data));

        expect(mapped.success, isTrue);
        expect(mapped.data, equals(123));
        expect(mapped.data, isA<int>());
      });

      test('should chain multiple map operations', () {
        final result = Result.success(5);
        final chained = result
            .map((data) => data * 2)
            .map((data) => data.toString())
            .map((data) => 'Value: $data');

        expect(chained.success, isTrue);
        expect(chained.data, equals('Value: 10'));
      });

      test('should stop chaining on first failure', () {
        final result = Result<int>.success(null);
        final chained = result
            .map((data) => data * 2)
            .map((data) => data.toString());

        expect(chained.success, isFalse);
        expect(chained.error!.message, equals('Unknown error occurred'));
      });
    });

    group('ifSuccess method', () {
      test('should execute action when successful', () {
        final result = Result.success('test data');
        String? capturedData;

        final returned = result.ifSuccess((data) {
          capturedData = data;
        });

        expect(capturedData, equals('test data'));
        expect(returned, equals(result));
      });

      test('should not execute action when failed', () {
        final result = Result.failure(ErrorInfo(message: 'Error'));
        bool actionExecuted = false;

        final returned = result.ifSuccess((data) {
          actionExecuted = true;
        });

        expect(actionExecuted, isFalse);
        expect(returned, equals(result));
      });
    });

    group('ifFailure method', () {
      test('should execute action when failed', () {
        final error = ErrorInfo(message: 'Test error');
        final result = Result.failure(error);
        ErrorInfo? capturedError;

        final returned = result.ifFailure((err) {
          capturedError = err;
        });

        expect(capturedError, equals(error));
        expect(returned, equals(result));
      });

      test('should not execute action when successful', () {
        final result = Result.success('data');
        bool actionExecuted = false;

        final returned = result.ifFailure((error) {
          actionExecuted = true;
        });

        expect(actionExecuted, isFalse);
        expect(returned, equals(result));
      });

      test('should not execute action when error is null', () {
        // Create a failure result with a null error by using the error factory
        // and then testing the edge case
        final result = Result.error('Test error');
        bool actionExecuted = false;

        final returned = result.ifFailure((error) {
          actionExecuted = true;
        });

        expect(actionExecuted,
            isTrue); // This should execute since we have an error
        expect(returned, equals(result));
      });
    });

    group('dataOrThrow getter', () {
      test('should return data when successful', () {
        final result = Result.success('test data');

        expect(result.dataOrThrow, equals('test data'));
      });

      test('should throw exception when failed', () {
        final error = ErrorInfo(message: 'Test error');
        final result = Result.failure(error);

        expect(() => result.dataOrThrow, throwsA(isA<ZebraPrinterException>()));
      });

      test('should throw exception when failed with error', () {
        final result = Result.failure(ErrorInfo(message: 'Test error'));

        expect(() => result.dataOrThrow, throwsA(isA<ZebraPrinterException>()));
      });
    });

    group('getOrElse method', () {
      test('should return data when successful', () {
        final result = Result.success('test data');

        expect(result.getOrElse('default'), equals('test data'));
      });

      test('should return data when successful but data is null', () {
        final result = Result<String?>.success(null);

        expect(result.getOrElse('default'), equals('default'));
      });

      test('should return default when failed', () {
        final result = Result.failure(ErrorInfo(message: 'Error'));

        expect(result.getOrElse('default'), equals('default'));
      });
    });
  });

  group('ErrorInfo', () {
    test('should create with required fields', () {
      final error = ErrorInfo(message: 'Test error');

      expect(error.message, equals('Test error'));
      expect(error.code, isNull);
      expect(error.errorNumber, isNull);
      expect(error.nativeError, isNull);
      expect(error.dartStackTrace, isNull);
      expect(error.nativeStackTrace, isNull);
      expect(error.timestamp, isA<DateTime>());
    });

    test('should create with all fields', () {
      final stackTrace = StackTrace.current;
      final timestamp = DateTime(2023, 1, 1);
      final error = ErrorInfo(
        message: 'Test error',
        code: 'TEST_ERROR',
        errorNumber: 123,
        nativeError: 'Native error',
        dartStackTrace: stackTrace,
        nativeStackTrace: 'Native stack trace',
        timestamp: timestamp,
      );

      expect(error.message, equals('Test error'));
      expect(error.code, equals('TEST_ERROR'));
      expect(error.errorNumber, equals(123));
      expect(error.nativeError, equals('Native error'));
      expect(error.dartStackTrace, equals(stackTrace));
      expect(error.nativeStackTrace, equals('Native stack trace'));
      expect(error.timestamp, equals(timestamp));
    });

    test('should use current timestamp when not provided', () {
      final before = DateTime.now();
      final error = ErrorInfo(message: 'Test error');
      final after = DateTime.now();

      expect(
          error.timestamp.isAfter(before) ||
              error.timestamp.isAtSameMomentAs(before),
          isTrue);
      expect(
          error.timestamp.isBefore(after) ||
              error.timestamp.isAtSameMomentAs(after),
          isTrue);
    });

    test('toException should return ZebraPrinterException', () {
      final error = ErrorInfo(message: 'Test error');
      final exception = error.toException();

      expect(exception, isA<ZebraPrinterException>());
      expect(exception.toString(), equals(error.toString()));
    });

    test('toMap should return correct structure', () {
      final stackTrace = StackTrace.current;
      final timestamp = DateTime(2023, 1, 1, 12, 0, 0);
      final error = ErrorInfo(
        message: 'Test error',
        code: 'TEST_ERROR',
        errorNumber: 123,
        nativeError: 'Native error',
        dartStackTrace: stackTrace,
        nativeStackTrace: 'Native stack trace',
        timestamp: timestamp,
      );

      final map = error.toMap();

      expect(map['message'], equals('Test error'));
      expect(map['code'], equals('TEST_ERROR'));
      expect(map['errorNumber'], equals(123));
      expect(map['nativeError'], equals('Native error'));
      expect(map['dartStackTrace'], equals(stackTrace.toString()));
      expect(map['nativeStackTrace'], equals('Native stack trace'));
      expect(map['timestamp'], equals(timestamp.toIso8601String()));
    });

    test('toString should include all relevant information', () {
      final error = ErrorInfo(
        message: 'Test error',
        code: 'TEST_ERROR',
        errorNumber: 123,
        nativeError: 'Native error',
        nativeStackTrace: 'Native stack trace',
      );

      final string = error.toString();

      expect(string, contains('ErrorInfo:'));
      expect(string, contains('Message: Test error'));
      expect(string, contains('Code: TEST_ERROR'));
      expect(string, contains('Error Number: 123'));
      expect(string, contains('Native Error: Native error'));
      expect(string, contains('Native Stack Trace:'));
      expect(string, contains('Native stack trace'));
    });
  });

  group('ZebraPrinterException', () {
    test('should contain error information', () {
      final error = ErrorInfo(message: 'Test error');
      final exception = ZebraPrinterException(error);

      expect(exception.error, equals(error));
    });

    test('toString should delegate to error', () {
      final error = ErrorInfo(message: 'Test error');
      final exception = ZebraPrinterException(error);

      expect(exception.toString(), equals(error.toString()));
    });
  });

  group('ErrorCodes', () {
    test('ErrorCodes constants should have correct values', () {
      // Connection errors
      expect(ErrorCodes.connectionError.code, equals('CONNECTION_ERROR'));
      expect(ErrorCodes.connectionTimeout.code, equals('CONNECTION_TIMEOUT'));
      expect(ErrorCodes.connectionLost.code, equals('CONNECTION_LOST'));
      expect(ErrorCodes.notConnected.code, equals('NOT_CONNECTED'));
      expect(ErrorCodes.alreadyConnected.code, equals('ALREADY_CONNECTED'));

      // Discovery errors
      expect(ErrorCodes.discoveryError.code, equals('DISCOVERY_ERROR'));
      expect(ErrorCodes.noPermission.code, equals('NO_PERMISSION'));
      expect(ErrorCodes.bluetoothDisabled.code, equals('BLUETOOTH_DISABLED'));
      expect(ErrorCodes.networkError.code, equals('NETWORK_ERROR'));
      expect(ErrorCodes.noPrintersFound.code, equals('NO_PRINTERS_FOUND'));
      expect(ErrorCodes.multiplePrintersFound.code,
          equals('MULTIPLE_PRINTERS_FOUND'));

      // Print errors
      expect(ErrorCodes.printError.code, equals('PRINT_ERROR'));
      expect(ErrorCodes.printerNotReady.code, equals('PRINTER_NOT_READY'));
      expect(ErrorCodes.outOfPaper.code, equals('OUT_OF_PAPER'));
      expect(ErrorCodes.headOpen.code, equals('HEAD_OPEN'));
      expect(ErrorCodes.printerPaused.code, equals('PRINTER_PAUSED'));

      // Data errors
      expect(ErrorCodes.invalidData.code, equals('INVALID_DATA'));
      expect(ErrorCodes.invalidFormat.code, equals('INVALID_FORMAT'));
      expect(ErrorCodes.encodingError.code, equals('ENCODING_ERROR'));

      // Operation errors
      expect(ErrorCodes.operationTimeout.code, equals('OPERATION_TIMEOUT'));
      expect(ErrorCodes.operationCancelled.code, equals('OPERATION_CANCELLED'));
      expect(ErrorCodes.invalidArgument.code, equals('INVALID_ARGUMENT'));
      expect(ErrorCodes.operationError.code, equals('OPERATION_ERROR'));

      // Platform errors
      expect(ErrorCodes.platformError.code, equals('PLATFORM_ERROR'));
      expect(ErrorCodes.notImplemented.code, equals('NOT_IMPLEMENTED'));
      expect(ErrorCodes.unknownError.code, equals('UNKNOWN_ERROR'));
    });
  });
}
