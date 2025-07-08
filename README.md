# Zebra Printer Utility Flutter Plugin

A professional Flutter plugin for robust, cross-platform Zebra printer integration. Supports iOS (MFi Bluetooth, Network) and Android (Network), with modern event-driven architecture, command pattern, and comprehensive diagnostics.

---

## Features

- **Cross-platform**: iOS (MFi Bluetooth, Network), Android (Network)
- **Modern Architecture**: Command pattern, event-driven workflows, and manager-based API
- **Automatic Format Detection**: ZPL/CPCL auto-detection and mode switching
- **Smart Device Discovery**: Intelligent, real-time printer discovery and selection
- **Comprehensive Diagnostics**: Status, error, and readiness checks with actionable recommendations
- **Advanced Error Handling**: Retry logic, error classification, and progress tracking
- **Buffer & State Management**: Auto-correction, buffer clearing, calibration, and more
- **Rich Example App**: Demonstrates all major workflows and best practices

---

## Architecture

```
┌─────────────────────┐
│   SmartPrintManager │
│   (Workflow Logic)  │
└─────────────────────┘
           │
           ▼
┌─────────────────────┐
│ ZebraPrinterManager │
│ (Instance Manager)  │
└─────────────────────┘
           │
           ▼
┌─────────────────────┐    ┌─────────────────────┐
│   ZebraPrinter      │    │ ZebraPrinterDiscovery│
│ (Native Wrapper)    │    │ (Discovery Logic)   │
└─────────────────────┘    └─────────────────────┘
```

- **ZebraPrinter**: Low-level native wrapper for ZSDK operations (primitive, stateless)
- **ZebraPrinterManager**: Manages printer instances, state, and exposes primitive operations
- **SmartPrintManager**: Orchestrates complex workflows, event streaming, and error handling
- **Command Pattern**: All printer operations are encapsulated as commands (one per file, created via CommandFactory)

---

## Quick Start

### Installation

```yaml
dependencies:
  zebrautil: ^2.0.0
```

### Basic Usage (Manager-Based API)

```dart
import 'package:zebrautil/zebrautil.dart';

final manager = ZebraPrinterManager();
await manager.initialize();

// Discover printers
final discoveryStream = manager.discovery.discoverPrintersStream();
discoveryStream.listen((devices) {
  print('Discovered: ${devices.length} printers');
});

// Connect to a printer
final result = await manager.connect('192.168.1.100');
if (!result.success) {
  print('Failed to connect: ${result.error?.message}');
}

// Print data (primitive)
final printResult = await manager.print('^XA^FO50,50^FDHello World^FS^XZ');
if (!printResult.success) {
  print('Print failed: ${printResult.error?.message}');
}
```

### Event-Driven Smart Print

```dart
final eventStream = manager.smartPrint(
  '^XA^FO50,50^FDHello World^FS^XZ',
  maxAttempts: 3,
);
eventStream.listen((event) {
  // Handle PrintEvent: step changes, errors, progress, completion
});
```

---

## Example App

A comprehensive example app is provided in the `/example` folder. It demonstrates all major workflows and best practices:

- **CPCL Test**: Manual CPCL label editing and direct printing, with device selection and connection.
- **Result-Based**: Demonstrates the operation manager and result-based async operations.
- **Smart Discovery**: Real-time device discovery, listing, and connection using the new manager/event system.
- **Smart Print**: Full event-driven, robust print workflow with real-time progress, error handling, and retry logic.

**All screens use a shared log panel for real-time feedback and debugging.**

### Running the Example

```sh
cd example
flutter run
```

---

## Advanced Usage

### Command Pattern

All printer operations are encapsulated as commands. Use the `CommandFactory` to create and execute commands:

```dart
final command = CommandFactory.createSendZplClearBufferCommand(printer);
final result = await command.execute();
```

### SmartPrintManager

For advanced workflows, use the `SmartPrintManager` for event-driven printing, retries, and error handling:

```dart
final smartManager = manager.smartPrintManager;
final eventStream = smartManager.smartPrint(
  '^XA^FO50,50^FDHello World^FS^XZ',
  device: myPrinter,
);
eventStream.listen((event) {
  // Handle PrintEvent
});
```

---

## Documentation

- **[API Reference](.readme/api/README.md)**
- **[Error Handling](.readme/guides/error-handling.md)**
- **[Printing Formats](.readme/guides/printing-formats.md)**
- **[Example App Guide](.readme/guides/example-app.md)**
- **[Development Docs](.readme/development/README.md)**
- **[Changelog](CHANGELOG.md)**

---

## Platform Support

| Platform | Status | Features |
|----------|--------|----------|
| iOS      | ✅ Supported | Bluetooth (MFi), Network, ZPL, CPCL |
| Android  | ⚠️ Limited | Network only, basic ZPL support |

---

## Getting Help

- See the [Example App Guide](.readme/guides/example-app.md) for troubleshooting
- Review [iOS Implementation](.readme/platforms/ios/README.md) for iOS-specific issues
- See [CPCL Printing Solution](.readme/lib/cpcl-printing-solution.md) for printing format help

---

## Contributing

See [Future Improvements](.readme/development/TODO.md) for planned features and areas for contribution.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.