# Network Discovery with iPad Hotspot Support - Complete Implementation Plan

## Executive Summary

This plan addresses the issue where network discovery doesn't find printers on iPad hotspot networks. The solution involves implementing multiple concurrent network discovery methods in the native iOS layer, with orchestration and deduplication handled in the Dart layer through `ZebraPrinterDiscovery`.

## Architecture Overview

### Layer Responsibilities

#### **Native iOS Layer** (ZSDKWrapper.m & ZebraPrinterInstance.swift)
- **ZSDKWrapper.m**: Thin wrapper exposing ZSDK discovery methods as-is
- **ZebraPrinterInstance.swift**: 
  - Converts ZSDK results to dictionaries
  - Streams raw discovery results to Dart
  - Implements proper cancellation mechanisms

#### **Dart Layer** (zebra_printer_discovery.dart)
- **ZebraPrinterDiscovery**: Main discovery orchestration
  - Manages concurrent discovery methods
  - Handles deduplication by address:port
  - Implements SGD model enhancement
  - Provides streaming and batch discovery APIs
- **Internal NetworkDiscovery class** (optional): 
  - Encapsulates network-specific discovery logic
  - Manages subnet ranges and discovery parameters

## Key Requirements from Discussion

### 1. Network Discovery Methods
Despite overlaps, all methods provide unique discovery capabilities:
- **Local Broadcast**: Finds printers on device's current subnet
- **Subnet Search**: Searches specific ranges (172.20.10.* for iPad hotspot)
- **Directed Broadcast**: Reaches remote subnets
- **Multicast**: Multi-hop discovery through routers

### 2. Architecture Decisions
- **No changes to ZSDKWrapper.m** - Already has necessary thin wrappers
- **Dictionary conversion in Swift** - Move from ObjC to Swift layer
- **SGD enhancement in Dart** - Use existing `getSetting` for model retrieval using the proper command patter described on 
- **Deduplication in Dart** - Native streams all results, Dart deduplicates

### 3. Performance Goals
- First printer: < 1 second
- Complete discovery: < 2.5 seconds
- Model enhancement: 2-3 seconds after discovery (non-blocking)

### 4. Cancellation Requirements
- Proper cancellation using ZSDK mechanisms
- Cancellation tokens/signals for all concurrent operations
- Clean resource cleanup on stop

## Implementation Details

### Phase 1: Native iOS Implementation

#### 1.1 ZSDKWrapper.m (No Changes)
Current implementation already provides:
```objc
+ (NSArray *)discoverLocalPrintersWithTimeout:(NSInteger)timeout error:(NSError **)error;
+ (NSArray *)discoverSubnetPrintersWithRange:(NSString *)subnetRange timeout:(NSInteger)timeout error:(NSError **)error;
+ (NSArray *)discoverDirectedBroadcastWithIp:(NSString *)ipAddress timeout:(NSInteger)timeout error:(NSError **)error;
+ (NSArray *)discoverMulticastWithHops:(NSInteger)hops timeout:(NSInteger)timeout error:(NSError **)error;
+ (NSString *)getSetting:(NSString *)setting fromConnection:(id)connection; // For SGD
```

#### 1.2 ZebraPrinterInstance.swift Updates

##### Move Dictionary Conversion from ObjC
```swift
private func convertDiscoveredPrinters(_ printers: [Any]?) -> [[String: Any]] {
    guard let printers = printers else { return [] }
    
    return printers.compactMap { printer in
        guard let networkPrinter = printer as? NSObject,
              networkPrinter.responds(to: Selector("address")),
              let address = networkPrinter.value(forKey: "address") as? String,
              !address.isEmpty else { return nil }
        
        let port = (networkPrinter.responds(to: Selector("port")) ? 
                   networkPrinter.value(forKey: "port") as? Int : nil) ?? 9100
        let dnsName = networkPrinter.responds(to: Selector("dnsName")) ?
                     networkPrinter.value(forKey: "dnsName") as? String : nil
        
        return [
            "Address": address,
            "port": port,
            "Name": dnsName ?? address,
            "dnsName": dnsName ?? "",
            "IsWifi": true,
            "isBluetooth": false,
            "connectionType": "network",
            "Status": "Available",
            "brand": "Zebra"
        ]
    }
}
```

