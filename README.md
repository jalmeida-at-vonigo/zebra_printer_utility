# Zebra Printer Utility Flutter Plugin

A Flutter plugin for integrating Zebra printers on iOS and Android platforms using the Zebra Link-OS SDK (ZSDK).

## Overview

This plugin provides a unified API for discovering, connecting to, and printing to Zebra printers across iOS and Android platforms. It supports both ZPL (Zebra Programming Language) and CPCL (Common Printer Command Language) printing formats.

## Features

- **Cross-platform support**: iOS and Android
- **Multiple connection types**: Bluetooth (MFi), Network (TCP/IP)
- **Printing formats**: ZPL, CPCL, and raw text
- **Automatic language detection**: Detects and switches printer language automatically
- **Printer discovery**: Scan for available printers
- **Connection management**: Connect, disconnect, and monitor connection status

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  zebra_util: ^0.0.1
```

### Basic Usage

```dart
import 'package:zebra_util/zebra_util.dart';

// Get a printer instance
final printer = ZebraUtil.getInstance();

// Start discovery
printer.startScan();

// Connect to a printer
await printer.connectToPrinter('192.168.1.100');

// Print ZPL
await printer.print('^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ');

// Print CPCL
await printer.print('! 0 200 200 210 1\r\nTEXT 4 0 0 0 Hello World\r\nFORM\r\nPRINT\r\n');
```

## Documentation

### 📚 [Example App](.readme/example/README.md)
Complete working example with multiple screens demonstrating all features.

### 🧪 [Testing Guide](.readme/example/testing-guide.md)
Comprehensive guide for testing the plugin on real devices and simulators.

### 📱 [iOS Implementation](.readme/ios/README.md)
Details about iOS-specific implementation and requirements.

### 🔧 [iOS ZSDK Integration Requirements](.readme/ios/zsdk-integration-requirements.md)
Technical details about iOS ZSDK integration and build requirements.

### 📦 [Library Documentation](.readme/lib/README.md)
Complete API reference and usage examples.

### 🖨️ [CPCL Printing Solution](.readme/lib/cpcl-printing-solution.md)
Guide for CPCL printing implementation and examples.

### 📋 [Future Improvements](.readme/development/TODO.md)
Planned features and improvements for the plugin.

## Platform Support

| Platform | Status | Features |
|----------|--------|----------|
| iOS | ✅ Supported | Bluetooth (MFi), Network, ZPL, CPCL |
| Android | ⚠️ Limited | Network only, basic ZPL support |

## Requirements

### iOS
- iOS 12.0+
- Xcode 12.0+
- Zebra Link-OS SDK (included)
- Bluetooth permissions for MFi devices
- Network permissions for TCP/IP printers

### Android
- Android API 21+
- Zebra Link-OS SDK (included)
- Network permissions for TCP/IP printers

## Getting Help

- Check the [Testing Guide](.readme/example/testing-guide.md) for troubleshooting
- Review [iOS Implementation](.readme/ios/README.md) for iOS-specific issues
- See [CPCL Printing Solution](.readme/lib/cpcl-printing-solution.md) for printing format help

## Contributing

See [Future Improvements](.readme/development/TODO.md) for planned features and areas for contribution.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.