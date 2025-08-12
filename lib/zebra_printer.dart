import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'internal/logger.dart';
import 'internal/native_models/method_channel_constants.dart';
import 'internal/native_models/printer_info.dart';
import 'internal/permission_manager.dart';
import 'internal/print_data_processor.dart';
import 'internal/zebra_error_bridge.dart';
import 'internal/zebra_printer_operation_callback_handler.dart';
import 'internal/zebra_printer_operation_manager.dart';
import 'models/connection_event.dart';
import 'models/print_enums.dart';
import 'models/print_operation_tracker.dart';
import 'models/result.dart';
import 'models/zebra_device.dart';

typedef DiscoveryWarningCallback = void Function(
    {String? phase, String? target, String? message});

class ZebraPrinter {
  
  /// Private constructor - use create() factory instead
  ZebraPrinter._(
    this.instanceId, {
    ZebraController? controller,
  })  : controller = controller ?? ZebraController(),
        _logger = Logger.withPrefix('ZebraPrinter.$instanceId') {
    _channel = MethodChannel('ZebraPrinterObject$instanceId');
    _channel.setMethodCallHandler(nativeMethodCallHandler);
    
    _operationManager = ZebraPrinterOperationManager(channel: _channel);
    _callbackHandler =
        ZebraPrinterOperationCallbackHandler(manager: _operationManager);
    

    _callbackHandler.registerEventHandler(
        MethodChannelConstants.connectionEventStatusChanged, (call) {
      final status = call.arguments?['Status'] ?? '';
      final color = call.arguments?['Color'] ?? 'R';
      this.controller.updatePrinterStatus(status, color);
    });

    // Register handler for connection_lost events from native layer
    _callbackHandler.registerEventHandler(
        MethodChannelConstants.connectionEventLost, (call) {
      final printerAddress = call.arguments?['printerAddress'] as String?;
      final reason = call.arguments?['reason'] as String?;

      _logger.warning(
          'Native connection_lost event received for $printerAddress: $reason');

      // Update cached state immediately
      _updateConnectionState(false, context: 'native connection_lost');

      // Additional event for native-detected connection loss
      if (printerAddress != null) {
        _emitConnectionEvent(ConnectionEvent.lost(
          printerAddress: printerAddress,
          reason: reason ?? 'Connection lost (detected by native layer)',
          metadata: {
            'source': 'native_event',
            'reason': reason ?? 'unknown',
          },
        ));
      }
    });

  }

  // Streamed discovery primitives (per-operation streams)
  Stream<ZebraDevice> discoverBTClassicStream(
      {int timeout = 5000, DiscoveryWarningCallback? onWarning}) {
    final controller = StreamController<ZebraDevice>.broadcast();
    String? operationId;

    () async {
      try {
        final hasPermission =
            await PermissionManager.checkBluetoothPermission();
        if (!hasPermission && !Platform.isIOS) {
          // On iOS, Bluetooth permission is only required for connection, not discovery
          if (!controller.isClosed) {
            controller.addError(ZebraErrorBridge.fromDartError<void>(
              Exception('Bluetooth permission denied'),
              stackTrace: StackTrace.current,
            ));
          }
          return;
        }
        
        // Start the discovery operation
        await _operationManager.execute<Map<String, dynamic>>(
          method: MethodChannelConstants.discoverBTClassicMethod,
          arguments: {'timeout': timeout},
          timeout: Duration(milliseconds: timeout + 1000),
          onOperationStart: (opId) {
            operationId = opId;
            _discoveryEventSubs[opId] =
                _operationManager.operationEvents(opId).listen((evt) {
              final method = evt['method'] as String?;
              final data = (evt['data'] as Map<String, dynamic>?) ?? {};
              if (method ==
                  MethodChannelConstants.discoverBTClassicEventPrinterFound) {
                final device =
                    NativePrinterInfo.fromNative(data).toZebraDevice();
                if (!controller.isClosed) controller.add(device);
              } else if (method ==
                  MethodChannelConstants.discoveryEventLogWarning) {
                onWarning?.call(
                  phase: data['phase'] as String?,
                  target: data['target'] as String?,
                  message: data['message'] as String?,
                );
              }
            });
            isScanning = true;
          },
        );
        
        // Operation completed, now close the stream
        if (!controller.isClosed) controller.close();
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
        if (!controller.isClosed) controller.close();
      } finally {
        // Clean up subscriptions
        if (operationId != null) {
          await _discoveryEventSubs.remove(operationId)?.cancel();
        }
        isScanning = false;
      }
    }();

    controller.onCancel = () async {
      if (operationId != null) {
        await _discoveryEventSubs.remove(operationId)?.cancel();
      }
      await stopDiscovery();
    };

    return controller.stream;
  }

