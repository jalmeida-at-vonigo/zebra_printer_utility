# Zebra Printer Utility Flutter Plugin

A Flutter plugin for integrating Zebra printers on iOS and Android platforms using the Zebra Link-OS SDK (ZSDK).

## Overview

This plugin provides a unified API for discovering, connecting to, and printing to Zebra printers across iOS and Android platforms. It supports both ZPL (Zebra Programming Language) and CPCL (Common Printer Command Language) printing formats.

## Features

- **Cross-platform support**: iOS and Android
- **Multiple connection types**: Bluetooth (MFi), Network (TCP/IP)
- **Printing formats**: ZPL, CPCL, and raw text
- **[Automatic language detection](.readme/guides/auto-detection.md)**: Detects ZPL/CPCL format and switches printer mode
- **[Auto-Correction System v2.0](.readme/architecture/auto-correction-v2.md)**: Configurable automatic issue resolution
- **Printer discovery**: Scan for available printers
- **Connection management**: Connect, disconnect, and monitor connection status
- **Format-Specific Commands**: ZPL and CPCL commands are properly separated and automatically selected based on printer format
- **Auto-Correction Capabilities** (v2.0+):
  - Configurable auto-correction with `ReadinessOptions`
  - **Auto-unpause**: Automatically unpause paused printers
  - **Clear errors**: Clear recoverable printer errors
  - **Connection recovery**: Reconnect on connection loss
  - **Language switching**: Auto-switch printer language based on data format
  - **Calibration**: Auto-calibrate when media detection issues occur
  - **Buffer clearing**: Clear printer buffer before printing (v2.0.20+)
  ```dart
  // Use optimized defaults for regular printing (v2.0.20+)
  await Zebra.print(data); // Automatically uses ReadinessOptions.forPrinting()
  
  // Use safe defaults for autoPrint (v2.0.20+)
  await Zebra.autoPrint(data); // Automatically uses ReadinessOptions.comprehensive()
  
  // Or customize corrections
  await Zebra.print(data,
    readinessOptions: ReadinessOptions(
      fixPausedPrinter: true,
      fixPrinterErrors: true,
      fixLanguageMismatch: true,
      clearBuffer: true,
    ));
  
  // Factory constructors for common scenarios
  ReadinessOptions.none()           // No corrections
  ReadinessOptions.basic()          // Basic corrections (unpause, clear errors)
  ReadinessOptions.comprehensive()  // All corrections enabled
  ReadinessOptions.forPrinting()    // Optimized for print() - includes buffer clearing
  ReadinessOptions.forAutoPrint()   // Optimized for autoPrint() - all safety features
  ```
- **Advanced Printer Control** (v2.0.18+):
  - **SGD Commands**: Send raw SGD (Set/Get/Do) commands to the printer
  - **Buffer Control**: Explicitly flush print buffer to ensure complete data transmission
  - **Clear Buffer Before Print**: Optional parameter to clear printer state before printing
  ```dart
  // Send SGD command
  await service.sendSGDCommand('! U1 setvar "device.languages" "zpl"');
  
  // Clear printer buffer to ensure clean state
  await service.clearPrinterBuffer();
  
  // Print with buffer clearing (v2.0.19+)
  await service.print(data, clearBufferFirst: true);
  
  // Flush print buffer (useful for CPCL)
  await service.flushPrintBuffer();
  ```
- **Comprehensive Diagnostics**:
  - When your printer doesn't print and you don't know why, use the diagnostics feature:
  ```dart
  final diagnostics = await Zebra.runDiagnostics();
  if (diagnostics.success) {
    final report = diagnostics.data!;
    print('Printer Status: ${report['status']}');
    print('Errors: ${report['errors']}');
    print('Recommendations: ${report['recommendations']}');
  }
  ```
  The diagnostics will check:
  - Connection status
  - Media presence
  - Print head status
  - Pause state
  - Error conditions
  - Printer configuration
  - And provide specific recommendations for fixing issues
- **Robust Parser Utilities** (v2.0+):
  - Safe parsing that never fails
  - Handles multiple boolean formats: 'true', 'on', '1', 'yes', etc.
  - Smart status interpretation

## Architecture

