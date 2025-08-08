import 'dart:async';

import 'internal/logger.dart';
import 'internal/policies/policies.dart' as policies;
import 'zebrautil.dart';

/// Service for discovering Zebra printers
/// Provides centralized discovery functionality for both Bluetooth and Network printers
///
/// **Error Handling Strategy:**
/// - Discovery methods return Result&lt;T&gt; for operation-level errors
/// - Real-time errors are emitted via the status stream
/// - Native discovery errors are handled by ZebraPrinter event handlers
/// - No constructor-level callbacks - errors are operation-specific
///
/// Note: CommunicationPolicy is handled by ZebraPrinterManager. This service
/// only uses timeout policies for discovery operations.
class ZebraPrinterDiscovery {
  ZebraPrinterDiscovery({
    required ZebraPrinter printer,
  }) : _printer = printer;
  
  // Timeout policy for all discovery operations
  static final _timeoutPolicy =
      policies.TimeoutPolicy.of(const Duration(seconds: 30));

  // Private fields
  final ZebraPrinter _printer;
  ZebraController? _controller;
  StreamController<List<ZebraDevice>>? _devicesStreamController;
  StreamController<String>? _statusStreamController;
  // No per-operation log subscription here; status stream already provides public messages
  
  Timer? _discoveryTimer;
  bool _isScanning = false;

