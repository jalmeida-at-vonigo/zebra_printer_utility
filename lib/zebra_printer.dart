import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/internal/operation_manager.dart';
import 'package:zebrautil/internal/operation_callback_handler.dart';
import 'package:zebrautil/internal/logger.dart';
import 'internal/commands/command_factory.dart';
import 'internal/permission_manager.dart';

/// Printer language modes
enum PrinterMode { zpl, cpcl }

class ZebraPrinter {
  final String instanceId;
  final ZebraController controller;
  bool isRotated = false;
  bool isScanning = false;
  bool shouldSync = false;

  Function(String, String?)? onDiscoveryError;
  Function()? onPermissionDenied;

  late final MethodChannel channel;
  late final OperationManager _operationManager;
  late final OperationCallbackHandler _callbackHandler;
  final Logger _logger;

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
      final brand = call.arguments?['brand'];
      final model = call.arguments?['model'];
      final displayName = call.arguments?['displayName'];
      final manufacturer = call.arguments?['manufacturer'];
      final firmwareRevision = call.arguments?['firmwareRevision'];
      final hardwareRevision = call.arguments?['hardwareRevision'];
      final connectionType = call.arguments?['connectionType'];
      final isBluetooth = call.arguments?['isBluetooth'] == true ||
          call.arguments?['isBluetooth'] == 'true';
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
        onDiscoveryError!('DISCOVERY_ERROR', errorText);
      }
    });
    _callbackHandler.registerEventHandler('onPrinterDiscoveryDone', (call) {
      isScanning = false;
    });
  }

  // Primitive: Start scanning
  void startScanning() async {
    _logger.info('Starting printer discovery process');
    isScanning = true;
    controller.cleanAll();
    try {
      final hasPermission = await PermissionManager.checkBluetoothPermission();
      if (!hasPermission) {
        _logger.warning('Bluetooth permission permanently denied');
        if (onPermissionDenied != null) {
          onPermissionDenied!();
        }
      }
      await _operationManager.execute<bool>(
        method: 'startScan',
        arguments: {},
        timeout: const Duration(seconds: 30),
      );
      _logger.info('Printer scan initiated successfully');
    } catch (e) {
      _logger.error('Failed to start printer discovery', e);
      isScanning = false;
      if (onDiscoveryError != null) {
        onDiscoveryError!('SCAN_ERROR', e.toString());
      }
    }
  }

  // Primitive: Stop scanning
  void stopScanning() async {
    _logger.info('Stopping printer discovery process');
    isScanning = false;
    shouldSync = true;
    try {
      await _operationManager.execute<bool>(
        method: 'stopScan',
        arguments: {},
        timeout: const Duration(seconds: 5),
      );
      _logger.info('Printer discovery stopped successfully');
    } catch (e) {
      _logger.error('Error stopping scan', e);
    }
  }

  // Primitive: Connect to printer
  Future<Result<void>> connectToPrinter(String address) async {
    _logger.info('Initiating connection to printer: $address');
    try {
      if (controller.selectedAddress != null) {
        await disconnect();
      }
      controller.selectedAddress = address;
      final result = await _operationManager.execute<bool>(
        method: 'connectToPrinter',
        arguments: {'Address': address},
        timeout: const Duration(seconds: 10),
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
        controller.updatePrinterStatus("Connected", "G");
        return Result.success();
      } else {
        _logger.error('Failed to establish connection to printer: $address');
        controller.selectedAddress = null;
        return Result.errorCode(
          ErrorCodes.connectionError,
        );
      }
    } on TimeoutException {
      _logger.error('Connection timeout to printer: $address');
      controller.selectedAddress = null;
      return Result.errorCode(
        ErrorCodes.connectionTimeout,
      );
    } on PlatformException catch (e) {
      _logger.error(
          'Platform exception during connection to printer: $address', e);
      controller.selectedAddress = null;
      return Result.errorCode(
        ErrorCodes.connectionError,
        formatArgs: [e.message ?? 'Connection failed'],
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
      _logger.error(
          'Unexpected error during connection to printer: $address', e, stack);
      controller.selectedAddress = null;
      return Result.errorCode(
        ErrorCodes.connectionError,
        formatArgs: ['Connection error: $e'],
        dartStackTrace: stack,
      );
    }
  }

  // Primitive: Disconnect
  Future<Result<void>> disconnect() async {
    _logger.info('Initiating printer disconnection');
    try {
      final result = await _operationManager.execute<bool>(
        method: 'disconnect',
        arguments: {},
        timeout: const Duration(seconds: 5),
      );
      if (controller.selectedAddress != null) {
        controller.updatePrinterStatus("Disconnected", "R");
        _logger.info('Updated printer status to disconnected');
      }
      if (result.success) {
        _logger.info('Printer disconnected successfully');
        return Result.success();
      } else {
        _logger.error('Disconnect operation failed: ${result.error?.message}');
        return Result.errorCode(
          ErrorCodes.connectionError,
        );
      }
    } on TimeoutException {
      _logger.error('Disconnect operation timed out');
      return Result.errorCode(
        ErrorCodes.connectionTimeout,
      );
    } on PlatformException catch (e) {
      _logger.error('Platform exception during disconnect', e);
      return Result.errorCode(
        ErrorCodes.connectionError,
        formatArgs: [e.message ?? 'Disconnect failed'],
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
      _logger.error('Unexpected error during disconnect', e, stack);
      return Result.errorCode(
        ErrorCodes.connectionError,
        formatArgs: ['Disconnect error: $e'],
        dartStackTrace: stack,
      );
    }
  }

  // Primitive: Print (send data)
  Future<Result<void>> print({required String data}) async {
    _logger.info('Sending print data to printer');
    try {
      final result = await _operationManager.execute<bool>(
        method: 'print',
        arguments: {'Data': data},
        timeout: const Duration(seconds: 30),
      );
      if (result.success) {
        _logger.info('Print operation completed successfully');
        return Result.success();
      } else {
        _logger.error('Print operation failed: ${result.error?.message}');
        return Result.errorCode(
          ErrorCodes.printError,
        );
      }
    } on TimeoutException {
      _logger.error('Print operation timed out after 30 seconds');
      return Result.errorCode(
        ErrorCodes.operationTimeout,
      );
    } on PlatformException catch (e) {
      _logger.error('Platform exception during print operation', e);
      return Result.errorCode(
        ErrorCodes.printError,
        formatArgs: [e.message ?? 'Print failed'],
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
      _logger.error('Unexpected error during print operation', e, stack);
      return Result.errorCode(
        ErrorCodes.printError,
        formatArgs: ['Print error: $e'],
        dartStackTrace: stack,
      );
    }
  }

  // Primitive: Get printer status
  Future<Result<Map<String, dynamic>>> getPrinterStatus() async {
    try {
      final statusCommand = CommandFactory.createGetPrinterStatusCommand(this);
      return await statusCommand.execute();
    } catch (e) {
      return Result.error('Failed to get printer status: $e');
    }
  }

  // Primitive: Get setting
  Future<String?> getSetting(String setting) async {
    try {
      final result = await _operationManager.execute<String>(
        method: 'getSetting',
        arguments: {'setting': setting},
        timeout: const Duration(seconds: 5),
      );
      return result.success && (result.data?.isNotEmpty ?? false)
          ? result.data
          : null;
    } catch (e) {
      return null;
    }
  }

  // Primitive: Set setting
  void setSetting(String setting, String value) {
    try {
      _operationManager.execute<bool>(
        method: 'setSettings',
        arguments: {'SettingCommand': '! U1 setvar "$setting" "$value"'},
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      if (onDiscoveryError != null) {
        onDiscoveryError!('SETTINGS_ERROR', e.toString());
      }
    }
  }

  // Primitive: Rotate print orientation (for ZPL)
  void rotate() {
    isRotated = !isRotated;
  }

  // Primitive: Check if printer is connected
  Future<bool> isPrinterConnected() async {
    try {
      final result = await _operationManager.execute<bool>(
        method: 'isPrinterConnected',
        arguments: {},
        timeout: const Duration(seconds: 5),
      );
      return result.success && (result.data ?? false);
    } catch (e) {
      return false;
    }
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
}
