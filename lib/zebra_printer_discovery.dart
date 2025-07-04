import 'dart:async';
import 'package:flutter/services.dart';
import 'package:zebrautil/zebrautil.dart';

/// Handles printer discovery and scanning operations
class ZebraPrinterDiscovery {
  ZebraPrinter? _printer;
  ZebraController? _controller;

  StreamController<List<ZebraDevice>>? _devicesStreamController;
  StreamController<String>? _statusStreamController;

  Timer? _discoveryTimer;
  bool _isScanning = false;
  final Logger _logger = Logger.withPrefix('ZebraPrinterDiscovery');

  /// Whether discovery is currently active
  bool get isScanning => _isScanning;

  /// Stream of discovered devices
  Stream<List<ZebraDevice>> get devices =>
      _devicesStreamController?.stream ?? const Stream.empty();

  /// Stream of status messages
  Stream<String> get status =>
      _statusStreamController?.stream ?? const Stream.empty();

  /// List of discovered printers
  List<ZebraDevice> get discoveredPrinters => _controller?.printers ?? [];

  /// Initialize the discovery service
  Future<void> initialize({
    ZebraPrinter? printer,
    ZebraController? controller,
    Function(String)? statusCallback,
  }) async {
    if (_printer != null) return;

    _logger.info('Initializing ZebraPrinterDiscovery service');
    _controller = controller ?? ZebraController();
    _devicesStreamController = StreamController<List<ZebraDevice>>.broadcast();
    _statusStreamController = StreamController<String>.broadcast();

    // Listen to controller changes
    _controller!.addListener(_onControllerChanged);

    if (printer != null) {
      _logger.info('Using provided printer instance');
      _printer = printer;
    } else {
      _logger.info('Creating new printer instance for discovery');
      _printer = await _getPrinterInstance(
        controller: _controller,
        onDiscoveryError: (code, message) {
          _logger.error('Discovery error: $code - $message');
          _statusStreamController?.add('Discovery error: $message');
        },
        onPermissionDenied: () {
          _logger.warning('Bluetooth permission denied during discovery');
          _statusStreamController?.add('Permission denied');
        },
      );
    }

    // Forward status messages if callback provided
    if (statusCallback != null) {
      _statusStreamController?.stream.listen(statusCallback);
    }
    _logger.info('ZebraPrinterDiscovery initialization completed');
  }

  void _onControllerChanged() {
    _devicesStreamController?.add(_controller!.printers);
  }

  /// Discover available printers (both Bluetooth and Network)
  /// Returns Result with list of discovered devices
  Future<Result<List<ZebraDevice>>> discoverPrinters({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _logger
        .info('Starting printer discovery with timeout: ${timeout.inSeconds}s');
    await _ensureInitialized();

    try {
      final completer = Completer<List<ZebraDevice>>();

      // Start discovery
      _isScanning = true;
      _logger.info('Initiating printer scan');
      _printer!.startScanning();
      _statusStreamController?.add('Scanning for printers...');

      // Set up timeout
      _discoveryTimer?.cancel();
      _discoveryTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          _logger.info('Discovery timeout reached, stopping scan');
          _printer!.stopScanning();
          _isScanning = false;
          _statusStreamController?.add('Discovery completed');
          completer.complete(_controller!.printers);
        }
      });

