import 'dart:async';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/zebra_device.dart';
import 'package:zebrautil/models/readiness_options.dart';
import 'package:zebrautil/zebra_printer_service.dart';
import 'package:zebrautil/zebra_printer_discovery.dart';

import 'package:zebrautil/internal/logger.dart';
import 'package:zebrautil/smart/zebra_printer_smart.dart';
import 'package:zebrautil/smart/options/smart_print_options.dart';
import 'package:zebrautil/smart/options/smart_batch_options.dart';
import 'package:zebrautil/smart/options/discovery_options.dart';
import 'package:zebrautil/smart/options/connect_options.dart';
import 'package:zebrautil/smart/models/zebra_printer_smart_status.dart';

/// Main entry point for Zebra printer operations
///
/// This class provides a unified API for all Zebra printer operations,
/// including the new ZSDK-optimized Smart API for high-performance printing.
class Zebra {
  static ZebraPrinterService? _service;
  static ZebraPrinterDiscovery? _discovery;
  static final Logger _logger = Logger.withPrefix('Zebra');

  // Smart API instance
  static ZebraPrinterSmart? _smartInstance;

  /// Get the smart API instance for advanced operations
  static ZebraPrinterSmart get smart {
    _smartInstance ??= ZebraPrinterSmart.instance;
    return _smartInstance!;
  }

  /// Smart print - ZSDK-optimized printing with "Just Works" philosophy
  ///
  /// This method provides high-performance printing by leveraging ZSDK's built-in optimizations:
  /// - Automatic connection management with ZSDK connection pooling
  /// - Format detection using ZSDK's ZebraPrinterFactory
  /// - iOS 13+ permission handling with MFi compliance
  /// - Comprehensive error handling and retry logic
  /// - Performance monitoring and self-healing
  ///
  /// Example usage:
  /// ```dart
  /// // Simple usage - everything automatic
  /// await Zebra.smartPrint('^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ');
  ///
  /// // With specific printer
  /// await Zebra.smartPrint(
  ///   '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  ///   address: '192.168.1.100',
  /// );
  ///
  /// // With options for granular control
  /// await Zebra.smartPrint(
  ///   '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  ///   options: SmartPrintOptions.fast(),
  /// );
  /// ```
  static Future<Result<void>> smartPrint(
    String data, {
    String? address,
    PrintFormat? format,
    SmartPrintOptions? options,
  }) async {
    _logger.info('Starting ZSDK-optimized smart print');
    return await smart.print(data,
        address: address, format: format, options: options);
  }

  /// Smart batch print - optimized for multiple labels
  ///
  /// This method provides high-performance batch printing with ZSDK optimization:
  /// - Single connection for entire batch
  /// - Parallel processing for network printers
  /// - Sequential processing for reliability
  /// - Comprehensive error handling
  ///
  /// Example usage:
  /// ```dart
  /// final labels = [
  ///   '^XA^FO50,50^A0N,50,50^FDLabel 1^FS^XZ',
  ///   '^XA^FO50,50^A0N,50,50^FDLabel 2^FS^XZ',
  ///   '^XA^FO50,50^A0N,50,50^FDLabel 3^FS^XZ',
  /// ];
  /// await Zebra.smartPrintBatch(labels);
  /// ```
  static Future<Result<void>> smartPrintBatch(
    List<String> data, {
    String? address,
    PrintFormat? format,
    SmartBatchOptions? options,
  }) async {
    _logger.info(
        'Starting ZSDK-optimized smart batch print with ${data.length} items');
    return await smart.printBatch(data,
        address: address, format: format, options: options);
  }

  /// Get smart API status with comprehensive metrics
  ///
  /// Returns detailed status information including:
  /// - Connection health
  /// - Cache hit rate
  /// - Performance metrics
  /// - Failure rates
  /// - Last operation details
  static Future<ZebraPrinterSmartStatus> getSmartStatus() async {
    return await smart.getStatus();
  }

  /// Discover printers using ZSDK discovery
  ///
  /// This method uses ZSDK's optimized discovery mechanisms:
  /// - Network discovery with UDP multicast
  /// - Bluetooth discovery with MFi compliance
  /// - USB discovery for connected devices
  /// - Cached results for improved performance
  static Future<Result<List<ZebraDevice>>> smartDiscover(
      {DiscoveryOptions? options}) async {
    _logger.info('Starting ZSDK printer discovery');
    return await smart.discover(options: options);
  }

  /// Connect to printer using ZSDK with connection pooling
  static Future<Result<void>> smartConnect(String address,
      {ConnectOptions? options}) async {
    _logger.info('Connecting to printer using ZSDK: $address');
    return await smart.connect(address, options: options);
  }

  /// Disconnect from current printer
  static Future<Result<void>> smartDisconnect() async {
    _logger.info('Disconnecting from printer');
    return await smart.disconnect();
  }

