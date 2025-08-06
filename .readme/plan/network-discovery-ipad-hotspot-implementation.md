# Network Discovery with iPad Hotspot Support - Complete Implementation Plan

## Executive Summary

This plan addresses the issue where network discovery doesn't find printers on iPad hotspot networks. The solution implements multiple channel endpoints for different discovery methods, with Dart managing concurrency and orchestration. This architecture provides better platform flexibility for future Android support.

## Architecture Overview

### Layer Responsibilities

#### **Native iOS Layer** (ZSDKWrapper.m & ZebraPrinterInstance.swift)
- **ZSDKWrapper.m**: Thin wrapper exposing ZSDK discovery methods as-is
- **ZebraPrinterInstance.swift**: 
  - Implements individual discovery method endpoints
  - Each discovery method is a separate channel call
  - **Streams printers as found** via `channel.invokeMethod("printerFound", ...)`
  - Returns completion status with found count
  - **All methods support cancellation** via DispatchWorkItem
  - Simple, focused implementations

#### **ZebraPrinter Layer** (zebra_printer.dart)
- **Primitive Discovery Methods**: Exposes all discovery operations
  - `discoverBTClassic()` - MFi Bluetooth discovery
  - `discoverLocalBroadcast()` - Local network broadcast
  - `discoverSubnet()` - Specific subnet search
  - `discoverDirectedBroadcast()` - Directed broadcast
  - `discoverMulticast()` - Multicast discovery
  - `stopDiscovery()` - Cancel all discovery operations
- **Channel Management**: ALL channel communication happens here
  - No other layer makes direct channel calls
  - Forwards printer found events to controller
  - Handles operation callbacks properly

#### **Dart Layer** (zebra_printer_discovery.dart)
- **ZebraPrinterDiscovery**: Main discovery orchestration
  - Manages concurrent discovery method calls **via ZebraPrinter primitives**
  - Controls which methods to invoke based on platform/config
  - Handles deduplication by address:port
  - Implements SGD model enhancement
  - Provides streaming and batch discovery APIs
  - **NEVER makes direct channel calls**

## Key Requirements from Discussion

### 1. Network Discovery Methods
Despite overlaps, all methods provide unique discovery capabilities:
- **Local Broadcast**: Finds printers on device's current subnet
- **Subnet Search**: Searches specific ranges (172.20.10.* for iPad hotspot)
- **Directed Broadcast**: Reaches remote subnets
- **Multicast**: Multi-hop discovery through routers

### 2. Architecture Decisions
- **Multiple channel endpoints** - Each discovery method is a separate channel call
- **Dart manages concurrency** - Better control and platform flexibility via ZebraPrinter primitives
- **No direct channel calls** - ALL channel operations go through ZebraPrinter
- **Full migration approach** - Replace startScan completely, no deprecation
- **Simple native methods** - Each method does one thing well with cancellation support
- **Streaming results** - Native methods stream printers as they are found, not accumulated
- **SGD enhancement in Dart** - Use CommandFactory pattern for model retrieval
- **Deduplication in Dart** - All results processed in Dart layer

### 3. Performance Goals
- First printer visible: < 1 second (streamed immediately when found)
- Complete discovery: < 2.5 seconds
- Model enhancement: 2-3 seconds after discovery (non-blocking)
- User feedback: Immediate as printers are discovered

### 4. Platform Considerations
- **iOS**: Uses MFi Bluetooth (exposed as "discoverBTClassic" for consistency)
- **Android (future)**: Can add platform-specific methods easily
- **Shared Dart logic**: Discovery orchestration works across platforms

## Implementation Details

### Phase 1: Native iOS Implementation

#### 1.1 Native Model Architecture

##### Create Native Model Types
```swift
// Create ios/Classes/nativeModel/PrinterInfo.swift
import Foundation

@objc public class PrinterInfo: NSObject {
    @objc public let address: String
    @objc public let name: String
    @objc public let status: String
    @objc public let isWifi: Bool
    @objc public let isBluetooth: Bool
    @objc public let connectionType: String
    @objc public let discoveryMethod: String
    
    // Optional properties
    @objc public let model: String?
    @objc public let manufacturer: String?
    @objc public let firmwareRevision: String?
    @objc public let hardwareRevision: String?
    @objc public let displayName: String?
    @objc public let port: Int
    @objc public let dnsName: String?
    
    @objc public init(
        address: String,
        name: String,
        status: String = "Available",
        isWifi: Bool = false,
        isBluetooth: Bool = false,
        connectionType: String = "Unknown",
        discoveryMethod: String = "unknown",
        model: String? = nil,
        manufacturer: String? = "Zebra",
        firmwareRevision: String? = nil,
        hardwareRevision: String? = nil,
        displayName: String? = nil,
        port: Int = 9100,
        dnsName: String? = nil
    ) {
        self.address = address
        self.name = name
        self.status = status
        self.isWifi = isWifi
        self.isBluetooth = isBluetooth
        self.connectionType = connectionType
        self.discoveryMethod = discoveryMethod
        self.model = model
        self.manufacturer = manufacturer
        self.firmwareRevision = firmwareRevision
        self.hardwareRevision = hardwareRevision
        self.displayName = displayName ?? (model != nil ? "Zebra \(model!) - \(name)" : "Zebra Printer - \(name)")
        self.port = port
        self.dnsName = dnsName
    }
    
    @objc public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "Address": address,
            "Name": name,
            "Status": status,
            "IsWifi": isWifi,
            "isBluetooth": isBluetooth,
            "connectionType": connectionType,
            "discoveryMethod": discoveryMethod,
            "port": port
        ]
        
        // Add optional properties if present
        if let model = model { dict["model"] = model }
        if let manufacturer = manufacturer { dict["manufacturer"] = manufacturer }
        if let firmwareRevision = firmwareRevision { dict["firmwareRevision"] = firmwareRevision }
        if let hardwareRevision = hardwareRevision { dict["hardwareRevision"] = hardwareRevision }
        if let displayName = displayName { dict["displayName"] = displayName }
        if let dnsName = dnsName { dict["dnsName"] = dnsName }
        
        return dict
    }
    
    @objc public static func fromDictionary(_ dict: [String: Any]) -> PrinterInfo? {
        guard let address = dict["Address"] as? String,
              let name = dict["Name"] as? String else {
            return nil
        }
        
        return PrinterInfo(
            address: address,
            name: name,
            status: dict["Status"] as? String ?? "Available",
            isWifi: dict["IsWifi"] as? Bool ?? false,
            isBluetooth: dict["isBluetooth"] as? Bool ?? false,
            connectionType: dict["connectionType"] as? String ?? "Unknown",
            discoveryMethod: dict["discoveryMethod"] as? String ?? "unknown",
            model: dict["model"] as? String,
            manufacturer: dict["manufacturer"] as? String,
            firmwareRevision: dict["firmwareRevision"] as? String,
            hardwareRevision: dict["hardwareRevision"] as? String,
            displayName: dict["displayName"] as? String,
            port: dict["port"] as? Int ?? 9100,
            dnsName: dict["dnsName"] as? String
        )
    }
}
```

