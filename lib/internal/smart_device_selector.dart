import 'dart:async';
import '../../models/smart_discovery_result.dart';
import '../../models/zebra_device.dart';
import '../../zebra_printer_discovery.dart';
import 'logger.dart';
import 'printer_preferences.dart';

/// Smart device selector for dynamic field service environments
/// 
/// This selector implements intelligent printer selection based on:
/// - Connection type priority (WiFi over BLE)
/// - Model compatibility and priority
/// - Connection availability and stability
/// - Previous connection success
class SmartDeviceSelector {
  static final Logger _logger = Logger.withPrefix('SmartDeviceSelector');
  
  // Track discovery history for stability detection
  static final Map<String, List<DateTime>> _discoveryHistory = {};
  static final Map<String, DateTime> _lastSeenTime = {};
  
  /// Select the optimal printer from available devices
  static Future<ZebraDevice?> selectOptimalPrinter(
    List<ZebraDevice> printers, {
    ZebraDevice? previouslySelected,
    bool? preferWiFi,
  }) async {
    if (printers.isEmpty) return null;
    
    _logger.info('Selecting optimal printer from ${printers.length} devices');
    
    // Get preferences if not provided
    preferWiFi ??= await PrinterPreferences.getPreferredConnectionType();
    
    // Get saved printer if no previously selected provided
    previouslySelected ??= await PrinterPreferences.getLastSelectedPrinter();
    
    // Update discovery history
    _updateDiscoveryHistory(printers);
    
    // STEP 1: If we have a previously selected printer that's still available, prefer it
    if (previouslySelected != null) {
      final stillAvailable = printers.firstWhere(
        (p) => p.address == previouslySelected!.address,
        orElse: () => ZebraDevice(address: '', name: '', status: '', isWifi: false),
      );
      if (stillAvailable.address.isNotEmpty && _isStableConnection(stillAvailable)) {
        _logger.info('Using previously selected printer: ${stillAvailable.name}');
        return stillAvailable;
      }
    }
    
    // STEP 2: Smart selection based on multiple criteria
    final scoredPrinters = await _scorePrinters(printers, preferWiFi: preferWiFi);
    
    // Sort by score (highest first)
    scoredPrinters.sort((a, b) => b.score.compareTo(a.score));
    
    if (scoredPrinters.isNotEmpty) {
      final selected = scoredPrinters.first.device;
      _logger.info('Selected printer: ${selected.name} (score: ${scoredPrinters.first.score})');
      return selected;
    }
    
    // STEP 3: Fallback - any available printer
    _logger.info('Fallback selection: using first available printer');
    return printers.first;
  }
  
  /// Score printers based on multiple criteria
  static Future<List<ScoredDevice>> _scorePrinters(
    List<ZebraDevice> printers, {
    required bool preferWiFi,
  }) async {
    // Get all connection success counts from storage
    final successCounts = await PrinterPreferences.getAllConnectionSuccessCounts();
    
    return printers.map((printer) {
      double score = 0.0;
      
      // Connection type score (0-30 points)
      if (printer.isWifi) {
        score += preferWiFi ? 30 : 20;
      } else {
        score += preferWiFi ? 20 : 30;
      }
      
      // Model priority score (0-25 points)
      score += _getModelScore(printer.name);
      
      // Stability score (0-20 points)
      score += _getStabilityScore(printer);
      
      // Connection history score from persistent storage (0-15 points)
      final persistentSuccessCount = successCounts[printer.address] ?? 0;
      score += _getConnectionHistoryScore(persistentSuccessCount);
      
      // Availability score (0-10 points)
      score += _getAvailabilityScore(printer);
      
      return ScoredDevice(printer, score);
    }).toList();
  }
  
  /// Get model priority score
  static double _getModelScore(String name) {
    // Priority order based on field service needs
    final modelPriorities = {
      'RW420': 25.0,   // WiFi-only, most reliable
      'ZQ521': 23.0,   // Latest model
      'ZQ520': 22.0,   // Standard model
      'ZQ510': 20.0,   // Older but reliable
      'ZQ': 15.0,      // Any ZQ model
      'Zebra': 10.0,   // Any Zebra printer
    };
    
    for (final entry in modelPriorities.entries) {
      if (name.toUpperCase().contains(entry.key)) {
        return entry.value;
      }
    }
    
    return 5.0; // Unknown model
  }
  
  /// Get stability score based on consistent discovery
  static double _getStabilityScore(ZebraDevice printer) {
    final history = _discoveryHistory[printer.address] ?? [];
    if (history.isEmpty) return 0.0;
    
    // Check if printer has been consistently discovered
    final now = DateTime.now();
    final recentDiscoveries = history.where(
      (time) => now.difference(time).inSeconds < 30
    ).length;
    
    // More recent discoveries = more stable
    if (recentDiscoveries >= 5) return 20.0;
    if (recentDiscoveries >= 3) return 15.0;
    if (recentDiscoveries >= 2) return 10.0;
    if (recentDiscoveries >= 1) return 5.0;
    
    return 0.0;
  }
  
