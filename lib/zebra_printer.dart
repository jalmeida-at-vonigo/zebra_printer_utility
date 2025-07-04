import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/models/readiness_options.dart';
import 'package:zebrautil/models/readiness_result.dart';
import 'package:zebrautil/models/printer_readiness.dart';
import 'package:zebrautil/internal/operation_manager.dart';
import 'package:zebrautil/internal/operation_callback_handler.dart';
import 'package:zebrautil/internal/state_change_verifier.dart';
import 'package:zebrautil/internal/logger.dart';
import 'zebra_sgd_commands.dart';
import 'zebra_printer_readiness_manager.dart';

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
  late final PrinterReadinessManager _readinessManager;

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
    
    // Initialize the readiness manager
    _readinessManager = PrinterReadinessManager(
      printer: this,
      statusCallback: (msg) => _logger.debug('Readiness: $msg'),
    );
  }

  void startScanning() async {
    _logger.info('Starting printer discovery process');
    isScanning = true;
    controller.cleanAll();
    
    try {
      _logger.info('Checking Bluetooth permissions');
      // Check permission using operation manager
      final isGrantPermissionResult = await _operationManager.execute<bool>(
        method: 'checkPermission',
        arguments: {},
        timeout: const Duration(seconds: 5),
      );
      final isGrantPermission = isGrantPermissionResult.success &&
          (isGrantPermissionResult.data ?? false);
      
      if (isGrantPermission) {
        _logger.info('Permission granted, starting printer scan');
        // Start scan using operation manager
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
      // Log error but don't fail
      _logger.error('Error stopping scan', e);
    }
  }

  void _setSettings(Command setting, dynamic values) {
    String command = "";
    switch (setting) {
      case Command.mediaType:
        if (values == EnumMediaType.blackMark) {
          command = '''
          ! U1 setvar "media.type" "label"
          ! U1 setvar "media.sense_mode" "bar"
          ''';
        } else if (values == EnumMediaType.journal) {
          command = '''
          ! U1 setvar "media.type" "journal"
          ''';
        } else if (values == EnumMediaType.label) {
          command = '''
          ! U1 setvar "media.type" "label"
           ! U1 setvar "media.sense_mode" "gap"
          ''';
        }

        break;
      case Command.calibrate:
        command = '''~jc^xa^jus^xz''';
        break;
      case Command.darkness:
        command = '! U1 setvar "print.tone" "$values"';
        break;
    }

    if (setting == Command.calibrate) {
      command = '''~jc^xa^jus^xz''';
    }

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

  void setOnDiscoveryError(Function(String, String?)? onDiscoveryError) {
    this.onDiscoveryError = onDiscoveryError;
  }

  void setOnPermissionDenied(Function() onPermissionDenied) {
    this.onPermissionDenied = onPermissionDenied;
  }

  void setDarkness(int darkness) {
    _setSettings(Command.darkness, darkness.toString());
  }

  void setMediaType(EnumMediaType mediaType) {
    _setSettings(Command.mediaType, mediaType);
  }

  void sendCommand(String command) {
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
      // Use operation manager for tracked connection
      final result = await _operationManager.execute<bool>(
        method: 'connectToPrinter',
        arguments: {'Address': address},
        timeout: const Duration(seconds: 10),
      );

      if (result.success && (result.data ?? false)) {
        _logger.info('Successfully connected to printer: $address');
        // Ensure the printer is in the list before updating status
        final existingPrinter = controller.printers.firstWhere(
          (p) => p.address == address,
          orElse: () => ZebraDevice(
            address: address,
            name: 'Printer $address',
            isWifi: !address.contains(':'), // Assume WiFi if no colons
            status: 'Connected',
          ),
        );

        // Add to list if not already there
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
      
      // Use operation manager for tracked connection
      final result = await _operationManager.execute<bool>(
        method: 'connectToGenericPrinter',
        arguments: {'Address': address},
        timeout: const Duration(seconds: 10),
      );

      if (result.success && (result.data ?? false)) {
        // Ensure the printer is in the list before updating status
        final existingPrinter = controller.printers.firstWhere(
          (p) => p.address == address,
          orElse: () => ZebraDevice(
            address: address,
            name: 'Generic Printer $address',
            isWifi: true, // Generic printers are typically network printers
            status: 'Connected',
          ),
        );

        // Add to list if not already there
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

  Future<Result<void>> print({required String data}) async {
    _logger.info(
        'Starting print operation, data length: ${data.length} characters');
    try {
      // Validate input
      if (data.isEmpty) {
        _logger.error('Print operation failed: Empty data provided');
        return Result.error(
          'Print data cannot be empty',
          code: ErrorCodes.invalidData,
        );
      }
      
      // Only modify ZPL data, not CPCL
      if (data.trim().startsWith("^XA")) {
        _logger.info('Detected ZPL format, applying modifications');
        // This is ZPL - apply modifications
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
      // Use operation manager for tracked printing
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

  /// Print with completion callback using operation manager
  Future<Result<void>> printWithCallback({
    required String data,
    String? operationId,
  }) async {
    try {
      // Validate input
      if (data.isEmpty) {
        return Result.error(
          'Print data cannot be empty',
          code: ErrorCodes.invalidData,
        );
      }

      // Only modify ZPL data, not CPCL
      if (data.trim().startsWith("^XA")) {
        // This is ZPL - apply modifications
        if (!data.contains("^PON")) {
          data = data.replaceAll("^XA", "^XA^PON");
        }

        if (isRotated) {
          data = data.replaceAll("^PON", "^POI");
        }
      }
      // For CPCL (starts with "!") or other formats, send as-is

      // Use operation manager for tracked execution
      final result = await _operationManager.execute<bool>(
        method: 'print',
        arguments: {'Data': data},
        timeout: const Duration(seconds: 30),
      );

      return result.success
          ? Result.success()
          : Result.error(
              'Print operation failed',
              code: ErrorCodes.printError,
            );
    } on TimeoutException {
      return Result.error(
        'Print operation timed out',
        code: ErrorCodes.operationTimeout,
      );
    } on PlatformException catch (e) {
      return Result.error(
        e.message ?? 'Print failed',
        code: ErrorCodes.printError,
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
      return Result.error(
        'Print error: $e',
        code: ErrorCodes.printError,
        dartStackTrace: stack,
      );
    }
  }

  Future<Result<void>> disconnect() async {
    _logger.info('Initiating printer disconnection');
    try {
      // Use operation manager for tracked disconnection
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

  void calibratePrinter() {
    _setSettings(Command.calibrate, null);
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

  void rotate() {
    isRotated = !isRotated;
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

  /// Get a printer setting value using SGD commands
  /// Returns null if the setting cannot be retrieved
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

  Future<void> nativeMethodCallHandler(MethodCall methodCall) async {
    // First try to handle through the callback handler
    await _callbackHandler.handleMethodCall(methodCall);

    // Handle special cases that need additional processing
    if (methodCall.method == "onDiscoveryDone") {
      if (shouldSync) {
        _getLocateValue(key: "connected").then((connectedString) {
          controller.synchronizePrinter(connectedString);
          shouldSync = false;
        });
      }
    }
  }

  /// Switch printer mode with verification
  /// This is an example of using StateChangeVerifier for operations without callbacks
  Future<Result<void>> setPrinterMode(PrinterMode mode) async {
    final verifier = StateChangeVerifier(
      printer: this,
      logCallback: (msg) => _logger.info(msg),
    );

    final command = mode == PrinterMode.zpl
        ? ZebraSGDCommands.setZPLMode()
        : ZebraSGDCommands.setCPCLMode();

    final desiredValue = mode == PrinterMode.zpl ? 'zpl' : 'line_print';

    final result = await verifier.setStringState(
      operationName: 'Set printer mode to ${mode.name}',
      command: command,
      getSetting: () => getSetting('device.languages'),
      validator: (value) =>
          value?.toLowerCase().contains(desiredValue) ?? false,
      checkDelay: const Duration(milliseconds: 300),
      maxAttempts: 3,
    );

    return result.success
        ? Result.success()
        : Result.error(result.error?.message ?? 'Failed to set printer mode');
  }

  // New Readiness API - replaces all old readiness methods

  /// Prepare printer for printing with specified options
  Future<Result<ReadinessResult>> prepareForPrint({
    ReadinessOptions? options,
  }) async {
    final opts = options ?? ReadinessOptions.forPrinting();
    return await _readinessManager.prepareForPrint(opts);
  }

  /// Run comprehensive diagnostics on the printer
  Future<Result<Map<String, dynamic>>> runDiagnostics() async {
    return await _readinessManager.runDiagnostics();
  }

  /// Get detailed status of the printer
  Future<Result<PrinterReadiness>> getDetailedStatus() async {
    return await _readinessManager.getDetailedStatus();
  }

  /// Validate if the printer state is ready
  Future<Result<bool>> validatePrinterState() async {
    return await _readinessManager.validatePrinterState();
  }

  /// Dispose the printer instance and clean up resources
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
