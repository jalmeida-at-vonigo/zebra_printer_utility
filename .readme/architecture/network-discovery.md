# Network Discovery Architecture

_Last updated: 2024-12-20_

## Overview

The Zebra printer plugin implements a comprehensive network discovery system that uses multiple concurrent discovery methods to ensure printers are found across various network configurations, including iPad hotspots.

## Discovery Methods

### 1. Bluetooth Classic (MFi)
- **Platform**: iOS only
- **Method**: `discoverBTClassic`
- **Implementation**: Uses ExternalAccessory framework to find paired MFi devices
- **Timeout**: 10 seconds default
- **Use Case**: Previously paired Zebra printers via iOS Bluetooth settings

### 2. Local Broadcast
- **Platform**: iOS, Android (planned)
- **Method**: `discoverLocalBroadcast`
- **Implementation**: Uses ZSDK `NetworkDiscoverer.localBroadcast`
- **Timeout**: 10 seconds default
- **Use Case**: Standard local network discovery

### 3. Subnet Search
- **Platform**: iOS, Android (planned)
- **Method**: `discoverSubnet`
- **Implementation**: Uses ZSDK `NetworkDiscoverer.subnetSearch`
- **Default Subnet**: 192.168.1.*
- **iPad Hotspot**: Explicitly includes 172.20.10.*
- **Timeout**: 10 seconds default
- **Use Case**: Targeted subnet scanning

### 4. Directed Broadcast
- **Platform**: iOS, Android (planned)
- **Method**: `discoverDirectedBroadcast`
- **Implementation**: Uses ZSDK `NetworkDiscoverer.directedBroadcast`
- **Default IP**: 255.255.255.255
- **iPad Hotspot**: Includes 172.20.10.255
- **Timeout**: 10 seconds default
- **Use Case**: Networks where local broadcast is blocked

### 5. Multicast
- **Platform**: iOS, Android (planned)
- **Method**: `discoverMulticast`
- **Implementation**: Uses ZSDK `NetworkDiscoverer.multicast`
- **Default Hops**: 5
- **Timeout**: 10 seconds default
- **Use Case**: Multi-hop network discovery

## Architecture Layers

### Native Layer (iOS)

```
┌─────────────────────────┐
│ ZebraPrinterInstance    │ ← Channel Handler
├─────────────────────────┤
│ - discoverBTClassic     │
│ - discoverLocalBroadcast│
│ - discoverSubnet        │
│ - discoverDirectedBcast │
│ - discoverMulticast     │
│ - stopScan              │
└─────────────────────────┘
           │
           ▼
┌─────────────────────────┐
│     ZSDKWrapper         │ ← Thin ZSDK Wrapper
├─────────────────────────┤
│ - Pass-through methods  │
│ - No business logic     │
└─────────────────────────┘
           │
           ▼
┌─────────────────────────┐
│    Zebra Link-OS SDK    │ ← Native SDK
└─────────────────────────┘
```

### Dart Layer

```
┌─────────────────────────┐
│ ZebraPrinterDiscovery   │ ← Public API
├─────────────────────────┤
│ - discoverPrintersStream│
│ - discoverPrinters      │
│ - stopDiscovery         │
└─────────────────────────┘
           │
           ▼
┌─────────────────────────┐
│    ZebraPrinter         │ ← Channel Operations
├─────────────────────────┤
│ - discoverBTClassic()   │
│ - discoverLocalBcast()  │
│ - discoverSubnet()      │
│ - discoverDirected()    │
│ - discoverMulticast()   │
│ - stopDiscovery()       │
└─────────────────────────┘
```

## Concurrent Execution

All discovery methods run concurrently to minimize discovery time:

```dart
// In ZebraPrinterDiscovery
await Future.wait([
  _printer.discoverBTClassic(),
  _printer.discoverLocalBroadcast(),
  _printer.discoverSubnet(subnet: _currentSubnet),
  _printer.discoverSubnet(subnet: '172.20.10'), // iPad hotspot
  _printer.discoverDirectedBroadcast(broadcastIp: _broadcastIp),
  _printer.discoverMulticast(),
]);
```

## Streaming Architecture

### Native → Dart Flow
1. Native discovery method finds a printer
2. Native immediately sends `printerFound` event via channel
3. Dart receives event and converts to `ZebraDevice`
4. Dart adds device to stream controller
5. UI receives real-time update

### Benefits
- First printer visible in < 1 second
- Progressive discovery updates
- Better user experience
- No waiting for full discovery completion

## Cancellation Support

### Native Implementation
```swift
// Each discovery method uses DispatchWorkItem
let workItem = DispatchWorkItem { [weak self] in
    // Discovery logic here
}
activeDiscoveryWorkItems.append(workItem)
discoveryQueue.async(execute: workItem)

// Unified cancellation
func stopScan() {
    for workItem in activeDiscoveryWorkItems {
        workItem.cancel()
    }
    activeDiscoveryWorkItems.removeAll()
}
```

### Dart Implementation
```dart
// Stop all discovery operations
await _printer.stopDiscovery();
```

## iPad Hotspot Support

### Problem
iPad creates a Personal Hotspot network on 172.20.10.* subnet, which is not covered by standard discovery methods.

### Solution
Explicitly include iPad hotspot ranges:
- Subnet search: 172.20.10.*
- Directed broadcast: 172.20.10.255

### Implementation
```dart
// Always search iPad hotspot subnet
await _printer.discoverSubnet(subnet: '172.20.10');
```

## Deduplication

Printers may be discovered by multiple methods. Deduplication occurs in Dart:

```dart
// In ZebraPrinterDiscovery
final uniqueDevices = <String, ZebraDevice>{};
for (final device in allDevices) {
  final key = '${device.address}:${device.port}';
  uniqueDevices[key] = device;
}
```

## Performance Metrics

### Sequential (Old)
- Total time: 5+ seconds
- UI blocking
- No intermediate results

### Concurrent (New)
- Total time: < 2.5 seconds
- Non-blocking
- Real-time streaming
- First result: < 1 second

## Error Handling

Each discovery method handles errors independently:
- Network errors don't stop other methods
- Timeout errors are expected and handled
- Results are aggregated regardless of individual failures

## Future Enhancements

### Android Implementation
- Follow same architecture
- Use Android-specific discovery APIs
- Maintain API compatibility

### Additional Methods
- DNS-SD for service discovery
- Custom port scanning
- Bluetooth LE support
- Network interface detection

## Related Documents
- [Native Layer Standards](../../.cursor/rules/native/native-layer-standards.mdc)
- [Implementation Plan](../plan/network-discovery-ipad-hotspot-implementation.md)
- [API Documentation](../api/README.md)