  Stream<ZebraDevice> discoverLocalBroadcastStream(
      {int timeout = 5000, DiscoveryWarningCallback? onWarning}) {
    final controller = StreamController<ZebraDevice>.broadcast();
    String? operationId;

    () async {
      try {
        await _operationManager.execute<Map<String, dynamic>>(
          method: MethodChannelConstants.discoverLocalBroadcastMethod,
          arguments: {'timeout': timeout},
          timeout: Duration(milliseconds: timeout + 1000),
          onOperationStart: (opId) {
            operationId = opId;
            _discoveryEventSubs[opId] =
                _operationManager.operationEvents(opId).listen((evt) {
              final method = evt['method'] as String?;
              final data = (evt['data'] as Map<String, dynamic>?) ?? {};
              if (method ==
                  MethodChannelConstants
                      .discoverLocalBroadcastEventPrinterFound) {
                final device =
                    NativePrinterInfo.fromNative(data).toZebraDevice();
                if (!controller.isClosed) controller.add(device);
              } else if (method ==
                  MethodChannelConstants.discoveryEventLogWarning) {
                onWarning?.call(
                  phase: data['phase'] as String?,
                  target: data['target'] as String?,
                  message: data['message'] as String?,
                );
              }
            });
            isScanning = true;
          },
        );
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        if (!controller.isClosed) controller.close();
        if (operationId != null) {
          await _discoveryEventSubs.remove(operationId)?.cancel();
        }
        isScanning = false;
      }
    }();

    controller.onCancel = () async {
      if (operationId != null) {
        await _discoveryEventSubs.remove(operationId)?.cancel();
      }
      await stopDiscovery();
    };

    return controller.stream;
  }

  Stream<ZebraDevice> discoverSubnetStream(
      {String subnet = '192.168.1',
      int timeout = 5000,
      DiscoveryWarningCallback? onWarning}) {
    final controller = StreamController<ZebraDevice>.broadcast();
    String? operationId;

    () async {
      try {
        await _operationManager.execute<Map<String, dynamic>>(
          method: MethodChannelConstants.discoverSubnetMethod,
          arguments: {'subnet': subnet, 'timeout': timeout},
          timeout: Duration(milliseconds: timeout + 1000),
          onOperationStart: (opId) {
            operationId = opId;
            _discoveryEventSubs[opId] =
                _operationManager.operationEvents(opId).listen((evt) {
              final method = evt['method'] as String?;
              final data = (evt['data'] as Map<String, dynamic>?) ?? {};
              if (method ==
                  MethodChannelConstants.discoverSubnetEventPrinterFound) {
                final device =
                    NativePrinterInfo.fromNative(data).toZebraDevice();
                if (!controller.isClosed) controller.add(device);
              } else if (method ==
                  MethodChannelConstants.discoveryEventLogWarning) {
                onWarning?.call(
                  phase: data['phase'] as String?,
                  target: data['target'] as String?,
                  message: data['message'] as String?,
                );
              }
            });
            isScanning = true;
          },
        );
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        if (!controller.isClosed) controller.close();
        if (operationId != null) {
          await _discoveryEventSubs.remove(operationId)?.cancel();
        }
        isScanning = false;
      }
    }();

    controller.onCancel = () async {
      if (operationId != null) {
        await _discoveryEventSubs.remove(operationId)?.cancel();
      }
      await stopDiscovery();
    };

    return controller.stream;
  }