  // Logger
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
    ZebraController? controller,
    Function(String)? statusCallback,
  }) async {
    if (_controller != null) return;

    _logger.info('Initializing ZebraPrinterDiscovery service');
    _controller = controller ?? ZebraController();
    _devicesStreamController = StreamController<List<ZebraDevice>>.broadcast();
    _statusStreamController = StreamController<String>.broadcast();

    // Listen to controller changes
    _controller!.addListener(_onControllerChanged);

    // Communication policy is now managed by ZebraPrinterManager
    // This class primarily manages the discovery flow

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
  /// Uses enhanced parallel network discovery with iOS HotSpot support
  /// 
  /// Discovery errors are handled via:
  /// - Result.error for method-level failures
  /// - status stream for real-time error notifications
  /// - ZebraPrinter event handlers for native discovery errors
  Future<Result<List<ZebraDevice>>> discoverPrinters({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _logger
        .info('Starting printer discovery with timeout: ${timeout.inSeconds}s');
    await _ensureInitialized();

    return await _timeoutPolicy.execute(
      () async {
        final List<ZebraDevice> allPrinters = [];
        final Set<String> uniqueAddresses = {};

        _logger.info(
            'Starting enhanced printer discovery (timeout: ${timeout.inSeconds}s)');
        _statusStreamController?.add('Discovering printers...');

        // Clear existing list
        _controller!.printers.clear();

        // Start streaming discovery with real-time results
        await _startStreamingDiscovery(timeout, uniqueAddresses, allPrinters);

        _logger.info(
            'Enhanced discovery completed with ${allPrinters.length} unique printers found');
        _statusStreamController
            ?.add('Discovery completed. Found ${allPrinters.length} printers');

        return Result.success(allPrinters);
      },
    );
  }

  /// Discover available printers with streaming approach
  /// Returns a stream of discovered devices and stops when criteria are met
  Stream<List<ZebraDevice>> discoverPrintersStream({
    Duration timeout = const Duration(seconds: 10),
    int? stopAfterCount,
    bool stopOnFirstPrinter = false,
    bool includeWifi = true,
    bool includeBluetooth = true,
    void Function({String? phase, String? target, String? message})? onWarning,
  }) async* {
    await _ensureInitialized();

    // Start discovery
    _isScanning = true;
    // Discovery will be started by individual methods
    _statusStreamController?.add('Scanning for printers...');

    // Kick off discovery concurrently so the stream can yield while discovery runs
    final Set<String> uniqueAddresses = {};
    final List<ZebraDevice> allPrinters = [];
    (() async {
      try {
        await _startStreamingDiscovery(timeout, uniqueAddresses, allPrinters,
            onWarning: onWarning);
      } catch (e) {
        _logger.warning('Failed to start streaming discovery: $e');
      }
    })();

    // Set up timeout
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(timeout, () {
      _stopAllDiscovery();
      _isScanning = false;
      _statusStreamController?.add('Discovery timeout reached');
    });

    // Track initial count to detect new printers
    final int initialCount = _controller!.printers.length;
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
        final List<ZebraDevice> filteredPrinters =
            currentPrinters.where((printer) {
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
          _stopAllDiscovery();
          _isScanning = false;
        }
      }
    }

    // Add the listener
    _controller!.addListener(onControllerChanged);

    // Yield initial state if we already have printers
    if (initialCount > 0) {
      final List<ZebraDevice> initialPrinters =
          _controller!.printers.where((printer) {
        if (!includeWifi && printer.isWifi) return false;
        if (!includeBluetooth && !printer.isWifi) return false;
        return true;
      }).toList();

      if (initialPrinters.isNotEmpty) {
        yield initialPrinters;
        
        // Check if we should stop immediately
        if (stopOnFirstPrinter || (stopAfterCount != null && initialPrinters.length >= stopAfterCount)) {
          _discoveryTimer?.cancel();
          _stopAllDiscovery();
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
    final List<ZebraDevice> currentPrinters =
        _controller!.printers.where((printer) {
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
      _stopAllDiscovery();
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

    return await _timeoutPolicy.execute(
      () async {
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
          return Result.errorCode(
            ErrorCodes.noPrintersFound,
          );
        }
      },
      operationName: 'Discover Printers Until First',
    );
  }

  /// Discover a specific number of printers
  Future<Result<List<ZebraDevice>>> discoverPrintersCount({
    required int count,
    Duration timeout = const Duration(seconds: 10),
    bool includeWifi = true,
    bool includeBluetooth = true,
  }) async {
    await _ensureInitialized();

    return await _timeoutPolicy.execute(
      () async {
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
          return Result.errorCode(
            ErrorCodes.noPrintersFound,
          );
        }
      },
      operationName: 'Discover Printers Count',
    );
  }

  /// Stop printer discovery
  Future<void> stopDiscovery() async {
    await _ensureInitialized();
    _discoveryTimer?.cancel();
    _printer.stopDiscovery();
    _isScanning = false;
    _statusStreamController?.add('Discovery stopped');
  }

  /// Find paired Bluetooth printers
  Future<List<ZebraDevice>> findPairedPrinters() async {
    await _ensureInitialized();
    
    final result = await _timeoutPolicy.execute(
      () async {
        List<ZebraDevice> pairedPrinters = [];

        // Check already discovered printers
        if (_controller!.printers.isNotEmpty) {
          pairedPrinters =
              _controller!.printers.where((p) => !p.isWifi).toList();
        }

        // Quick discovery if needed
        if (pairedPrinters.isEmpty) {
          _statusStreamController
              ?.add('Checking for paired Bluetooth printers...');
          // Discovery will be started by individual methods
          await Future.delayed(const Duration(seconds: 2));
          _stopAllDiscovery();
          pairedPrinters =
              _controller!.printers.where((p) => !p.isWifi).toList();
        }
        
        return Result.success(pairedPrinters);
      },
      operationName: 'Find Paired Printers',
    );

    return result.success ? result.data ?? [] : [];
  }

  /// Get list of paired/discovered printers for selection
  Future<List<ZebraDevice>> getAvailablePrinters() async {
    await _ensureInitialized();

    // If we already have printers, return them
    if (_controller!.printers.isNotEmpty) {
      return _controller!.printers;
    }

    // Otherwise discover with retry logic
    final result = await _timeoutPolicy.execute(
      () => discoverPrinters(timeout: const Duration(seconds: 5)),
      operationName: 'Get Available Printers',
    );
    
    return result.success ? result.data ?? [] : [];
  }

  /// Ensure the discovery service is initialized
  Future<void> _ensureInitialized() async {
    if (_controller == null) {
      await initialize();
    }
  }

  /// Discover Bluetooth printers with streaming callback
  Future<void> _discoverBluetoothPrintersStream(
    Duration timeout,
    void Function(ZebraDevice) onPrinterFound,
      {void Function({String? phase, String? target, String? message})?
          onWarning}
  ) async {
    try {
      _isScanning = true;
      
      // Use BT Classic discovery (per-operation stream)
      final subscription = _printer
          .discoverBTClassic(timeout: timeout.inMilliseconds)
          .listen(
            (device) => onPrinterFound(device),
        onError: (e) {
          _logger.warning('BT Classic discovery error: $e');
          onWarning?.call(phase: 'btClassic', target: null, message: '$e');
          _statusStreamController?.add('BT Classic discovery warning: $e');
        },
      );
      await subscription.asFuture<void>();
      await subscription.cancel();
      _logger.info('BT Classic discovery stream completed');
    } catch (e) {
      _logger.warning('Bluetooth discovery stream failed: $e');
    }
  }

  /// Discover network printers with streaming callback
  Future<void> _discoverNetworkPrintersStream(
    Duration timeout,
    void Function(ZebraDevice) onPrinterFound,
      {void Function({String? phase, String? target, String? message})?
          onWarning}
  ) async {
    try {
      // Run all network discovery streams concurrently
      final futures = <Future<void>>[];

      // Local broadcast
      futures.add(() async {
        final sub = _printer
            .discoverLocalBroadcast(
                timeout: timeout.inMilliseconds, onWarning: onWarning)
            .listen(onPrinterFound, onError: (e) {
          _logger.warning('Local broadcast discovery error: $e');
          onWarning?.call(phase: 'localBroadcast', target: null, message: '$e');
          _statusStreamController?.add('Local broadcast discovery warning: $e');
        });
        await sub.asFuture<void>();
        await sub.cancel();
      }());
      
      // Subnet search (including iPad hotspot)
      futures.add(() async {
        final sub = _printer
            .discoverSubnet(
                subnet: '192.168.1',
                timeout: timeout.inMilliseconds,
                onWarning: onWarning)
            .listen(onPrinterFound, onError: (e) {
          _logger.warning('Subnet discovery error: $e');
          onWarning?.call(phase: 'subnet', target: null, message: '$e');
          _statusStreamController?.add('Subnet discovery warning: $e');
        });
        await sub.asFuture<void>();
        await sub.cancel();
      }());
      
      // Directed broadcast
      futures.add(() async {
        final sub = _printer
            .discoverDirectedBroadcast(
                ipAddress: '192.168.1.255',
                timeout: timeout.inMilliseconds,
                onWarning: onWarning)
            .listen(onPrinterFound, onError: (e) {
          _logger.warning('Directed broadcast discovery error: $e');
          onWarning?.call(
              phase: 'directedBroadcast', target: null, message: '$e');
          _statusStreamController
              ?.add('Directed broadcast discovery warning: $e');
        });
        await sub.asFuture<void>();
        await sub.cancel();
      }());

      // Multicast
      futures.add(() async {
        final sub = _printer
            .discoverMulticast(
                hops: 5, timeout: timeout.inMilliseconds, onWarning: onWarning)
            .listen(onPrinterFound, onError: (e) {
          _logger.warning('Multicast discovery error: $e');
          onWarning?.call(phase: 'multicast', target: 'hops=5', message: '$e');
          _statusStreamController?.add('Multicast discovery warning: $e');
        });
        await sub.asFuture<void>();
        await sub.cancel();
      }());

      // Wait for all network discovery methods
      await Future.wait(futures);
    } catch (e) {
      _logger.warning('Network discovery stream failed: $e');
    }
  }

  /// Start streaming discovery with real-time results
  /// Printers are added to the UI as soon as they are found
  Future<void> _startStreamingDiscovery(
    Duration timeout,
    Set<String> uniqueAddresses,
    List<ZebraDevice> allPrinters,
      {void Function({String? phase, String? target, String? message})?
          onWarning}
  ) async {
    final completer = Completer<void>();
    int completedMethods = 0;
    const int totalMethods = 2; // Bluetooth + Network

    void checkCompletion() {
      completedMethods++;
      if (completedMethods >= totalMethods && !completer.isCompleted) {
        completer.complete();
      }
    }

    void addPrinter(ZebraDevice printer) {
      if (uniqueAddresses.add(printer.address)) {
        allPrinters.add(printer);
        _controller!.printers.add(printer);
        // Immediately notify UI of new printer
        _devicesStreamController?.add(_controller!.printers);
        _logger.info('Found printer: ${printer.name} (${printer.address})');
      }
    }

    // Start Bluetooth discovery with real-time callback
    _statusStreamController?.add('Starting Bluetooth discovery...');
    _discoverBluetoothPrintersStream(timeout, addPrinter).then((_) {
      checkCompletion();
    }).catchError((e) {
      _logger.warning('Bluetooth discovery failed: $e');
      checkCompletion();
    });

    // Start enhanced network discovery with real-time callback
    _statusStreamController?.add('Starting enhanced network discovery...');
    _discoverNetworkPrintersStream(timeout, addPrinter, onWarning: onWarning)
        .then((_) {
      checkCompletion();
    }).catchError((e) {
      _logger.warning('Network discovery failed: $e');
      checkCompletion();
    });

    // Wait for all discovery methods to complete or timeout
    await Future.any([
      completer.future,
      Future.delayed(timeout),
    ]);

    // Note: per-operation log warnings are emitted via the operation manager.
    // ZebraPrinterDiscovery already exposes status messages; callers can choose to listen
    // to status stream for high-level messages. Detailed per-address/range warnings are
    // available by subscribing directly to ZebraPrinter.operationEvents if needed.
  }

  /// Stop all discovery operations
  void _stopAllDiscovery() {
    if (_isScanning) {
      _printer.stopDiscovery();
      _isScanning = false;
    }
  }

  /// Dispose of resources
  void dispose() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    // _printer is managed externally and should not be disposed here
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _controller = null;
    _devicesStreamController?.close();
    _devicesStreamController = null;
    _statusStreamController?.close();
    _statusStreamController = null;
    // CommunicationPolicy is no longer managed here,
    // as it's now handled by ZebraPrinterManager.
  }
} 