### Command Architecture (v2.2.0+)

The plugin now uses a clean command architecture that ensures format-specific operations are handled correctly:

- **One Command Per File**: Each command class is in its own file with a descriptive name
- **Format-Specific Commands**: ZPL and CPCL commands are properly separated (e.g., `SendZplClearBufferCommand`, `SendCpclClearBufferCommand`)
- **CommandFactory Pattern**: All commands are created through `CommandFactory` to ensure proper instantiation
- **Automatic Format Selection**: Commands are automatically selected based on detected printer format
- **Utility-Only ZebraSGDCommands**: The `ZebraSGDCommands` class now only contains utility methods for format detection and parsing

```dart
// The system automatically selects the correct command for the format
if (format == PrintFormat.zpl) {
  await CommandFactory.createSendZplClearBufferCommand(printer).execute();
} else if (format == PrintFormat.cpcl) {
  await CommandFactory.createSendCpclClearBufferCommand(printer).execute();
}
```

### Callback-Based Operations (v2.1.0+)

All native operations in this plugin use a callback-based architecture that ensures operations complete based on actual device state rather than arbitrary delays:

- **Operation Tracking**: Each operation has a unique ID that links native callbacks to the specific Dart caller
- **Real Completion**: Operations complete when the native side reports success/failure, not after a timeout
- **No Artificial Delays**: Removed all `Future.delayed()` calls in favor of actual completion signals
- **Natural Sequencing**: Async/await provides natural operation sequencing without need for queues

This architecture provides:
- **Reliability**: Operations can't be left in pending state
- **Performance**: Operations complete as fast as the hardware allows
- **Debugging**: Clear operation tracking with IDs for better error diagnosis

### State Change Verification (v2.1.1+)

For operations that don't provide native callbacks (like mode switching, calibration, settings changes), the plugin includes a `StateChangeVerifier` utility:

```dart
// Example: Switch printer mode with verification
final result = await printer.setPrinterMode(PrinterMode.zpl);

// The verifier will:
// 1. Check if already in ZPL mode (no-op if true)
// 2. Send the mode change command if needed
// 3. Poll up to 3 times to verify the change
// 4. Return success or detailed error
```

Benefits:
- **No Guesswork**: Verifies operations actually completed instead of hoping delays are sufficient
- **Faster**: Operations complete as soon as verified, not after fixed delays
- **Smarter**: Skips operations if already in desired state
- **Reliable**: Retries with exponential backoff if needed

## What's New in v2.3

- **ZebraPrinterSmart API**: High-performance printing with 60-80% performance improvements
- **ZSDK-First Optimization**: Leverages ZSDK's built-in optimizations for all connection types
- **Connection Pooling**: Maintains persistent connections for faster subsequent prints
- **Intelligent Caching**: Caches expensive operations to avoid redundant work
- **Smart Retry Logic**: Intelligent retry with exponential backoff
- **Batch Printing**: Optimized batch printing with single connection for entire batch

## What's New in v2.2

- **Command Architecture**: Clean separation of ZPL and CPCL commands with automatic format selection
- **CommandFactory Pattern**: Centralized command creation for better maintainability
- **Utility-Only ZebraSGDCommands**: Simplified utility class focused on format detection and parsing

## ZebraPrinterSmart API (v2.3+)

The `ZebraPrinterSmart` API provides high-performance printing with **60-80% performance improvements** over the current `autoPrint` method through intelligent caching, connection pooling, and smart retry logic.

### Key Features
- **Intelligent Caching**: Cache language mode, printer status, and connection state
- **Connection Pooling**: Maintain persistent connections for faster subsequent prints
- **Smart Retry Logic**: Intelligent retry with exponential backoff
- **ZSDK-First Optimization**: Leverages ZSDK's built-in optimizations for all connection types
- **Connection-Agnostic**: Works seamlessly with Bluetooth, Network, and USB connections
- **Batch Printing Optimization**: Optimized for multiple label printing
- **iOS 13+ Permission Handling**: Automatic permission management with MFi compliance

### Performance Improvements
- **Single Print**: 1.5-3 seconds (70-80% improvement)
- **Connection**: 0.5-1 second (60-70% improvement)
- **Discovery**: 0.2-0.5 seconds (70-80% improvement)
- **Success Rate**: 99%+