##### Implement Cancellable Network Discovery
```swift
private var discoveryOperations = [String: DispatchWorkItem]()
private let discoveryQueue = DispatchQueue(label: "com.zebrautil.discovery", attributes: .concurrent)

private func startNetworkDiscovery(args: [String: Any]?, operationId: String?, result: @escaping FlutterResult) {
    let timeout = args?["timeout"] as? Int ?? 5000
    let customSubnets = args?["customSubnets"] as? [String] ?? []
    let enableMulticast = args?["enableMulticast"] as? Bool ?? false
    
    // Create cancellable work items
    let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        
        let group = DispatchGroup()
        var isCancelled = false
        
        // Check cancellation before each operation
        func checkCancellation() -> Bool {
            return self.discoveryOperations[operationId ?? ""]?.isCancelled ?? false
        }
        
        // Method 1: Local Broadcast
        if !checkCancellation() {
            group.enter()
            self.discoveryQueue.async {
                defer { group.leave() }
                guard !checkCancellation() else { return }
                
                var error: NSError?
                let localPrinters = ZSDKWrapper.discoverLocalPrinters(withTimeout: 2000, error: &error)
                
                if let dicts = self.convertDiscoveredPrinters(localPrinters), !checkCancellation() {
                    for var printer in dicts {
                        printer["discoveryMethod"] = "localBroadcast"
                        printer["discoveredAt"] = ISO8601DateFormatter().string(from: Date())
                        
                        DispatchQueue.main.async {
                            guard !checkCancellation() else { return }
                            self.channel.invokeMethod("printerFound", arguments: printer)
                        }
                    }
                }
            }
        }
        
        // Method 2: iPad Hotspot Subnet (CRITICAL)
        if !checkCancellation() {
            group.enter()
            self.discoveryQueue.async {
                defer { group.leave() }
                guard !checkCancellation() else { return }
                
                var error: NSError?
                let hotspotPrinters = ZSDKWrapper.discoverSubnetPrinters(
                    withRange: "172.20.10.*",
                    timeout: 800,
                    error: &error
                )
                
                if let dicts = self.convertDiscoveredPrinters(hotspotPrinters), !checkCancellation() {
                    for var printer in dicts {
                        printer["discoveryMethod"] = "iPadHotspot"
                        DispatchQueue.main.async {
                            guard !checkCancellation() else { return }
                            self.channel.invokeMethod("printerFound", arguments: printer)
                        }
                    }
                }
            }
        }
        
        // Method 3: Common Subnets
        let commonSubnets = ["192.168.1", "192.168.0", "10.0.0", "192.168.88"]
        for subnet in commonSubnets {
            if checkCancellation() { break }
            
            group.enter()
            self.discoveryQueue.async {
                defer { group.leave() }
                guard !checkCancellation() else { return }
                
                var error: NSError?
                let subnetPrinters = ZSDKWrapper.discoverSubnetPrinters(
                    withRange: "\(subnet).*",
                    timeout: 500,
                    error: &error
                )
                
                if let dicts = self.convertDiscoveredPrinters(subnetPrinters), !checkCancellation() {
                    for var printer in dicts {
                        printer["discoveryMethod"] = "subnet-\(subnet)"
                        DispatchQueue.main.async {
                            guard !checkCancellation() else { return }
                            self.channel.invokeMethod("printerFound", arguments: printer)
                        }
                    }
                }
            }
        }
        
        // Method 4: Custom Subnets
        for subnet in customSubnets {
            if checkCancellation() { break }
            
            group.enter()
            self.discoveryQueue.async {
                defer { group.leave() }
                guard !checkCancellation() else { return }
                
                var error: NSError?
                let customPrinters = ZSDKWrapper.discoverSubnetPrinters(
                    withRange: "\(subnet).*",
                    timeout: 500,
                    error: &error
                )
                
                if let dicts = self.convertDiscoveredPrinters(customPrinters), !checkCancellation() {
                    for var printer in dicts {
                        printer["discoveryMethod"] = "customSubnet"
                        DispatchQueue.main.async {
                            guard !checkCancellation() else { return }
                            self.channel.invokeMethod("printerFound", arguments: printer)
                        }
                    }
                }
            }
        }
        
        // Method 5: Multicast (optional)
        if enableMulticast && !checkCancellation() {
            group.enter()
            self.discoveryQueue.async {
                defer { group.leave() }
                guard !checkCancellation() else { return }
                
                var error: NSError?
                let multicastPrinters = ZSDKWrapper.discoverMulticast(
                    withHops: 2,
                    timeout: 1500,
                    error: &error
                )
                
                if let dicts = self.convertDiscoveredPrinters(multicastPrinters), !checkCancellation() {
                    for var printer in dicts {
                        printer["discoveryMethod"] = "multicast"
                        DispatchQueue.main.async {
                            guard !checkCancellation() else { return }
                            self.channel.invokeMethod("printerFound", arguments: printer)
                        }
                    }
                }
            }
        }
        
        // Wait with timeout
        let waitResult = group.wait(timeout: .now() + 2.5)
        
        // Cleanup
        self.discoveryOperations.removeValue(forKey: operationId ?? "")
        
        // Send completion if not cancelled
        if !checkCancellation() {
            DispatchQueue.main.async {
                if let operationId = operationId {
                    self.channel.invokeMethod("onDiscoveryComplete", arguments: [
                        "operationId": operationId,
                        "cancelled": false
                    ])
                }
                result(true)
            }
        }
    }
    
    // Store work item for cancellation
    if let operationId = operationId {
        discoveryOperations[operationId] = workItem
    }
    
    // Execute work item
    discoveryQueue.async(execute: workItem)
}

// Add cancellation method
private func cancelDiscovery(operationId: String?, result: @escaping FlutterResult) {
    if let operationId = operationId,
       let workItem = discoveryOperations[operationId] {
        workItem.cancel()
        discoveryOperations.removeValue(forKey: operationId)
        
        DispatchQueue.main.async {
            self.channel.invokeMethod("onDiscoveryComplete", arguments: [
                "operationId": operationId,
                "cancelled": true
            ])
        }
    }
    
    result(true)
}
```

