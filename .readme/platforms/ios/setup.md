# iOS Setup Guide

Complete setup guide for integrating the Zebra Printer Plugin on iOS.

## Requirements

- **iOS**: 12.0 or later
- **Xcode**: 12.0 or later
- **Swift**: 5.0 or later
- **Zebra SDK**: Link-OS SDK (included in plugin)

## Configuration Steps

### 1. Info.plist Configuration

Add the following entries to your iOS app's `Info.plist` file:

```xml
<!-- Bluetooth Permissions -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to discover and connect to Zebra printers</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth access to communicate with Zebra printers</string>

<!-- Network Permissions -->
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs local network access to discover network printers</string>

<!-- External Accessory Protocol (Required for MFi Bluetooth) -->
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>com.zebra.rawport</string>
</array>

<!-- Bonjour Services (For network discovery) -->
<key>NSBonjourServices</key>
<array>
    <string>_printer._tcp</string>
    <string>_ipp._tcp</string>
</array>
```

### 2. Background Modes (Optional)

If you need to print while the app is in the background:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>external-accessory</string>
</array>
```

### 3. Xcode Capabilities

Enable in your project settings:
1. **External Accessory** - Required for Bluetooth printers
2. **Background Modes** > External accessory communication (if using background printing)

### 4. CocoaPods Setup

The plugin's podspec is automatically included. After adding the plugin to `pubspec.yaml`:

```bash
cd ios
pod install
```

## Troubleshooting

### Build Issues

**"No such module 'ZSDK_API'"**
- The ZSDK cannot be imported directly in Swift
- Use the provided Objective-C wrapper

**Framework not found**
```bash
cd ios
pod deintegrate
pod install
```

**Minimum deployment target**
- Ensure iOS deployment target is 12.0 or higher in Xcode

### Runtime Issues

**Bluetooth printers not discovered**
- Verify Bluetooth is enabled
- Check printer is paired in iOS Settings
- Ensure `UISupportedExternalAccessoryProtocols` includes `com.zebra.rawport`

**Network printers not discovered**
- Confirm device is on same network as printer
- Check local network permission is granted
- Verify NSBonjourServices configuration

**Permission dialogs not appearing**
- Clean build folder
- Delete app and reinstall
- Check Info.plist is properly formatted

## Next Steps

- [Architecture Overview](architecture.md)
- [Implementation Details](implementation.md)
- [API Reference](../../api/ios-api.md) 