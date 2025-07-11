import 'dart:async';
import 'package:flutter/services.dart';
import 'operation_manager.dart';

/// Handles method calls from native side and routes them to appropriate operations
class OperationCallbackHandler {
  /// Constructor
  OperationCallbackHandler({required this.manager});

  final OperationManager manager;

  /// Callbacks for events that don't belong to specific operations
  final Map<String, Function(MethodCall)> eventHandlers = {};

  /// Handle a method call from native side
  Future<void> handleMethodCall(MethodCall call) async {
    try {
      final operationId = call.arguments?['operationId'] as String?;

      // Handle operation-specific callbacks
      if (operationId != null) {
        switch (call.method) {
          // Connection callbacks
          case 'onConnectComplete':
            manager.completeOperation(operationId, true);
            break;
          case 'onConnectError':
            _handleEnrichedError(
                operationId, call.arguments, 'Connection failed');
            break;

          // Disconnect callbacks
          case 'onDisconnectComplete':
            manager.completeOperation(operationId, true);
            break;
          case 'onDisconnectError':
            _handleEnrichedError(
                operationId, call.arguments, 'Disconnect failed');
            break;

          // Print callbacks
          case 'onPrintComplete':
            manager.completeOperation(operationId, true);
            break;
          case 'onPrintError':
            _handleEnrichedError(operationId, call.arguments, 'Print failed');
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
            _handleEnrichedError(
                operationId, call.arguments, 'Settings operation failed');
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
            _handleEnrichedError(
                operationId, call.arguments, 'Status check failed');
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
        try {
          handler(call);
        } catch (e) {
          // Log error but don't let it crash the app
        }
      }
    } catch (e) {
      // Log the error but don't let it propagate as an unhandled exception
    }
  }

  /// Handle enriched error information from native side
  void _handleEnrichedError(String operationId, Map<String, dynamic>? arguments, String defaultMessage) {
    final message = arguments?['message'] ?? arguments?['error'] ?? defaultMessage;
    final code = arguments?['code'] ?? 'UNKNOWN_ERROR';
    final nativeStackTrace = arguments?['nativeStackTrace'] as String?;
    final context = arguments?['context'] as Map<String, dynamic>?;
    final timestamp = arguments?['timestamp'] as String?;
    final nativeError = arguments?['nativeError'] as String?;
    final nativeErrorCode = arguments?['nativeErrorCode'] as int?;
    final nativeErrorDomain = arguments?['nativeErrorDomain'] as String?;
    
    // Create enriched error string with context
    final enrichedError = _createEnrichedErrorString(
      message, code, nativeStackTrace, context, 
      timestamp, nativeError, nativeErrorCode, nativeErrorDomain
    );
    
    manager.failOperation(operationId, enrichedError);
  }

  /// Create enriched error string with all available context
  String _createEnrichedErrorString(
    String message,
    String code,
    String? nativeStackTrace,
    Map<String, dynamic>? context,
    String? timestamp,
    String? nativeError,
    int? nativeErrorCode,
    String? nativeErrorDomain,
  ) {
    final parts = <String>[message];

    if (code != 'UNKNOWN_ERROR') {
      parts.add('Code: $code');
    }

    if (nativeError != null) {
      parts.add('Native: $nativeError');
    }

    if (nativeErrorCode != null) {
      parts.add('Native Code: $nativeErrorCode');
    }

    if (nativeErrorDomain != null) {
      parts.add('Native Domain: $nativeErrorDomain');
    }
    
    if (context != null && context.isNotEmpty) {
      final contextStr =
          context.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      parts.add('Context: {$contextStr}');
    }
    
    if (timestamp != null) {
      parts.add('Time: $timestamp');
    }
    
    if (nativeStackTrace != null) {
      parts.add('Native Stack: $nativeStackTrace');
    }
    
    return parts.join(' | ');
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
