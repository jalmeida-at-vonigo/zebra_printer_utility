import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'internal/logger.dart';
import 'internal/operation_callback_handler.dart';
import 'internal/operation_manager.dart';
import 'internal/permission_manager.dart';
import 'internal/zebra_error_bridge.dart';
import 'models/print_enums.dart';
import 'models/print_operation_tracker.dart';
import 'models/result.dart';
import 'models/zebra_device.dart';

/// Printer language modes
enum PrinterMode { zpl, cpcl }

class ZebraPrinter {
  ZebraPrinter(
    this.instanceId, {
    ZebraController? controller,
    this.onDiscoveryError,
    this.onPermissionDenied,
  })  : controller = controller ?? ZebraController(),
        _logger = Logger.withPrefix('ZebraPrinter.$instanceId') {
    channel = MethodChannel('ZebraPrinterObject$instanceId');
    channel.setMethodCallHandler(nativeMethodCallHandler);
    
    _operationManager = OperationManager(channel: channel);
    _callbackHandler = OperationCallbackHandler(manager: _operationManager);
    
    // Register event handlers for non-operation callbacks
    _callbackHandler.registerEventHandler('printerFound', (call) {
      final address = call.arguments?['Address'] ?? '';
      final name = call.arguments?['Name'] ?? 'Unknown Printer';
      final status = call.arguments?['Status'] ?? 'Found';
      final isWifi = call.arguments?['IsWifi'] == true ||
          call.arguments?['IsWifi'] == 'true';
      final brand = call.arguments?['brand'] ?? 'Zebra';
      final model = call.arguments?['model'];
      var displayName = call.arguments?['displayName'];
      final manufacturer = call.arguments?['manufacturer'] ?? 'Zebra';
      final firmwareRevision = call.arguments?['firmwareRevision'];
      final hardwareRevision = call.arguments?['hardwareRevision'];
      var connectionType = call.arguments?['connectionType'];
      final isBluetooth = call.arguments?['isBluetooth'] == true ||
          call.arguments?['isBluetooth'] == 'true';
      
      // Generate displayName if not provided
      if (displayName == null || displayName.isEmpty) {
        if (model != null && model.isNotEmpty) {
          displayName = 'Zebra $model - $name';
        } else {
          displayName = 'Zebra Printer - $name';
        }
      }

      // Generate connectionType if not provided
      if (connectionType == null || connectionType.isEmpty) {
        if (isBluetooth) {
          connectionType = 'MFi Bluetooth';
        } else if (isWifi) {
          connectionType = 'Network';
        } else {
          connectionType = 'Unknown';
        }
      }
      
      this.controller.addPrinter(ZebraDevice(
            address: address,
            name: name,
            status: status,
            isWifi: isWifi,
            brand: brand,
            model: model,
            displayName: displayName,
            manufacturer: manufacturer,
            firmwareRevision: firmwareRevision,
            hardwareRevision: hardwareRevision,
            connectionType: connectionType,
            isBluetooth: isBluetooth,
          ));
    });
    _callbackHandler.registerEventHandler('changePrinterStatus', (call) {
      final status = call.arguments?['Status'] ?? '';
      final color = call.arguments?['Color'] ?? 'R';
      this.controller.updatePrinterStatus(status, color);
    });
    _callbackHandler.registerEventHandler('printerRemoved', (call) {
      final address = call.arguments?['Address'] ?? '';
      this.controller.removePrinter(address);
    });
    _callbackHandler.registerEventHandler('onDiscoveryError', (call) {
      final errorText = call.arguments?['ErrorText'] ?? 'Unknown error';
      if (onDiscoveryError != null) {
        onDiscoveryError!(ErrorCodes.discoveryError.code, errorText);
      }
    });
    _callbackHandler.registerEventHandler('onPrinterDiscoveryDone', (call) {
      isScanning = false;
    });
  }

  final String instanceId;
  final ZebraController controller;
  void Function(String code, String message)? onDiscoveryError;
  void Function()? onPermissionDenied;

  late final MethodChannel channel;
  late final OperationManager _operationManager;
  late final OperationCallbackHandler _callbackHandler;
  final Logger _logger;

  bool isRotated = false;
  bool isScanning = false;
  bool shouldSync = false;

  // Primitive: Start scanning
  Future<Result<void>> startScanning() async {
    _logger.info('Starting printer discovery process');
    isScanning = true;
    controller.cleanAll();
    
    return await ZebraErrorBridge.executeAndHandle<void>(
      operation: () async {
        final hasPermission =
            await PermissionManager.checkBluetoothPermission();
        if (!hasPermission) {
          _logger.warning('Bluetooth permission permanently denied');
          throw Exception('Bluetooth permission denied');
        }

        final result = await _operationManager.execute<bool>(
          method: 'startScan',
          arguments: {},
          timeout: const Duration(seconds: 30),
        );

        if (result.success) {
          _logger.info('Printer scan initiated successfully');
          return;
        } else {
          isScanning = false;
          throw Exception(result.error?.message ?? 'Discovery start failed');
        }
      },
      operationType: OperationType.discovery,
      timeout: const Duration(seconds: 30),
    );
  }

  // Primitive: Stop scanning
  Future<Result<void>> stopScanning() async {
    _logger.info('Stopping printer discovery process');
    isScanning = false;
    shouldSync = true;
    
    return await ZebraErrorBridge.executeAndHandle<void>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: 'stopScan',
          arguments: {},
          timeout: const Duration(seconds: 5),
        );

