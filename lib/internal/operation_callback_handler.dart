import 'package:flutter/services.dart';
import 'operation_manager.dart';

/// Handles method calls from native side and routes them to appropriate operations
class OperationCallbackHandler {
  final OperationManager manager;

  /// Callbacks for events that don't belong to specific operations
  final Map<String, Function(MethodCall)> eventHandlers = {};

  OperationCallbackHandler({required this.manager});

  /// Handle a method call from native side
  Future<void> handleMethodCall(MethodCall call) async {
    final operationId = call.arguments?['operationId'] as String?;

    // Handle operation-specific callbacks
    if (operationId != null) {
      switch (call.method) {
        // Connection callbacks
        case 'onConnectComplete':
          manager.completeOperation(operationId, true);
          break;
        case 'onConnectError':
          final error = call.arguments?['error'] ?? 'Connection failed';
          manager.failOperation(operationId, error);
          break;

        // Disconnect callbacks
        case 'onDisconnectComplete':
          manager.completeOperation(operationId, true);
          break;
        case 'onDisconnectError':
          final error = call.arguments?['error'] ?? 'Disconnect failed';
          manager.failOperation(operationId, error);
          break;

        // Print callbacks
        case 'onPrintComplete':
          manager.completeOperation(operationId, true);
          break;
        case 'onPrintError':
          final error = call.arguments?['error'] ?? 'Print failed';
          manager.failOperation(operationId, error);
          break;

        // Settings callbacks
        case 'onSettingsComplete':
          manager.completeOperation(operationId, true);
          break;
        case 'onSettingsResult':
          final value = call.arguments?['value'];
          manager.completeOperation(operationId, value);
          break;
        case 'onSettingsError':
          final error = call.arguments?['error'] ?? 'Settings operation failed';
          manager.failOperation(operationId, error);
          break;

        // Discovery callbacks
        case 'onDiscoveryDone':
          manager.completeOperation(operationId, true);
          break;
        case 'onStopScanComplete':
          manager.completeOperation(operationId, true);
          break;

        // Permission callbacks
        case 'onPermissionResult':
          final granted = call.arguments?['granted'] ?? false;
          manager.completeOperation(operationId, granted);
          break;

        // Status callbacks
        case 'onStatusResult':
          final status = call.arguments?['status'];
          manager.completeOperation(operationId, status);
          break;
        case 'onStatusError':
          final error = call.arguments?['error'] ?? 'Status check failed';
          manager.failOperation(operationId, error);
          break;

        // Connection status callback
        case 'onConnectionStatusResult':
          final isConnected = call.arguments?['connected'] ?? false;
          manager.completeOperation(operationId, isConnected);
          break;

        // Locate value callback
        case 'onLocateValueResult':
          final value = call.arguments?['value'] ?? '';
          manager.completeOperation(operationId, value);
          break;
      }
    }

    // Handle non-operation events (like printer discovery events)
    final handler = eventHandlers[call.method];
    if (handler != null) {
      handler(call);
    }
  }

  /// Register an event handler for non-operation callbacks
  void registerEventHandler(String method, Function(MethodCall) handler) {
    eventHandlers[method] = handler;
  }

  /// Unregister an event handler
  void unregisterEventHandler(String method) {
    eventHandlers.remove(method);
  }
}
