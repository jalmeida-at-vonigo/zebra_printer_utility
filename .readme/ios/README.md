# iOS Setup for Zebra Printer Plugin

## Required Setup

### 1. Info.plist Configuration

Add the following entries to your iOS app's `Info.plist` file:

```xml
<!-- External Accessory Protocol -->
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>com.zebra.rawport</string>
</array>

<!-- Bluetooth Usage Description -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to discover and connect to Zebra printers</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth access to communicate with Zebra printers</string>

<!-- Local Network Usage Description (for network printer discovery) -->
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs local network access to discover network printers</string>

<!-- Bonjour Services (for network discovery) -->
<key>NSBonjourServices</key>
<array>
    <string>_printer._tcp</string>
    <string>_ipp._tcp</string>
</array>
```

### 2. Background Modes (Optional)

If you need to print while the app is in the background, add:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>external-accessory</string>
</array>
```

### 3. Capabilities

In Xcode, enable the following capabilities:
- External Accessory (for Bluetooth printers)
- Background Modes > External accessory communication (if needed)

### 4. Framework Requirements

The plugin includes the Zebra Link-OS SDK (ZSDK_API.xcframework) which requires:
- iOS 12.0 or later
- Swift 5.0 or later

## Usage

The iOS implementation provides full support for:
- Bluetooth printer discovery and connection
- Network printer discovery (local broadcast, multicast)
- ZPL command printing
- Printer status monitoring
- Thread-safe operations
- Proper error handling

## Troubleshooting

### Bluetooth Discovery Issues
- Ensure Bluetooth is enabled on the device
- Check that the printer is paired in iOS Settings
- Verify the External Accessory protocols are correctly configured

### Network Discovery Issues
- Ensure the device is on the same network as the printer
- Check that local network permissions are granted
- Verify firewall settings allow discovery protocols

### Build Issues
- Clean the build folder: `flutter clean`
- Update pods: `cd ios && pod install`
- Ensure minimum iOS deployment target is 12.0 or higher

# iOS Implementation

This section contains documentation specific to the iOS implementation of the Zebra Printer Utility plugin.

## Overview

The iOS implementation uses the Zebra Link-OS SDK (ZSDK) through an Objective-C wrapper to provide printer functionality to Flutter.

## Architecture

### Key Components
- **ZebrautilPlugin.swift**: Main plugin registration and method channel handling
- **ZebraPrinterInstance.swift**: Printer operations and business logic
- **ZSDKWrapper.h/m**: Objective-C wrapper for ZSDK APIs
- **zebrautil.podspec**: CocoaPods configuration

### Design Principles
- Use Objective-C wrapper for ZSDK integration (Swift cannot import ZSDK directly)
- Keep business logic in Swift
- Handle all ZSDK operations on background threads
- Provide meaningful error messages

## Setup Requirements

### Prerequisites
- iOS 12.0+
- Xcode 12.0+
- Zebra Link-OS SDK (included in the project)

### Permissions
Add to your `Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to Zebra printers</string>
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs network access to connect to Zebra printers</string>
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>com.zebra.rawport</string>
</array>
```

## Features

- **Bluetooth Discovery**: MFi Bluetooth printer discovery
- **Network Discovery**: TCP/IP printer discovery
- **ZPL Printing**: Zebra Programming Language support
- **CPCL Printing**: Common Printer Command Language support
- **Automatic Language Detection**: Detects and switches printer language
- **Connection Management**: Connect, disconnect, and status monitoring

## Technical Details

For detailed technical information about ZSDK integration, see [ZSDK Integration Requirements](zsdk-integration-requirements.md).

## Common Issues

### Build Issues
- **"No such module 'ZSDK_API'"**: Use Objective-C wrapper, don't import directly in Swift
- **Framework not found**: Ensure podspec vendored_frameworks path is correct
- **Build errors**: Run `pod install` in example/ios after configuration changes

### Runtime Issues
- **Printers not found**: Check permissions and network connectivity
- **Print commands as text**: Ensure printer language is set correctly
- **Connection failures**: Verify printer address and network settings

## Documentation Links

- [Main Project README](../../README.md)
- [Example App Documentation](../example/README.md)
- [Library Documentation](../lib/README.md)
- [Development Documentation](../development/README.md)
- [ZSDK Integration Requirements](zsdk-integration-requirements.md) 