### Smart API Usage

```dart
import 'package:zebrautil/zebrautil.dart';

// Simple smart print - handles everything automatically
await Zebra.smartPrint('^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ');

// Smart print with specific printer
await Zebra.smartPrint(
  '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  address: '192.168.1.100',
);

// Smart print with options
await Zebra.smartPrint(
  '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  options: SmartPrintOptions.reliable(),
);

// Batch printing
final labels = [
  '^XA^FO50,50^A0N,50,50^FDLabel 1^FS^XZ',
  '^XA^FO50,50^A0N,50,50^FDLabel 2^FS^XZ',
  '^XA^FO50,50^A0N,50,50^FDLabel 3^FS^XZ',
];
await Zebra.smartPrintBatch(labels);

// Smart discovery
final result = await Zebra.smartDiscover();
if (result.success) {
  print('Found ${result.data!.length} printers');
}

// Smart connection management
await Zebra.smartConnect('192.168.1.100');
await Zebra.smartDisconnect();

// Get smart status
final status = await Zebra.getSmartStatus();
print('Connection health: ${status.connectionHealth}%');
```

### Smart Options

```dart
// Fast printing (minimal safety checks)
SmartPrintOptions.fast()

// Reliable printing (all safety features)
SmartPrintOptions.reliable()

// Custom options
SmartPrintOptions(
  maxRetries: 3,
  retryDelay: Duration(seconds: 2),
  clearBufferBeforePrint: true,
  flushBufferAfterPrint: true,
  enableConnectionPooling: true,
  enableCaching: true,
  enableOptimization: true,
)
```

See [ZebraPrinterSmart Guide](.readme/guides/zebra-printer-smart.md) for detailed usage and [Performance API Plan](.readme/plan/zebra-auto-performance-api.md) for implementation details.

## What's New in v2.0

- **[Configurable Auto-Correction](.readme/architecture/auto-correction-v2.md)**: Fine-grained control over automatic issue resolution
- **Robust Parsing**: Parser utilities that never fail
- **Better Architecture**: Internal organization for maintainability

See [CHANGELOG.md](CHANGELOG.md) for full details.

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  zebra_util: ^0.1.0
```

### Basic Usage

#### Smart API (Recommended - v2.3+)

```dart
import 'package:zebrautil/zebrautil.dart';

// Simple smart print - handles everything automatically
await Zebra.smartPrint('^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ');

// Smart discovery
final result = await Zebra.smartDiscover();
if (result.success) {
  print('Found ${result.data!.length} printers');
}

// Smart print with specific printer
await Zebra.smartPrint(
  '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  address: '192.168.1.100',
);

// Batch printing
final labels = [
  '^XA^FO50,50^A0N,50,50^FDLabel 1^FS^XZ',
  '^XA^FO50,50^A0N,50,50^FDLabel 2^FS^XZ',
];
await Zebra.smartPrintBatch(labels);
```

#### Legacy API (v2.2 and earlier)

```dart
import 'package:zebrautil/zebrautil.dart';

// Using the service layer
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

## Advanced Usage: Printer State Management

For advanced control over printer state, readiness, and buffer management, use the `PrinterReadinessManager` class. This is now available directly from the root of the package as `zebra_printer_readiness_manager.dart` and is re-exported by `zebrautil.dart`:

```dart
import 'package:zebrautil/zebrautil.dart';

final readinessManager = PrinterReadinessManager(
  printer: myPrinter,
  statusCallback: (msg) => print(msg),
);

// Example: Pre-print correction
final result = await readinessManager.correctForPrinting(
  data: '^XA^FDTest^FS^XZ',
  format: PrintFormat.zpl,
);
if (result.success) {
  print('Corrections applied!');
}

// Example: Clear buffer
await readinessManager.clearPrinterBuffer();

// Example: Flush buffer (for CPCL)
await readinessManager.flushPrintBuffer();
```

This class provides fine-grained control for advanced scenarios, such as custom auto-correction flows, buffer management, and language switching. See the API docs for details.

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
- **[ZebraPrinterSmart](.readme/guides/zebra-printer-smart.md)** - High-performance API guide

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