##### Update startScan Method
```swift
private func startScan(call: FlutterMethodCall, operationId: String?, result: @escaping FlutterResult) {
    isScanning = true
    discoveredPrinters.removeAll()
    discoveredMfiPrinters.removeAll()
    
    LogUtil.info("Starting printer discovery (MFi Bluetooth and Network)")
    
    // Start MFi Bluetooth discovery (existing)
    startMfiBluetoothDiscovery()
    
    // Start Network discovery (new)
    let args = call.arguments as? [String: Any]
    startNetworkDiscovery(args: args, operationId: operationId) { _ in }
    
    result(true)
}
```

### Phase 2: Dart Implementation

#### 2.1 Update ZebraPrinterDiscovery

##### Core Discovery Orchestration
```dart
class ZebraPrinterDiscovery {
  // Add network discovery helper
  late final _networkDiscovery = _NetworkDiscovery(this);
  
  // Track discovered printers with deduplication
  final Map<String, ZebraDevice> _discoveredPrinters = {};
  final Map<String, Set<String>> _printerDiscoveryMethods = {};
  
  // Cancellation support
  String? _currentOperationId;
  
  /// Enhanced discovery with network support
  Stream<List<ZebraDevice>> discoverPrintersStream({
    Duration timeout = const Duration(seconds: 10),
    int? stopAfterCount,
    bool stopOnFirstPrinter = false,
    bool includeWifi = true,
    bool includeBluetooth = true,
    List<String>? customSubnets,
    bool enableMulticast = false,
  }) async* {
    await _ensureInitialized();
    
    // Generate operation ID for cancellation
    _currentOperationId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Clear previous results
    _discoveredPrinters.clear();
    _printerDiscoveryMethods.clear();
    
    // Set up method call handler for network discovery results
    _printer.channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'printerFound':
          _handleNetworkPrinterFound(call.arguments);
          break;
        case 'onDiscoveryComplete':
          _handleDiscoveryComplete(call.arguments);
          break;
      }
    });
    
    // Start concurrent discovery
    final futures = <Future>[];
    
    // Bluetooth discovery (existing implementation)
    if (includeBluetooth) {
      futures.add(_startBluetoothDiscovery(timeout));
    }
    
    // Network discovery (enhanced)
    if (includeWifi) {
      futures.add(_networkDiscovery.startDiscovery(
        timeout: timeout,
        customSubnets: customSubnets ?? [],
        enableMulticast: enableMulticast,
        operationId: _currentOperationId!,
      ));
    }
    
    // Stream results as they arrive
    final streamController = StreamController<List<ZebraDevice>>();
    
    // Monitor for completion criteria
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      final currentDevices = _discoveredPrinters.values.toList();
      
      // Check stop criteria
      bool shouldStop = false;
      if (stopOnFirstPrinter && currentDevices.isNotEmpty) {
        shouldStop = true;
      } else if (stopAfterCount != null && currentDevices.length >= stopAfterCount) {
        shouldStop = true;
      }
      
      // Stream current state
      streamController.add(currentDevices);
      
      if (shouldStop) {
        timer.cancel();
        _stopDiscovery();
      }
    });
    
    // Set timeout
    Future.delayed(timeout, () {
      _stopDiscovery();
      streamController.close();
    });
    
    yield* streamController.stream;
  }
  
  void _handleNetworkPrinterFound(Map<String, dynamic> printerData) {
    final device = ZebraDevice.fromJson(printerData);
    final key = '${device.address}:${device.port ?? 9100}';
    
    // Deduplication
    if (_discoveredPrinters.containsKey(key)) {
      final existing = _discoveredPrinters[key]!;
      final merged = _mergeDevices(existing, device);
      _discoveredPrinters[key] = merged;
      
      // Track discovery methods
      _printerDiscoveryMethods[key] ??= {};
      _printerDiscoveryMethods[key]!.add(printerData['discoveryMethod'] ?? 'unknown');
    } else {
      _discoveredPrinters[key] = device;
      _printerDiscoveryMethods[key] = {printerData['discoveryMethod'] ?? 'unknown'};
      
      // Start model enhancement concurrently
      _enhanceDeviceModel(device);
    }
  }
  
  /// Stop all discovery operations
  Future<void> stopDiscovery() async {
    await _stopDiscovery();
  }
  
  Future<void> _stopDiscovery() async {
    // Cancel network discovery
    if (_currentOperationId != null) {
      await _printer.channel.invokeMethod('cancelDiscovery', {
        'operationId': _currentOperationId,
      });
    }
    
    // Stop Bluetooth discovery
    _printer.stopScanning();
    _isScanning = false;
    
    // Clear operation ID
    _currentOperationId = null;
  }
  
  /// Enhance device with model information via SGD
  Future<void> _enhanceDeviceModel(ZebraDevice device) async {
    try {
      // Create temporary connection for SGD query
      final tempPrinter = ZebraPrinter('temp_${device.address}');
      
      // Quick connect with timeout
      final connectResult = await tempPrinter.connect(device.address)
          .timeout(Duration(seconds: 2), onTimeout: () => Result.error('Timeout'));
      
      if (connectResult.success) {
        // Get model using existing getSetting
        final modelResult = await tempPrinter.getSetting('appl.name');
        
        await tempPrinter.disconnect();
        
        if (modelResult.success && modelResult.data?.isNotEmpty == true) {
          final enhanced = device.copyWith(
            model: modelResult.data,
            displayName: 'Zebra ${modelResult.data} - ${device.name}',
          );
          
          // Update stored device
          final key = '${device.address}:${device.port ?? 9100}';
          _discoveredPrinters[key] = enhanced;
        }
      }
    } catch (e) {
      // Enhancement is non-critical
      _logger.debug('Model enhancement failed for ${device.address}: $e');
    }
  }
  
  ZebraDevice _mergeDevices(ZebraDevice existing, ZebraDevice newDevice) {
    return existing.copyWith(
      // Prefer DNS name over IP
      name: _isBetterName(newDevice.name, existing.name) 
          ? newDevice.name 
          : existing.name,
      // Keep enhanced data
      model: existing.model ?? newDevice.model,
      displayName: existing.displayName ?? newDevice.displayName,
    );
  }
  
  bool _isBetterName(String newName, String existingName) {
    // DNS names are better than IP addresses
    final isNewDns = !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(newName);
    final isExistingDns = !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(existingName);
    return isNewDns && !isExistingDns;
  }
}
```