  Stream<ZebraDevice> discoverDirectedBroadcastStream(
      {String ipAddress = '192.168.1.255',
      int timeout = 5000,
      DiscoveryWarningCallback? onWarning}) {
    final controller = StreamController<ZebraDevice>.broadcast();
    String? operationId;

    () async {
      try {
        await _operationManager.execute<Map<String, dynamic>>(
          method: MethodChannelConstants.discoverDirectedBroadcastMethod,
          arguments: {'ipAddress': ipAddress, 'timeout': timeout},
          timeout: Duration(milliseconds: timeout + 1000),
          onOperationStart: (opId) {
            operationId = opId;
            _discoveryEventSubs[opId] =
                _operationManager.operationEvents(opId).listen((evt) {
              final method = evt['method'] as String?;
              final data = (evt['data'] as Map<String, dynamic>?) ?? {};
              if (method ==
                  MethodChannelConstants
                      .discoverDirectedBroadcastEventPrinterFound) {
                final device =
                    NativePrinterInfo.fromNative(data).toZebraDevice();
                if (!controller.isClosed) controller.add(device);
              } else if (method ==
                  MethodChannelConstants.discoveryEventLogWarning) {
                onWarning?.call(
                  phase: data['phase'] as String?,
                  target: data['target'] as String?,
                  message: data['message'] as String?,
                );
              }
            });
            isScanning = true;
          },
        );
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        if (!controller.isClosed) controller.close();
        if (operationId != null) {
          await _discoveryEventSubs.remove(operationId)?.cancel();
        }
        isScanning = false;
      }
    }();

    controller.onCancel = () async {
      if (operationId != null) {
        await _discoveryEventSubs.remove(operationId)?.cancel();
      }
      await stopDiscovery();
    };

    return controller.stream;
  }

  Stream<ZebraDevice> discoverMulticastStream(
      {int hops = 5, int timeout = 5000, DiscoveryWarningCallback? onWarning}) {
    final controller = StreamController<ZebraDevice>.broadcast();
    String? operationId;

    () async {
      try {
        await _operationManager.execute<Map<String, dynamic>>(
          method: MethodChannelConstants.discoverMulticastMethod,
          arguments: {'hops': hops, 'timeout': timeout},
          timeout: Duration(milliseconds: timeout + 1000),
          onOperationStart: (opId) {
            operationId = opId;
            _discoveryEventSubs[opId] =
                _operationManager.operationEvents(opId).listen((evt) {
              final method = evt['method'] as String?;
              final data = (evt['data'] as Map<String, dynamic>?) ?? {};
              if (method ==
                  MethodChannelConstants.discoverMulticastEventPrinterFound) {
                final device =
                    NativePrinterInfo.fromNative(data).toZebraDevice();
                if (!controller.isClosed) controller.add(device);
              } else if (method ==
                  MethodChannelConstants.discoveryEventLogWarning) {
                onWarning?.call(
                  phase: data['phase'] as String?,
                  target: data['target'] as String?,
                  message: data['message'] as String?,
                );
              }
            });
            isScanning = true;
          },
        );
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        if (!controller.isClosed) controller.close();
        if (operationId != null) {
          await _discoveryEventSubs.remove(operationId)?.cancel();
        }
        isScanning = false;
      }
    }();

    controller.onCancel = () async {
      if (operationId != null) {
        await _discoveryEventSubs.remove(operationId)?.cancel();
      }
      await stopDiscovery();
    };

    return controller.stream;
  }

  /// Factory method to create a ZebraPrinter instance
  static Future<ZebraPrinter> create({
    ZebraController? controller,
  }) async {
    // Get instance ID from platform
    const platform = MethodChannel(MethodChannelConstants.mainChannel);
    final String instanceId = await platform
            .invokeMethod<String>(MethodChannelConstants.getInstanceMethod) ??
        'default';

    return ZebraPrinter._(
      instanceId,
      controller: controller,
    );
  }

 
  final String instanceId;
  final ZebraController controller;