  // ===== LEGACY API (Maintained for backward compatibility) =====

  /// Initialize the Zebra printer service
  ///
  /// This method initializes the legacy printer service for backward compatibility.
  /// For new applications, consider using the Smart API methods above.
  static Future<void> initialize({
    Function(String code, String? message)? onDiscoveryError,
    Function()? onPermissionDenied,
  }) async {
    _logger.info('Initializing Zebra printer service (legacy)');
    
    if (_service == null) {
      _service = ZebraPrinterService();
      await _service!.initialize(
        onDiscoveryError: onDiscoveryError,
        onPermissionDenied: onPermissionDenied,
      );
    }
  }

  /// Ensure the service is initialized
  static Future<void> _ensureInitialized() async {
    if (_service == null) {
      await initialize();
    }
  }

  /// Print data using the legacy API
  ///
  /// This method uses the legacy printing workflow. For better performance,
  /// consider using `smartPrint()` instead.
  static Future<Result<void>> print(String data,
      {PrintFormat? format,
      bool clearBufferFirst = false,
      ReadinessOptions? readinessOptions}) async {
    await _ensureInitialized();
    return await _service!.print(data,
        format: format,
        clearBufferFirst: clearBufferFirst,
        readinessOptions: readinessOptions);
  }

  /// Auto-print workflow using the legacy API
  ///
  /// This method uses the legacy auto-print workflow. For better performance,
  /// consider using `smartPrint()` instead.
  static Future<Result<void>> autoPrint(String data,
      {ZebraDevice? printer,
      String? address,
      PrintFormat? format,
      int maxRetries = 3,
      bool verifyConnection = true,
      bool disconnectAfter = true,
      ReadinessOptions? readinessOptions,
      Duration? printCompletionDelay}) async {
    await _ensureInitialized();
    
    // Use provided readinessOptions or default to comprehensive
    final effectiveOptions =
        readinessOptions ?? ReadinessOptions.comprehensive();
    
    return await _service!.autoPrint(data,
        printer: printer,
        address: address,
        format: format,
        maxRetries: maxRetries,
        verifyConnection: verifyConnection,
        disconnectAfter: disconnectAfter,
        readinessOptions: effectiveOptions,
        printCompletionDelay: printCompletionDelay);
  }

  /// Get available printers using legacy discovery
  ///
  /// This method uses the legacy discovery mechanism. For better performance,
  /// consider using `smartDiscover()` instead.
  static Future<List<ZebraDevice>> getAvailablePrinters() async {
    await _ensureInitialized();
    return await _service!.getAvailablePrinters();
  }

  /// Calibrate the connected printer
  ///
  /// This will perform media calibration on the printer.
  static Future<Result<void>> calibrate() async {
    await _ensureInitialized();
    return await _service!.calibrate();
  }

  /// Set printer darkness/density
  ///
  /// [darkness] should be between -30 and 30.
  static Future<Result<void>> setDarkness(int darkness) async {
    await _ensureInitialized();
    return await _service!.setDarkness(darkness);
  }

  /// Get the discovery service
  ///
  /// This provides access to the legacy discovery service. For better performance,
  /// consider using `smartDiscover()` instead.
  static ZebraPrinterDiscovery get discovery {
    _discovery ??= ZebraPrinterDiscovery();
    return _discovery!;
  }



  /// Get the printer service
  ///
  /// This provides access to the legacy printer service. For new applications,
  /// consider using the Smart API methods instead.
  static ZebraPrinterService? get service => _service;

  /// Disconnect from the current printer
  ///
  /// This disconnects using the legacy service. For better performance,
  /// consider using `smartDisconnect()` instead.
  static Future<Result<void>> disconnect() async {
    await _ensureInitialized();
    return await _service!.disconnect();
  }

  /// Check if a printer is connected
  ///
  /// This checks connection status using the legacy service.
  static Future<bool> isPrinterConnected() async {
    await _ensureInitialized();
    return await _service!.isPrinterConnected();
  }

  /// Get the currently connected printer
  ///
  /// This gets the connected printer using the legacy service.
  static ZebraDevice? get connectedPrinter {
    return _service?.connectedPrinter;
  }

  /// Get discovered printers
  ///
  /// This gets discovered printers using the legacy service. For better performance,
  /// consider using `smartDiscover()` instead.
  static List<ZebraDevice> get discoveredPrinters {
    return _service?.discoveredPrinters ?? [];
  }

  /// Get the status stream
  ///
  /// This provides status updates from the legacy service.
  static Stream<String> get statusStream {
    return _service?.status ?? const Stream.empty();
  }

  /// Get the connection stream
  ///
  /// This provides connection updates from the legacy service.
  static Stream<ZebraDevice?> get connectionStream {
    return _service?.connection ?? const Stream.empty();
  }
}