#### 2.2 Internal Network Discovery Class

```dart
/// Internal class for network discovery operations
class _NetworkDiscovery {
  final ZebraPrinterDiscovery _parent;
  
  _NetworkDiscovery(this._parent);
  
  /// Start network discovery with multiple methods
  Future<void> startDiscovery({
    required Duration timeout,
    required List<String> customSubnets,
    required bool enableMulticast,
    required String operationId,
  }) async {
    try {
      await _parent._printer.channel.invokeMethod('startNetworkDiscovery', {
        'timeout': timeout.inMilliseconds,
        'customSubnets': customSubnets,
        'enableMulticast': enableMulticast,
        'operationId': operationId,
      });
    } catch (e) {
      _parent._logger.error('Network discovery failed to start: $e');
    }
  }
  
  /// Get recommended subnets based on current network
  static List<String> getRecommendedSubnets() {
    // Could be enhanced to detect current network and suggest subnets
    return [
      '192.168.1',
      '192.168.0', 
      '10.0.0',
      '172.20.10', // iPad hotspot
      '192.168.88', // MikroTik default
    ];
  }
  
  /// Check if address is in iPad hotspot range
  static bool isIPadHotspotAddress(String address) {
    return address.startsWith('172.20.10.');
  }
}
```

### Phase 3: Testing Implementation