#### 1.2 ZSDKWrapper.m Updates Needed
Current implementation has:
```objc
// Already implemented:
+ (NSArray *)discoverSubnetPrintersWithRange:(NSString *)subnetRange timeout:(NSInteger)timeout error:(NSError **)error;
+ (NSArray *)discoverDirectedBroadcastWithIp:(NSString *)ipAddress timeout:(NSInteger)timeout error:(NSError **)error;
+ (NSString *)getSetting:(NSString *)setting fromConnection:(id)connection; // For SGD
```

Need to add to ZSDKWrapper.h:
```objc
// Add these method declarations
+ (NSArray *)discoverLocalBroadcastWithTimeout:(NSInteger)timeout error:(NSError **)error;
+ (NSArray *)discoverMulticastWithHops:(NSInteger)hops timeout:(NSInteger)timeout error:(NSError **)error;
```

Need to add to ZSDKWrapper.m:
```objc
// Import NetworkDiscoverer header
#import "NetworkDiscoverer.h"

// Add these method implementations
+ (NSArray *)discoverLocalBroadcastWithTimeout:(NSInteger)timeout error:(NSError **)error {
    return [NetworkDiscoverer localBroadcastWithTimeout:timeout error:error];
}

+ (NSArray *)discoverMulticastWithHops:(NSInteger)hops timeout:(NSInteger)timeout error:(NSError **)error {
    return [NetworkDiscoverer multicastWithHops:hops andWaitForResponsesTimeout:timeout error:error];
}
```

#### 1.3 ZebraPrinterInstance.swift Updates

##### Add Individual Discovery Method Handlers
```swift
// Add imports at top of file
import ExternalAccessory

// MARK: - Discovery Method Handlers

func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    // Existing methods...
    
    // Discovery methods
    case "discoverBTClassic":
        discoverBTClassic(call: call, result: result)
    case "discoverLocalBroadcast":
        discoverLocalBroadcast(call: call, result: result)
    case "discoverSubnet":
        discoverSubnet(call: call, result: result)
    case "discoverDirectedBroadcast":
        discoverDirectedBroadcast(call: call, result: result)
    case "discoverMulticast":
        discoverMulticast(call: call, result: result)
    case "stopScan":
        stopScan(call: call, result: result)
    
    default:
        result(FlutterMethodNotImplemented)
    }
}
```

##### Bluetooth Classic Discovery (MFi on iOS) - Using PrinterInfo
```swift
private func discoverBTClassic(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let timeout = args?["timeout"] as? Int ?? 5000
    let operationId = "btClassic_\(Date().timeIntervalSince1970)"
    
    let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        var foundCount = 0
        
        // MFi Bluetooth discovery using External Accessory
        let accessoryManager = EAAccessoryManager.shared()
        let connectedAccessories = accessoryManager.connectedAccessories
        
        for accessory in connectedAccessories {
            // Check if cancelled or scanning stopped
            guard !self.activeDiscoveryWorkItems[operationId]?.isCancelled ?? false,
                  self.isScanning else { break }
            
            // Check if this is a Zebra printer
            if accessory.protocolStrings.contains("com.zebra.rawport") {
                if let serialNumber = accessory.serialNumber, !serialNumber.isEmpty {
                    // Create PrinterInfo object
                    let printerInfo = PrinterInfo(
                        address: serialNumber,
                        name: accessory.name ?? "Zebra Printer",
                        status: "Available",
                        isWifi: false,
                        isBluetooth: true,
                        connectionType: "bluetooth",
                        discoveryMethod: "btClassic",
                        model: accessory.modelNumber,
                        manufacturer: accessory.manufacturer,
                        firmwareRevision: accessory.firmwareRevision,
                        hardwareRevision: accessory.hardwareRevision
                    )
                    
                    // Stream each printer as it's found
                    DispatchQueue.main.async {
                        guard self.isScanning else { return }
                        self.channel.invokeMethod("printerFound", arguments: printerInfo.toDictionary())
                    }
                    foundCount += 1
                }
            }
        }
        
        // Remove work item when done
        self.activeDiscoveryWorkItems.removeValue(forKey: operationId)
        
        // Send completion with count
        DispatchQueue.main.async {
            result(["foundCount": foundCount])
        }
    }
    
    // Store and execute work item
    activeDiscoveryWorkItems[operationId] = workItem
    discoveryQueue.async(execute: workItem)
}
```

