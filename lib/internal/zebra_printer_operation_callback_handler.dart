import 'dart:async';

import 'package:flutter/services.dart';

import 'native_models/method_channel_constants.dart';
import 'zebra_printer_operation_manager.dart';

/// Handles method calls from native side and routes them to appropriate operations
class ZebraPrinterOperationCallbackHandler {
  /// Constructor
  ZebraPrinterOperationCallbackHandler({required this.manager});

  final ZebraPrinterOperationManager manager;

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
          case MethodChannelConstants.connectToPrinterCallbackOnComplete:
            manager.completeOperation(operationId, true);
            break;
          case MethodChannelConstants.connectToPrinterCallbackOnError:
            _handleEnrichedError(
                operationId, call.arguments, 'Connection failed');
            break;

          // Disconnect callbacks
          case MethodChannelConstants.disconnectCallbackOnComplete:
            manager.completeOperation(operationId, true);
            break;
          case MethodChannelConstants.disconnectCallbackOnError:
            _handleEnrichedError(
                operationId, call.arguments, 'Disconnect failed');
            break;

          // Print callbacks
          case MethodChannelConstants.printCallbackOnComplete:
            manager.completeOperation(operationId, true);
            break;
          case MethodChannelConstants.printCallbackOnError:
            _handleEnrichedError(operationId, call.arguments, 'Print failed');
            break;

          // Settings callbacks
          case MethodChannelConstants.setSettingsCallbackOnComplete:
            manager.completeOperation(operationId, true);
            break;
          case MethodChannelConstants.getSettingCallbackOnResult:
            final value = call.arguments?['value'];
            manager.completeOperation(operationId, value);
            break;
          case MethodChannelConstants.setSettingsCallbackOnError:
            _handleEnrichedError(
                operationId, call.arguments, 'Settings operation failed');
            break;

          // Discovery callbacks - BT Classic
          case MethodChannelConstants.discoverBTClassicCallbackOnComplete:
            final foundCount = call.arguments?['foundCount'] ?? 0;
            manager.completeOperation(operationId, {'foundCount': foundCount});
            break;
          case MethodChannelConstants.discoverBTClassicCallbackOnError:
            _handleEnrichedError(
                operationId, call.arguments, 'BT Classic discovery failed');
            break;

          // Discovery callbacks - Local Broadcast
          case MethodChannelConstants.discoverLocalBroadcastCallbackOnComplete:
            final foundCount = call.arguments?['foundCount'] ?? 0;
            manager.completeOperation(operationId, {'foundCount': foundCount});
            break;
          case MethodChannelConstants.discoverLocalBroadcastCallbackOnError:
            _handleEnrichedError(operationId, call.arguments,
                'Local broadcast discovery failed');
            break;

          // Discovery callbacks - Subnet
          case MethodChannelConstants.discoverSubnetCallbackOnComplete:
            final foundCount = call.arguments?['foundCount'] ?? 0;
            manager.completeOperation(operationId, {'foundCount': foundCount});
            break;
          case MethodChannelConstants.discoverSubnetCallbackOnError:
            _handleEnrichedError(
                operationId, call.arguments, 'Subnet discovery failed');
            break;

          // Discovery callbacks - Directed Broadcast
          case MethodChannelConstants
                .discoverDirectedBroadcastCallbackOnComplete:
            final foundCount = call.arguments?['foundCount'] ?? 0;
            manager.completeOperation(operationId, {'foundCount': foundCount});
            break;
          case MethodChannelConstants.discoverDirectedBroadcastCallbackOnError:
            _handleEnrichedError(operationId, call.arguments,
                'Directed broadcast discovery failed');
            break;

          // Discovery callbacks - Multicast
          case MethodChannelConstants.discoverMulticastCallbackOnComplete:
            final foundCount = call.arguments?['foundCount'] ?? 0;
            manager.completeOperation(operationId, {'foundCount': foundCount});
            break;
          case MethodChannelConstants.discoverMulticastCallbackOnError:
            _handleEnrichedError(
                operationId, call.arguments, 'Multicast discovery failed');
            break;

          // Stop scan callback
          case MethodChannelConstants.stopScanCallbackOnComplete:
            manager.completeOperation(operationId, true);
            break;

          // Status callbacks
          case MethodChannelConstants.getPrinterStatusCallbackOnResult:
            final status = call.arguments?['status'];
            manager.completeOperation(operationId, status);
            break;
          case MethodChannelConstants.getDetailedPrinterStatusCallbackOnResult:
            final detailedStatus = call.arguments?['detailedStatus'];
            manager.completeOperation(operationId, detailedStatus);
            break;
          case MethodChannelConstants.getPrinterStatusCallbackOnError:
            _handleEnrichedError(
                operationId, call.arguments, 'Status check failed');
            break;

          // Connection status callback
          case MethodChannelConstants.isConnectedCallbackOnResult:
            final isConnected = call.arguments?['connected'] ?? false;
            manager.completeOperation(operationId, isConnected);
            break;

          // Locate value callback
          case MethodChannelConstants.getValueForCallbackOnResult:
            final value = call.arguments?['value'] ?? '';
            manager.completeOperation(operationId, value);
            break;
          case MethodChannelConstants.getValueForCallbackOnError:
            _handleEnrichedError(
                operationId, call.arguments, 'Locate value failed');
            break;

          // Fallback for unknown methods
          case MethodChannelConstants.callbackOnMethodNotImplemented:
            _handleEnrichedError(
                operationId, call.arguments, 'Method not implemented');
            break;
        }
      }

      // Handle streaming events with operationId (like printer discovery)
      if (operationId != null) {
        // Emit via manager's per-operation event stream
        if (call.arguments is Map<String, dynamic>) {
          // Wrap with method tag so callers can filter by event kind
          manager.emitEvent(operationId, {
            'method': call.method,
            'data': call.arguments as Map<String, dynamic>,
          });
        }

        return;
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
