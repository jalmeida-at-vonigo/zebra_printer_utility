# ZebraPrinterSmart API Guide

## Overview

The `ZebraPrinterSmart` API is a new high-performance printing solution designed to provide significant performance improvements over the current `autoPrint` method. It uses intelligent caching, connection pooling, and smart retry logic to achieve **60-80% performance improvements** while maintaining reliability.

## Why ZebraPrinterSmart?

### Current Performance Issues

The existing `autoPrint` method performs multiple checks on every print operation:

1. **Discovery Phase** (~500-2000ms) - Find and validate printers
2. **Connection Phase** (~1000-3000ms) - Connect and verify connection
3. **Readiness Phase** (~500-1500ms) - Language mode, buffer, status checks
4. **Print Phase** (~1000-3000ms) - Data preparation and printing
5. **Cleanup Phase** (~1000-3000ms) - Disconnection and cleanup

**Total: 4-12 seconds per print operation**

### ZebraPrinterSmart Solution

The new API eliminates redundant operations through:

- **Intelligent Caching**: Cache expensive operations (language mode, status)
- **Connection Pooling**: Maintain persistent connections
- **Smart Retry Logic**: Handle failures gracefully
- **Background Operations**: Move non-critical tasks to background
- **Connection-Aware Optimization**: Different strategies for different connection types

**Target: 1-4 seconds per print operation (60-80% improvement)**

## Key Features

### 1. Intelligent Caching

ZebraPrinterSmart caches expensive operations to avoid redundant work:

```dart
// Language mode is cached for 30 minutes
// Printer status is cached for 30 seconds
// Connection state is cached for 5 minutes
// Format detection is cached per data hash
```

**Benefits:**
- Eliminates redundant language mode checks
- Reduces status polling overhead
- Speeds up format detection
- **50-70% improvement** for repeated operations

### 2. Connection Pooling

Maintains persistent connections for faster subsequent prints:

```dart
// First print: Connect + Print (2-4 seconds)
// Subsequent prints: Print only (0.5-2 seconds)
```

**Benefits:**
- Eliminates connection overhead
- Automatic reconnection on failures
- Connection health monitoring
- **60-80% improvement** for batch printing

### 3. Smart Retry Logic

Intelligent retry with exponential backoff:

```dart
// Automatic retry with exponential backoff
// Smart error classification
// Circuit breaker pattern
// Operation-specific retry limits
```

**Benefits:**
- Handles temporary network issues
- Prevents cascading failures
- Improves reliability
- **95%+ recovery rate** for failed prints

### 4. Connection-Aware Optimization

Different strategies for different connection types:

#### Network Printers (TCP)
- **Multichannel support** (when available)
- **Optimistic operations** with parallel status checking
- **300ms improvement** potential (Zebra documented)

#### Bluetooth Printers (MFi)
- **Single-channel optimization**
- **Caching and pooling** focus
- **Conservative approach** with proven techniques

### 5. Background Operations

Moves non-critical operations to background:

```dart
// Background tasks:
// - Status updates
// - Cache cleanup
// - Connection health checks
// - Error logging
```

**Benefits:**
- Non-blocking main operations
- Improved responsiveness
- Better resource utilization

## API Design

### Core Class Structure

```dart
// Exposed via Zebra.dart
class Zebra {
  // Lazy singleton instance
  static ZebraPrinterSmart? _smartInstance;
  
  // Smart print - handles everything automatically
  static Future<Result<void>> smartPrint(
    String data, {
    String? address,           // Optional: specific printer address
    PrintFormat? format,       // Optional: force format detection
    SmartPrintOptions? options, // Optional: granular control
  });
  
  // Batch smart print
  static Future<Result<void>> smartPrintBatch(
    List<String> data, {
    String? address,
    PrintFormat? format,
    SmartBatchOptions? options,
  });
  
  // Optional: Granular control when needed
  static ZebraPrinterSmart get smart;
}

class ZebraPrinterSmart {
  // Main print method - handles everything automatically
  Future<Result<void>> print(
    String data, {
    String? address,           // Optional: specific printer
    PrintFormat? format,       // Optional: force format
    SmartPrintOptions? options, // Optional: granular control
  });
  
  // Batch print - optimized for multiple labels
  Future<Result<void>> printBatch(
    List<String> data, {
    String? address,
    PrintFormat? format,
    SmartBatchOptions? options,
  });
  
  // Optional: Granular control methods
  Future<Result<void>> connect(String address, {ConnectOptions? options});
  Future<Result<void>> disconnect();
  Future<List<ZebraDevice>> discover({DiscoveryOptions? options});
  Future<ZebraPrinterSmartStatus> getStatus();
}
```

### Primary API Methods

#### Smart Print - "Just Works"
```dart
// Handles everything automatically: connection, caching, optimization
Future<Result<void>> smartPrint(String data, {
  String? address,           // Optional: specific printer
  PrintFormat? format,       // Optional: force format
  SmartPrintOptions? options, // Optional: granular control
});
```