##### Network Discovery Methods
```swift
private func discoverLocalBroadcast(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let timeout = args?["timeout"] as? Int ?? 3000
    let operationId = "localBroadcast_\(Date().timeIntervalSince1970)"
    
    let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        var foundCount = 0
        
        var error: NSError?
        let printers = ZSDKWrapper.discoverLocalBroadcast(withTimeout: timeout, error: &error)
        
        if let error = error {
            self.activeDiscoveryWorkItems.removeValue(forKey: operationId)
            DispatchQueue.main.async {
                result(FlutterError(code: "DISCOVERY_ERROR", 
                                  message: error.localizedDescription, 
                                  details: nil))
            }
            return
        }
        
        let printerInfos = self.convertNetworkPrinters(printers)
        // Stream each printer as it's found
        for printerInfo in printerInfos {
            // Check if cancelled
            guard !self.activeDiscoveryWorkItems[operationId]?.isCancelled ?? false,
                  self.isScanning else { break }
            
            // Override discovery method
            var dict = printerInfo.toDictionary()
            dict["discoveryMethod"] = "localBroadcast"
            
            DispatchQueue.main.async {
                guard self.isScanning else { return }
                self.channel.invokeMethod("printerFound", arguments: dict)
            }
            foundCount += 1
        }
        
        // Remove work item when done
        self.activeDiscoveryWorkItems.removeValue(forKey: operationId)
        
        // Send completion with count
        DispatchQueue.main.async {
            result(["foundCount": foundCount])
        }
    }
    
    // Store and execute work item
    activeDiscoveryWorkItems[operationId] = workItem
    discoveryQueue.async(execute: workItem)
}

private func discoverSubnet(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let subnet = args?["subnet"] as? String ?? "192.168.1"
    let timeout = args?["timeout"] as? Int ?? 1000
    let operationId = "subnet_\(subnet)_\(Date().timeIntervalSince1970)"
    
    let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        var foundCount = 0
        
        var error: NSError?
        let range = "\(subnet).*"
        let printers = ZSDKWrapper.discoverSubnetPrinters(withRange: range, 
                                                         timeout: timeout, 
                                                         error: &error)
        
        if let error = error {
            self.activeDiscoveryWorkItems.removeValue(forKey: operationId)
            DispatchQueue.main.async {
                result(FlutterError(code: "DISCOVERY_ERROR", 
                                  message: error.localizedDescription, 
                                  details: ["subnet": subnet]))
            }
            return
        }
        
        if let printerDicts = self.convertNetworkPrinters(printers) {
            // Stream each printer as it's found
            for printer in printerDicts {
                // Check if cancelled
                guard !self.activeDiscoveryWorkItems[operationId]?.isCancelled ?? false,
                      self.isScanning else { break }
                
                var printerInfo = printer
                printerInfo["discoveryMethod"] = "subnet"
                
                DispatchQueue.main.async {
                    guard self.isScanning else { return }
                    self.channel.invokeMethod("printerFound", arguments: printerInfo)
                }
                foundCount += 1
            }
        }
        
        // Remove work item when done
        self.activeDiscoveryWorkItems.removeValue(forKey: operationId)
        
        // Send completion with count
        DispatchQueue.main.async {
            result(["foundCount": foundCount])
        }
    }
    
    // Store and execute work item
    activeDiscoveryWorkItems[operationId] = workItem
    discoveryQueue.async(execute: workItem)
}

private func discoverDirectedBroadcast(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let ipAddress = args?["ipAddress"] as? String ?? "192.168.1.255"
    let timeout = args?["timeout"] as? Int ?? 1500
    let operationId = "directedBroadcast_\(ipAddress)_\(Date().timeIntervalSince1970)"
    
    let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        var foundCount = 0
        
        var error: NSError?
        let printers = ZSDKWrapper.discoverDirectedBroadcast(withIp: ipAddress, 
                                                            timeout: timeout, 
                                                            error: &error)
        
        if let error = error {
            self.activeDiscoveryWorkItems.removeValue(forKey: operationId)
            DispatchQueue.main.async {
                result(FlutterError(code: "DISCOVERY_ERROR", 
                                  message: error.localizedDescription, 
                                  details: ["ipAddress": ipAddress]))
            }
            return
        }
        
        if let printerDicts = self.convertNetworkPrinters(printers) {
            // Stream each printer as it's found
            for printer in printerDicts {
                // Check if cancelled
                guard !self.activeDiscoveryWorkItems[operationId]?.isCancelled ?? false,
                      self.isScanning else { break }
                
                var printerInfo = printer
                printerInfo["discoveryMethod"] = "directedBroadcast"
                
                DispatchQueue.main.async {
                    guard self.isScanning else { return }
                    self.channel.invokeMethod("printerFound", arguments: printerInfo)
                }
                foundCount += 1
            }
        }
        
        // Remove work item when done
        self.activeDiscoveryWorkItems.removeValue(forKey: operationId)
        
        // Send completion with count
        DispatchQueue.main.async {
            result(["foundCount": foundCount])
        }
    }
    
    // Store and execute work item
    activeDiscoveryWorkItems[operationId] = workItem
    discoveryQueue.async(execute: workItem)
}

private func discoverMulticast(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let hops = args?["hops"] as? Int ?? 2
    let timeout = args?["timeout"] as? Int ?? 2000
    let operationId = "multicast_\(hops)_\(Date().timeIntervalSince1970)"
    
    let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        var foundCount = 0
        
        var error: NSError?
        let printers = ZSDKWrapper.discoverMulticast(withHops: hops, 
                                                    timeout: timeout, 
                                                    error: &error)
        
        if let error = error {
            self.activeDiscoveryWorkItems.removeValue(forKey: operationId)
            DispatchQueue.main.async {
                result(FlutterError(code: "DISCOVERY_ERROR", 
                                  message: error.localizedDescription, 
                                  details: ["hops": hops]))
            }
            return
        }
        
        if let printerDicts = self.convertNetworkPrinters(printers) {
            // Stream each printer as it's found
            for printer in printerDicts {
                // Check if cancelled
                guard !self.activeDiscoveryWorkItems[operationId]?.isCancelled ?? false,
                      self.isScanning else { break }
                
                var printerInfo = printer
                printerInfo["discoveryMethod"] = "multicast"
                
                DispatchQueue.main.async {
                    guard self.isScanning else { return }
                    self.channel.invokeMethod("printerFound", arguments: printerInfo)
                }
                foundCount += 1
            }
        }
        
        // Remove work item when done
        self.activeDiscoveryWorkItems.removeValue(forKey: operationId)
        
        // Send completion with count
        DispatchQueue.main.async {
            result(["foundCount": foundCount])
        }
    }
    
    // Store and execute work item
    activeDiscoveryWorkItems[operationId] = workItem
    discoveryQueue.async(execute: workItem)
}

// Helper to convert network printers to PrinterInfo
private func convertNetworkPrinters(_ printers: [Any]?) -> [PrinterInfo] {
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
        
        return PrinterInfo(
            address: address,
            name: dnsName ?? address,
            status: "Available",
            isWifi: true,
            isBluetooth: false,
            connectionType: "network",
            discoveryMethod: "network", // Will be overridden by caller
            model: nil,
            manufacturer: "Zebra",
            firmwareRevision: nil,
            hardwareRevision: nil,
            displayName: nil,
            port: port,
            dnsName: dnsName
        )
    }
}
```

##### Add Stop Scan Method
```swift
// Track active discovery operations for cancellation
private var activeDiscoveryWorkItems = [String: DispatchWorkItem]()
private let discoveryQueue = DispatchQueue(label: "com.zebrautil.discovery", attributes: .concurrent)

private func stopScan(call: FlutterMethodCall, result: @escaping FlutterResult) {
    LogUtil.info("Stopping all discovery operations")
    
    // Cancel all active discovery work items
    for (operationId, workItem) in activeDiscoveryWorkItems {
        LogUtil.debug("Cancelling discovery operation: \(operationId)")
        workItem.cancel()
    }
    activeDiscoveryWorkItems.removeAll()
    
    // Set scanning flag to false to stop any ongoing operations
    isScanning = false
    
    // Clear discovered printers if needed
    discoveredPrinters.removeAll()
    discoveredMfiPrinters.removeAll()
    
    // Send stop confirmation
    DispatchQueue.main.async {
        self.channel.invokeMethod("onDiscoveryStopped", arguments: nil)
        result(true)
    }
}
```

