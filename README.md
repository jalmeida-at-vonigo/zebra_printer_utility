# Zebra Printer Utility Flutter Plugin

A Flutter plugin for integrating Zebra printers on iOS and Android platforms using the Zebra Link-OS SDK (ZSDK).

## Overview

This plugin provides a unified API for discovering, connecting to, and printing to Zebra printers across iOS and Android platforms. It supports both ZPL (Zebra Programming Language) and CPCL (Common Printer Command Language) printing formats.

## Features

- **Cross-platform support**: iOS and Android
- **Multiple connection types**: Bluetooth (MFi), Network (TCP/IP)
- **Printing formats**: ZPL, CPCL, and raw text
- **[Automatic language detection](.readme/guides/auto-detection.md)**: Detects ZPL/CPCL format and switches printer mode
- **Printer discovery**: Scan for available printers
- **Connection management**: Connect, disconnect, and monitor connection status

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  zebra_util: ^0.1.0
```

### Basic Usage

```dart
import 'package:zebrautil/zebrautil.dart';

// Using the service layer (recommended)
final service = ZebraPrinterService();
await service.initialize();

// Start discovery
final discoverResult = await service.discoverPrinters();
discoverResult
  .ifSuccess((devices) => print('Found ${devices.length} printers'))
  .ifFailure((error) => print('Discovery failed: ${error.message}'));

// Connect to a printer
final connectResult = await service.connect('192.168.1.100');
if (!connectResult.success) {
  print('Failed to connect: ${connectResult.error!.message}');
  return;
}

// Print ZPL with error handling
final printResult = await service.print('^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ');
if (!printResult.success) {
  print('Print failed: ${printResult.error!.message}');
}

// Using auto-print for quick printing
final result = await service.autoPrint(
  '! 0 200 200 210 1\r\nTEXT 4 0 0 0 Hello World\r\nFORM\r\nPRINT\r\n',
);
result
  .ifSuccess((_) => print('Printed successfully!'))
  .ifFailure((error) => print('Error: ${error.code} - ${error.message}'));
```

## Documentation

### 🔌 API Reference
- **[API Documentation](.readme/api/README.md)** - Complete API reference
- **[Error Handling](.readme/guides/error-handling.md)** - Result pattern and error codes
- **[Printing Formats](.readme/guides/printing-formats.md)** - ZPL and CPCL guide

### 📱 Platform Guides
- **[iOS Platform](.readme/platforms/ios/README.md)** - iOS setup and implementation
  - [Setup Guide](.readme/platforms/ios/setup.md)
  - [Architecture](.readme/platforms/ios/architecture.md)
- **[Android Platform](.readme/platforms/android/README.md)** - Android status and limitations

### 📚 Guides & Examples
- **[Example App](.readme/guides/example-app.md)** - Complete working example
- **[Auto-Detection](.readme/guides/auto-detection.md)** - Format detection explained
- **[Performance](.readme/guides/performance.md)** - Optimization guidelines
- **[Testing Guide](.readme/guides/testing.md)** - Testing on devices and simulators

### 🔧 Development
- **[Development Docs](.readme/development/README.md)** - For contributors
- **[Future Improvements](.readme/development/TODO.md)** - Roadmap
- **[Architecture Changes](.readme/development/ARCHITECTURE_IMPROVEMENTS.md)** - Recent improvements
- **[Changelog](.readme/development/CHANGELOG.md)** - Version history

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