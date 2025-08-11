import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/native_models/enriched_native_error.dart';
import 'package:zebrautil/internal/native_models/method_channel_constants.dart';
import 'package:zebrautil/internal/zebra_printer_operation_callback_handler.dart';
import 'package:zebrautil/internal/zebra_printer_operation_manager.dart';

import 'zebra_printer_operation_callback_handler_test.mocks.dart';

@GenerateMocks([ZebraPrinterOperationManager])
void main() {
  group('ZebraPrinterOperationCallbackHandler', () {
    late MockZebraPrinterOperationManager mockManager;
    late ZebraPrinterOperationCallbackHandler handler;
    late List<String> calls;

    setUp(() {
      mockManager = MockZebraPrinterOperationManager();
      handler = ZebraPrinterOperationCallbackHandler(manager: mockManager);
      calls = [];

      // Set up stubs to track calls
      when(mockManager.completeOperation(any, any)).thenAnswer((invocation) {
        final id = invocation.positionalArguments[0] as String;
        final value = invocation.positionalArguments[1];
        calls.add('complete:$id:$value');
      });

      when(mockManager.failOperation(any, any)).thenAnswer((invocation) {
        final id = invocation.positionalArguments[0] as String;
        final error = invocation.positionalArguments[1];
        if (error is String) {
          calls.add('fail:$id:$error');
        } else if (error is EnrichedNativeError) {
          // Handle EnrichedNativeError case
          String errorStr = 'fail:$id:${error.message} | Code: ${error.code}';
          if (error.context != null) {
            errorStr += ' | Context: ${error.context}';
          }
          errorStr +=
              ' | Time: ${error.timestamp} | Native Stack: ${error.nativeStackTrace}';
          calls.add(errorStr);
        } else {
          calls.add('fail:$id:$error');
        }
      });
    });

    test('routes connect callbacks', () async {
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.connectToPrinterCallbackOnComplete,
          {'operationId': '1'}));
      expect(calls, contains('complete:1:true'));
      verify(mockManager.completeOperation('1', true)).called(1);
      
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.connectToPrinterCallbackOnError, {
        'operationId': '2',
        'message': 'fail',
        'code': 'CONNECTION_ERROR',
        'timestamp': '2023-01-01T00:00:00Z',
        'nativeStackTrace': 'stack trace',
        'instanceId': 'test',
        'queue': 'main'
      }));
      expect(
          calls,
          contains(
              'fail:2:fail | Code: CONNECTION_ERROR | Time: 2023-01-01T00:00:00Z | Native Stack: stack trace'));
      verify(mockManager.failOperation('2', any)).called(1);
    });

    test('routes disconnect callbacks', () async {
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.disconnectCallbackOnComplete,
          {'operationId': '1'}));
      expect(calls, contains('complete:1:true'));
      verify(mockManager.completeOperation('1', true)).called(1);
      
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.disconnectCallbackOnError, {
        'operationId': '2',
        'message': 'fail',
        'code': 'DISCONNECT_ERROR',
        'timestamp': '2023-01-01T00:00:00Z',
        'nativeStackTrace': 'stack trace',
        'instanceId': 'test',
        'queue': 'main'
      }));
      expect(
          calls,
          contains(
              'fail:2:fail | Code: DISCONNECT_ERROR | Time: 2023-01-01T00:00:00Z | Native Stack: stack trace'));
      verify(mockManager.failOperation('2', any)).called(1);
    });

    test('routes print callbacks', () async {
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.printCallbackOnComplete,
          {'operationId': '1'}));
      expect(calls, contains('complete:1:true'));
      verify(mockManager.completeOperation('1', true)).called(1);
      
      await handler.handleMethodCall(
          const MethodCall(MethodChannelConstants.printCallbackOnError, {
        'operationId': '2',
        'message': 'fail',
        'code': 'PRINT_ERROR',
        'timestamp': '2023-01-01T00:00:00Z',
        'nativeStackTrace': 'stack trace',
        'instanceId': 'test',
        'queue': 'main',
        'context': {'operation': 'print', 'dataLength': 100}
      }));
      expect(
          calls,
          contains(
              'fail:2:fail | Code: PRINT_ERROR | Context: {operation: print, dataLength: 100} | Time: 2023-01-01T00:00:00Z | Native Stack: stack trace'));
      verify(mockManager.failOperation('2', any)).called(1);
    });

    test('routes settings callbacks', () async {
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.setSettingsCallbackOnComplete,
          {'operationId': '1'}));
      expect(calls, contains('complete:1:true'));
      verify(mockManager.completeOperation('1', true)).called(1);
      
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.getSettingCallbackOnResult,
          {'operationId': '2', 'value': 42}));
      expect(calls, contains('complete:2:42'));
      verify(mockManager.completeOperation('2', 42)).called(1);
      
      await handler.handleMethodCall(
          const MethodCall(MethodChannelConstants.setSettingsCallbackOnError, {
        'operationId': '3',
        'message': 'fail',
        'code': 'SETTINGS_ERROR',
        'timestamp': '2023-01-01T00:00:00Z',
        'nativeStackTrace': 'stack trace',
        'instanceId': 'test',
        'queue': 'main',
        'context': {'operation': 'setSettings', 'command': 'test=value'}
      }));
      expect(
          calls,
          contains(
              'fail:3:fail | Code: SETTINGS_ERROR | Context: {operation: setSettings, command: test=value} | Time: 2023-01-01T00:00:00Z | Native Stack: stack trace'));
      verify(mockManager.failOperation('3', any)).called(1);
    });

    test('routes discovery and permission callbacks', () async {
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.discoverBTClassicCallbackOnComplete,
          {'operationId': '1', 'foundCount': 0}));
      expect(calls, contains('complete:1:{foundCount: 0}'));
      verify(mockManager.completeOperation('1', {'foundCount': 0})).called(1);
      
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.stopScanCallbackOnComplete,
          {'operationId': '2'}));
      expect(calls, contains('complete:2:true'));
      verify(mockManager.completeOperation('2', true)).called(1);
      
    });

    test('routes status and connection status callbacks', () async {
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.getPrinterStatusCallbackOnResult,
          {'operationId': '1', 'status': 'OK'}));
      expect(calls, contains('complete:1:OK'));
      verify(mockManager.completeOperation('1', 'OK')).called(1);
      
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.getPrinterStatusCallbackOnError, {
        'operationId': '2',
        'message': 'fail',
        'code': 'STATUS_ERROR',
        'timestamp': '2023-01-01T00:00:00Z',
        'nativeStackTrace': 'stack trace',
        'instanceId': 'test',
        'queue': 'main'
      }));
      expect(
          calls,
          contains(
              'fail:2:fail | Code: STATUS_ERROR | Time: 2023-01-01T00:00:00Z | Native Stack: stack trace'));
      verify(mockManager.failOperation('2', any)).called(1);
      
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.isConnectedCallbackOnResult,
          {'operationId': '3', 'connected': true}));
      expect(calls, contains('complete:3:true'));
      verify(mockManager.completeOperation('3', true)).called(1);
    });

    test('routes locate value callback', () async {
      await handler.handleMethodCall(const MethodCall(
          MethodChannelConstants.getValueForCallbackOnResult,
          {'operationId': '1', 'value': 'loc'}));
      expect(calls, contains('complete:1:loc'));
      verify(mockManager.completeOperation('1', 'loc')).called(1);
    });

    test('calls registered event handler for non-operation event', () async {
      String? called;
      handler.registerEventHandler('printerFound', (call) {
        called = call.method;
      });
      await handler
          .handleMethodCall(
          const MethodCall('printerFound', {'address': 'abc'}));
      expect(called, equals('printerFound'));
      
      handler.unregisterEventHandler('printerFound');
      called = null;
      await handler
          .handleMethodCall(
          const MethodCall('printerFound', {'address': 'abc'}));
      expect(called, isNull);
    });


  });
}
