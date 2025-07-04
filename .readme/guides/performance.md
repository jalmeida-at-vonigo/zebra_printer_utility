# Performance Guidelines

## Overview

This guide provides recommendations for optimal performance when using the Zebra Printer Plugin.

## Smart API (v2.3+) - Recommended

For the best performance, use the **ZebraPrinterSmart API** which provides **60-80% performance improvements** over legacy methods:

```dart
import 'package:zebrautil/zebrautil.dart';

// Simple smart print - handles everything automatically
await Zebra.smartPrint('^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ');

// Smart discovery with caching
final result = await Zebra.smartDiscover();

// Batch printing with connection pooling
final labels = [
  '^XA^FO50,50^A0N,50,50^FDLabel 1^FS^XZ',
  '^XA^FO50,50^A0N,50,50^FDLabel 2^FS^XZ',
];
await Zebra.smartPrintBatch(labels);

// Performance-optimized options
await Zebra.smartPrint(
  data,
  options: SmartPrintOptions.fast(), // Minimal safety checks
);
```

### Smart API Performance Benefits

- **Single Print**: 1.5-3 seconds (70-80% improvement)
- **Connection**: 0.5-1 second (60-70% improvement)  
- **Discovery**: 0.2-0.5 seconds (70-80% improvement)
- **Success Rate**: 99%+

See [ZebraPrinterSmart Guide](zebra-printer-smart.md) for detailed usage.

## Legacy API Performance (v2.2 and earlier)

## Discovery Performance

### Timeout Recommendations

```dart
// Bluetooth discovery (MFi devices respond quickly)
const bluetoothTimeout = Duration(seconds: 3);

// Network discovery (may take longer)
const networkTimeout = Duration(seconds: 5);

// Combined discovery
const defaultTimeout = Duration(seconds: 5);
```

### Optimizing Discovery

```dart
// 1. Cache discovered printers
class PrinterCache {
  static final Map<String, ZebraDevice> _cache = {};
  static DateTime? _lastDiscovery;
  
  static bool get isValid {
    if (_lastDiscovery == null) return false;
    return DateTime.now().difference(_lastDiscovery!) < Duration(minutes: 5);
  }
  
  static Future<List<ZebraDevice>> discover({bool force = false}) async {
    if (!force && isValid) {
      return _cache.values.toList();
    }
    
    final service = ZebraPrinterService();
    final printers = await service.discoverPrinters();
    
    _cache.clear();
    for (final printer in printers) {
      _cache[printer.address] = printer;
    }
    _lastDiscovery = DateTime.now();
    
    return printers;
  }
}
```

### Platform-Specific Discovery

```dart
// iOS: Bluetooth discovery is fast for paired devices
if (Platform.isIOS) {
  // Shorter timeout for paired devices
  timeout = Duration(seconds: 2);
}

// Android: Network-only, may need longer timeout
if (Platform.isAndroid) {
  timeout = Duration(seconds: 7);
}
```

## Connection Performance

### Connection Pooling

```dart
class PrinterConnectionPool {
  static final Map<String, ZebraPrinter> _connections = {};
  
  static Future<ZebraPrinter> getConnection(String address) async {
    // Reuse existing connection
    if (_connections.containsKey(address)) {
      final printer = _connections[address]!;
      if (await printer.isPrinterConnected()) {
        return printer;
      }
      // Remove stale connection
      _connections.remove(address);
    }
    
    // Create new connection
    final printer = ZebraUtil.getInstance();
    await printer.connectToPrinter(address);
    _connections[address] = printer;
    return printer;
  }
  
  static Future<void> closeAll() async {
    for (final printer in _connections.values) {
      await printer.disconnect();
    }
    _connections.clear();
  }
}
```

### Connection Best Practices

1. **Keep Connections Open**: For multiple prints, maintain connection
2. **Implement Heartbeat**: Check connection periodically
3. **Handle Reconnection**: Automatic reconnection on failure

```dart
class ManagedPrinterConnection {
  Timer? _heartbeat;
  
  void startHeartbeat() {
    _heartbeat = Timer.periodic(Duration(seconds: 30), (_) async {
      if (!await printer.isPrinterConnected()) {
        await reconnect();
      }
    });
  }
}
```

## Print Data Size Limits

### Maximum Data Sizes

| Connection Type | Recommended Max | Absolute Max |
|----------------|-----------------|--------------|
| Bluetooth MFi | 64 KB | 128 KB |
| Network TCP | 256 KB | 1 MB |
| USB | 512 KB | 2 MB |