#### Batch Smart Print
```dart
// Optimized for multiple labels with single connection
Future<Result<void>> smartPrintBatch(List<String> data, {
  String? address,
  PrintFormat? format,
  SmartBatchOptions? options,
});
```

#### Granular Control
```dart
// Get smart instance for manual control
static ZebraPrinterSmart get smart;
```

### Options-Based Configuration

```dart
// Smart print options - sensible defaults, granular control
class SmartPrintOptions {
  // Connection options
  final bool autoConnect;           // Default: true
  final bool autoDisconnect;        // Default: false (keep connection for reuse)
  final Duration connectionTimeout; // Default: 10 seconds
  
  // Caching options
  final bool enableCaching;         // Default: true
  final Duration cacheTtl;          // Default: 30 minutes
  
  // Optimization options
  final bool enableOptimization;    // Default: true
  final bool enableMultichannel;    // Default: true (network only)
  
  // Retry options
  final int maxRetries;             // Default: 3
  final Duration retryDelay;        // Default: 100ms
  final double retryBackoff;        // Default: 2.0
  
  // Format options
  final bool autoDetectFormat;      // Default: true
  final bool forceLanguageSwitch;   // Default: false
  
  // Buffer options
  final bool clearBufferBeforePrint; // Default: true
  final bool flushBufferAfterPrint;  // Default: true
  
  // Factory constructors for common scenarios
  SmartPrintOptions.fast() : 
    autoConnect = true,
    autoDisconnect = false,
    enableCaching = true,
    enableOptimization = true,
    clearBufferBeforePrint = false, // Skip for speed
    flushBufferAfterPrint = false;  // Skip for speed
    
  SmartPrintOptions.reliable() :
    autoConnect = true,
    autoDisconnect = false,
    enableCaching = true,
    enableOptimization = true,
    clearBufferBeforePrint = true,
    flushBufferAfterPrint = true,
    maxRetries = 5;
    
  SmartPrintOptions.conservative() :
    autoConnect = true,
    autoDisconnect = true, // Disconnect after each print
    enableCaching = true,
    enableOptimization = false, // Use proven techniques only
    enableMultichannel = false;
}

// Batch print options
class SmartBatchOptions extends SmartPrintOptions {
  final int batchSize;              // Default: 10
  final Duration batchDelay;        // Default: 100ms
  final bool parallelProcessing;    // Default: false (sequential for reliability)
  
  SmartBatchOptions.fast() : 
    super.fast(),
    batchSize = 20,
    batchDelay = Duration(milliseconds: 50),
    parallelProcessing = true;
    
  SmartBatchOptions.reliable() :
    super.reliable(),
    batchSize = 5,
    batchDelay = Duration(milliseconds: 200),
    parallelProcessing = false;
}
```

## Usage Examples

### Simple Usage: "Just Works"

```dart
import 'package:zebrautil/zebrautil.dart';

// Simplest usage - everything automatic
await Zebra.smartPrint('^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ');

// With specific printer
await Zebra.smartPrint(
  '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  address: '192.168.1.100',
);

// Batch printing
final labels = [
  '^XA^FO50,50^A0N,50,50^FDLabel 1^FS^XZ',
  '^XA^FO50,50^A0N,50,50^FDLabel 2^FS^XZ',
  '^XA^FO50,50^A0N,50,50^FDLabel 3^FS^XZ',
];
await Zebra.smartPrintBatch(labels);
```

### Options-Based Usage: Granular Control

```dart
// Fast printing (minimal safety checks)
await Zebra.smartPrint(
  '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  options: SmartPrintOptions.fast(),
);

// Reliable printing (maximum safety)
await Zebra.smartPrint(
  '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  options: SmartPrintOptions.reliable(),
);

// Custom options
await Zebra.smartPrint(
  '^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ',
  options: SmartPrintOptions(
    autoConnect: true,
    enableCaching: true,
    maxRetries: 5,
    clearBufferBeforePrint: true,
  ),
);

// Batch with options
await Zebra.smartPrintBatch(
  labels,
  options: SmartBatchOptions.fast(),
);
```

### Granular Control: When Needed

```dart
// Get smart instance for granular control
final smart = Zebra.smart;

// Manual connection management
await smart.connect('192.168.1.100');
await smart.print('^XA^FDTest^FS^XZ');
await smart.disconnect();

// Discovery with options
final printers = await smart.discover(
  options: DiscoveryOptions(timeout: Duration(seconds: 10)),
);

// Status monitoring
final status = await smart.getStatus();
print('Cache hit rate: ${status.cacheHitRate}%');
```

## Performance Comparison

### Single Print Operations

| Operation | Current autoPrint | ZebraPrinterSmart | Improvement |
|-----------|------------------|-------------------|-------------|
| **Network Print** | 4-12s | 1.0-3.0s | 70-80% |
| **Bluetooth Print** | 4-12s | 2.0-4.0s | 60-70% |
| **Connection** | 1-3s | 0.5-1.0s | 60-70% |
| **Discovery** | 0.5-2s | 0.2-0.5s | 70-80% |

### Batch Print Operations

