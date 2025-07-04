import 'dart:async';
import 'package:flutter/services.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/models/readiness_result.dart';
import 'package:zebrautil/models/printer_readiness.dart';
import 'package:zebrautil/models/readiness_options.dart';
import 'package:zebrautil/zebra_printer.dart';

class MockZebraPrinter extends ZebraPrinter {
  bool _isConnected = false;
  final String _address;
  bool _shouldFail = false;
  String _failureReason = 'Mock failure';
  bool _isRotated = false;
  bool _isScanning = false;
  bool _shouldSync = false;

  MockZebraPrinter(this._address) : super(_address);

  void setShouldFail(bool shouldFail, [String reason = 'Mock failure']) {
    _shouldFail = shouldFail;
    _failureReason = reason;
  }

  void setConnected(bool connected) {
    _isConnected = connected;
  }

  String get address => _address;

  @override
  bool get isRotated => _isRotated;

  @override
  bool get isScanning => _isScanning;

  @override
  bool get shouldSync => _shouldSync;

  @override
  void startScanning() async {
    if (_shouldFail) {
      if (onDiscoveryError != null) {
        onDiscoveryError!('SCAN_ERROR', _failureReason);
      }
      return;
    }
    _isScanning = true;
    controller.cleanAll();
  }

  @override
  void stopScanning() async {
    _isScanning = false;
    _shouldSync = true;
  }

  @override
  Future<Result<void>> connectToPrinter(String address) async {
    if (_shouldFail) {
      return Result.error(_failureReason, code: ErrorCodes.connectionError);
    }
    _isConnected = true;
    controller.selectedAddress = address;
    return Result.success();
  }

  @override
  Future<Result<void>> connectToGenericPrinter(String address) async {
    if (_shouldFail) {
      return Result.error(_failureReason, code: ErrorCodes.connectionError);
    }
    _isConnected = true;
    controller.selectedAddress = address;
    return Result.success();
  }

  @override
  Future<Result<void>> disconnect() async {
    if (_shouldFail) {
      return Result.error(_failureReason, code: ErrorCodes.connectionError);
    }
    _isConnected = false;
    controller.selectedAddress = null;
    return Result.success();
  }

  @override
  Future<bool> isPrinterConnected() async {
    return _isConnected && !_shouldFail;
  }

  @override
  Future<Result<void>> print({required String data}) async {
    if (_shouldFail) {
      return Result.error(_failureReason, code: ErrorCodes.printError);
    }
    return Result.success();
  }

  @override
  void setDarkness(int darkness) {
    // Mock implementation
  }

  @override
  void setMediaType(EnumMediaType mediaType) {
    // Mock implementation
  }

  @override
  void calibratePrinter() {
    // Mock implementation
  }

  @override
  void sendCommand(String command) {
    if (_shouldFail) {
      if (onDiscoveryError != null) {
        onDiscoveryError!('COMMAND_ERROR', _failureReason);
      }
    }
  }

  @override
  void setSettings(String command) {
    if (_shouldFail) {
      if (onDiscoveryError != null) {
        onDiscoveryError!('SETTINGS_ERROR', _failureReason);
      }
    }
  }

  @override
  Future<String?> getSetting(String setting) async {
    if (_shouldFail) {
      return null;
    }
    return 'mock_value';
  }

  @override
  void rotate() {
    _isRotated = !_isRotated;
  }

  @override
  void setOnDiscoveryError(Function(String, String?)? onDiscoveryError) {
    this.onDiscoveryError = onDiscoveryError;
  }

  @override
  void setOnPermissionDenied(Function() onPermissionDenied) {
    this.onPermissionDenied = onPermissionDenied;
  }

  @override
  Future<void> nativeMethodCallHandler(MethodCall methodCall) async {
    // Mock implementation
  }

  @override
  void dispose() {
    // Mock implementation
  }

  @override
  Future<Result<ReadinessResult>> prepareForPrint({
    required PrintFormat format,
    ReadinessOptions? options,
  }) async {
    if (_shouldFail) {
      return Result.error(_failureReason, code: ErrorCodes.operationError);
    }
    final readiness = PrinterReadiness()
      ..isConnected = _isConnected
      ..hasMedia = true
      ..headClosed = true
      ..isPaused = false
      ..fullCheckPerformed = true;

    return Result.success(ReadinessResult(
      isReady: true,
      readiness: readiness,
      appliedFixes: [],
      failedFixes: [],
      fixErrors: {},
      totalTime: Duration.zero,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<Result<PrinterReadiness>> getDetailedStatus() async {
    if (_shouldFail) {
      return Result.error(_failureReason, code: ErrorCodes.operationError);
    }
    final readiness = PrinterReadiness()
      ..isConnected = _isConnected
      ..hasMedia = true
      ..headClosed = true
      ..isPaused = false
      ..fullCheckPerformed = true;

    return Result.success(readiness);
  }

  @override
  Future<Result<bool>> validatePrinterState() async {
    if (_shouldFail) {
      return Result.error(_failureReason, code: ErrorCodes.operationError);
    }
    return Result.success(_isConnected);
  }

  @override
  Future<Result<Map<String, dynamic>>> runDiagnostics() async {
    if (_shouldFail) {
      return Result.error(_failureReason, code: ErrorCodes.operationError);
    }
    return Result.success({
      'connection': _isConnected,
      'status': 'healthy',
      'mock': true,
    });
  }
} 