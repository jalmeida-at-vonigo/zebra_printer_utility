/// Result class for consistent error handling across the plugin
class Result<T> {
  final bool success;
  final T? data;
  final ErrorInfo? error;

  const Result._({
    required this.success,
    this.data,
    this.error,
  });

  /// Create a successful result
  factory Result.success([T? data]) {
    return Result._(
      success: true,
      data: data,
    );
  }

  /// Create a failed result
  factory Result.failure(ErrorInfo error) {
    return Result._(
      success: false,
      error: error,
    );
  }

  /// Create a failed result from exception
  factory Result.error(
    String message, {
    String? code,
    int? errorNumber,
    dynamic nativeError,
    StackTrace? dartStackTrace,
  }) {
    return Result._(
      success: false,
      error: ErrorInfo(
        message: message,
        code: code,
        errorNumber: errorNumber,
        nativeError: nativeError,
        dartStackTrace: dartStackTrace,
      ),
    );
  }

  /// Transform the data if successful
  Result<R> map<R>(R Function(T data) transform) {
    if (success && data != null) {
      final nonNullData = data as T;
      return Result.success(transform(nonNullData));
    }
    return Result.failure(error ?? ErrorInfo(message: 'Unknown error'));
  }

  /// Execute function if successful
  Result<T> ifSuccess(void Function(T? data) action) {
    if (success) {
      action(data);
    }
    return this;
  }

  /// Execute function if failed
  Result<T> ifFailure(void Function(ErrorInfo error) action) {
    if (!success && error != null) {
      action(error!);
    }
    return this;
  }

  /// Get data or throw exception
  T get dataOrThrow {
    if (success) {
      return data as T;
    }
    throw error?.toException() ?? Exception('Unknown error');
  }

  /// Get data or default value
  T getOrElse(T defaultValue) {
    return success ? (data ?? defaultValue) : defaultValue;
  }
}

/// Error information with comprehensive details
class ErrorInfo {
  /// Human-readable error message
  final String message;

  /// Error code (e.g., 'CONNECTION_ERROR', 'PRINT_ERROR')
  final String? code;

  /// Numeric error code from native layer
  final int? errorNumber;

  /// Native error object (platform specific)
  final dynamic nativeError;

  /// Dart stack trace
  final StackTrace? dartStackTrace;

  /// Native stack trace as string
  final String? nativeStackTrace;

  /// Timestamp when error occurred
  final DateTime timestamp;

  ErrorInfo({
    required this.message,
    this.code,
    this.errorNumber,
    this.nativeError,
    this.dartStackTrace,
    this.nativeStackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to exception for throwing
  Exception toException() {
    return ZebraPrinterException(this);
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'code': code,
      'errorNumber': errorNumber,
      'nativeError': nativeError?.toString(),
      'dartStackTrace': dartStackTrace?.toString(),
      'nativeStackTrace': nativeStackTrace,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ErrorInfo:');
    buffer.writeln('  Message: $message');
    if (code != null) buffer.writeln('  Code: $code');
    if (errorNumber != null) buffer.writeln('  Error Number: $errorNumber');
    buffer.writeln('  Timestamp: $timestamp');
    if (nativeError != null) {
      buffer.writeln('  Native Error: $nativeError');
    }
    if (nativeStackTrace != null) {
      buffer.writeln('  Native Stack Trace:');
      buffer.writeln(nativeStackTrace);
    }
    if (dartStackTrace != null) {
      buffer.writeln('  Dart Stack Trace:');
      buffer.writeln(dartStackTrace);
    }
    return buffer.toString();
  }
}

/// Custom exception for Zebra printer errors
class ZebraPrinterException implements Exception {
  final ErrorInfo error;

  ZebraPrinterException(this.error);

  @override
  String toString() => error.toString();
}

/// Standard error codes used throughout the plugin
class ErrorCodes {
  // Connection errors
  static const String connectionError = 'CONNECTION_ERROR';
  static const String connectionTimeout = 'CONNECTION_TIMEOUT';
  static const String connectionLost = 'CONNECTION_LOST';
  static const String notConnected = 'NOT_CONNECTED';
  static const String alreadyConnected = 'ALREADY_CONNECTED';

  // Discovery errors
  static const String discoveryError = 'DISCOVERY_ERROR';
  static const String noPermission = 'NO_PERMISSION';
  static const String bluetoothDisabled = 'BLUETOOTH_DISABLED';
  static const String networkError = 'NETWORK_ERROR';
  static const String noPrintersFound = 'NO_PRINTERS_FOUND';
  static const String multiplePrintersFound = 'MULTIPLE_PRINTERS_FOUND';

  // Print errors
  static const String printError = 'PRINT_ERROR';
  static const String printerNotReady = 'PRINTER_NOT_READY';
  static const String outOfPaper = 'OUT_OF_PAPER';
  static const String headOpen = 'HEAD_OPEN';
  static const String printerPaused = 'PRINTER_PAUSED';

  // Data errors
  static const String invalidData = 'INVALID_DATA';
  static const String invalidFormat = 'INVALID_FORMAT';
  static const String encodingError = 'ENCODING_ERROR';

  // Operation errors
  static const String operationTimeout = 'OPERATION_TIMEOUT';
  static const String operationCancelled = 'OPERATION_CANCELLED';
  static const String invalidArgument = 'INVALID_ARGUMENT';
  static const String operationError = 'OPERATION_ERROR';

  // Platform errors
  static const String platformError = 'PLATFORM_ERROR';
  static const String notImplemented = 'NOT_IMPLEMENTED';
  static const String unknownError = 'UNKNOWN_ERROR';
}
