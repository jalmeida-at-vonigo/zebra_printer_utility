import 'dart:async';
import 'dart:io';

import '../models/result.dart';
import '../models/zebra_device.dart';

import 'logger.dart';

/// Pure Dart implementation of network printer discovery
/// Supports iOS hotspot scenarios and parallel discovery methods
class NetworkDiscovery {
  static final Logger _logger = Logger.withPrefix('NetworkDiscovery');

  /// Discover network printers using multiple parallel methods
  /// Optimized for iOS hotspot scenarios
  static Future<Result<List<ZebraDevice>>> discoverNetworkPrinters({
    Duration timeout = const Duration(seconds: 10),
    List<String> customSubnets = const [],
  }) async {
    _logger.info('Starting parallel network discovery');
    
    final List<ZebraDevice> allPrinters = [];
    final Set<String> uniqueAddresses = {};
    
    // Use Completer to handle parallel execution
    final Completer<void> allComplete = Completer();
    int completedMethods = 0;
    const int totalMethods = 3; // mDNS, iOS hotspot range, common networks
    
    void checkCompletion() {
      completedMethods++;
      if (completedMethods >= totalMethods && !allComplete.isCompleted) {
        allComplete.complete();
      }
    }
    
    // Method 1: mDNS/Bonjour Discovery (parallel)
    _discoverViaMdns(timeout: const Duration(seconds: 2)).then((printers) {
      for (final printer in printers) {
        if (uniqueAddresses.add(printer.address)) {
          allPrinters.add(printer);
        }
      }
      checkCompletion();
    }).catchError((e) {
      _logger.warning('mDNS discovery failed: $e');
      checkCompletion();
    });
    
    // Method 2: iOS HotSpot Subnet Search (parallel) - iOS only
    if (Platform.isIOS) {
      _discoverViaSubnetSearch(['172.20.10'],
              timeout: const Duration(seconds: 1))
          .then((printers) {
        for (final printer in printers) {
          if (uniqueAddresses.add(printer.address)) {
            allPrinters.add(printer);
          }
        }
        checkCompletion();
      }).catchError((e) {
        _logger.warning('iOS HotSpot discovery failed: $e');
        checkCompletion();
      });
    } else {
      // Skip iOS HotSpot discovery on non-iOS platforms
      checkCompletion();
    }
    
    // Method 3: Common Network Ranges (parallel)
    final commonSubnets = ['192.168.1', '192.168.0', '10.0.0', ...customSubnets];
    _discoverViaSubnetSearch(commonSubnets, timeout: const Duration(seconds: 1)).then((printers) {
      for (final printer in printers) {
        if (uniqueAddresses.add(printer.address)) {
          allPrinters.add(printer);
        }
      }
      checkCompletion();
    }).catchError((e) {
      _logger.warning('Common network discovery failed: $e');
      checkCompletion();
    });
    
    // Wait for all methods to complete or timeout
    try {
      await allComplete.future.timeout(timeout);
    } catch (e) {
      _logger.warning('Discovery timeout reached');
    }
    
    _logger.info(
        'Network discovery completed. Found ${allPrinters.length} unique printers');
    return Result.success(allPrinters);
  }

  /// Discover network printers with streaming callback for real-time UI updates
  /// Printers are reported as soon as they are found
  static Future<void> discoverNetworkPrintersStream({
    Duration timeout = const Duration(seconds: 10),
    required void Function(ZebraDevice) onPrinterFound,
    List<String> customSubnets = const [],
  }) async {
    _logger.info('Starting streaming network discovery');
    
    final Set<String> uniqueAddresses = {};
    
    // Use Completer to handle parallel execution
    final Completer<void> allComplete = Completer();
    int completedMethods = 0;
    const int totalMethods = 3; // mDNS, iOS HotSpot range, common networks
    
    void checkCompletion() {
      completedMethods++;
      if (completedMethods >= totalMethods && !allComplete.isCompleted) {
        allComplete.complete();
      }
    }
    
    void reportPrinter(ZebraDevice printer) {
      if (uniqueAddresses.add(printer.address)) {
        onPrinterFound(printer);
      }
    }
    
    // Method 1: iOS HotSpot range (parallel)
    _discoverViaSubnetSearchStream(
      ['172.20.10'], 
      onPrinterFound: reportPrinter,
      timeout: const Duration(seconds: 2),
    ).then((_) {
      checkCompletion();
    }).catchError((e) {
      _logger.warning('iOS HotSpot discovery failed: $e');
      checkCompletion();
    });
    
    // Method 2: Common network ranges (parallel)
    _discoverViaSubnetSearchStream(
      ['192.168.1'], 
      onPrinterFound: reportPrinter,
      timeout: const Duration(seconds: 2),
    ).then((_) {
      checkCompletion();
    }).catchError((e) {
      _logger.warning('Common network discovery failed: $e');
      checkCompletion();
    });
    
    // Method 3: Custom subnets if provided (parallel)
    if (customSubnets.isNotEmpty) {
      _discoverViaSubnetSearchStream(
        customSubnets, 
        onPrinterFound: reportPrinter,
        timeout: const Duration(seconds: 2),
      ).then((_) {
        checkCompletion();
      }).catchError((e) {
        _logger.warning('Custom subnet discovery failed: $e');
        checkCompletion();
      });
    } else {
      // No custom subnets, mark as complete immediately
      checkCompletion();
    }
    
    // Wait for all methods to complete or timeout
    try {
      await allComplete.future.timeout(timeout);
    } catch (e) {
      _logger.warning('Streaming discovery timeout reached');
    }
    
    _logger.info('Streaming network discovery completed');
  }
  