        if (result.success) {
          _logger.info('Printer discovery stopped successfully');
          return;
        } else {
          throw Exception(result.error?.message ?? 'Discovery stop failed');
        }
      },
      operationType: OperationType.discovery,
      timeout: const Duration(seconds: 5),
    );
  }

  // Primitive: Connect to printer
  Future<Result<void>> connectToPrinter(String address) async {
    _logger.info('Initiating connection to printer: $address');
    
    return await ZebraErrorBridge.executeAndHandle<void>(
      operation: () async {
        // Check if already connected to the same printer
        if (controller.selectedAddress == address) {
          _logger.info(
              'Already connected to printer: $address, skipping reconnection');
          return;
        }

        // Only disconnect if connecting to a different printer
        if (controller.selectedAddress != null) {
          _logger.info(
              'Disconnecting from previous printer before connecting to: $address');
          await disconnect();
        }

        controller.selectedAddress = address;
        final result = await _operationManager.execute<bool>(
          method: 'connectToPrinter',
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
          return;
        } else {
          _logger.error('Failed to establish connection to printer: $address');
          controller.selectedAddress = null;
          throw Exception(result.error?.message ?? 'Connection failed');
        }
      },
      operationType: OperationType.connection,
      deviceAddress: address,
    );
  }

  // Primitive: Disconnect
  Future<Result<void>> disconnect() async {
    _logger.info('Initiating printer disconnection');
    
    return await ZebraErrorBridge.executeAndHandle<void>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: 'disconnect',
          arguments: {},
          timeout: const Duration(seconds: 5),
        );
        if (controller.selectedAddress != null) {
          controller.updatePrinterStatus('Disconnected', 'R');
          _logger.info('Updated printer status to disconnected');
        }
        if (result.success) {
          _logger.info('Printer disconnected successfully');
          return;
        } else {
          _logger
              .error('Disconnect operation failed: ${result.error?.message}');
          throw Exception(result.error?.message ?? 'Disconnect failed');
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

    final result = await ZebraErrorBridge.executeAndHandle<void>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: 'print',
          arguments: {'Data': data},
          timeout: const Duration(seconds: 30),
        );
        if (result.success) {
          _logger.info('Print operation completed successfully');
          return;
        } else {
          _logger.error('Print operation failed: ${result.error?.message}');
          throw Exception(result.error?.message ?? 'Print operation failed');
        }
      },
      operationType: OperationType.print,
      printData: data,
    );

    if (result.success) {
      return Result.success(tracker);
    } else {
      // Stop tracking if the operation failed
      tracker.stopPrint();
      return Result.errorCode(
        ErrorCodes.printError,
        formatArgs: [result.error?.message ?? 'Print operation failed'],
      );
    }
  }

  // Primitive: Get printer status
  Future<Result<Map<String, dynamic>>> getPrinterStatus() async {
    _logger.info('Getting printer status');
    
    return await ZebraErrorBridge.executeAndHandle<Map<String, dynamic>>(
      operation: () async {
        final result = await _operationManager.execute<Map<String, dynamic>>(
          method: 'getPrinterStatus',
          arguments: {},
          timeout: const Duration(seconds: 5),
        );
        if (result.success && result.data != null) {
          _logger.info('Printer status retrieved successfully');
          return result.data!;
        } else {
          _logger
              .error('Failed to get printer status: ${result.error?.message}');
          throw Exception(result.error?.message ?? 'Status retrieval failed');
        }
      },
      operationType: OperationType.status,
      isDetailed: false,
    );
  }

  // Primitive: Get detailed printer status
  Future<Result<Map<String, dynamic>>> getDetailedPrinterStatus() async {
    _logger.info('Getting detailed printer status');
    
    return await ZebraErrorBridge.executeAndHandle<Map<String, dynamic>>(
      operation: () async {
        final result = await _operationManager.execute<Map<String, dynamic>>(
          method: 'getDetailedPrinterStatus',
          arguments: {},
          timeout: const Duration(seconds: 5),
        );
        if (result.success && result.data != null) {
          _logger.info('Detailed printer status retrieved successfully');
          return result.data!;
        } else {
          _logger.error(
              'Failed to get detailed printer status: ${result.error?.message}');
          throw Exception(
              result.error?.message ?? 'Detailed status retrieval failed');
        }
      },
      operationType: OperationType.status,
      isDetailed: true,
    );
  }

  // Primitive: Get setting
  Future<Result<String?>> getSetting(String setting) async {
    return await ZebraErrorBridge.executeAndHandle<String?>(
      operation: () async {
        final result = await _operationManager.execute<String>(
          method: 'getSetting',
          arguments: {'setting': setting},
          timeout: const Duration(seconds: 7),
        );
        if (result.success) {
          final data = result.data?.isNotEmpty == true ? result.data : null;
          return data;
        } else {
          throw Exception(result.error?.message ?? 'Setting retrieval failed');
        }
      },
      operationType: OperationType.command,
      command: 'getSetting($setting)',
    );
  }

  // Primitive: Rotate print orientation (for ZPL)
  void rotate() {
    isRotated = !isRotated;
  }

  // Primitive: Check if printer is connected
  Future<Result<bool>> isPrinterConnected() async {
    return await ZebraErrorBridge.executeAndHandle<bool>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: 'isPrinterConnected',
          arguments: {},
          timeout: const Duration(seconds: 7),
        );
        if (result.success) {
          return result.data ?? false;
        } else {
          throw Exception(result.error?.message ?? 'Connection check failed');
        }
      },
      operationType: OperationType.connection,
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