  /// Get connection history score based on success count
  static double _getConnectionHistoryScore(int successCount) {
    if (successCount >= 5) return 15.0;
    if (successCount >= 3) return 10.0;
    if (successCount >= 1) return 5.0;
    
    return 0.0;
  }
  
  /// Get availability score based on current status
  static double _getAvailabilityScore(ZebraDevice printer) {
    // Check if printer status indicates availability
    final status = printer.status.toLowerCase();
    
    if (status.contains('connected')) return 10.0;
    if (status.contains('ready')) return 8.0;
    if (status.contains('found')) return 5.0;
    
    return 3.0;
  }
  
  /// Update discovery history for stability tracking
  static void _updateDiscoveryHistory(List<ZebraDevice> printers) {
    final now = DateTime.now();
    
    for (final printer in printers) {
      // Add to discovery history
      _discoveryHistory[printer.address] ??= [];
      _discoveryHistory[printer.address]!.add(now);
      
      // Keep only recent history (last 60 seconds)
      _discoveryHistory[printer.address] = _discoveryHistory[printer.address]!
          .where((time) => now.difference(time).inSeconds < 60)
          .toList();
      
      // Update last seen time
      _lastSeenTime[printer.address] = now;
    }
    
    // Clean up old entries
    _discoveryHistory.removeWhere((address, history) {
      final lastSeen = _lastSeenTime[address];
      return lastSeen == null || now.difference(lastSeen).inSeconds > 120;
    });
  }
  
  /// Check if a printer has stable connection
  static bool _isStableConnection(ZebraDevice printer) {
    final history = _discoveryHistory[printer.address] ?? [];
    return history.length >= 2;
  }
  
  /// Record successful connection for future scoring (now uses persistent storage)
  static Future<void> recordSuccessfulConnection(String address) async {
    await PrinterPreferences.saveConnectionHistory(address, true);
    _logger.info('Recorded successful connection for $address');
  }
  
  /// Record failed connection (uses persistent storage)
  static Future<void> recordFailedConnection(String address) async {
    await PrinterPreferences.saveConnectionHistory(address, false);
    _logger.info('Recorded failed connection for $address');
  }
  
  /// Smart discovery with continuous updates
  static Stream<SmartDiscoveryResult> smartDiscoveryStream({
    required ZebraPrinterDiscovery discovery,
    Duration timeout = const Duration(seconds: 10),
    bool? preferWiFi,
    ZebraDevice? previouslySelected,
  }) async* {
    _logger.info('Starting smart discovery stream');
    
    // Get preferences if not provided
    preferWiFi ??= await PrinterPreferences.getPreferredConnectionType();
    previouslySelected ??= await PrinterPreferences.getLastSelectedPrinter();
    
    final startTime = DateTime.now();
    ZebraDevice? currentSelection;
    List<ZebraDevice> allPrinters = [];
    
    // Start discovery
    final discoveryStream = discovery.discoverPrintersStream(
      timeout: timeout,
      includeWifi: true,
      includeBluetooth: true,
    );
    
    await for (final printers in discoveryStream) {
      allPrinters = printers;
      
      // Update selection with each discovery update
      final newSelection = await selectOptimalPrinter(
        printers,
        previouslySelected: previouslySelected ?? currentSelection,
        preferWiFi: preferWiFi,
      );
      
      // Emit update if selection changed or if it's the first selection
      if (newSelection != null && 
          (currentSelection == null || newSelection.address != currentSelection.address)) {
        currentSelection = newSelection;
        
        yield SmartDiscoveryResult(
          selectedPrinter: currentSelection,
          allPrinters: List.from(allPrinters),
          isComplete: false,
          discoveryDuration: DateTime.now().difference(startTime),
        );
      } else if (currentSelection == null && printers.isNotEmpty) {
        // No selection could be made, but we have printers
        yield SmartDiscoveryResult(
          selectedPrinter: null,
          allPrinters: List.from(allPrinters),
          isComplete: false,
          discoveryDuration: DateTime.now().difference(startTime),
        );
      }
    }
    
    // Final result
    yield SmartDiscoveryResult(
      selectedPrinter: currentSelection,
      allPrinters: List.from(allPrinters),
      isComplete: true,
      discoveryDuration: DateTime.now().difference(startTime),
    );
    
    _logger.info('Smart discovery completed. Found ${allPrinters.length} printers');
  }
} 