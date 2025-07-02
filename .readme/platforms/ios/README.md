# iOS Platform Documentation

Documentation for iOS implementation of the Zebra Printer Plugin.

## 📋 Contents

### Setup & Configuration
- **[Setup Guide](setup.md)** - Complete iOS setup instructions
- **[Architecture Overview](architecture.md)** - Technical architecture and ZSDK integration

### Development
- **[Implementation Details](implementation.md)** - iOS-specific implementation notes
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions

## ✅ Platform Features

| Feature | Status | Notes |
|---------|--------|-------|
| Bluetooth Discovery | ✅ Full | MFi devices only |
| Network Discovery | ✅ Full | Local network and multicast |
| ZPL Printing | ✅ Full | Complete support |
| CPCL Printing | ✅ Full | Complete support |
| Bi-directional Communication | ✅ Full | SGD commands with responses |
| Background Printing | ✅ Full | With proper configuration |
| Thread Safety | ✅ Full | All operations thread-safe |

## 🔧 Key Components

- **ZebrautilPlugin.swift** - Plugin registration and method channel
- **ZebraPrinterInstance.swift** - Core printer operations
- **ZSDKWrapper** - Objective-C bridge to Zebra SDK
- **ZSDK_API.xcframework** - Zebra Link-OS SDK

## 🚀 Quick Start

1. Add plugin to `pubspec.yaml`
2. Follow [Setup Guide](setup.md)
3. Run `pod install` in iOS directory
4. Import and use in your Flutter app

## 📱 Minimum Requirements

- iOS 12.0+
- Xcode 12.0+
- Swift 5.0+

## 🔗 Related Documentation

- [Main README](../../../README.md)
- [API Reference](../../api/README.md)
- [Example App](../../guides/example-app.md) 