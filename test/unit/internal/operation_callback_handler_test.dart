import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/operation_callback_handler.dart';
import 'package:zebrautil/internal/operation_manager.dart';
import 'package:flutter/services.dart';

class MockOperationManager implements OperationManager {
  final List<String> calls = [];
  final Map<String, dynamic> _activeOperations = {};

  @override
  void completeOperation(String id, dynamic value) {
    calls.add('complete:$id:$value');
    _activeOperations[id] = value;
  }

  @override
  void failOperation(String id, String error) {
    calls.add('fail:$id:$error');
    _activeOperations[id] = error;
  }

  @override
  void dispose() {}

  @override
  void cancelAll() {}

  @override
  int get activeOperationCount => _activeOperations.length;

  @override
  List<String> get activeOperationIds => _activeOperations.keys.toList();

  // Mock implementation of other required methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('OperationCallbackHandler', () {
    late MockOperationManager mockManager;
    late OperationCallbackHandler handler;

    setUp(() {
      mockManager = MockOperationManager();
      handler = OperationCallbackHandler(manager: mockManager);
    });

    test('routes connect callbacks', () async {
      await handler.handleMethodCall(
          MethodCall('onConnectComplete', {'operationId': '1'}));
      expect(mockManager.calls, contains('complete:1:true'));
      await handler.handleMethodCall(
          MethodCall('onConnectError', {'operationId': '2', 'error': 'fail'}));
      expect(mockManager.calls, contains('fail:2:fail'));
    });

    test('routes disconnect callbacks', () async {
      await handler.handleMethodCall(
          MethodCall('onDisconnectComplete', {'operationId': '1'}));
      expect(mockManager.calls, contains('complete:1:true'));
      await handler.handleMethodCall(MethodCall(
          'onDisconnectError', {'operationId': '2', 'error': 'fail'}));
      expect(mockManager.calls, contains('fail:2:fail'));
    });

    test('routes print callbacks', () async {
      await handler.handleMethodCall(
          MethodCall('onPrintComplete', {'operationId': '1'}));
      expect(mockManager.calls, contains('complete:1:true'));
      await handler.handleMethodCall(
          MethodCall('onPrintError', {'operationId': '2', 'error': 'fail'}));
      expect(mockManager.calls, contains('fail:2:fail'));
    });

    test('routes settings callbacks', () async {
      await handler.handleMethodCall(
          MethodCall('onSettingsComplete', {'operationId': '1'}));
      expect(mockManager.calls, contains('complete:1:true'));
      await handler.handleMethodCall(
          MethodCall('onSettingsResult', {'operationId': '2', 'value': 42}));
      expect(mockManager.calls, contains('complete:2:42'));
      await handler.handleMethodCall(
          MethodCall('onSettingsError', {'operationId': '3', 'error': 'fail'}));
      expect(mockManager.calls, contains('fail:3:fail'));
    });

    test('routes discovery and permission callbacks', () async {
      await handler.handleMethodCall(
          MethodCall('onDiscoveryDone', {'operationId': '1'}));
      expect(mockManager.calls, contains('complete:1:true'));
      await handler.handleMethodCall(
          MethodCall('onStopScanComplete', {'operationId': '2'}));
      expect(mockManager.calls, contains('complete:2:true'));
      await handler.handleMethodCall(MethodCall(
          'onPermissionResult', {'operationId': '3', 'granted': true}));
      expect(mockManager.calls, contains('complete:3:true'));
    });

    test('routes status and connection status callbacks', () async {
      await handler.handleMethodCall(
          MethodCall('onStatusResult', {'operationId': '1', 'status': 'OK'}));
      expect(mockManager.calls, contains('complete:1:OK'));
      await handler.handleMethodCall(
          MethodCall('onStatusError', {'operationId': '2', 'error': 'fail'}));
      expect(mockManager.calls, contains('fail:2:fail'));
      await handler.handleMethodCall(MethodCall(
          'onConnectionStatusResult', {'operationId': '3', 'connected': true}));
      expect(mockManager.calls, contains('complete:3:true'));
    });

    test('routes locate value callback', () async {
      await handler.handleMethodCall(MethodCall(
          'onLocateValueResult', {'operationId': '1', 'value': 'loc'}));
      expect(mockManager.calls, contains('complete:1:loc'));
    });

    test('calls registered event handler for non-operation event', () async {
      String? called;
      handler.registerEventHandler('printerFound', (call) {
        called = call.method;
      });
      await handler
          .handleMethodCall(MethodCall('printerFound', {'address': 'abc'}));
      expect(called, equals('printerFound'));
      handler.unregisterEventHandler('printerFound');
      called = null;
      await handler
          .handleMethodCall(MethodCall('printerFound', {'address': 'abc'}));
      expect(called, isNull);
    });
  });
}