  late final MethodChannel _channel;
  late final ZebraPrinterOperationManager _operationManager;
  late final ZebraPrinterOperationCallbackHandler _callbackHandler;
  final Logger _logger;

  bool isRotated = false;
  bool isScanning = false;
  bool shouldSync = false;

  // Connection state tracking for round-trip optimization
  bool? _isConnected;
  DateTime? _lastConnectionVerified;
  static const _connectionValidityDuration = Duration(seconds: 30);


  // Per-operation discovery event subscriptions
  final Map<String, StreamSubscription<Map<String, dynamic>>>
      _discoveryEventSubs = {};

  // Connection event stream for real-time UI updates
  final StreamController<ConnectionEvent> _connectionEventController =
      StreamController<ConnectionEvent>.broadcast();

  /// Stream of real-time connection events
  /// Subscribe to this for immediate UI updates when connection status changes
  Stream<ConnectionEvent> get connectionEvents =>
      _connectionEventController.stream;

  /// Get cached printer connection status without round-trip to printer
  /// Returns null if no cached value or value is stale
  bool? get isPrinterConnectedCached {
    if (_isConnected == null || _lastConnectionVerified == null) {
      return null;
    }

    final now = DateTime.now();
    final timeSinceVerified = now.difference(_lastConnectionVerified!);

    if (timeSinceVerified > _connectionValidityDuration) {
      _logger.debug(
          'Cached connection status expired (${timeSinceVerified.inSeconds}s old)');
      return null;
    }

    return _isConnected;
  }

  /// Update connection state based on operation results
  /// Called internally when operations succeed or fail with connection errors
  void _updateConnectionState(bool connected, {String? context}) {
    final wasConnected = _isConnected;
    _isConnected = connected;

    if (connected) {
      _lastConnectionVerified = DateTime.now();
      if (wasConnected != true) {
        _logger.info(
            'Connection state updated: CONNECTED${context != null ? ' ($context)' : ''}');
        // Emit connection established event
        if (controller.selectedAddress != null) {
          _emitConnectionEvent(ConnectionEvent.connected(
            printerAddress: controller.selectedAddress!,
            message: 'Connected${context != null ? ' ($context)' : ''}',
            metadata: {'context': context ?? 'unknown'},
          ));
        }
      }
    } else {
      _lastConnectionVerified = null;
      if (wasConnected != false) {
        _logger.info(
            'Connection state updated: DISCONNECTED${context != null ? ' ($context)' : ''}');
        // Emit connection lost event
        if (controller.selectedAddress != null) {
          _emitConnectionEvent(ConnectionEvent.lost(
            printerAddress: controller.selectedAddress!,
            reason: 'Connection lost${context != null ? ' ($context)' : ''}',
            metadata: {'context': context ?? 'unknown'},
          ));
        }
      }
    }
  }

  /// Emit a connection event to all listeners
  void _emitConnectionEvent(ConnectionEvent event) {
    if (!_connectionEventController.isClosed) {
      _connectionEventController.add(event);
      _logger.debug('Emitted connection event: ${event.type.displayName}');
    }
  }

  /// Check if cached connection value is still valid
  bool _isCachedConnectionValid() {
    return _isConnected != null &&
        _lastConnectionVerified != null &&
        DateTime.now().difference(_lastConnectionVerified!) <
            _connectionValidityDuration;
  }



  // Primitive: Discover MFi Bluetooth printers (BT Classic on iOS)
  // Returns a per-operation stream of devices
  Stream<ZebraDevice> discoverBTClassic(
          {int timeout = 5000, DiscoveryWarningCallback? onWarning}) =>
      discoverBTClassicStream(timeout: timeout, onWarning: onWarning);

  // Returns a per-operation stream of devices
  Stream<ZebraDevice> discoverLocalBroadcast(
          {int timeout = 5000, DiscoveryWarningCallback? onWarning}) =>
      discoverLocalBroadcastStream(timeout: timeout, onWarning: onWarning);

  // Returns a per-operation stream of devices
  Stream<ZebraDevice> discoverSubnet(
          {String subnet = '192.168.1',
          int timeout = 5000,
          DiscoveryWarningCallback? onWarning}) =>
      discoverSubnetStream(
          subnet: subnet, timeout: timeout, onWarning: onWarning);