#### 3.1 iOS Native Tests
```swift
func testNetworkDiscoveryCancellation() {
    let expectation = XCTestExpectation(description: "Discovery cancelled")
    let instance = ZebraPrinterInstance(instanceId: "test", registrar: mockRegistrar)
    
    // Start discovery
    instance.startNetworkDiscovery(
        args: ["timeout": 10000], 
        operationId: "test123"
    ) { _ in }
    
    // Cancel after 500ms
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        instance.cancelDiscovery(operationId: "test123") { _ in
            expectation.fulfill()
        }
    }
    
    wait(for: [expectation], timeout: 2.0)
}

func testConcurrentDiscoveryMethods() {
    // Test that all methods run concurrently
    // Verify timing is under 2.5 seconds total
}
```

#### 3.2 Dart Tests
```dart
test('deduplicates network printers by address:port', () async {
  final discovery = ZebraPrinterDiscovery(printer: mockPrinter);
  
  // Simulate finding same printer via different methods
  discovery._handleNetworkPrinterFound({
    'Address': '192.168.1.100',
    'port': 9100,
    'Name': '192.168.1.100',
    'discoveryMethod': 'localBroadcast',
  });
  
  discovery._handleNetworkPrinterFound({
    'Address': '192.168.1.100', 
    'port': 9100,
    'Name': 'ZEBRA-PRINTER.local',
    'discoveryMethod': 'subnet-192.168.1',
  });
  
  // Should have only one printer with DNS name
  expect(discovery._discoveredPrinters.length, 1);
  expect(discovery._discoveredPrinters.values.first.name, 'ZEBRA-PRINTER.local');
});

test('cancels discovery operations', () async {
  final discovery = ZebraPrinterDiscovery(printer: mockPrinter);
  
  // Start discovery
  final stream = discovery.discoverPrintersStream(
    timeout: Duration(seconds: 10),
  );
  
  // Cancel after 1 second
  Timer(Duration(seconds: 1), () {
    discovery.stopDiscovery();
  });
  
  // Verify stream completes within 2 seconds
  await stream.toList().timeout(Duration(seconds: 2));
});
```

#### 3.3 Integration Tests
```dart
testWidgets('discovers printers on iPad hotspot', (tester) async {
  // Must run on real iPad hotspot
  final discovery = ZebraPrinterDiscovery(printer: realPrinter);
  
  final printers = await discovery.discoverPrintersStream(
    timeout: Duration(seconds: 10),
  ).toList();
  
  // Verify iPad hotspot printers found
  final iPadHotspotPrinters = printers
      .expand((list) => list)
      .where((p) => p.address.startsWith('172.20.10.'));
  
  expect(iPadHotspotPrinters.isNotEmpty, true);
});
```

## Migration Strategy

### Step 1: Native iOS Changes
1. Move `convertDiscoveredPrinters` from ZSDKWrapper to ZebraPrinterInstance
2. Implement cancellable network discovery with DispatchWorkItem
3. Add discovery method metadata to results
4. Ensure proper resource cleanup

### Step 2: Dart Implementation  
1. Update ZebraPrinterDiscovery to handle network discovery
2. Implement deduplication logic
3. Add SGD model enhancement
4. Create internal NetworkDiscovery helper class

### Step 3: Testing
1. Unit tests for all components
2. Integration tests on real iPad hotspot
3. Performance tests for 2.5-second goal
4. Cancellation tests

## Success Criteria

1. ✅ Discovers printers on iPad hotspot (172.20.10.*)
2. ✅ No duplicate printers in results
3. ✅ Discovery completes within 2.5 seconds
4. ✅ Model enhancement doesn't block discovery
5. ✅ Proper cancellation of all operations
6. ✅ Clean resource management
7. ✅ Backwards compatibility maintained

## Key Architecture Benefits

1. **Clean Separation**: Native layer streams raw results, Dart handles logic
2. **Proper Cancellation**: All operations can be cleanly cancelled
3. **Performance**: Concurrent discovery with 2.5-second max time
4. **Comprehensive**: Multiple discovery methods for maximum coverage
5. **Non-blocking**: Model enhancement happens concurrently
6. **Maintainable**: Clear layer responsibilities

## Risk Mitigation

1. **Network Timeout**: Each method has individual timeout
2. **Resource Leaks**: Proper cleanup with cancellation tokens
3. **UI Responsiveness**: All operations on background threads
4. **Backwards Compatibility**: Existing APIs unchanged

## Timeline Estimate

- Native iOS Implementation: 2-3 days
- Dart Implementation: 2-3 days  
- Testing & Integration: 2-3 days
- Total: 6-9 days

## Notes

- All discovery methods justified despite overlaps
- ZSDKWrapper remains a thin wrapper (no changes)
- ZebraPrinterDiscovery handles all Dart-side orchestration
- Proper cancellation using iOS DispatchWorkItem
- SGD enhancement uses existing infrastructure