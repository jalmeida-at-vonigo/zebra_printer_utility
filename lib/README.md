# Zebra Printer Flutter Plugin - API Documentation

## Simple API (Recommended)

The plugin provides a simple static API through the `Zebra` class for easy integration:

```dart
import 'package:zebrautil/zebra_util.dart';

// Method 1: Manual workflow
final printers = await Zebra.discoverPrinters();
final connected = await Zebra.connect(printers.first.address);
if (connected) {
  await Zebra.print('^XA^FO50,50^ADN,36,20^FDHello World^FS^XZ');
  await Zebra.disconnect();
}

// Method 2: Auto-print workflow (NEW)
// Automatically handles discovery, connection, printing, and disconnection
final success = await Zebra.autoPrint('^XA^FO50,50^ADN,36,20^FDHello World^FS^XZ');

// Auto-print with specific printer and format
final success = await Zebra.autoPrint(
  data, 
  address: '192.168.1.100',
  format: PrintFormat.ZPL,
);

// Auto-print CPCL data
final success = await Zebra.autoPrint(
  '! 0 200 200 210 1\nTEXT 4 0 30 40 Hello\nFORM\nPRINT\n',
  format: PrintFormat.CPCL,
);
```

### Key Features

- **Simple async/await API** - All operations return Futures for easy async handling
- **Non-blocking UI** - All operations run on background threads
- **Stream-based status updates** - Listen to real-time updates
- **Type-safe** - Full Dart type safety with proper error handling
- **Auto-print workflow** - Single method to handle discovery, connection, printing, and disconnection

### Available Methods

#### Discovery
```dart
// Discover printers with optional timeout
Future<List<ZebraDevice>> discoverPrinters({Duration timeout = const Duration(seconds: 10)})

// Stop discovery manually
Future<void> stopDiscovery()
```

#### Connection
```dart
// Connect to printer by address
Future<bool> connect(String address)

// Disconnect from current printer
Future<void> disconnect()

// Check if connected
Future<bool> isConnected()
```

#### Printing
```dart
// Print data with optional format specification
Future<bool> print(String data, {PrintFormat? format})

// Auto-print workflow (handles connection automatically)
Future<bool> autoPrint(String data, {String? address, PrintFormat? format})

// Get available printers for selection
Future<List<ZebraDevice>> getAvailablePrinters()
```

Supported formats:
- `PrintFormat.ZPL` - Zebra Programming Language
- `PrintFormat.CPCL` - Comtec Printer Control Language

#### Configuration
```dart
// Calibrate printer
Future<bool> calibrate()

// Set darkness (-30 to 30)
Future<bool> setDarkness(int darkness)

// Set media type
Future<bool> setMediaType(EnumMediaType type)

// Rotate print orientation
void rotate()
```

### Streams

Listen to real-time updates:

```dart
// Stream of discovered devices
Zebra.devices.listen((List<ZebraDevice> devices) {
  print('Found ${devices.length} printers');
});

// Stream of connection status
Zebra.connection.listen((ZebraDevice? printer) {
  if (printer != null) {
    print('Connected to ${printer.name}');
  } else {
    print('Disconnected');
  }
});

// Stream of status messages
Zebra.status.listen((String message) {
  print('Status: $message');
});
```

### Properties

```dart
// Currently connected printer
ZebraDevice? connectedPrinter = Zebra.connectedPrinter;

// List of discovered printers
List<ZebraDevice> printers = Zebra.discoveredPrinters;

// Check if discovery is active
bool isScanning = Zebra.isScanning;
```

### Auto-Print Workflow

The `autoPrint` method provides a complete printing workflow in a single call:

```dart
// Simple auto-print (discovers and uses first available printer)
final success = await Zebra.autoPrint(zplData);

// Auto-print to specific printer
final success = await Zebra.autoPrint(zplData, address: '192.168.1.100');
```

The auto-print workflow:
1. Checks if already connected to the right printer
2. Discovers printers if needed (with 5-second timeout)
3. Connects to the printer
4. Configures printer for the specified format (ZPL/CPCL)
5. Sends the print data
6. Disconnects after printing

**Note**: If multiple printers are discovered and no address is specified, the method returns `false` and you must use `getAvailablePrinters()` to let the user select one.

## Service-Based API

For more control, use the `ZebraPrinterService` class:

```dart
final service = ZebraPrinterService();

// Initialize the service
await service.initialize();

// Use the same methods as the static API
final printers = await service.discoverPrinters();

// Don't forget to dispose when done
service.dispose();
```

## Legacy API

The original API is still available for backwards compatibility:

```dart
final printer = await ZebraUtil.getPrinterInstance();
printer.startScanning();
// ... etc
```

## Platform Notes

### iOS
- Bluetooth printers must be paired in iOS Settings first
- Uses MFi (Made for iPhone/iPad) protocol
- Network printers work without pairing

### Android
- Bluetooth discovery works without pre-pairing
- Requires location permission for Bluetooth scanning
- Network discovery requires network permission

## Error Handling

All async methods return `Future<bool>` for operations that can fail:

```dart
final success = await Zebra.connect(address);
if (!success) {
  // Handle connection failure
}
```

For detailed error messages, listen to the status stream:

```dart
Zebra.status.listen((message) {
  if (message.contains('error')) {
    showError(message);
  }
});
``` 