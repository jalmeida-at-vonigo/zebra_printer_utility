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
- `INVALID_DEVICE_ADDRESS` - Invalid device address format
- `CONNECTION_RETRY_FAILED` - Connection failed after retries
- `CONNECTION_FAILED` - Connection attempt failed
- `DISCONNECT_FAILED` - Disconnection attempt failed

### Discovery Errors
- `DISCOVERY_ERROR` - General discovery failure
- `DISCOVERY_TIMEOUT` - Discovery operation timed out
- `NO_PERMISSION` - Missing required permissions
- `BLUETOOTH_DISABLED` - Bluetooth is turned off
- `NETWORK_ERROR` - Network discovery failed
- `NO_PRINTERS_FOUND` - No printers were found during discovery

### Print Errors
- `PRINT_ERROR` - General print failure
- `PRINT_TIMEOUT` - Print operation timed out
- `PRINTER_NOT_READY` - Printer not ready to print
- `OUT_OF_PAPER` - No media detected
- `HEAD_OPEN` - Print head is open
- `PRINTER_PAUSED` - Printer is paused
- `RIBBON_ERROR` - Ribbon issue detected
- `PRINT_RETRY_FAILED` - Print failed after retries
- `PRINT_FAILED` - Print operation failed
- `PRINTER_JAMMED` - Printer is jammed
- `RIBBON_OUT` - Ribbon is out
- `MEDIA_ERROR` - Media issue detected
- `PRINT_HEAD_ERROR` - Print head malfunction

### Data Errors
- `PRINT_DATA_INVALID_FORMAT` - Print data format is invalid
- `PRINT_DATA_TOO_LARGE` - Print data exceeds size limits
- `INVALID_FORMAT` - Unrecognized data format
- `EMPTY_DATA` - No data provided
- `LANGUAGE_MISMATCH` - Printer language mismatch

### Operation Errors
- `OPERATION_TIMEOUT` - Operation timed out
- `OPERATION_CANCELLED` - Operation was cancelled
- `INVALID_ARGUMENT` - Invalid method argument
- `OPERATION_ERROR` - General operation failure

### Status Errors
- `STATUS_CHECK_FAILED` - Status check failed
- `STATUS_TIMEOUT` - Status check timed out
- `DETAILED_STATUS_CHECK_FAILED` - Detailed status check failed
- `BASIC_STATUS_CHECK_FAILED` - Basic status check failed
- `STATUS_CONNECTION_ERROR` - Connection error during status check
- `STATUS_TIMEOUT_ERROR` - Timeout during status check

### Command Errors
- `COMMAND_ERROR` - Command execution failed

### Hardware Errors
- `CALIBRATION_REQUIRED` - Printer calibration required
- `BUFFER_FULL` - Printer buffer is full
- `TEMPERATURE_ERROR` - Temperature issue detected

### System Errors
- `NOT_IMPLEMENTED` - Feature not implemented
- `UNKNOWN_ERROR` - Unexpected error
- `INTERNAL_ERROR` - Internal system error

### ZSDK-Specific Errors
- `ZEBRA_NO_CONNECTION` - ZSDK connection error
- `ZEBRA_WRITE_FAILURE` - ZSDK write operation failed
- `ZEBRA_READ_FAILURE` - ZSDK read operation failed
- `ZEBRA_UNKNOWN_PRINTER_LANGUAGE` - Unknown printer language
- `ZEBRA_INVALID_PRINTER_LANGUAGE` - Invalid printer language
- `ZEBRA_MALFORMED_NETWORK_DISCOVERY_ADDRESS` - Invalid discovery address
- `ZEBRA_NETWORK_ERROR_DURING_DISCOVERY` - Network error during discovery
- `ZEBRA_INVALID_DISCOVERY_HOP_COUNT` - Invalid hop count
- `ZEBRA_MALFORMED_PRINTER_STATUS_RESPONSE` - Invalid status response
- `ZEBRA_INVALID_FORMAT_NAME` - Invalid format name
- `ZEBRA_BAD_FILE_DIRECTORY_ENTRY` - Bad file directory entry
- `ZEBRA_MALFORMED_FORMAT_FIELD_NUMBER` - Invalid format field number
- `ZEBRA_INVALID_FILE_NAME` - Invalid file name
- `ZEBRA_INVALID_PRINTER_DRIVE_LETTER` - Invalid drive letter

### Timeout-Specific Errors
- `CONNECTION_SPECIFIC_TIMEOUT` - Connection-specific timeout
- `PRINT_SPECIFIC_TIMEOUT` - Print-specific timeout
- `STATUS_SPECIFIC_TIMEOUT` - Status-specific timeout
- `COMMAND_SPECIFIC_TIMEOUT` - Command-specific timeout

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

