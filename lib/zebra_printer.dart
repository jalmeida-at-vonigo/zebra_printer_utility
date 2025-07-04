import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/internal/operation_manager.dart';
import 'package:zebrautil/internal/operation_callback_handler.dart';
import 'package:zebrautil/internal/logger.dart';
import 'package:zebrautil/zebra_printer_readiness_manager.dart';
import 'package:zebrautil/models/readiness_result.dart';
import 'package:zebrautil/models/printer_readiness.dart';
import 'package:zebrautil/models/readiness_options.dart';

/// Printer language modes
enum PrinterMode { zpl, cpcl }

/// Simplified ZebraPrinter class - clean Dart layer for printer operations
/// Complex smart logic moved to ZebraPrinterSmart API
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
      final isWifi = call.arguments?['IsWifi'] == 'true';
      
      this.controller.addPrinter(ZebraDevice(
            address: address,
            name: name,
            status: status,
            isWifi: isWifi,
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

  // ===== DISCOVERY OPERATIONS =====

  void startScanning() async {
    _logger.info('Starting printer discovery process');
    isScanning = true;
    controller.cleanAll();
    
    try {
      _logger.info('Checking Bluetooth permissions');
      final isGrantPermissionResult = await _operationManager.execute<bool>(
        method: 'checkPermission',
        arguments: {},
        timeout: const Duration(seconds: 5),
      );
      final isGrantPermission = isGrantPermissionResult.success &&
          (isGrantPermissionResult.data ?? false);
      
      if (isGrantPermission) {
        _logger.info('Permission granted, starting printer scan');
        await _operationManager.execute<bool>(
          method: 'startScan',
          arguments: {},
          timeout: const Duration(seconds: 30),
        );
        _logger.info('Printer scan initiated successfully');
      } else {
        _logger.warning('Permission denied for Bluetooth access');
        isScanning = false;
        if (onPermissionDenied != null) onPermissionDenied!();
      }
    } catch (e) {
      _logger.error('Failed to start printer discovery', e);
      isScanning = false;
      if (onDiscoveryError != null) {
        onDiscoveryError!('SCAN_ERROR', e.toString());
      }
    }
  }

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

  // ===== CONNECTION OPERATIONS =====

  Future<Result<void>> connectToPrinter(String address) async {
    _logger.info('Initiating connection to printer: $address');
    try {
      if (controller.selectedAddress != null) {
        _logger.info(
            'Disconnecting from current printer before connecting to new one');
        await disconnect();
      }
      if (controller.selectedAddress == address) {
        _logger.info(
            'Already connected to target printer, disconnecting and reconnecting');
        await disconnect();
        controller.selectedAddress = null;
        return Result.success();
      }
      controller.selectedAddress = address;
      
      _logger.info('Attempting connection to printer: $address');
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
        return Result.error(
          'Failed to establish connection',
          code: ErrorCodes.connectionError,
        );
      }
    } on TimeoutException {
      _logger.error('Connection timeout to printer: $address');
      controller.selectedAddress = null;
      return Result.error(
        'Connection timed out',
        code: ErrorCodes.connectionTimeout,
      );
    } on PlatformException catch (e) {
      _logger.error(
          'Platform exception during connection to printer: $address', e);
      controller.selectedAddress = null;
      return Result.error(
        e.message ?? 'Connection failed',
        code: ErrorCodes.connectionError,
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
      _logger.error(
          'Unexpected error during connection to printer: $address', e, stack);
      controller.selectedAddress = null;
      return Result.error(
        'Connection error: $e',
        code: ErrorCodes.connectionError,
        dartStackTrace: stack,
      );
    }
  }

  Future<Result<void>> connectToGenericPrinter(String address) async {
    try {
      if (controller.selectedAddress != null) {
        await disconnect();
      }
      if (controller.selectedAddress == address) {
        await disconnect();
        controller.selectedAddress = null;
        return Result.success();
      }
      controller.selectedAddress = address;
      
      final result = await _operationManager.execute<bool>(
        method: 'connectToGenericPrinter',
        arguments: {'Address': address},
        timeout: const Duration(seconds: 10),
      );

      if (result.success && (result.data ?? false)) {
        final existingPrinter = controller.printers.firstWhere(
          (p) => p.address == address,
          orElse: () => ZebraDevice(
            address: address,
            name: 'Generic Printer $address',
            isWifi: true,
            status: 'Connected',
          ),
        );

        if (!controller.printers.any((p) => p.address == address)) {
          controller.addPrinter(existingPrinter);
        }
        
        controller.updatePrinterStatus("Connected", "G");
        return Result.success();
      } else {
        controller.selectedAddress = null;
        return Result.error(
          'Failed to establish generic connection',
          code: ErrorCodes.connectionError,
        );
      }
    } on TimeoutException {
      controller.selectedAddress = null;
      return Result.error(
        'Connection timed out',
        code: ErrorCodes.connectionTimeout,
      );
    } on PlatformException catch (e) {
      controller.selectedAddress = null;
      return Result.error(
        e.message ?? 'Generic connection failed',
        code: ErrorCodes.connectionError,
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
      controller.selectedAddress = null;
      return Result.error(
        'Generic connection error: $e',
        code: ErrorCodes.connectionError,
        dartStackTrace: stack,
      );
    }
  }

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
        return Result.error(
          'Disconnect failed',
          code: ErrorCodes.connectionError,
        );
      }
    } on TimeoutException {
      _logger.error('Disconnect operation timed out');
      return Result.error(
        'Disconnect timed out',
        code: ErrorCodes.connectionTimeout,
      );
    } on PlatformException catch (e) {
      _logger.error('Platform exception during disconnect', e);
      return Result.error(
        e.message ?? 'Disconnect failed',
        code: ErrorCodes.connectionError,
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
      _logger.error('Unexpected error during disconnect', e, stack);
      return Result.error(
        'Disconnect error: $e',
        code: ErrorCodes.connectionError,
        dartStackTrace: stack,
      );
    }
  }

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

  // ===== PRINT OPERATIONS =====

  Future<Result<void>> print({required String data}) async {
    _logger.info(
        'Starting print operation, data length: ${data.length} characters');
    try {
      if (data.isEmpty) {
        _logger.error('Print operation failed: Empty data provided');
        return Result.error(
          'Print data cannot be empty',
          code: ErrorCodes.invalidData,
        );
      }
      
      // Basic ZPL modifications (kept for compatibility)
      if (data.trim().startsWith("^XA")) {
        _logger.info('Detected ZPL format, applying basic modifications');
        if (!data.contains("^PON")) {
          data = data.replaceAll("^XA", "^XA^PON");
          _logger.info('Added print orientation normal (^PON) to ZPL');
        }

        if (isRotated) {
          data = data.replaceAll("^PON", "^POI");
          _logger.info('Applied rotation (^POI) to ZPL data');
        }
      } else if (data.trim().startsWith("!")) {
        _logger.info('Detected CPCL format, sending as-is');
      } else {
        _logger.info('Unknown format, sending data as-is');
      }

      _logger.info('Sending print data to printer');
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
        return Result.error(
          'Print failed',
          code: ErrorCodes.printError,
        );
      }
    } on TimeoutException {
      _logger.error('Print operation timed out after 30 seconds');
      return Result.error(
        'Print operation timed out',
        code: ErrorCodes.operationTimeout,
      );
    } on PlatformException catch (e) {
      _logger.error('Platform exception during print operation', e);
      return Result.error(
        e.message ?? 'Print failed',
        code: ErrorCodes.printError,
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
      _logger.error('Unexpected error during print operation', e, stack);
      return Result.error(
        'Print error: $e',
        code: ErrorCodes.printError,
        dartStackTrace: stack,
      );
    }
  }

  // ===== BASIC SETTINGS OPERATIONS =====

  void setDarkness(int darkness) {
    final command = '! U1 setvar "print.tone" "$darkness"';
    _sendSettingCommand(command);
  }

  void setMediaType(EnumMediaType mediaType) {
    String command = "";
    switch (mediaType) {
      case EnumMediaType.blackMark:
        command = '''
        ! U1 setvar "media.type" "label"
        ! U1 setvar "media.sense_mode" "bar"
        ''';
        break;
      case EnumMediaType.journal:
        command = '! U1 setvar "media.type" "journal"';
        break;
      case EnumMediaType.label:
        command = '''
        ! U1 setvar "media.type" "label"
        ! U1 setvar "media.sense_mode" "gap"
        ''';
        break;
    }
    _sendSettingCommand(command);
  }

  void calibratePrinter() {
    const command = '~jc^xa^jus^xz';
    _sendSettingCommand(command);
  }

  void sendCommand(String command) {
    try {
      _operationManager.execute<bool>(
        method: 'sendCommand',
        arguments: {'command': command},
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      if (onDiscoveryError != null) {
        onDiscoveryError!('COMMAND_ERROR', e.toString());
      }
    }
  }

  /// Set printer settings using SGD commands
  void setSettings(String command) {
    try {
      _operationManager.execute<bool>(
        method: 'setSettings',
        arguments: {'SettingCommand': command},
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      if (onDiscoveryError != null) {
        onDiscoveryError!('SETTINGS_ERROR', e.toString());
      }
    }
  }

  void _sendSettingCommand(String command) {
    try {
      _operationManager.execute<bool>(
        method: 'setSettings',
        arguments: {'SettingCommand': command},
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      if (onDiscoveryError != null) {
        onDiscoveryError!('SETTINGS_ERROR', e.toString());
      }
    }
  }

  // ===== STATUS AND QUERY OPERATIONS =====

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

  Future<String> _getLocateValue({required String key}) async {
    try {
      final result = await _operationManager.execute<String>(
        method: 'getLocateValue',
        arguments: {'ResourceKey': key},
        timeout: const Duration(seconds: 5),
      );
      return result.success ? (result.data ?? "") : "";
    } catch (e) {
      return "";
    }
  }

  // ===== UTILITY OPERATIONS =====

  void rotate() {
    isRotated = !isRotated;
  }

  void setOnDiscoveryError(Function(String, String?)? onDiscoveryError) {
    this.onDiscoveryError = onDiscoveryError;
  }

  void setOnPermissionDenied(Function() onPermissionDenied) {
    this.onPermissionDenied = onPermissionDenied;
  }

  // ===== INTERNAL METHODS =====

  Future<void> nativeMethodCallHandler(MethodCall methodCall) async {
    await _callbackHandler.handleMethodCall(methodCall);

    if (methodCall.method == "onDiscoveryDone") {
      if (shouldSync) {
        _getLocateValue(key: "connected").then((connectedString) {
          controller.synchronizePrinter(connectedString);
          shouldSync = false;
        });
      }
    }
  }

  void dispose() {
    _operationManager.dispose();
  }

  // ===== READINESS AND DIAGNOSTICS METHODS =====

  /// Prepare printer for printing with specified options
  Future<Result<ReadinessResult>> prepareForPrint({
    required PrintFormat format,
    ReadinessOptions? options,
  }) async {
    final readinessManager = PrinterReadinessManager(
      printer: this,
    );
    return await readinessManager.prepareForPrint(
        format, options ?? ReadinessOptions.quick());
  }

  /// Get detailed status of the printer
  Future<Result<PrinterReadiness>> getDetailedStatus() async {
    final readinessManager = PrinterReadinessManager(
      printer: this,
    );
    return await readinessManager.getDetailedStatus();
  }

  /// Validate if the printer state is ready
  Future<Result<bool>> validatePrinterState() async {
    final readinessManager = PrinterReadinessManager(
      printer: this,
    );
    return await readinessManager.validatePrinterState();
  }

  /// Run comprehensive diagnostics on the printer
  Future<Result<Map<String, dynamic>>> runDiagnostics() async {
    final readinessManager = PrinterReadinessManager(
      printer: this,
    );
    return await readinessManager.runDiagnostics();
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
