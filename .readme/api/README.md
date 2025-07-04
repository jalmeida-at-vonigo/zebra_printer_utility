# API Reference

Complete API documentation for the Zebra Printer Plugin.

## Smart API (v2.3+) - Recommended

### Zebra (Static API)
High-performance static API with intelligent caching, connection pooling, and smart retry logic.

**Key Methods:**
- `smartPrint(String data, ...)` - High-performance printing with 60-80% improvements
- `smartPrintBatch(List<String> data, ...)` - Optimized batch printing
- `smartDiscover()` - Smart discovery with caching
- `smartConnect(String address)` - Smart connection management
- `smartDisconnect()` - Smart disconnection
- `getSmartStatus()` - Get smart API status and health

**Usage:**
```dart
import 'package:zebrautil/zebrautil.dart';

// Simple smart print - handles everything automatically
await Zebra.smartPrint('^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ');

// Smart print with specific printer
await Zebra.smartPrint(
  '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  address: '192.168.1.100',
);

// Batch printing with connection pooling
final labels = [
  '^XA^FO50,50^A0N,50,50^FDLabel 1^FS^XZ',
  '^XA^FO50,50^A0N,50,50^FDLabel 2^FS^XZ',
];
await Zebra.smartPrintBatch(labels);

// Smart discovery
final result = await Zebra.smartDiscover();
if (result.success) {
  print('Found ${result.data!.length} printers');
}
```

### ZebraPrinterSmart
Advanced smart printer instance for granular control.

**Key Methods:**
- `print(String data, ...)` - Smart print with options
- `printBatch(List<String> data, ...)` - Smart batch printing
- `connect(String address, ...)` - Smart connection with options
- `disconnect()` - Smart disconnection
- `discover(...)` - Smart discovery with options
- `getStatus()` - Get detailed smart status

### SmartPrintOptions
Configuration options for smart printing.

**Factory Constructors:**
- `SmartPrintOptions.fast()` - Minimal safety checks for speed
- `SmartPrintOptions.reliable()` - All safety features for reliability
- `SmartPrintOptions.conservative()` - Maximum safety and compatibility

**Custom Options:**
```dart
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

### SmartBatchOptions
Configuration options for batch printing.

**Inherits from SmartPrintOptions with additional batch-specific options:**
- `batchSize` - Number of labels per batch
- `batchDelay` - Delay between batches
- `enableBatchOptimization` - Enable batch-specific optimizations

## Legacy API (v2.2 and earlier)

### Core Classes

### ZebraPrinterService
High-level service for printer operations with automatic connection management and retry logic.

**Key Methods:**
- `autoPrint(String data, ...)` - Complete workflow: connect, print, disconnect (optimized to avoid redundant readiness checks)
- `print(String data, ...)` - Print data with optional auto-corrections and format detection
- `connect(String address)` - Connect to printer by address
- `disconnect()` - Disconnect from current printer
- `checkPrinterReadiness()` - Check if printer is ready to print
- `runDiagnostics()` - Run comprehensive printer diagnostics
- `getAvailablePrinters()` - Get list of discovered printers

### ZebraPrinter
Low-level printer interface. Used internally by ZebraPrinterService.

**Key Methods:**
- `startScanning()` - Start printer discovery
- `stopScanning()` - Stop printer discovery
- `connectToPrinter(String address)` - Connect to printer (returns `Result<void>`)
- `disconnect()` - Disconnect from printer (returns `Result<void>`)
- `print({required String data})` - Send print data (returns `Result<void>`)
- `isPrinterConnected()` - Check connection status (returns `Future<bool>`)

### ZebraDevice
Represents a discovered printer.

**Properties:**
- `address` - Printer address (MAC or IP)
- `name` - Printer name
- `isWifi` - Network printer flag
- `status` - Current status
- `isConnected` - Connection state

### PrinterReadiness
Detailed printer status information returned by `checkPrinterReadiness()`.

**Properties:**
- `isReady` - Overall readiness state
- `isConnected` - Connection status (nullable if not checked)
- `hasMedia` - Media presence (nullable if not checked)
- `headClosed` - Print head status (nullable if not checked)
- `isPaused` - Pause status (nullable if not checked)
- `mediaStatus` - Raw media status from printer
- `headStatus` - Raw head status from printer
- `pauseStatus` - Raw pause status from printer
- `hostStatus` - Raw host status from printer
- `errors` - List of error messages
- `warnings` - List of warning messages
- `timestamp` - When the check was performed
- `fullCheckPerformed` - Whether all status checks were completed

**Usage:**
```dart
final result = await service.checkPrinterReadiness();
if (result.success) {
  final readiness = result.data!;
  if (readiness.isReady) {
    print('Printer is ready');
  } else {
    print('Not ready: ${readiness.summary}');
    // Check specific issues
    if (readiness.hasMedia == false) {
      print('No media loaded');
    }
    if (readiness.headClosed == false) {
      print('Print head is open');
    }
  }
}
```

### PrinterStateManager
Advanced utility for direct printer state, readiness, and buffer management. Exposed via `zebrautil.dart` as of v2.0.24.

**Key Methods:**
- `checkPrinterReadiness()` - Check printer connection, media, head, pause, and error status (core responsibility)
- `runDiagnostics()` - Run comprehensive printer diagnostics and provide recommendations (core responsibility)
- `correctReadiness(PrinterReadiness)` - Attempt to auto-correct printer issues (unpause, clear errors, calibrate, etc.)
- `correctForPrinting({required String data, PrintFormat? format})` - Pre-print correction flow (buffer clear, language switch, readiness)
- `clearPrinterBuffer()` - Clear all pending data and reset print engine state
- `flushPrintBuffer()` - Ensure all buffered data is processed (important for CPCL)
- `switchLanguageForData(String data)` - Switch printer language based on print data

**Usage:**
```dart
import 'package:zebrautil/zebrautil.dart';