  // Returns a per-operation stream of devices
  Stream<ZebraDevice> discoverDirectedBroadcast(
          {String ipAddress = '192.168.1.255',
          int timeout = 5000,
          DiscoveryWarningCallback? onWarning}) =>
      discoverDirectedBroadcastStream(
          ipAddress: ipAddress, timeout: timeout, onWarning: onWarning);

  // Returns a per-operation stream of devices
  Stream<ZebraDevice> discoverMulticast(
          {int hops = 5,
          int timeout = 5000,
          DiscoveryWarningCallback? onWarning}) =>
      discoverMulticastStream(
          hops: hops, timeout: timeout, onWarning: onWarning);

  // Primitive: Stop all discovery operations
  Future<Result<void>> stopDiscovery() async {
    _logger.info('Stopping all discovery operations');
    isScanning = false;
    shouldSync = true;
    
    return await ZebraErrorBridge.executeAndHandleResult<void>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: MethodChannelConstants.stopScanMethod,
          arguments: {},
          timeout: const Duration(seconds: 5),
        );

        if (result.success) {
          _logger.info('All discovery operations stopped successfully');
          return Result.success();
        } else {
          return ZebraErrorBridge.fromInnerResult<void>(
            result,
            ErrorCodes.discoveryError,
            formatArgs: [result.error?.message ?? 'Failed to stop discovery'],
          );
        }
      },
      operationType: OperationType.discovery,
      timeout: const Duration(seconds: 5),
    );
  }

  // Primitive: Connect to printer
  Future<Result<void>> connectToPrinter(String address) async {
    _logger.info('Initiating connection to printer: $address');
    
    return await ZebraErrorBridge.executeAndHandleResult<void>(
      operation: () async {
        // Check if already connected to the same printer
        if (controller.selectedAddress == address) {
          _logger.info(
              'Already connected to printer: $address, skipping reconnection');
          return Result.success();
        }

        // Only disconnect if connecting to a different printer
        if (controller.selectedAddress != null) {
          _logger.info(
              'Disconnecting from previous printer before connecting to: $address');
          final disconnectResult = await disconnect();
          if (!disconnectResult.success) {
            return ZebraErrorBridge.fromInnerResult<void>(
              disconnectResult,
              ErrorCodes.connectionError,
              formatArgs: ['Failed to disconnect before reconnecting'],
            );
          }
        }

        controller.selectedAddress = address;
        final result = await _operationManager.execute<bool>(
          method: MethodChannelConstants.connectToPrinterMethod,
          arguments: {'Address': address},
          timeout: const Duration(seconds: 7),
        );
        if (result.success && (result.data ?? false)) {
          _updateConnectionState(true, context: 'connectToPrinter success');
          _logger.info('Successfully connected to printer: $address');
          final existingPrinter = controller.printers.firstWhere(
            (p) => p.address == address,
            orElse: () => ZebraDevice(
              address: address,
              name: 'Printer $address',
              isWifi: !address.contains(':'),
              status: 'Connected',
            ),
          );
          if (!controller.printers.any((p) => p.address == address)) {
            controller.addPrinter(existingPrinter);
          }
          controller.updatePrinterStatus('Connected', 'G');
          return Result.success();
        } else {
          _updateConnectionState(false, context: 'connectToPrinter failed');
          _logger.error('Failed to establish connection to printer: $address');
          controller.selectedAddress = null;
          return ZebraErrorBridge.fromInnerResult<void>(
            result,
            ErrorCodes.connectionError,
            formatArgs: [result.error?.message ?? 'Connection failed'],
          );
        }
      },
      operationType: OperationType.connection,
      deviceAddress: address,
    );
  }

  // Primitive: Disconnect
  Future<Result<void>> disconnect() async {
    _logger.info('Initiating printer disconnection');
    
    return await ZebraErrorBridge.executeAndHandleResult<void>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: MethodChannelConstants.disconnectMethod,
          arguments: {},
          timeout: const Duration(seconds: 5),
        );
        if (controller.selectedAddress != null) {
          controller.updatePrinterStatus('Disconnected', 'R');
          _logger.info('Updated printer status to disconnected');
        }
        if (result.success) {
          _updateConnectionState(false, context: 'disconnect success');
          _logger.info('Printer disconnected successfully');
          return Result.success();
        } else {
          _logger
              .error('Disconnect operation failed: ${result.error?.message}');
          // Don't update connection state on disconnect failure - might still be connected
          return ZebraErrorBridge.fromInnerResult<void>(
            result,
            ErrorCodes.disconnectFailed,
            formatArgs: [result.error?.message ?? 'Disconnect failed'],
          );
        }
      },
      operationType: OperationType.connection,
      deviceAddress: controller.selectedAddress,
    );
  }

  // Primitive: Print (send data) - processes data then calls main implementation
  Future<Result<PrintOperationTracker>> print({
    required String data,
    PrintFormat format = PrintFormat.zpl,
  }) async {
    _logger.info('Processing and sending print data to printer');

    // Process the data first
    final processResult = PrintDataProcessor.process(data, format);
    if (!processResult.success) {
      _logger.error(
          'Print data processing failed: ${processResult.error?.message}');
      return ZebraErrorBridge.fromInnerResult<PrintOperationTracker>(
        processResult,
        ErrorCodes.printDataInvalidFormat,
        formatArgs: [processResult.error?.message ?? 'Data processing failed'],
      );
    }

    // Call the main implementation with processed data
    return await printWithProcessedData(processResult.data!);
  }

  // Primitive: Print (send processed data)
  Future<Result<PrintOperationTracker>> printWithProcessedData(
    ProcessedPrintData processedData,
  ) async {
    _logger.info('Sending processed print data to printer');

    // Create tracker for this print operation
    final tracker = PrintOperationTracker();

    // Start tracking BEFORE the native operation
    tracker.startPrint(processedData.data, processedData.format);
    _logger.info(
        'Started tracking print operation: ${tracker.operationId} (format: ${processedData.format.name})');

    return await ZebraErrorBridge.executeAndHandleResult<PrintOperationTracker>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: MethodChannelConstants.printMethod,
          arguments: {'Data': processedData.data},
          timeout: const Duration(seconds: 30),
        );
        if (result.success) {
          _updateConnectionState(true, context: 'print success');
          _logger.info('Processed print data sent successfully');
          tracker.stopPrint();
          return Result.success(tracker);
        } else {
          _logger.error('Print operation failed: ${result.error?.message}');
          tracker.stopPrint();

          // Check if this is a connection error and update state
          final errorResult =
              ZebraErrorBridge.fromInnerResult<PrintOperationTracker>(
            result,
            ErrorCodes.printError,
            formatArgs: [result.error?.message ?? 'Print failed'],
          );

          if (ZebraErrorBridge.isConnectionRelatedError(errorResult)) {
            _updateConnectionState(false, context: 'print connection error');
          }

          return errorResult;
        }
      },
      operationType: OperationType.print,
      printData: processedData.data,
    );
  }

  // Primitive: Get printer status
  Future<Result<Map<String, dynamic>>> getPrinterStatus() async {
    _logger.info('Getting printer status');
    
    return await ZebraErrorBridge.executeAndHandleResult<Map<String, dynamic>>(
      operation: () async {
        final result = await _operationManager.execute<Map<String, dynamic>>(
          method: MethodChannelConstants.getPrinterStatusMethod,
          arguments: {},
          timeout: const Duration(seconds: 5),
        );
        if (result.success && result.data != null) {
          _updateConnectionState(true, context: 'getPrinterStatus success');
          _logger.info('Printer status retrieved successfully');
          return Result.success(result.data!);
        } else {
          _logger
              .error('Failed to get printer status: ${result.error?.message}');
          
          final errorResult =
              ZebraErrorBridge.fromInnerResult<Map<String, dynamic>>(
            result,
            ErrorCodes.statusCheckFailed,
            formatArgs: [
              result.error?.message ?? 'Failed to get printer status'
            ],
          );
          
          if (ZebraErrorBridge.isConnectionRelatedError(errorResult)) {
            _updateConnectionState(false,
                context: 'getPrinterStatus connection error');
          }

          return errorResult;
        }
      },
      operationType: OperationType.status,
    );
  }

  // Primitive: Get detailed printer status
  Future<Result<Map<String, dynamic>>> getDetailedPrinterStatus() async {
    _logger.info('Getting detailed printer status');
    
    return await ZebraErrorBridge.executeAndHandleResult<Map<String, dynamic>>(
      operation: () async {
        final result = await _operationManager.execute<Map<String, dynamic>>(
          method: MethodChannelConstants.getDetailedPrinterStatusMethod,
          arguments: {},
          timeout: const Duration(seconds: 10),
        );
        if (result.success && result.data != null) {
          _logger.info('Detailed printer status retrieved successfully');
          return Result.success(result.data!);
        } else {
          _logger.error(
              'Failed to get detailed printer status: ${result.error?.message}');
          return ZebraErrorBridge.fromInnerResult<Map<String, dynamic>>(
            result,
            ErrorCodes.detailedStatusCheckFailed,
            formatArgs: [
              result.error?.message ?? 'Failed to get detailed printer status'
            ],
          );
        }
      },
      operationType: OperationType.status,
      isDetailed: true,
    );
  }

  // Primitive: Get setting
  Future<Result<String?>> getSetting(String setting) async {
    _logger.info('Getting printer setting: $setting');

    return await ZebraErrorBridge.executeAndHandleResult<String?>(
      operation: () async {
        final result = await _operationManager.execute<String?>(
          method: MethodChannelConstants.getSettingMethod,
          arguments: {'setting': setting},
          timeout: const Duration(seconds: 5),
        );
        if (result.success) {
          _logger.info(
              'Setting retrieved successfully: $setting = ${result.data}');
          return Result.success(result.data);
        } else {
          _logger.error(
              'Failed to get setting $setting: ${result.error?.message}');
          return ZebraErrorBridge.fromInnerResult<String?>(
            result,
            ErrorCodes.commandError,
            formatArgs: [
              setting,
              result.error?.message ?? 'Failed to get setting'
            ],
          );
        }
      },
      operationType: OperationType.command,
      command: setting,
    );
  }

  // Primitive: Rotate print orientation (for ZPL)
  void rotate() {
    isRotated = !isRotated;
  }

  // Primitive: Check if printer is connected
  Future<Result<bool>> isPrinterConnected({bool forceCheck = false}) async {
    // Use cached value if valid and not forcing check
    if (!forceCheck && _isCachedConnectionValid()) {
      _logger.debug('Using cached connection status: $_isConnected');
      return Result.success(_isConnected!);
    }

    _logger.info(
        'Checking printer connection status${forceCheck ? ' (forced)' : ''}');

    return await ZebraErrorBridge.executeAndHandleResult<bool>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: MethodChannelConstants.isConnectedMethod,
          arguments: {},
          timeout: const Duration(seconds: 3),
        );
        if (result.success) {
          final isConnected = result.data ?? false;
          _updateConnectionState(isConnected, context: 'isPrinterConnected');
          _logger.info(
              'Connection status: ${isConnected ? 'Connected' : 'Disconnected'}');
          return Result.success(isConnected);
        } else {
          _logger.error(
              'Failed to check connection status: ${result.error?.message}');
          // Don't update state on check failure - might be temporary
          return ZebraErrorBridge.fromInnerResult<bool>(
            result,
            ErrorCodes.connectionError,
            formatArgs: [
              result.error?.message ?? 'Failed to check connection status'
            ],
          );
        }
      },
      operationType: OperationType.connection,
    );
  }

  // Primitive: Send command
  Future<Result<void>> sendCommand(String command) async {
    _logger.info('Sending command to printer: $command');
    
    return await ZebraErrorBridge.executeAndHandleResult<void>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: MethodChannelConstants.setSettingsMethod,
          arguments: {'SettingCommand': command},
          timeout: const Duration(seconds: 5),
        );
        if (result.success) {
          _updateConnectionState(true, context: 'sendCommand success');
          _logger.info('Command sent successfully: $command');
          return Result.success();
        } else {
          _logger.error(
              'Failed to send command $command: ${result.error?.message}');
          
          final errorResult = ZebraErrorBridge.fromInnerResult<void>(
            result,
            ErrorCodes.commandError,
            formatArgs: [
              command,
              result.error?.message ?? 'Failed to send command'
            ],
          );
          
          if (ZebraErrorBridge.isConnectionRelatedError(errorResult)) {
            _updateConnectionState(false,
                context: 'sendCommand connection error');
          }

          return errorResult;
        }
      },
      operationType: OperationType.command,
      command: command,
    );
  }

  // Primitive: Get instance ID
  Future<Result<String>> getInstanceId() async {
    _logger.info('Getting instance ID');

    return await ZebraErrorBridge.executeAndHandleResult<String>(
      operation: () async {
        final result = await _operationManager.execute<String>(
          method: MethodChannelConstants.getInstanceMethod,
          arguments: {},
          timeout: const Duration(seconds: 5),
        );

        if (result.success && result.data != null) {
          _logger.info('Instance ID retrieved successfully');
          return Result.success(result.data!);
        } else {
          return ZebraErrorBridge.fromInnerResult<String>(
            result,
            ErrorCodes.operationError,
            formatArgs: [
              result.error?.message ?? 'Instance ID retrieval failed'
            ],
          );
        }
      },
      operationType: OperationType.general,
    );
  }

  // Primitive: Native method call handler
  Future<void> nativeMethodCallHandler(MethodCall methodCall) async {
    try {
      await _callbackHandler.handleMethodCall(methodCall);
    } catch (e, stack) {
      _logger.error(
          'Error in nativeMethodCallHandler for method ${methodCall.method}: $e',
          null,
          stack);
      try {
        final operationId = methodCall.arguments?['operationId'] as String?;
        if (operationId != null) {
          _operationManager.failOperation(
              operationId, 'Native method call error: $e');
        }
      } catch (failError) {
        _logger.error(
            'Error failing operation after native method call error: $failError');
      }
    }
  }

  // Primitive: Dispose
  void dispose() {
    _connectionEventController.close();
    _operationManager.dispose();
  }
}

