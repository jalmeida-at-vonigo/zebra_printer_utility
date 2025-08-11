import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'internal/logger.dart';
import 'internal/native_models/method_channel_constants.dart';
import 'internal/native_models/printer_info.dart';
import 'internal/permission_manager.dart';
import 'internal/zebra_error_bridge.dart';
import 'internal/zebra_printer_operation_callback_handler.dart';
import 'internal/zebra_printer_operation_manager.dart';
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
        if (!hasPermission) {
          if (!controller.isClosed) {
            controller.addError(ZebraErrorBridge.fromDartError<void>(
              Exception('Bluetooth permission denied'),
              stackTrace: StackTrace.current,
            ));
          }
          return;
        }
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
                      MethodChannelConstants
                          .discoverBTClassicEventPrinterFound ||
                  method ==
                      MethodChannelConstants
                          .discoverLocalBroadcastEventPrinterFound ||
                  method ==
                      MethodChannelConstants.discoverSubnetEventPrinterFound ||
                  method ==
                      MethodChannelConstants
                          .discoverDirectedBroadcastEventPrinterFound ||
                  method ==
                      MethodChannelConstants
                          .discoverMulticastEventPrinterFound) {
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


  // Per-operation discovery event subscriptions
  final Map<String, StreamSubscription<Map<String, dynamic>>>
      _discoveryEventSubs = {};

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
          _logger.info('Printer disconnected successfully');
          return Result.success();
        } else {
          _logger
              .error('Disconnect operation failed: ${result.error?.message}');
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

  // Primitive: Print (send data)
  Future<Result<PrintOperationTracker>> print({
    required String data,
    PrintFormat format = PrintFormat.zpl,
  }) async {
    _logger.info('Sending print data to printer');
    
    // Create tracker for this print operation
    final tracker = PrintOperationTracker();

    // Start tracking BEFORE the native operation
    tracker.startPrint(data, format);
    _logger.info(
        'Started tracking print operation: ${tracker.operationId} (format: ${format.name})');

    return await ZebraErrorBridge.executeAndHandleResult<PrintOperationTracker>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: MethodChannelConstants.printMethod,
          arguments: {'Data': data},
          timeout: const Duration(seconds: 30),
        );
        if (result.success) {
          _logger.info('Print data sent successfully');
          tracker.stopPrint();
          return Result.success(tracker);
        } else {
          _logger.error('Print operation failed: ${result.error?.message}');
          tracker.stopPrint();
          return ZebraErrorBridge.fromInnerResult<PrintOperationTracker>(
            result,
            ErrorCodes.printError,
            formatArgs: [result.error?.message ?? 'Print failed'],
          );
        }
      },
      operationType: OperationType.print,
      printData: data,
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
          _logger.info('Printer status retrieved successfully');
          return Result.success(result.data!);
        } else {
          _logger
              .error('Failed to get printer status: ${result.error?.message}');
          return ZebraErrorBridge.fromInnerResult<Map<String, dynamic>>(
            result,
            ErrorCodes.statusCheckFailed,
            formatArgs: [
              result.error?.message ?? 'Failed to get printer status'
            ],
          );
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
  Future<Result<bool>> isPrinterConnected() async {
    _logger.info('Checking printer connection status');

    return await ZebraErrorBridge.executeAndHandleResult<bool>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: MethodChannelConstants.isConnectedMethod,
          arguments: {},
          timeout: const Duration(seconds: 3),
        );
        if (result.success) {
          final isConnected = result.data ?? false;
          _logger.info(
              'Connection status: ${isConnected ? 'Connected' : 'Disconnected'}');
          return Result.success(isConnected);
        } else {
          _logger.error(
              'Failed to check connection status: ${result.error?.message}');
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
          _logger.info('Command sent successfully: $command');
          return Result.success();
        } else {
          _logger.error(
              'Failed to send command $command: ${result.error?.message}');
          return ZebraErrorBridge.fromInnerResult<void>(
            result,
            ErrorCodes.commandError,
            formatArgs: [
              command,
              result.error?.message ?? 'Failed to send command'
            ],
          );
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