final stateManager = PrinterStateManager(
  printer: myPrinter,
  options: AutoCorrectionOptions.all(),
  statusCallback: (msg) => print(msg),
);

final result = await stateManager.correctForPrinting(
  data: '^XA^FDTest^FS^XZ',
  format: PrintFormat.zpl,
);
if (result.success) {
  print('Corrections applied!');
}
```

This class is intended for advanced scenarios where you need fine-grained control over printer state, buffer, or language switching. For most use cases, use `ZebraPrinterService` or the static `Zebra` API.

## Enums

### PrintFormat
```dart
enum PrintFormat { ZPL, CPCL }
```

### EnumMediaType
```dart
enum EnumMediaType { Label, BlackMark, Journal }
```

### Command
```dart
enum Command { calibrate, mediaType, darkness }
```

## Platform-Specific APIs

- [iOS API](ios-api.md)
- [Android API](android-api.md)

## Usage Examples

### Basic Printing
```dart
// Initialize service
final service = ZebraPrinterService();
await service.initialize();

// Connect
final connectResult = await service.connect('192.168.1.100');
if (!connectResult.success) {
  print('Connection failed: ${connectResult.error!.message}');
  return;
}

// Print ZPL
final printResult = await service.print('^XA^FO50,50^ADN,36,20^FDHello World^FS^XZ');
if (!printResult.success) {
  print('Print failed: ${printResult.error!.message}');
}

// Disconnect
await service.disconnect();
```

### Auto-Print Workflow
```dart
final service = ZebraPrinterService();
await service.initialize();

// Auto-print to paired printer
final result = await service.autoPrint(
  '^XA^FO50,50^ADN,36,20^FDHello World^FS^XZ',
  format: PrintFormat.zpl,
);

if (result.success) {
  print('Print successful');
} else {
  print('Print failed: ${result.error!.message}');
}
```

### Discovery
```dart
final service = ZebraPrinterService();
await service.initialize();

final result = await service.discoverPrinters(
  timeout: Duration(seconds: 5),
);

if (result.success) {
  final printers = result.data!;
  for (final printer in printers) {
    print('Found: ${printer.name} at ${printer.address}');
  }
} else {
  print('Discovery failed: ${result.error!.message}');
}
```

## Error Handling

All action methods return `Result<T>` objects that encapsulate success or failure:

```dart
final result = await service.connect(address);

// Check success
if (result.success) {
  // Handle success
} else {
  // Access error details
  print('Error: ${result.error!.message}');
  print('Code: ${result.error!.code}');
  print('Stack: ${result.error!.dartStackTrace}');
}

// Or use functional methods
result
  .ifSuccess((_) => print('Connected!'))
  .ifFailure((error) => print('Failed: ${error.message}'));
```

Common error codes:
- `CONNECTION_ERROR` - Failed to connect
- `CONNECTION_TIMEOUT` - Connection timed out
- `NOT_CONNECTED` - Operation requires connection
- `PRINT_ERROR` - Failed to print
- `NO_PERMISSION` - Missing required permissions
- `NO_PRINTERS_FOUND` - No printers discovered
- `PRINTER_NOT_READY` - Printer not ready to print

See the [Error Handling Guide](../guides/error-handling.md) for complete details.

## Best Practices

1. Always check connection before printing
2. Use `ZebraPrinterService` for production apps
3. Handle discovery timeouts gracefully
4. Dispose of resources when done
5. Use `autoPrint` for simple use cases 