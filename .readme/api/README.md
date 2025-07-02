# API Reference

Complete API documentation for the Zebra Printer Plugin.

## Core Classes

### ZebraUtil
Main entry point for the plugin. Provides singleton access to printer functionality.

```dart
final printer = ZebraUtil.getInstance();
```

### ZebraPrinter
Manages printer operations and discovery.

**Key Methods:**
- `startScanning()` - Start printer discovery
- `stopScanning()` - Stop printer discovery
- `connectToPrinter(String address)` - Connect to printer
- `disconnect()` - Disconnect from printer
- `print({required String data})` - Send print data
- `isPrinterConnected()` - Check connection status

### ZebraPrinterService
High-level service for printer operations with built-in queue management.

**Key Methods:**
- `initialize()` - Initialize the service
- `discoverPrinters()` - Discover available printers
- `connect(String address)` - Connect with retry logic
- `print(String data, {PrintFormat? format})` - Print with format detection
- `autoPrint(String data, {...})` - Auto-connect and print

### ZebraDevice
Represents a discovered printer.

**Properties:**
- `address` - Printer address (MAC or IP)
- `name` - Printer name
- `isWifi` - Network printer flag
- `status` - Current status
- `isConnected` - Connection state

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
// Get instance
final printer = ZebraUtil.getInstance();

// Connect
await printer.connectToPrinter('192.168.1.100');

// Print ZPL
await printer.print(data: '^XA^FO50,50^ADN,36,20^FDHello World^FS^XZ');

// Disconnect
await printer.disconnect();
```

### Using Service Layer
```dart
final service = ZebraPrinterService();
await service.initialize();

// Auto-print to paired printer
final success = await service.autoPrint(
  '^XA^FO50,50^ADN,36,20^FDHello World^FS^XZ',
  format: PrintFormat.ZPL,
);
```

### Discovery
```dart
final service = ZebraPrinterService();
final printers = await service.discoverPrinters(
  timeout: Duration(seconds: 5),
);

for (final printer in printers) {
  print('Found: ${printer.name} at ${printer.address}');
}
```

## Error Handling

All methods that can fail throw `PlatformException` with error codes:

- `NO_PERMISSION` - Missing required permissions
- `CONNECTION_ERROR` - Failed to connect
- `PRINT_ERROR` - Failed to print
- `NOT_CONNECTED` - Operation requires connection

## Best Practices

1. Always check connection before printing
2. Use `ZebraPrinterService` for production apps
3. Handle discovery timeouts gracefully
4. Dispose of resources when done
5. Use `autoPrint` for simple use cases 