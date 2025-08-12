import 'dart:async';

import 'package:flutter/services.dart';
import 'logger.dart';
import 'native_models/enriched_native_error.dart';
import 'native_models/method_channel_constants.dart';
import 'zebra_printer_operation_manager.dart';

/// Callback handler for Zebra printer operations
class ZebraPrinterOperationCallbackHandler {
  ZebraPrinterOperationCallbackHandler({required this.manager});

  final ZebraPrinterOperationManager manager;
  final Map<String, Function(MethodCall)> eventHandlers = {};
  final Logger _logger = Logger.withPrefix('CallbackHandler');
  


  /// Handle method calls from native layer
  Future<void> handleMethodCall(MethodCall call) async {
    _logger.info(
        '🔍 CALLBACK_HANDLER: Processing method call - Method: ${call.method}');
    _logger.info('🔍 CALLBACK_HANDLER: Arguments: ${call.arguments}');
    
    try {
      // Extract operationId from arguments if present
      final operationId = call.arguments?['operationId'] as String?;
      if (operationId != null) {
        _logger.info(
            '🔍 CALLBACK_HANDLER: Operation callback detected for $operationId: ${call.method}');
      }

      // Handle operation-specific callbacks (completion/error)
      if (operationId != null) {
        _logger.info(
            '🔍 CALLBACK_HANDLER: Processing switch for method: "${call.method}"');
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

          // Handle discovery streaming events (printer found events)
          case MethodChannelConstants.discoverBTClassicEventPrinterFound:
          case MethodChannelConstants.discoverLocalBroadcastEventPrinterFound:
          case MethodChannelConstants.discoverSubnetEventPrinterFound:
          case MethodChannelConstants
                .discoverDirectedBroadcastEventPrinterFound:
          case MethodChannelConstants.discoverMulticastEventPrinterFound:
          case MethodChannelConstants.discoveryEventLogWarning:
            // These are streaming events, emit them to the operation event stream
            if (call.arguments is Map) {
              // Convert Map<Object?, Object?> to Map<String, dynamic> for type safety
              final Map<String, dynamic> eventData =
                  Map<String, dynamic>.from(call.arguments as Map);
              _logger.info(
                  '🎯 CALLBACK_HANDLER: Routing discovery event ${call.method} to operation $operationId');
              manager.emitEvent(operationId, {
                'method': call.method,
                'data': eventData,
              });
            }
            break;

          default:
            // For any other method with operationId, treat as streaming event
            _logger.info(
                '🔍 CALLBACK_HANDLER: Default case for method: ${call.method}');
            if (call.arguments is Map) {
              // Convert Map<Object?, Object?> to Map<String, dynamic> for type safety
              final Map<String, dynamic> eventData =
                  Map<String, dynamic>.from(call.arguments as Map);
              _logger.info(
                  '🎯 CALLBACK_HANDLER: Emitting default event for operation $operationId');
              manager.emitEvent(operationId, {
                'method': call.method,
                'data': eventData,
              });
            }
            break;
        }
        return; // Exit early for operationId events
      }

      // Handle non-operation events (like connection status events)
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
    if (arguments != null) {
      final enrichedError = EnrichedNativeError.fromNative(arguments);
      manager.failOperation(operationId, enrichedError);
    } else {
      manager.failOperation(operationId, defaultMessage);
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