### Phase 2: Dart Native Model Architecture

#### 2.1 Create Dart Native Model Types

```dart
// Create lib/internal/native_models/printer_info.dart
class NativePrinterInfo {
  final String address;
  final String name;
  final String status;
  final bool isWifi;
  final bool isBluetooth;
  final String connectionType;
  final String discoveryMethod;
  
  // Optional properties
  final String? model;
  final String? manufacturer;
  final String? firmwareRevision;
  final String? hardwareRevision;
  final String? displayName;
  final int port;
  final String? dnsName;
  
  const NativePrinterInfo({
    required this.address,
    required this.name,
    this.status = 'Available',
    this.isWifi = false,
    this.isBluetooth = false,
    this.connectionType = 'Unknown',
    this.discoveryMethod = 'unknown',
    this.model,
    this.manufacturer = 'Zebra',
    this.firmwareRevision,
    this.hardwareRevision,
    this.displayName,
    this.port = 9100,
    this.dnsName,
  });
  
  /// Create from native dictionary
  factory NativePrinterInfo.fromNative(Map<String, dynamic> data) {
    return NativePrinterInfo(
      address: data['Address'] as String? ?? '',
      name: data['Name'] as String? ?? 'Unknown Printer',
      status: data['Status'] as String? ?? 'Available',
      isWifi: data['IsWifi'] == true || data['IsWifi'] == 'true',
      isBluetooth: data['isBluetooth'] == true || data['isBluetooth'] == 'true',
      connectionType: data['connectionType'] as String? ?? 'Unknown',
      discoveryMethod: data['discoveryMethod'] as String? ?? 'unknown',
      model: data['model'] as String?,
      manufacturer: data['manufacturer'] as String? ?? 'Zebra',
      firmwareRevision: data['firmwareRevision'] as String?,
      hardwareRevision: data['hardwareRevision'] as String?,
      displayName: data['displayName'] as String?,
      port: data['port'] as int? ?? 9100,
      dnsName: data['dnsName'] as String?,
    );
  }
  
  /// Convert to native dictionary format
  Map<String, dynamic> toNative() {
    final Map<String, dynamic> dict = {
      'Address': address,
      'Name': name,
      'Status': status,
      'IsWifi': isWifi,
      'isBluetooth': isBluetooth,
      'connectionType': connectionType,
      'discoveryMethod': discoveryMethod,
      'port': port,
    };
    
    // Add optional properties if present
    if (model != null) dict['model'] = model;
    if (manufacturer != null) dict['manufacturer'] = manufacturer;
    if (firmwareRevision != null) dict['firmwareRevision'] = firmwareRevision;
    if (hardwareRevision != null) dict['hardwareRevision'] = hardwareRevision;
    if (displayName != null) dict['displayName'] = displayName;
    if (dnsName != null) dict['dnsName'] = dnsName;
    
    return dict;
  }
  
  /// Convert to ZebraDevice model
  ZebraDevice toZebraDevice() {
    return ZebraDevice(
      address: address,
      name: name,
      status: status,
      isWifi: isWifi,
      isBluetooth: isBluetooth,
      brand: manufacturer ?? 'Zebra',
      model: model,
      displayName: displayName ?? _generateDisplayName(),
      manufacturer: manufacturer ?? 'Zebra',
      firmwareRevision: firmwareRevision,
      hardwareRevision: hardwareRevision,
      connectionType: connectionType,
      port: port,
      dnsName: dnsName,
    );
  }
  
  String _generateDisplayName() {
    if (model != null && model!.isNotEmpty) {
      return 'Zebra $model - $name';
    } else {
      return 'Zebra Printer - $name';
    }
  }
}
```

### Phase 3: ZebraPrinter Primitive Methods

#### 3.1 Add Discovery Primitives to ZebraPrinter

```dart
// In zebra_printer.dart - Add these primitive methods

  // Primitive: Discover MFi Bluetooth (replaces startScan)
  Future<Result<Map<String, dynamic>>> discoverBTClassic({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _logger.info('Starting MFi Bluetooth discovery');
    
    return await ZebraErrorBridge.executeAndHandle<Map<String, dynamic>>(
      operation: () async {
        final result = await _operationManager.execute<Map<String, dynamic>>(
          method: 'discoverBTClassic',
          arguments: {'timeout': timeout.inMilliseconds},
          timeout: timeout,
        );
        
        if (result.success && result.data != null) {
          _logger.info('BT Classic discovery completed: ${result.data}');
          return result.data!;
        } else {
          throw Exception(result.error?.message ?? 'BT Classic discovery failed');
        }
      },
      operationType: OperationType.discovery,
    );
  }

  // Primitive: Local broadcast discovery
  Future<Result<List<Map<String, dynamic>>>> discoverLocalBroadcast({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _logger.info('Starting local broadcast discovery');
    
    return await ZebraErrorBridge.executeAndHandle<List<Map<String, dynamic>>>(
      operation: () async {
        final result = await _operationManager.execute<List<dynamic>>(
          method: 'discoverLocalBroadcast',
          arguments: {'timeout': timeout.inMilliseconds},
          timeout: timeout,
        );
        
        if (result.success && result.data != null) {
          final printers = result.data!.cast<Map<String, dynamic>>();
          _logger.info('Local broadcast found ${printers.length} printers');
          return printers;
        } else {
          throw Exception(result.error?.message ?? 'Local broadcast discovery failed');
        }
      },
      operationType: OperationType.discovery,
    );
  }

  // Primitive: Subnet discovery
  Future<Result<List<Map<String, dynamic>>>> discoverSubnet({
    required String subnet,
    Duration timeout = const Duration(seconds: 1),
  }) async {
    _logger.info('Starting subnet discovery for $subnet');
    
    return await ZebraErrorBridge.executeAndHandle<List<Map<String, dynamic>>>(
      operation: () async {
        final result = await _operationManager.execute<List<dynamic>>(
          method: 'discoverSubnet',
          arguments: {
            'subnet': subnet,
            'timeout': timeout.inMilliseconds,
          },
          timeout: timeout,
        );
        
        if (result.success && result.data != null) {
          final printers = result.data!.cast<Map<String, dynamic>>();
          _logger.info('Subnet $subnet found ${printers.length} printers');
          return printers;
        } else {
          throw Exception(result.error?.message ?? 'Subnet discovery failed');
        }
      },
      operationType: OperationType.discovery,
    );
  }

  // Primitive: Multicast discovery
  Future<Result<List<Map<String, dynamic>>>> discoverMulticast({
    int hops = 4,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    _logger.info('Starting multicast discovery with $hops hops');
    
    return await ZebraErrorBridge.executeAndHandle<List<Map<String, dynamic>>>(
      operation: () async {
        final result = await _operationManager.execute<List<dynamic>>(
          method: 'discoverMulticast',
          arguments: {
            'hops': hops,
            'timeout': timeout.inMilliseconds,
          },
          timeout: timeout,
        );
        
        if (result.success && result.data != null) {
          final printers = result.data!.cast<Map<String, dynamic>>();
          _logger.info('Multicast found ${printers.length} printers');
          return printers;
        } else {
          throw Exception(result.error?.message ?? 'Multicast discovery failed');
        }
      },
      operationType: OperationType.discovery,
    );
  }

  // Primitive: Stop all discovery operations
  Future<Result<void>> stopDiscovery() async {
    _logger.info('Stopping all discovery operations');
    
    return await ZebraErrorBridge.executeAndHandle<void>(
      operation: () async {
        final result = await _operationManager.execute<bool>(
          method: 'stopScan',
          arguments: {},
          timeout: const Duration(seconds: 5),
        );
        
        if (result.success) {
          _logger.info('Discovery operations stopped successfully');
          return;
        } else {
          throw Exception(result.error?.message ?? 'Failed to stop discovery');
        }
      },
      operationType: OperationType.discovery,
    );
  }
```

