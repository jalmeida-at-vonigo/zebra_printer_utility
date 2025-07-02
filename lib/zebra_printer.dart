import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zebrautil/zebra_device.dart';
import 'package:zebrautil/result.dart';

enum EnumMediaType { Label, BlackMark, Journal }

enum Command { calibrate, mediaType, darkness }

enum PrintFormat { ZPL, CPCL }

class ZebraPrinter {
  late MethodChannel channel;

  Function(String, String?)? onDiscoveryError;
  Function? onPermissionDenied;
  bool isRotated = false;
  bool isScanning = false;
  bool shouldSync = false;
  late ZebraController controller;

  ZebraPrinter(String id,
      {this.onDiscoveryError,
      this.onPermissionDenied,
      ZebraController? controller}) {
    channel = MethodChannel('ZebraPrinterObject' + id);
    channel.setMethodCallHandler(nativeMethodCallHandler);
    this.controller = controller ?? ZebraController();
  }

  void startScanning() {
    isScanning = true;
    controller.cleanAll();
    channel.invokeMethod("checkPermission").then((isGrantPermission) {
      if (isGrantPermission) {
        channel.invokeMethod("startScan");
      } else {
        isScanning = false;
        if (onPermissionDenied != null) onPermissionDenied!();
      }
    });
  }

  void stopScanning() {
    isScanning = false;
    shouldSync = true;
    channel.invokeMethod("stopScan");
  }

  void _setSettings(Command setting, dynamic values) {
    String command = "";
    switch (setting) {
      case Command.mediaType:
        if (values == EnumMediaType.BlackMark) {
          command = '''
          ! U1 setvar "media.type" "label"
          ! U1 setvar "media.sense_mode" "bar"
          ''';
        } else if (values == EnumMediaType.Journal) {
          command = '''
          ! U1 setvar "media.type" "journal"
          ''';
        } else if (values == EnumMediaType.Label) {
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
        command = '''! U1 setvar "print.tone" "$values"''';
        break;
    }

    if (setting == Command.calibrate) {
      command = '''~jc^xa^jus^xz''';
    }

    try {
      channel.invokeMethod("setSettings", {"SettingCommand": command});
    } on PlatformException catch (e) {
      if (onDiscoveryError != null) onDiscoveryError!(e.code, e.message);
    }
  }

  void setOnDiscoveryError(Function(String, String?)? onDiscoveryError) {
    this.onDiscoveryError = onDiscoveryError;
  }

  void setOnPermissionDenied(Function(String, String) onPermissionDenied) {
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
      channel.invokeMethod("setSettings", {"SettingCommand": command});
    } on PlatformException catch (e) {
      if (onDiscoveryError != null) onDiscoveryError!(e.code, e.message);
    }
  }

  Future<Result<void>> connectToPrinter(String address) async {
    try {
      if (controller.selectedAddress != null) {
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      if (controller.selectedAddress == address) {
        await disconnect();
        controller.selectedAddress = null;
        return Result.success();
      }
      controller.selectedAddress = address;
      await channel.invokeMethod("connectToPrinter", {"Address": address});

      // Check connection status after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      final isConnected = await isPrinterConnected();
      if (isConnected) {
        controller.updatePrinterStatus("Connected", "G");
        return Result.success();
      } else {
        controller.selectedAddress = null;
        return Result.error(
          'Failed to establish connection',
          code: ErrorCodes.connectionError,
        );
      }
    } on PlatformException catch (e) {
      controller.selectedAddress = null;
      return Result.error(
        e.message ?? 'Connection failed',
        code: ErrorCodes.connectionError,
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
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
        await Future.delayed(const Duration(milliseconds: 300));
      }
      if (controller.selectedAddress == address) {
        await disconnect();
        controller.selectedAddress = null;
        return Result.success();
      }
      controller.selectedAddress = address;
      await channel
          .invokeMethod("connectToGenericPrinter", {"Address": address});

      // Check connection status after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      final isConnected = await isPrinterConnected();
      if (isConnected) {
        controller.updatePrinterStatus("Connected", "G");
        return Result.success();
      } else {
        controller.selectedAddress = null;
        return Result.error(
          'Failed to establish generic connection',
          code: ErrorCodes.connectionError,
        );
      }
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
        if (!data.contains("^PON")) data = data.replaceAll("^XA", "^XA^PON");

        if (isRotated) {
          data = data.replaceAll("^PON", "^POI");
        }
      }
      // For CPCL (starts with "!") or other formats, send as-is

      await channel.invokeMethod("print", {"Data": data});
      return Result.success();
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
    try {
      await channel.invokeMethod("disconnect", null);
      if (controller.selectedAddress != null) {
        controller.updatePrinterStatus("Disconnected", "R");
      }
      return Result.success();
    } on PlatformException catch (e) {
      return Result.error(
        e.message ?? 'Disconnect failed',
        code: ErrorCodes.connectionError,
        errorNumber: int.tryParse(e.code),
        nativeError: e,
      );
    } catch (e, stack) {
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
    final result = await channel.invokeMethod<bool>("isPrinterConnected");
    return result ?? false;
  }

  void rotate() {
    this.isRotated = !this.isRotated;
  }

  Future<String> _getLocateValue({required String key}) async {
    final String? value = await channel
        .invokeMethod<String?>("getLocateValue", {"ResourceKey": key});
    return value ?? "";
  }

  Future<void> nativeMethodCallHandler(MethodCall methodCall) async {
    if (methodCall.method == "printerFound") {
      final newPrinter = ZebraDevice(
        address: methodCall.arguments["Address"],
        status: methodCall.arguments["Status"],
        name: methodCall.arguments["Name"],
        isWifi: methodCall.arguments["IsWifi"] == "true",
      );
      controller.addPrinter(newPrinter);
    } else if (methodCall.method == "printerRemoved") {
      final String address = methodCall.arguments["Address"];
      controller.removePrinter(address);
    } else if (methodCall.method == "changePrinterStatus") {
      final String status = methodCall.arguments["Status"];
      final String color = methodCall.arguments["Color"];
      controller.updatePrinterStatus(status, color);
    } else if (methodCall.method == "onDiscoveryError" &&
        onDiscoveryError != null) {
      onDiscoveryError!(
          methodCall.arguments["ErrorCode"], methodCall.arguments["ErrorText"]);
    } else if (methodCall.method == "onDiscoveryDone") {
      if (shouldSync) {
        _getLocateValue(key: "connected").then((connectedString) {
          controller.synchronizePrinter(connectedString);
          shouldSync = false;
        });
      }
    }
  }
}

/// Notifier for printers, contains list of printers and methods to add, remove and update printers
class ZebraController extends ChangeNotifier {
  List<ZebraDevice> _printers = [];
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
      _printers[index] = _printers[index].copyWith(
          status: status,
          color: newColor,
          isConnected: color == 'G');
      notifyListeners();
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