      final devices = await completer.future;
      _logger.info('Discovery completed, found ${devices.length} printers');
      return Result.success(devices);
    } catch (e, stack) {
      _logger.error('Discovery error occurred', e, stack);
      _statusStreamController?.add('Discovery error: $e');
      return Result.error(
        'Failed to discover printers: $e',
        code: ErrorCodes.discoveryError,
        dartStackTrace: stack,
      );
    }
  }

  /// Discover available printers with streaming approach
  /// Returns a stream of discovered devices and stops when criteria are met
  Stream<List<ZebraDevice>> discoverPrintersStream({
    Duration timeout = const Duration(seconds: 10),
    int? stopAfterCount,
    bool stopOnFirstPrinter = false,
    bool includeWifi = true,
    bool includeBluetooth = true,
  }) async* {
    await _ensureInitialized();

    // Start discovery
    _isScanning = true;
    _printer!.startScanning();
    _statusStreamController?.add('Scanning for printers...');

    // Set up timeout
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(timeout, () {
      _printer!.stopScanning();
      _isScanning = false;
      _statusStreamController?.add('Discovery timeout reached');
    });

    // Track initial count to detect new printers
    int initialCount = _controller!.printers.length;
    int lastYieldedCount = initialCount;

    // Create a completer to handle the stream completion
    final completer = Completer<void>();
    
    // Listen to controller changes
    void onControllerChanged() {
      final currentPrinters = _controller!.printers;
      final currentCount = currentPrinters.length;

      // Only yield if we have new printers
      if (currentCount > lastYieldedCount) {
        // Filter printers based on criteria
        List<ZebraDevice> filteredPrinters = currentPrinters.where((printer) {
          if (!includeWifi && printer.isWifi) return false;
          if (!includeBluetooth && !printer.isWifi) return false;
          return true;
        }).toList();

        // Check if we should stop
        bool shouldStop = false;
        if (stopAfterCount != null && filteredPrinters.length >= stopAfterCount) {
          shouldStop = true;
          _statusStreamController?.add('Found ${filteredPrinters.length} printers, stopping discovery');
        } else if (stopOnFirstPrinter && filteredPrinters.isNotEmpty) {
          shouldStop = true;
          _statusStreamController?.add('Found first printer, stopping discovery');
        }

        // Yield the current list
        if (!completer.isCompleted) {
          completer.complete();
        }
        lastYieldedCount = currentCount;

        // Stop if criteria met
        if (shouldStop) {
          _discoveryTimer?.cancel();
          _printer!.stopScanning();
          _isScanning = false;
        }
      }
    }

    // Add the listener
    _controller!.addListener(onControllerChanged);

    // Yield initial state if we already have printers
    if (initialCount > 0) {
      List<ZebraDevice> initialPrinters = _controller!.printers.where((printer) {
        if (!includeWifi && printer.isWifi) return false;
        if (!includeBluetooth && !printer.isWifi) return false;
        return true;
      }).toList();

      if (initialPrinters.isNotEmpty) {
        yield initialPrinters;
        
        // Check if we should stop immediately
        if (stopOnFirstPrinter || (stopAfterCount != null && initialPrinters.length >= stopAfterCount)) {
          _discoveryTimer?.cancel();
          _printer!.stopScanning();
          _isScanning = false;
          _controller!.removeListener(onControllerChanged);
          return;
        }
      }
    }

    // Wait for the first controller change or timeout
    try {
      await completer.future.timeout(timeout);
    } catch (e) {
      // Timeout occurred, continue to yield current state
    }

    // Yield current state
    List<ZebraDevice> currentPrinters = _controller!.printers.where((printer) {
      if (!includeWifi && printer.isWifi) return false;
      if (!includeBluetooth && !printer.isWifi) return false;
      return true;
    }).toList();

    if (currentPrinters.isNotEmpty) {
      yield currentPrinters;
    }

    // Clean up
    _controller!.removeListener(onControllerChanged);
    if (_isScanning) {
      _printer!.stopScanning();
      _isScanning = false;
    }
  }

  /// Discover printers and return immediately when first printer is found
  /// This is a convenience method for the common use case
  Future<Result<List<ZebraDevice>>> discoverPrintersUntilFirst({
    Duration timeout = const Duration(seconds: 10),
    bool includeWifi = true,
    bool includeBluetooth = true,
  }) async {
    await _ensureInitialized();

    try {
      final completer = Completer<List<ZebraDevice>>();
      List<ZebraDevice>? foundPrinters;

      // Start streaming discovery
      final subscription = discoverPrintersStream(
        timeout: timeout,
        stopOnFirstPrinter: true,
        includeWifi: includeWifi,
        includeBluetooth: includeBluetooth,
      ).listen(
        (printers) {
          if (printers.isNotEmpty && !completer.isCompleted) {
            foundPrinters = printers;
            completer.complete(printers);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Set up timeout fallback
      Timer(timeout, () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(foundPrinters ?? []);
        }
      });

      final devices = await completer.future;
      subscription.cancel();
      
      if (devices.isNotEmpty) {
        _statusStreamController?.add('Found ${devices.length} printer(s)');
        return Result.success(devices);
      } else {
        return Result.error(
          'No printers found within timeout',
          code: ErrorCodes.noPrintersFound,
        );
      }
    } catch (e, stack) {
      _statusStreamController?.add('Discovery error: $e');
      return Result.error(
        'Failed to discover printers: $e',
        code: ErrorCodes.discoveryError,
        dartStackTrace: stack,
      );
    }
  }

  /// Discover a specific number of printers
  Future<Result<List<ZebraDevice>>> discoverPrintersCount({
    required int count,
    Duration timeout = const Duration(seconds: 10),
    bool includeWifi = true,
    bool includeBluetooth = true,
  }) async {
    await _ensureInitialized();

    try {
      final completer = Completer<List<ZebraDevice>>();
      List<ZebraDevice>? foundPrinters;

      // Start streaming discovery
      final subscription = discoverPrintersStream(
        timeout: timeout,
        stopAfterCount: count,
        includeWifi: includeWifi,
        includeBluetooth: includeBluetooth,
      ).listen(
        (printers) {
          if (printers.length >= count && !completer.isCompleted) {
            foundPrinters = printers.take(count).toList();
            completer.complete(foundPrinters!);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Set up timeout fallback
      Timer(timeout, () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(foundPrinters ?? []);
        }
      });

      final devices = await completer.future;
      subscription.cancel();
      
      if (devices.length >= count) {
        _statusStreamController?.add('Found ${devices.length} printer(s)');
        return Result.success(devices);
      } else {
        return Result.error(
          'Only found ${devices.length} printer(s), expected $count',
          code: ErrorCodes.noPrintersFound,
        );
      }
    } catch (e, stack) {
      _statusStreamController?.add('Discovery error: $e');
      return Result.error(
        'Failed to discover printers: $e',
        code: ErrorCodes.discoveryError,
        dartStackTrace: stack,
      );
    }
  }

  /// Stop printer discovery
  Future<void> stopDiscovery() async {
    await _ensureInitialized();
    _discoveryTimer?.cancel();
    _printer!.stopScanning();
    _isScanning = false;
    _statusStreamController?.add('Discovery stopped');
  }

  /// Find paired Bluetooth printers
  Future<List<ZebraDevice>> findPairedPrinters() async {
    await _ensureInitialized();
    
    List<ZebraDevice> pairedPrinters = [];

    try {
      // Check already discovered printers
      if (_controller!.printers.isNotEmpty) {
        pairedPrinters = _controller!.printers.where((p) => !p.isWifi).toList();
      }

      // Quick discovery if needed
      if (pairedPrinters.isEmpty) {
        _statusStreamController?.add('Checking for paired Bluetooth printers...');
        _printer!.startScanning();
        await Future.delayed(const Duration(seconds: 2));
        _printer!.stopScanning();
        pairedPrinters = _controller!.printers.where((p) => !p.isWifi).toList();
      }
    } catch (e) {
      _statusStreamController?.add('Error finding paired printers: $e');
    }

    return pairedPrinters;
  }

  /// Get list of paired/discovered printers for selection
  Future<List<ZebraDevice>> getAvailablePrinters() async {
    await _ensureInitialized();

    // If we already have printers, return them
    if (_controller!.printers.isNotEmpty) {
      return _controller!.printers;
    }

    // Otherwise discover
    final result = await discoverPrinters(timeout: const Duration(seconds: 5));
    return result.success ? result.data ?? [] : [];
  }

  /// Ensure the discovery service is initialized
  Future<void> _ensureInitialized() async {
    if (_printer == null) {
      await initialize();
    }
  }

  /// Create a new printer instance
  static Future<ZebraPrinter> _getPrinterInstance({
    ZebraController? controller,
    Function(String code, String? message)? onDiscoveryError,
    Function()? onPermissionDenied,
  }) async {
    const platform = MethodChannel('zebrautil');

    // Get instance ID from platform - iOS returns a String UUID
    final String instanceId =
        await platform.invokeMethod<String>('getInstance') ?? 'default';

    // Return new printer instance
    return ZebraPrinter(
      instanceId,
      controller: controller,
      onDiscoveryError: onDiscoveryError,
      onPermissionDenied: onPermissionDenied,
    );
  }

  /// Dispose of resources
  void dispose() {
    _discoveryTimer?.cancel();
    _printer?.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _devicesStreamController?.close();
    _statusStreamController?.close();
  }
} 