### Data Chunking for Large Jobs

```dart
class PrintDataChunker {
  static const int chunkSize = 32 * 1024; // 32KB chunks
  
  static Future<void> printLargeData(
    ZebraPrinter printer,
    String data,
  ) async {
    final bytes = data.codeUnits;
    
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
      final chunk = String.fromCharCodes(bytes.sublist(i, end));
      
      await printer.print(data: chunk);
      
      // Small delay between chunks
      if (end < bytes.length) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }
  }
}
```

### Image Printing Optimization

```dart
// Compress images before printing
Future<String> optimizeImageForPrinting(String imagePath) async {
  // 1. Resize to printer DPI (typically 203 or 300)
  // 2. Convert to monochrome
  // 3. Use appropriate compression
  
  const maxWidth = 800;  // For 4" label at 203 DPI
  const quality = 85;    // JPEG quality
  
  // Implementation depends on image package
  return compressedImagePath;
}
```

## Batch Printing Performance

### Efficient Batch Processing

```dart
class BatchPrintManager {
  final ZebraPrinterService service;
  
  Future<void> printBatch(List<String> labels) async {
    // 1. Connect once
    await service.connect(printerAddress);
    
    // 2. Detect format once
    final format = ZebraSGDCommands.detectDataLanguage(labels.first);
    
    // 3. Set printer mode once
    if (format != null) {
      await service._doSetPrinterMode(format);
    }
    
    // 4. Print without mode checking
    for (final label in labels) {
      await service._doPrint(label, ensureMode: false);
      
      // Small delay to prevent buffer overflow
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    // 5. Disconnect when done
    await service.disconnect();
  }
}
```

### Queue Management

```dart
// Optimal queue size based on connection type
int getOptimalQueueSize(bool isBluetooth) {
  return isBluetooth ? 5 : 20;  // Bluetooth has smaller buffers
}

// Print with flow control
Stream<Result<void>> printStream(List<String> items) async* {
  final queueSize = getOptimalQueueSize(printer.isBluetooth);
  
  for (int i = 0; i < items.length; i += queueSize) {
    final batch = items.skip(i).take(queueSize);
    
    for (final item in batch) {
      yield await printer.print(item);
    }
    
    // Allow printer to process
    await Future.delayed(Duration(seconds: 1));
  }
}
```

## Memory Management

### Dispose Resources

```dart
class PrinterManager {
  ZebraPrinterService? _service;
  StreamSubscription? _statusSubscription;
  
  void dispose() {
    _statusSubscription?.cancel();
    _service?.dispose();
    _service = null;
  }
}
```

### Avoid Memory Leaks

```dart
// Use weak references for callbacks
class PrinterCallback {
  WeakReference<MyWidget>? _widgetRef;
  
  void onPrinterFound(ZebraDevice device) {
    final widget = _widgetRef?.target;
    if (widget != null && widget.mounted) {
      widget.addPrinter(device);
    }
  }
}
```

## Platform-Specific Optimizations

### iOS Optimizations

```dart
if (Platform.isIOS) {
  // 1. Use background queues for discovery
  // 2. Leverage MFi for faster Bluetooth
  // 3. Batch discovery results
}
```

### Android Optimizations

```dart
if (Platform.isAndroid) {
  // 1. Use network discovery only
  // 2. Implement connection timeout
  // 3. Handle network changes
}
```

## Monitoring Performance

### Basic Metrics

```dart
class PrintMetrics {
  static void measurePrintTime(String label) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await printer.print(data: label);
      
      final elapsed = stopwatch.elapsed;
      print('Print time: ${elapsed.inMilliseconds}ms');
      
      // Log slow prints
      if (elapsed.inSeconds > 5) {
        print('Slow print detected: ${label.length} bytes');
      }
    } finally {
      stopwatch.stop();
    }
  }
}
```

### Performance Debugging

```dart
// Enable verbose logging
ZebraPrinterService.enableDebugLogging = true;

// Monitor operation queue
service.operationQueueSize.listen((size) {
  if (size > 10) {
    print('Warning: Large operation queue: $size');
  }
});
```

## Best Practices Summary

1. **Discovery**: Cache results, use appropriate timeouts
2. **Connections**: Reuse connections, implement pooling
3. **Data Size**: Respect limits, chunk large data
4. **Batch Printing**: Minimize mode switches, use flow control
5. **Memory**: Dispose resources, avoid leaks
6. **Platform**: Optimize for each platform's strengths 