/// Notifier for printers, contains list of printers and methods to add, remove and update printers
class ZebraController extends ChangeNotifier {
  final List<ZebraDevice> _printers = [];
  List<ZebraDevice> get printers => List.unmodifiable(_printers);
  String? selectedAddress;

  void addPrinter(ZebraDevice printer) {
    if (_printers.contains(printer)) return;
    _printers.add(printer);
    notifyListeners();
  }

  void removePrinter(String address) {
    _printers.removeWhere((element) => element.address == address);
    notifyListeners();
  }

  void cleanAll() {
    if(_printers.isEmpty) return;
    _printers.removeWhere((element) => !element.isConnected);
  }

  void updatePrinterStatus(String status, String color) {
    if (selectedAddress != null) {
      Color newColor = Colors.grey.withValues(alpha: 0.6);
      switch (color) {
        case 'R':
          newColor = Colors.red;
          break;
        case 'G':
          newColor = Colors.green;
          break;
        default:
          newColor = Colors.grey.withValues(alpha: 0.6);
          break;
      }
      final int index =
          _printers.indexWhere((element) => element.address == selectedAddress);
      if (index != -1) {
        _printers[index] = _printers[index].copyWith(
            status: status, color: newColor, isConnected: color == 'G');
        notifyListeners();
      }
    }
  }

  void synchronizePrinter(String connectedString) {
    if (selectedAddress == null) return;
    final int index =
        _printers.indexWhere((element) => element.address == selectedAddress);
    if (index == -1) {
      selectedAddress = null;
      return;
    }
    if (_printers[index].isConnected) return;
    _printers[index] = _printers[index].copyWith(
        status: connectedString, color: Colors.green, isConnected: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _printers.clear();
    super.dispose();
  }
}