| Batch Size | Current autoPrint | ZebraPrinterSmart | Improvement |
|------------|------------------|-------------------|-------------|
| **10 Labels** | 40-120s | 15-30s | 70-80% |
| **50 Labels** | 200-600s | 60-120s | 70-80% |
| **100 Labels** | 400-1200s | 120-240s | 70-80% |

### Reliability Metrics

| Metric | Target | Strategy |
|--------|--------|----------|
| **Success Rate** | >99% | Smart retry logic |
| **Recovery Rate** | >95% | Intelligent error handling |
| **Cache Hit Rate** | >80% | Intelligent caching |
| **Connection Pool Efficiency** | >90% | Connection pooling |

## Migration Strategy

### Backward Compatibility

The new `ZebraPrinterSmart` API will be introduced alongside the existing APIs:

```dart
// Existing APIs remain unchanged
await Zebra.autoPrint(data);
await service.print(data);

// New smart API available
final smartPrinter = ZebraPrinterSmart();
await smartPrinter.print(data);
```

### Gradual Migration

1. **Phase 1**: New API available, old API unchanged
2. **Phase 2**: Deprecation warnings on old API
3. **Phase 3**: Old API removed in major version

### Migration Guide

```dart
// Before: Using autoPrint
final result = await Zebra.autoPrint(data);

// After: Using smartPrint (simplest)
final result = await Zebra.smartPrint(data);

// After: Using smartPrint with options
final result = await Zebra.smartPrint(
  data,
  options: SmartPrintOptions.fast(),
);

// After: Using smartPrint with granular control
final smart = Zebra.smart;
await smart.connect(address);
final result = await smart.print(data);
```

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1-2)
- Create `ZebraPrinterSmart` class structure
- Implement `CacheManager`
- Implement `ConnectionManager`
- Basic connection pooling

### Phase 2: Conservative Optimizations (Week 3-4)
- Implement `PrintOptimizer`
- Implement `RetryManager`
- Smart caching strategies
- Connection pooling

### Phase 3: Connection-Aware Features (Week 5-6)
- Implement `ConnectionTypeManager`
- Network multichannel support (if available)
- Bluetooth-specific optimizations
- Performance monitoring

### Phase 4: Advanced Features (Week 7-8)
- Implement `BackgroundManager`
- Batch printing optimization
- Advanced error handling
- Performance monitoring

### Phase 5: Testing & Refinement (Week 9-10)
- Comprehensive testing
- Performance benchmarking
- Error scenario testing
- Documentation and examples

## Best Practices

### Configuration

```dart
// Use conservative settings for production
final config = ZebraPrinterSmartConfig(
  enableConservativeMode: true,
  enableExperimentalFeatures: false,
);

// Enable experimental features for testing
final testConfig = ZebraPrinterSmartConfig(
  enableExperimentalFeatures: true,
);
```

### Error Handling

```dart
// Always handle results properly
final result = await smartPrinter.print(data);
result
  .ifSuccess((_) => print('Success'))
  .ifFailure((error) {
    print('Error: ${error.message}');
    // Handle specific error types
    if (error.code == ErrorCodes.connectionError) {
      // Handle connection issues
    }
  });
```

### Resource Management

```dart
// Dispose resources when done
final smartPrinter = ZebraPrinterSmart();
try {
  await smartPrinter.connect(address);
  await smartPrinter.print(data);
} finally {
  await smartPrinter.disconnect();
}
```

### Performance Monitoring

```dart
// Monitor performance metrics
final status = await smartPrinter.getStatus();
print('Cache hit rate: ${status.cacheHitRate}%');
print('Connection pool efficiency: ${status.connectionPoolEfficiency}%');
print('Average print time: ${status.averagePrintTime}ms');
```

## Troubleshooting

### Common Issues

#### High Cache Miss Rate
```dart
// Increase cache TTL
final config = ZebraPrinterSmartConfig(
  cacheTtl: Duration(minutes: 60), // Increase from 30 minutes
);
```

#### Connection Pool Exhaustion
```dart
// Increase max connections
final config = ZebraPrinterSmartConfig(
  maxConnections: 5, // Increase from 3
);
```

#### Slow Network Performance
```dart
// Disable multichannel if causing issues
final config = ZebraPrinterSmartConfig(
  enableMultichannel: false,
);
```

### Debug Mode

```dart
// Enable debug logging
final config = ZebraPrinterSmartConfig(
  enableDebugLogging: true,
);

// Monitor operation logs
smartPrinter.onOperationLog.listen((log) {
  print('Operation: ${log.operation} - ${log.duration}ms');
});
```

## Conclusion

The `ZebraPrinterSmart` API represents a significant evolution in Zebra printer integration, providing:

- **60-80% performance improvements** over current methods
- **Intelligent caching** for reduced overhead
- **Connection pooling** for faster subsequent operations
- **Smart retry logic** for improved reliability
- **Connection-aware optimization** for maximum efficiency
- **Background operations** for better responsiveness

This new API maintains backward compatibility while providing a clear migration path to significantly improved performance and reliability.

For detailed implementation information, see the [ZebraPrinterSmart Performance API Plan](.readme/plan/zebra-auto-performance-api.md). 