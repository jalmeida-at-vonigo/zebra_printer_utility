# Error Handling Guide

## Overview

The Zebra Printer Plugin uses a consistent Result-based error handling pattern that provides detailed error information including error codes, messages, and stack traces from both Dart and native layers.

## Result Pattern

All operations return a `Result<T>` object that encapsulates success or failure:

```dart
class Result<T> {
  final bool success;
  final T? data;
  final ErrorInfo? error;
}
```

## Basic Usage

### Handling Results

```dart
final result = await printerService.connect('192.168.1.100');

if (result.success) {
  print('Connected successfully');
} else {
  print('Connection failed: ${result.error!.message}');
}
```

### Using Functional Methods

```dart
// Chain operations
await printerService.connect(address)
  .ifSuccess((data) => print('Connected'))
  .ifFailure((error) => print('Failed: ${error.message}'));

// Transform data
final labelResult = await printerService.getPrinterInfo()
  .map((info) => 'Printer: ${info.model}');

// Get data or default
final printerName = await printerService.getPrinterName()
  .getOrElse('Unknown Printer');
```

## Error Information

Each error contains comprehensive details:

```dart
class ErrorInfo {
  String message;          // Human-readable message
  String? code;           // Error code (see ErrorCodes)
  int? errorNumber;       // Native error number
  dynamic nativeError;    // Platform-specific error
  StackTrace? dartStackTrace;
  String? nativeStackTrace;
  DateTime timestamp;
}
```

## Error Codes

### Connection Errors
- `CONNECTION_ERROR` - General connection failure
- `CONNECTION_TIMEOUT` - Connection attempt timed out
- `CONNECTION_LOST` - Lost connection during operation
- `NOT_CONNECTED` - Operation requires connection
- `ALREADY_CONNECTED` - Already connected to a printer

### Discovery Errors
- `DISCOVERY_ERROR` - General discovery failure
- `NO_PERMISSION` - Missing required permissions
- `BLUETOOTH_DISABLED` - Bluetooth is turned off
- `NETWORK_ERROR` - Network discovery failed
- `NO_PRINTERS_FOUND` - No printers were found during discovery
- `MULTIPLE_PRINTERS_FOUND` - Multiple printers found when expecting one (e.g., in autoPrint)

### Print Errors
- `PRINT_ERROR` - General print failure
- `PRINTER_NOT_READY` - Printer not ready to print
- `OUT_OF_PAPER` - No media detected
- `HEAD_OPEN` - Print head is open
- `PRINTER_PAUSED` - Printer is paused

### Data Errors
- `INVALID_DATA` - Print data is invalid
- `INVALID_FORMAT` - Unrecognized print format
- `ENCODING_ERROR` - Data encoding error

### Operation Errors
- `OPERATION_TIMEOUT` - Operation timed out
- `OPERATION_CANCELLED` - Operation was cancelled
- `INVALID_ARGUMENT` - Invalid method argument
- `OPERATION_ERROR` - General operation failure

### Platform Errors
- `PLATFORM_ERROR` - Platform-specific error
- `NOT_IMPLEMENTED` - Feature not implemented
- `UNKNOWN_ERROR` - Unexpected error

## Error Handling Examples

### Connection with Retry

```dart
Future<Result<void>> connectWithRetry(String address, {int maxRetries = 3}) async {
  for (int i = 0; i < maxRetries; i++) {
    final result = await printerService.connect(address);
    
    if (result.success) {
      return result;
    }
    
    // Check if error is retryable
    if (result.error!.code == ErrorCodes.connectionTimeout && i < maxRetries - 1) {
      await Future.delayed(Duration(seconds: 2));
      continue;
    }
    
    return result;
  }
  
  return Result.error('Failed after $maxRetries attempts');
}
```

### Comprehensive Error Logging

```dart
void logError(ErrorInfo error) {
  logger.error('Printer Error: ${error.message}');
  logger.error('Code: ${error.code}');
  logger.error('Error Number: ${error.errorNumber}');
  logger.error('Timestamp: ${error.timestamp}');
  
  if (error.nativeError != null) {
    logger.error('Native Error: ${error.nativeError}');
  }
  
  if (error.nativeStackTrace != null) {
    logger.error('Native Stack:\n${error.nativeStackTrace}');
  }
  
  if (error.dartStackTrace != null) {
    logger.error('Dart Stack:\n${error.dartStackTrace}');
  }
}
```

### User-Friendly Error Messages

```dart
String getUserMessage(ErrorInfo error) {
  switch (error.code) {
    case ErrorCodes.notConnected:
      return 'Please connect to a printer first';
    case ErrorCodes.outOfPaper:
      return 'The printer is out of paper';
    case ErrorCodes.headOpen:
      return 'Please close the printer head';
    case ErrorCodes.connectionTimeout:
      return 'Could not connect to printer. Please check it is turned on';
    case ErrorCodes.noPermission:
      return 'Please grant Bluetooth permission in Settings';
    default:
      return error.message;
  }
}
```

## Platform-Specific Errors

### iOS Errors

```dart
// MFi Bluetooth errors
if (error.nativeError is NSError) {
  final nsError = error.nativeError as NSError;
  switch (nsError.code) {
    case -1: // EAAccessoryManager error
      return 'Printer not paired in iOS Settings';
  }
}
```

### Android Errors

```dart
// Android-specific handling
if (error.code == ErrorCodes.bluetoothDisabled) {
  // Prompt user to enable Bluetooth
  showBluetoothEnableDialog();
}
```

## Best Practices

1. **Always Check Results**
   ```dart
   // Don't assume success
   final result = await operation();
   if (!result.success) {
     handleError(result.error!);
     return;
   }
   ```

2. **Provide Context**
   ```dart
   try {
     final result = await riskyOperation();
     if (!result.success) {
       throw result.error!.toException();
     }
   } catch (e, stack) {
     return Result.error(
       'Failed during label printing',
       code: ErrorCodes.printError,
       dartStackTrace: stack,
     );
   }
   ```

3. **Log Errors**
   ```dart
   result.ifFailure((error) {
     logger.error('Operation failed', error: error.toMap());
   });
   ```

4. **Handle Specific Errors**
   ```dart
   if (result.error?.code == ErrorCodes.connectionLost) {
     // Attempt reconnection
     await reconnect();
   }
   ```

## Migration from Exceptions

If migrating from exception-based code:

```dart
// Old pattern
try {
  await printer.connect(address);
} catch (e) {
  print('Error: $e');
}

// New pattern
final result = await printer.connect(address);
if (!result.success) {
  print('Error: ${result.error!.message}');
}

// Or use dataOrThrow for compatibility
// Note: dataOrThrow is available for advanced consumers who want exception-based access, but is never used internally by the library.
try {
  await printer.connect(address).dataOrThrow;
} catch (e) {
  print('Error: $e');
}
```