  /// Discover printers via mDNS/Bonjour (limited on iOS HotSpot)
  static Future<List<ZebraDevice>> _discoverViaMdns({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _logger.info('Starting mDNS discovery');
    final List<ZebraDevice> printers = [];
    
    // Note: Pure Dart mDNS implementation is complex and limited
    // Direct IP scanning provides better reliability for iOS HotSpot scenarios
    // Future enhancement could implement RawDatagramSocket for native mDNS
    
    return printers;
  }
  
  /// Discover printers via subnet scanning (optimal for iOS HotSpot)
  static Future<List<ZebraDevice>> _discoverViaSubnetSearch(
    List<String> subnetPrefixes, {
    Duration timeout = const Duration(seconds: 2),
    int port = 9100,
  }) async {
    _logger.info('Starting subnet search for prefixes: $subnetPrefixes');
    final List<ZebraDevice> printers = [];
    final List<Future<ZebraDevice?>> scanFutures = [];
    
    // Scan all IP addresses in parallel for each subnet
    for (final prefix in subnetPrefixes) {
      for (int i = 1; i <= 254; i++) {
        final ip = '$prefix.$i';
        scanFutures.add(_scanIpForPrinter(ip, port, timeout));
      }
    }
    
    // Wait for all scans to complete
    final results = await Future.wait(scanFutures);
    
    // Collect successful discoveries
    for (final result in results) {
      if (result != null) {
        printers.add(result);
      }
    }
    
    _logger.info('Subnet search found ${printers.length} printers');
    return printers;
  }

  /// Discover printers via subnet scanning with streaming callback
  static Future<void> _discoverViaSubnetSearchStream(
    List<String> subnetPrefixes, {
    required void Function(ZebraDevice) onPrinterFound,
    Duration timeout = const Duration(seconds: 2),
    int port = 9100,
  }) async {
    _logger.info('Starting streaming subnet search for prefixes: $subnetPrefixes');
    
    // Launch scans for all IP addresses, but report immediately when found
    final List<Future<void>> scanFutures = [];
    
    for (final prefix in subnetPrefixes) {
      for (int i = 1; i <= 254; i++) {
        final ip = '$prefix.$i';
        scanFutures.add(_scanIpForPrinterStream(ip, port, timeout, onPrinterFound));
      }
    }
    
    // Wait for all scans to complete
    await Future.wait(scanFutures);
    
    _logger.info('Streaming subnet search completed for prefixes: $subnetPrefixes');
  }
  
  /// Scan a specific IP address for a Zebra printer
  static Future<ZebraDevice?> _scanIpForPrinter(
    String ip,
    int port,
    Duration timeout,
  ) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      await socket.close();
      
      // If we can connect, it's likely a printer
      _logger.debug('Found printer at $ip:$port');
      return ZebraDevice(
        address: ip,
        name: ip,
        status: 'Found',
        isWifi: true,
        isBluetooth: false,
        connectionType: 'Network',
        brand: 'Zebra',
        displayName: 'Zebra Printer - $ip',
        port: port,
        discoveryMethod: 'subnet_search',
      );
    } catch (e) {
      // Connection failed - not a printer or not reachable
      return null;
    }
  }

  /// Scan a specific IP address for a Zebra printer with streaming callback
  static Future<void> _scanIpForPrinterStream(
    String ip,
    int port,
    Duration timeout,
    void Function(ZebraDevice) onPrinterFound,
  ) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      await socket.close();
      
      // If we can connect, it's likely a printer - create device and enhance it
      _logger.debug('Found printer at $ip:$port');
      final device = ZebraDevice(
        address: ip,
        name: ip,
        status: 'Found',
        isWifi: true,
        isBluetooth: false,
        connectionType: 'Network',
        brand: 'Zebra',
        displayName: 'Zebra Printer - $ip',
        port: port,
        discoveryMethod: 'subnet_search',
      );
      
      // Report discovered printer immediately
      onPrinterFound(device);
    } catch (e) {
      // Connection failed - not a printer or not reachable
      // Don't report anything
    }
  }
  

  
}