### Phase 3: Dart Implementation

#### 3.1 Update ZebraPrinterDiscovery

##### Core Discovery Orchestration
```dart
// Required imports
import 'dart:io' show Platform;
import 'internal/commands/command_factory.dart';

class ZebraPrinterDiscovery {
  // Track discovered printers with deduplication
  final Map<String, ZebraDevice> _discoveredPrinters = {};
  final Map<String, Set<String>> _printerDiscoveryMethods = {};
  
  // Active discovery futures for cancellation
  final List<Future> _activeDiscoveryFutures = [];
  
  /// Enhanced discovery with network support - Dart manages concurrency
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
    
    // Clear previous results
    _discoveredPrinters.clear();
    _printerDiscoveryMethods.clear();
    _activeDiscoveryFutures.clear();
    
    // Create stream controller for results
    final streamController = StreamController<List<ZebraDevice>>();
    bool isStopped = false;
    
    // Listen to printer found events from ZebraPrinter controller
    // The ZebraPrinter will handle channel callbacks and update controller
    _printer.controller.addListener(() {
      if (!isStopped && _printer.controller.printers.isNotEmpty) {
        // Process any new printers added to controller
        for (final printer in _printer.controller.printers) {
          final key = '${printer.address}:${printer.port ?? 9100}';
          if (!_discoveredPrinters.containsKey(key)) {
            _handleStreamedPrinter(printer.toJson());
            streamController.add(_discoveredPrinters.values.toList());
          }
        }
      }
    });
    
    // Start concurrent discovery methods
    if (includeBluetooth) {
      // Call native MFi Bluetooth discovery (replaces old startScan)
      _activeDiscoveryFutures.add(
        _discoverBTClassic(timeout).then((result) {
          // BTClassic streams results via printerFound, just track completion
          _logger.debug('BT Classic discovery completed: $result');
        }).catchError((e) {
          _logger.warning('BT Classic discovery failed: $e');
        })
      );
    }
    
    if (includeWifi) {
      // Local broadcast
      _activeDiscoveryFutures.add(
        _discoverLocalBroadcast(timeout: Duration(seconds: 3)).then((devices) {
          if (!isStopped) _addDevices(devices, 'localBroadcast');
        }).catchError((e) {
          _logger.warning('Local broadcast discovery failed: $e');
        })
      );
      
      // iPad hotspot subnet (CRITICAL)
      _activeDiscoveryFutures.add(
        _discoverSubnet('172.20.10', timeout: Duration(milliseconds: 800)).then((devices) {
          if (!isStopped) _addDevices(devices, 'iPadHotspot');
        }).catchError((e) {
          _logger.warning('iPad hotspot discovery failed: $e');
        })
      );
      
      // Common subnets
      final commonSubnets = ['192.168.1', '192.168.0', '10.0.0', '192.168.88'];
      for (final subnet in commonSubnets) {
        _activeDiscoveryFutures.add(
          _discoverSubnet(subnet, timeout: Duration(milliseconds: 500)).then((devices) {
            if (!isStopped) _addDevices(devices, 'subnet-$subnet');
          }).catchError((e) {
            _logger.debug('Subnet $subnet discovery failed: $e');
          })
        );
      }
      
      // Custom subnets
      if (customSubnets != null) {
        for (final subnet in customSubnets) {
          _activeDiscoveryFutures.add(
            _discoverSubnet(subnet, timeout: Duration(milliseconds: 500)).then((devices) {
              if (!isStopped) _addDevices(devices, 'customSubnet-$subnet');
            }).catchError((e) {
              _logger.debug('Custom subnet $subnet discovery failed: $e');
            })
          );
        }
      }
      
      // Multicast (optional)
      if (enableMulticast) {
        _activeDiscoveryFutures.add(
          _discoverMulticast(hops: 2, timeout: Duration(seconds: 2)).then((devices) {
            if (!isStopped) _addDevices(devices, 'multicast');
          }).catchError((e) {
            _logger.warning('Multicast discovery failed: $e');
          })
        );
      }
    }
    
    // Monitor results and check stop criteria
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      final currentDevices = _discoveredPrinters.values.toList();
      
      // Check stop criteria
      if ((stopOnFirstPrinter && currentDevices.isNotEmpty) ||
          (stopAfterCount != null && currentDevices.length >= stopAfterCount)) {
        timer.cancel();
        isStopped = true;
        _cancelActiveDiscovery();
      }
      
      // Stream current state
      if (!streamController.isClosed) {
        streamController.add(currentDevices);
      }
    });
    
    // Set overall timeout
    Future.delayed(timeout, () {
      isStopped = true;
      _cancelActiveDiscovery();
      streamController.close();
    });
    
    yield* streamController.stream;
  }
  
  // Individual discovery methods that call native endpoints
  
  Future<Map<String, dynamic>> _discoverBTClassic(Duration timeout) async {
    try {
      // This replaces the old startScan method - now explicitly for MFi Bluetooth
      final result = await _printer.discoverBTClassic(
        timeout: timeout,
      );
      
      if (result.success) {
        // Returns completion info - printers are streamed via controller
        return result.data ?? {'foundCount': 0};
      } else {
        _logger.error('BT Classic discovery error: ${result.error?.message}');
        return {'foundCount': 0, 'error': result.error?.message};
      }
    } catch (e) {
      _logger.error('BT Classic discovery error: $e');
      return {'foundCount': 0, 'error': e.toString()};
    }
  }
  
  Future<List<ZebraDevice>> _discoverLocalBroadcast({required Duration timeout}) async {
    try {
      final result = await _printer.discoverLocalBroadcast(
        timeout: timeout,
      );
      
      if (result.success) {
        return _parseDiscoveryResults(result.data);
      } else {
        _logger.error('Local broadcast discovery error: ${result.error?.message}');
        return [];
      }
    } catch (e) {
      _logger.error('Local broadcast discovery error: $e');
      return [];
    }
  }
  
  Future<List<ZebraDevice>> _discoverSubnet(String subnet, {required Duration timeout}) async {
    try {
      final result = await _printer.discoverSubnet(
        subnet: subnet,
        timeout: timeout,
      );
      
      if (result.success) {
        return _parseDiscoveryResults(result.data);
      } else {
        _logger.error('Subnet $subnet discovery error: ${result.error?.message}');
        return [];
      }
    } catch (e) {
      _logger.error('Subnet $subnet discovery error: $e');
      return [];
    }
  }
  
  Future<List<ZebraDevice>> _discoverMulticast({required int hops, required Duration timeout}) async {
    try {
      final result = await _printer.discoverMulticast(
        hops: hops,
        timeout: timeout,
      );
      
      if (result.success) {
        return _parseDiscoveryResults(result.data);
      } else {
        _logger.error('Multicast discovery error: ${result.error?.message}');
        return [];
      }
    } catch (e) {
      _logger.error('Multicast discovery error: $e');
      return [];
    }
  }
  
  List<ZebraDevice> _parseDiscoveryResults(dynamic result) {
    if (result == null || result is! List) return [];
    
    return result
        .where((item) => item is Map)
        .map((item) => ZebraDevice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
  
  void _addDevices(List<ZebraDevice> devices, String discoveryMethod) {
    for (final device in devices) {
      final key = '${device.address}:${device.port ?? 9100}';
      
      // Deduplication
      if (_discoveredPrinters.containsKey(key)) {
        final existing = _discoveredPrinters[key]!;
        final merged = _mergeDevices(existing, device);
        _discoveredPrinters[key] = merged;
        
        // Track discovery methods
        _printerDiscoveryMethods[key] ??= {};
        _printerDiscoveryMethods[key]!.add(discoveryMethod);
      } else {
        _discoveredPrinters[key] = device;
        _printerDiscoveryMethods[key] = {discoveryMethod};
        
        // Start model enhancement concurrently
        _enhanceDeviceModel(device);
      }
    }
  }
  
  void _handleStreamedPrinter(Map<String, dynamic> printerData) {
    final device = ZebraDevice.fromJson(printerData);
    final key = '${device.address}:${device.port ?? 9100}';
    final discoveryMethod = printerData['discoveryMethod'] as String? ?? 'unknown';
    
    // Deduplication
    if (_discoveredPrinters.containsKey(key)) {
      final existing = _discoveredPrinters[key]!;
      final merged = _mergeDevices(existing, device);
      _discoveredPrinters[key] = merged;
      
      // Track discovery methods
      _printerDiscoveryMethods[key] ??= {};
      _printerDiscoveryMethods[key]!.add(discoveryMethod);
    } else {
      _discoveredPrinters[key] = device;
      _printerDiscoveryMethods[key] = {discoveryMethod};
      
      // Start model enhancement concurrently
      _enhanceDeviceModel(device);
    }
  }
  
  void _cancelActiveDiscovery() {
    // Note: Individual channel calls complete independently
    // No explicit cancellation needed with this architecture
    _activeDiscoveryFutures.clear();
  }
  
  /// Stop all discovery operations
  Future<void> stopDiscovery() async {
    _cancelActiveDiscovery();
    
    // Call ZebraPrinter primitive to stop all discovery operations
    final result = await _printer.stopDiscovery();
    if (!result.success) {
      _logger.warning('Failed to stop discovery: ${result.error?.message}');
    }
    
    _isScanning = false;
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
        // Get model using CommandFactory pattern
        final getModelCommand = CommandFactory.createGetSettingCommand(
          tempPrinter, 
          'appl.name'
        );
        final modelResult = await getModelCommand.execute();
        
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



### Phase 3: Testing Implementation

#### 3.1 iOS Native Tests
```swift
func testIndividualDiscoveryMethods() {
    let expectation = XCTestExpectation(description: "Discovery completed")
    let instance = ZebraPrinterInstance(instanceId: "test", registrar: mockRegistrar)
    
    // Test BT Classic discovery
    instance.discoverBTClassic(call: FlutterMethodCall(methodName: "discoverBTClassic", arguments: ["timeout": 5000])) { result in
        XCTAssertTrue(result is [String: Any])
        XCTAssertNotNil((result as? [String: Any])?["foundCount"])
    }
    
    // Test local broadcast
    instance.discoverLocalBroadcast(call: FlutterMethodCall(methodName: "discoverLocalBroadcast", arguments: ["timeout": 3000])) { result in
        XCTAssertTrue(result is [String: Any])
    }
    
    // Test subnet discovery
    instance.discoverSubnet(call: FlutterMethodCall(methodName: "discoverSubnet", arguments: ["subnet": "172.20.10", "timeout": 1000])) { result in
        XCTAssertTrue(result is [String: Any])
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
}

func testStopScanCancelsAllOperations() {
    let instance = ZebraPrinterInstance(instanceId: "test", registrar: mockRegistrar)
    
    // Start multiple discovery operations
    instance.discoverBTClassic(call: FlutterMethodCall(methodName: "discoverBTClassic", arguments: ["timeout": 10000])) { _ in }
    instance.discoverLocalBroadcast(call: FlutterMethodCall(methodName: "discoverLocalBroadcast", arguments: ["timeout": 10000])) { _ in }
    instance.discoverSubnet(call: FlutterMethodCall(methodName: "discoverSubnet", arguments: ["subnet": "192.168.1", "timeout": 10000])) { _ in }
    
    // Verify operations are tracked
    XCTAssertGreaterThan(instance.activeDiscoveryWorkItems.count, 0)
    
    // Stop all operations
    let stopExpectation = XCTestExpectation(description: "Stop completed")
    instance.stopScan(call: FlutterMethodCall(methodName: "stopScan", arguments: nil)) { result in
        XCTAssertEqual(result as? Bool, true)
        stopExpectation.fulfill()
    }
    
    wait(for: [stopExpectation], timeout: 1.0)
    
    // Verify all operations are cancelled
    XCTAssertEqual(instance.activeDiscoveryWorkItems.count, 0)
    XCTAssertFalse(instance.isScanning)
}
```

#### 3.2 Dart Tests
```dart
test('handles streamed printer results', () async {
  final discovery = ZebraPrinterDiscovery(printer: mockPrinter);
  
  // Start discovery stream
  final streamSubscription = discovery.discoverPrintersStream(
    timeout: Duration(seconds: 5),
  ).listen((devices) {
    // Verify devices appear as they are streamed
  });
  
  // Simulate native layer streaming printers
  await mockPrinter.channel.invokeMethod('printerFound', {
    'Address': '192.168.1.100',
    'port': 9100,
    'Name': 'First Printer',
    'discoveryMethod': 'localBroadcast',
  });
  
  // Verify printer appears immediately
  await Future.delayed(Duration(milliseconds: 100));
  expect(discovery._discoveredPrinters.length, 1);
  
  // Simulate another printer found
  await mockPrinter.channel.invokeMethod('printerFound', {
    'Address': '172.20.10.5',
    'port': 9100,
    'Name': 'iPad Hotspot Printer',
    'discoveryMethod': 'subnet-172.20.10',
  });
  
  // Verify both printers present
  await Future.delayed(Duration(milliseconds: 100));
  expect(discovery._discoveredPrinters.length, 2);
  
  await streamSubscription.cancel();
});

test('concurrent discovery with multiple methods', () async {
  final discovery = ZebraPrinterDiscovery(printer: mockPrinter);
  
  // Mock channel method calls
  when(mockPrinter.channel.invokeMethod('discoverBTClassic', any))
      .thenAnswer((_) async => {"foundCount": 1});
      
  when(mockPrinter.channel.invokeMethod('discoverLocalBroadcast', any))
      .thenAnswer((_) async => [
        {'Address': '192.168.1.100', 'port': 9100, 'Name': 'Network Printer'}
      ]);
      
  when(mockPrinter.channel.invokeMethod('discoverSubnet', any))
      .thenAnswer((invocation) async {
        final args = invocation.positionalArguments[1];
        if (args['subnet'] == '172.20.10') {
          return [
            {'Address': '172.20.10.5', 'port': 9100, 'Name': 'iPad Hotspot Printer'}
          ];
        }
        return [];
      });
  
  // Start discovery stream
  final devices = <List<ZebraDevice>>[];
  final sub = discovery.discoverPrintersStream(
    timeout: Duration(seconds: 2),
    includeWifi: true,
    includeBluetooth: true,
  ).listen(devices.add);
  
  // Allow time for discovery
  await Future.delayed(Duration(milliseconds: 500));
  
  // Verify all methods were called concurrently
  verify(mockPrinter.channel.invokeMethod('discoverBTClassic', any)).called(1);
  verify(mockPrinter.channel.invokeMethod('discoverLocalBroadcast', any)).called(1);
  verify(mockPrinter.channel.invokeMethod('discoverSubnet', argThat(
    predicate((arg) => arg['subnet'] == '172.20.10'),
  ))).called(1);
  
  // Verify devices were found
  expect(devices.isNotEmpty, true);
  final lastUpdate = devices.last;
  expect(lastUpdate.any((d) => d.address == 'BT001'), true);
  expect(lastUpdate.any((d) => d.address == '192.168.1.100'), true);
  expect(lastUpdate.any((d) => d.address == '172.20.10.5'), true);
  
  await sub.cancel();
});

test('deduplicates network printers by address:port', () async {
  final discovery = ZebraPrinterDiscovery(printer: mockPrinter);
  
  // Simulate finding same printer via different methods
  discovery._addDevices([
    ZebraDevice(address: '192.168.1.100', port: 9100, name: '192.168.1.100'),
  ], 'localBroadcast');
  
  discovery._addDevices([
    ZebraDevice(address: '192.168.1.100', port: 9100, 
                name: 'zebra-printer.local', dnsName: 'zebra-printer.local'),
  ], 'multicast');
  
  // Should have only one printer with merged data
  expect(discovery._discoveredPrinters.length, 1);
  
  final printer = discovery._discoveredPrinters.values.first;
  expect(printer.name, 'zebra-printer.local'); // DNS name preferred
  expect(discovery._printerDiscoveryMethods['192.168.1.100:9100'], 
         {'localBroadcast', 'multicast'});
});

test('stopDiscovery cancels all operations', () async {
  final discovery = ZebraPrinterDiscovery(printer: mockPrinter);
  
  // Mock stopScan method
  when(mockPrinter.channel.invokeMethod('stopScan'))
      .thenAnswer((_) async => true);
  
  // Start discovery
  final streamFuture = discovery.discoverPrintersStream(
    timeout: Duration(seconds: 10),
  ).toList();
  
  // Simulate some printers being found
  await Future.delayed(Duration(milliseconds: 500));
  
  // Stop discovery
  await discovery.stopDiscovery();
  
  // Verify stopScan was called
  verify(mockPrinter.channel.invokeMethod('stopScan')).called(1);
  
  // Verify stream completes quickly after stop
  await streamFuture.timeout(Duration(seconds: 1));
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
1. Add missing methods to ZSDKWrapper.h/m (local broadcast, multicast)
2. **REMOVE** `startScan` method completely - full migration to individual discovery methods
3. Add individual discovery method handlers to ZebraPrinterInstance.swift
4. Implement `discoverBTClassic` (EAAccessoryManager), `discoverLocalBroadcast`, `discoverSubnet`, `discoverDirectedBroadcast`, `discoverMulticast`
5. Add `stopScan` method to cancel all active discovery operations
6. Move `convertNetworkPrinters` to ZebraPrinterInstance (if exists in wrapper)
7. Each method streams printers as found via `printerFound` channel
8. All methods support cancellation via DispatchWorkItem

### Step 2: ZebraPrinter Primitive Methods
1. Add all discovery primitive methods to ZebraPrinter
2. Each method uses ZebraErrorBridge for proper error handling
3. All channel communication happens only in ZebraPrinter
4. Forward printer found events to controller

### Step 3: Dart Implementation  
1. Update ZebraPrinterDiscovery to call ZebraPrinter primitives (NO direct channel calls)
2. Listen to ZebraPrinter controller for printer found events
3. Implement concurrent discovery management in Dart
4. Add deduplication logic by address:port
5. Implement SGD model enhancement using CommandFactory pattern
6. Stream results as printers are found

### Step 4: Testing
1. Unit tests for all components
2. Integration tests on real iPad hotspot
3. Performance tests for 2.5-second goal
4. Cancellation tests

## Success Criteria

1. ✅ Discovers printers on iPad hotspot (172.20.10.*)
2. ✅ Printers appear immediately as they are discovered (streamed)
3. ✅ No duplicate printers in results
4. ✅ Discovery completes within 2.5 seconds
5. ✅ Model enhancement doesn't block discovery
6. ✅ Proper cancellation of all operations via stopScan
7. ✅ Clean resource management
8. ✅ Full migration completed (no deprecated code)
9. ✅ Individual discovery methods callable from Dart via ZebraPrinter primitives
10. ✅ All channel operations go through ZebraPrinter only

## Implementation Checklist

### iOS Native Layer
- [ ] Create `ios/Classes/nativeModel/` folder
- [ ] Create `PrinterInfo.swift` native model class
- [ ] Add missing methods to ZSDKWrapper.h/m:
  - [ ] `discoverLocalBroadcastWithTimeout:error:`
  - [ ] `discoverMulticastWithHops:timeout:error:`
- [ ] **REMOVE** `startScan` method completely from ZebraPrinterInstance.swift
- [ ] Add method handlers in ZebraPrinterInstance.swift:
  - [ ] `discoverBTClassic` (using EAAccessoryManager) with DispatchWorkItem
  - [ ] `discoverLocalBroadcast` with DispatchWorkItem
  - [ ] `discoverSubnet` with DispatchWorkItem
  - [ ] `discoverDirectedBroadcast` with DispatchWorkItem
  - [ ] `discoverMulticast` with DispatchWorkItem
  - [ ] `stopScan` - cancels all active discovery operations
- [ ] Update `convertNetworkPrinters` to return `[PrinterInfo]`
- [ ] Update all discovery methods to use `PrinterInfo` instead of dictionaries
- [ ] Update method routing in handle()
- [ ] Add discovery work item tracking for cancellation

### ZebraPrinter Primitives
- [ ] Add `discoverBTClassic()` primitive method
- [ ] Add `discoverLocalBroadcast()` primitive method
- [ ] Add `discoverSubnet()` primitive method
- [ ] Add `discoverDirectedBroadcast()` primitive method (if needed)
- [ ] Add `discoverMulticast()` primitive method
- [ ] Add `stopDiscovery()` primitive method
- [ ] All methods use ZebraErrorBridge for error handling
- [ ] All methods use _operationManager for channel calls

### Dart Native Model Layer
- [ ] Create `lib/internal/native_models/` folder
- [ ] Create `printer_info.dart` native model class
- [ ] Add `fromNative()` factory for converting from native dictionaries
- [ ] Add `toNative()` method for converting to native format
- [ ] Add `toZebraDevice()` method for converting to app models

### Dart Layer
- [ ] **NO direct channel calls** - all operations via ZebraPrinter primitives
- [ ] Update ZebraPrinter to use `NativePrinterInfo` for type safety
- [ ] Replace startScan usage with `discoverBTClassic()` calls
- [ ] Listen to ZebraPrinter controller for printer found events
- [ ] Implement concurrent discovery management
- [ ] Add _handleStreamedPrinter for controller events
- [ ] Add _addDevices deduplication logic
- [ ] Update stream controller logic
- [ ] Add discovery method tracking
- [ ] Update stopDiscovery to call ZebraPrinter.stopDiscovery()
- [ ] Implement SGD model enhancement with CommandFactory

### Testing
- [ ] iOS unit tests for each discovery method
- [ ] iOS unit tests for streaming printers via `printerFound`
- [ ] iOS unit tests for stopScan cancelling all operations
- [ ] Dart unit tests for handling streamed printer results
- [ ] Dart unit tests for concurrent discovery
- [ ] Dart unit tests for deduplication
- [ ] Dart unit tests for stopDiscovery
- [ ] Integration tests on real iPad hotspot
- [ ] Performance tests (< 2.5s)
- [ ] UX tests for immediate printer visibility

## Key Architecture Benefits

1. **Platform Flexibility**: Each platform can implement discovery differently
2. **Dart Control**: Discovery orchestration in Dart for consistency
3. **Streaming Results**: Native layer streams printers as found for better UX
4. **Real-time Updates**: Users see printers immediately as they are discovered
5. **Simple Native Layer**: Each method does one thing well
6. **Performance**: Concurrent discovery with 2.5-second max time
7. **Future Android Support**: Easy to add platform-specific methods
8. **Maintainable**: Clear separation of concerns

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

- **Architecture Change**: Moved from single streaming channel to multiple method endpoints
- **Full Migration**: startScan completely removed, replaced by individual discovery methods
- **No Deprecation**: Following codebase rules - no deprecated code, full migration only
- **Channel Calls**: ALL channel operations go through ZebraPrinter - NO direct channel calls elsewhere
- **stopScan Added**: New unified method to cancel all active discovery operations
- **Streaming Discovery**: Each native method streams printers via `printerFound` as they are discovered
- **Real-time Results**: Printers appear in UI immediately, not after discovery completes
- **Naming Convention**: Using "BT Classic" for consistency, even though iOS uses MFi
- **Android Ready**: This architecture makes Android implementation straightforward
- **No BLE/BT LTE Support**: ZSDK v1.6.1158 does not provide Bluetooth Low Energy support on iOS
- **MFi Bluetooth Only**: iOS uses External Accessory framework for already-paired printers
- **Network Discovery Methods**: All use NetworkDiscoverer class from ZSDK
- **Missing Wrapper Methods**: Need to add local broadcast and multicast to ZSDKWrapper
- **All discovery methods justified despite overlaps** - they can find different printers
- **ZebraPrinterDiscovery handles all orchestration** - manages concurrent calls via ZebraPrinter primitives
- **Cancellation Support**: ALL methods use DispatchWorkItem for proper cancellation
- **SGD enhancement uses CommandFactory pattern** - per command usage guide
- **Deduplication by address:port** - same printer via multiple methods merged
- **ZebraErrorBridge**: All ZebraPrinter primitives use proper error handling
- **Native Model Architecture**: Strong typing with PrinterInfo/NativePrinterInfo for type safety
- **Model Synchronization**: Native and Dart models mirror each other for consistency