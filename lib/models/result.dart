/// Result category enumeration for type-safe classification
enum ResultCategory {
  connection,
  discovery,
  print,
  status,
  command,
  data,
  operation,
  platform,
  system,
  configuration,
  validation,
}

/// Error type enumeration for granular classification
enum ErrorType {
  // Connection types
  connectionFailure,
  connectionTimeout,
  connectionLost,

  // Permission/Security types
  permissionDenied,
  authenticationFailed,

  // Hardware types
  hardwareFailure,
  sensorMalfunction,
  printHeadError,
  powerError,

  // Timeout types
  operationTimeout,
  statusTimeout,
  printTimeout,

  // Data/Format types
  invalidData,
  formatError,
  encodingError,

  // General types
  unknown,
  validation,
  configuration,
}

/// Result class for consistent error handling across the plugin
class Result<T> {
  const Result._({
    required this.success,
    this.data,
    this.error,
    this.successInfo,
  });

  /// Create a successful result
  factory Result.success([T? data]) {
    return Result._(
      success: true,
      data: data,
    );
  }

  /// Create a successful result with success info
  factory Result.successWithInfo(
    SuccessInfo successInfo, [
    T? data,
  ]) {
    return Result._(
      success: true,
      data: data,
      successInfo: successInfo,
    );
  }

  /// Create a successful result using SuccessCode
  factory Result.successCode(
    SuccessCode successCode, {
    List<Object>? formatArgs,
    T? data,
  }) {
    return Result._(
      success: true,
      data: data,
      successInfo: SuccessInfo.fromSuccessCode(
        successCode,
        formatArgs: formatArgs,
      ),
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

  /// Create a failed result using ErrorCode
  factory Result.errorCode(
    ErrorCode errorCode, {
    List<Object>? formatArgs,
    int? errorNumber,
    dynamic nativeError,
    StackTrace? dartStackTrace,
  }) {
    return Result._(
      success: false,
      error: ErrorInfo.fromErrorCode(
        errorCode,
        formatArgs: formatArgs,
        errorNumber: errorNumber,
        nativeError: nativeError,
        dartStackTrace: dartStackTrace,
      ),
    );
  }

  /// Create a failed result from another Result's error
  /// This preserves all error details from the source Result
  factory Result.errorFromResult(Result source, [String? additionalMessage]) {
    if (source.success || source.error == null) {
      // If source is successful or has no error, create a generic error
      return Result._(
        success: false,
        error: ErrorInfo(
          message: additionalMessage ?? 'Error created from successful result',
          code: ErrorCodes.internalError.code,
          dartStackTrace: StackTrace.current,
        ),
      );
    }

    // Copy all error details
    final sourceError = source.error!;
    final message = additionalMessage != null
        ? '$additionalMessage: ${sourceError.message}'
        : sourceError.message;

    return Result._(
      success: false,
      error: ErrorInfo(
        message: message,
        code: sourceError.code,
        errorNumber: sourceError.errorNumber,
        nativeError: sourceError.nativeError,
        dartStackTrace: sourceError.dartStackTrace,
        nativeStackTrace: sourceError.nativeStackTrace,
        timestamp: sourceError.timestamp,
        originalErrorCode: sourceError.originalErrorCode,
      ),
    );
  }

  /// Create a successful result from another Result
  /// This can be used to transform data while preserving success info
  factory Result.successFromResult(Result source, [T? data]) {
    if (!source.success) {
      // If source is not successful, this is likely a programming error
      // but we'll create a success anyway as requested
      return Result._(
        success: true,
        data: data,
        successInfo: SuccessInfo(
          message: 'Success created from failed result',
          code: SuccessCodes.operationSuccess.code,
        ),
      );
    }

    // Copy success info if available
    if (source.successInfo != null) {
      final sourceInfo = source.successInfo!;
      return Result._(
        success: true,
        data: data,
        successInfo: SuccessInfo(
          message: sourceInfo.message,
          code: sourceInfo.code,
          timestamp: sourceInfo.timestamp,
          originalSuccessCode: sourceInfo.originalSuccessCode,
        ),
      );
    }

    // No success info, just create plain success
    return Result._(
      success: true,
      data: data,
    );
  }

  final bool success;
  final T? data;
  final ErrorInfo? error;
  final SuccessInfo? successInfo;

  /// Transform the data if successful
  Result<R> map<R>(R Function(T data) transform) {
    if (success && data != null) {
      final nonNullData = data as T;
      return Result.success(transform(nonNullData));
    }
    return Result.failure(
        error ?? ErrorInfo.fromErrorCode(ErrorCodes.unknownError));
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

  /// Get data or throw exception if not successful.
  ///
  /// This is intended for advanced consumers who want exception-based access.
  /// It must NOT be used anywhere in the library code itself.
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
  
  /// Get data or execute a function that returns a default value
  T getOrElseCall(T Function() defaultFunc) {
    return success ? (data ?? defaultFunc()) : defaultFunc();
  }

  /// Get data or null
  T? get dataOrNull => success ? data : null;
}

/// Type-safe error classification extensions for Result
extension ResultErrorClassification<T> on Result<T> {
  /// Get the error category if this is a failure
  ResultCategory? get errorCategory {
    if (success || error?.originalErrorCode?.category == null) return null;
    return error!.originalErrorCode!.category;
  }

  /// Get the error type if this is a failure
  ErrorType? get errorType {
    if (success || error?.code == null) return null;

    // Map error codes to ErrorType enum for granular classification
    final code = error!.code!.toLowerCase();

    // Connection types
    if (code.contains('connection_error') ||
        code.contains('connection_failed')) {
      return ErrorType.connectionFailure;
    }
    if (code.contains('connection_timeout') ||
        code.contains('connection_specific_timeout')) {
      return ErrorType.connectionTimeout;
    }
    if (code.contains('connection_lost')) {
      return ErrorType.connectionLost;
    }

    // Permission/Security types
    if (code.contains('no_permission') || code.contains('permission')) {
      return ErrorType.permissionDenied;
    }
    if (code.contains('authentication')) {
      return ErrorType.authenticationFailed;
    }

    // Hardware types
    if (code.contains('hardware') ||
        code.contains('sensor_error') ||
        code.contains('temperature_error') ||
        code.contains('power_error')) {
      return ErrorType.hardwareFailure;
    }
    if (code.contains('sensor')) {
      return ErrorType.sensorMalfunction;
    }
    if (code.contains('print_head')) {
      return ErrorType.printHeadError;
    }
    if (code.contains('power')) {
      return ErrorType.powerError;
    }

    // Timeout types
    if (code.contains('operation_timeout')) {
      return ErrorType.operationTimeout;
    }
    if (code.contains('status_timeout') ||
        code.contains('status_specific_timeout')) {
      return ErrorType.statusTimeout;
    }
    if (code.contains('print_timeout') ||
        code.contains('print_specific_timeout')) {
      return ErrorType.printTimeout;
    }

    // Data/Format types
    if (code.contains('invalid_data') ||
        code.contains('invalid_format') ||
        code.contains('data_corruption')) {
      return ErrorType.invalidData;
    }
    if (code.contains('format_error') || code.contains('malformed')) {
      return ErrorType.formatError;
    }
    if (code.contains('encoding')) {
      return ErrorType.encodingError;
    }

    // Validation types
    if (code.contains('validation')) {
      return ErrorType.validation;
    }
    if (code.contains('configuration')) {
      return ErrorType.configuration;
    }

    // Default to unknown
    return ErrorType.unknown;
  }

  /// Type-safe error classification methods
  bool get isConnectionError =>
      errorCategory == ResultCategory.connection ||
      errorType == ErrorType.connectionFailure;

  bool get isTimeoutError => [
        ErrorType.connectionTimeout,
        ErrorType.printTimeout,
        ErrorType.operationTimeout,
        ErrorType.statusTimeout
      ].contains(errorType);

  bool get isPermissionError => errorType == ErrorType.permissionDenied;

  bool get isHardwareError => [
        ErrorType.hardwareFailure,
        ErrorType.sensorMalfunction,
        ErrorType.printHeadError,
        ErrorType.powerError
      ].contains(errorType);

  bool get isRetryableError => [
        ErrorType.connectionTimeout,
        ErrorType.printTimeout,
        ErrorType.operationTimeout,
        ErrorType.connectionLost
      ].contains(errorType);

  bool get isNonRetryableError => [
        ErrorType.permissionDenied,
        ErrorType.hardwareFailure,
        ErrorType.invalidData,
        ErrorType.formatError
      ].contains(errorType);
}

/// Structured success code with formatable message template
class SuccessCode {

  const SuccessCode({
    required this.code,
    required this.messageTemplate,
    required this.category,
    required this.description,
  });
  final String code;
  final String messageTemplate;
  final ResultCategory category;
  final String description;

  /// Format the message template with provided arguments
  String formatMessage(List<Object>? args) {
    if (args == null || args.isEmpty) {
      return messageTemplate;
    }

    try {
      return messageTemplate.replaceAllMapped(
        RegExp(r'\{(\d+)\}'),
        (match) {
          final index = int.parse(match.group(1)!);
          if (index < args.length) {
            return args[index].toString();
          }
          return match.group(0)!;
        },
      );
    } catch (e) {
      // Fallback to template if formatting fails
      return messageTemplate;
    }
  }

  @override
  String toString() => 'SuccessCode($code: $messageTemplate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuccessCode &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Success information with comprehensive details
class SuccessInfo {
  SuccessInfo({
    required this.message,
    this.code,
    DateTime? timestamp,
    this.originalSuccessCode,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create SuccessInfo from SuccessCode
  factory SuccessInfo.fromSuccessCode(
    SuccessCode successCode, {
    List<Object>? formatArgs,
    DateTime? timestamp,
  }) {
    return SuccessInfo(
      message: successCode.formatMessage(formatArgs),
      code: successCode.code,
      timestamp: timestamp,
      originalSuccessCode: successCode,
    );
  }

  /// Human-readable success message
  final String message;

  /// Success code (e.g., 'CONNECTION_SUCCESS', 'PRINT_SUCCESS')
  final String? code;

  /// Timestamp when success occurred
  final DateTime timestamp;

  /// Original success code if created from SuccessCode
  final SuccessCode? originalSuccessCode;

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'code': code,
      'timestamp': timestamp.toIso8601String(),
      'category': originalSuccessCode?.category,
      'description': originalSuccessCode?.description,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('SuccessInfo:');
    buffer.writeln('  Message: $message');
    if (code != null) buffer.writeln('  Code: $code');
    if (originalSuccessCode?.category != null) {
      buffer.writeln('  Category: ${originalSuccessCode!.category}');
    }
    if (originalSuccessCode?.description != null) {
      buffer.writeln('  Description: ${originalSuccessCode!.description}');
    }
    buffer.writeln('  Timestamp: $timestamp');
    return buffer.toString();
  }
}

/// Structured error code with formatable message template
class ErrorCode {
  const ErrorCode({
    required this.code,
    required this.messageTemplate,
    required this.category,
    required this.description,
    this.recoveryHint,
  });
  final String code;
  final String messageTemplate;
  final ResultCategory category;
  final String description;
  final String? recoveryHint;

  /// Format the message template with provided arguments
  String formatMessage(List<Object>? args) {
    if (args == null || args.isEmpty) {
      return messageTemplate;
    }

    try {
      return messageTemplate.replaceAllMapped(
        RegExp(r'\{(\d+)\}'),
        (match) {
          final index = int.parse(match.group(1)!);
          if (index < args.length) {
            return args[index].toString();
          }
          return match.group(0)!;
        },
      );
    } catch (e) {
      // Fallback to template if formatting fails
      return messageTemplate;
    }
  }

  @override
  String toString() => 'ErrorCode($code: $messageTemplate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorCode &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Error information with comprehensive details
class ErrorInfo {
  ErrorInfo({
    required this.message,
    this.code,
    this.errorNumber,
    this.nativeError,
    this.dartStackTrace,
    this.nativeStackTrace,
    DateTime? timestamp,
    this.originalErrorCode,
    this.recoveryHint,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create ErrorInfo from ErrorCode
  factory ErrorInfo.fromErrorCode(
    ErrorCode errorCode, {
    List<Object>? formatArgs,
    int? errorNumber,
    dynamic nativeError,
    StackTrace? dartStackTrace,
    String? nativeStackTrace,
    DateTime? timestamp,
  }) {
    return ErrorInfo(
      message: errorCode.formatMessage(formatArgs),
      code: errorCode.code,
      errorNumber: errorNumber,
      nativeError: nativeError,
      dartStackTrace: dartStackTrace,
      nativeStackTrace: nativeStackTrace,
      timestamp: timestamp,
      originalErrorCode: errorCode,
      recoveryHint: errorCode.recoveryHint,
    );
  }

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

  /// Original error code if created from ErrorCode
  final ErrorCode? originalErrorCode;

  /// Recovery hint for user intervention
  final String? recoveryHint;

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
      'category': originalErrorCode?.category,
      'description': originalErrorCode?.description,
      'recoveryHint': recoveryHint,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ErrorInfo:');
    buffer.writeln('  Message: $message');
    if (code != null) buffer.writeln('  Code: $code');
    if (originalErrorCode?.category != null) {
      buffer.writeln('  Category: ${originalErrorCode!.category}');
    }
    if (originalErrorCode?.description != null) {
      buffer.writeln('  Description: ${originalErrorCode!.description}');
    }
    if (recoveryHint != null) {
      buffer.writeln('  Recovery Hint: $recoveryHint');
    }
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

  ZebraPrinterException(this.error);

  final ErrorInfo error;
  @override
  String toString() => error.toString();
}

/// Comprehensive success codes used throughout the plugin
/// All success messages must be defined here - never define success codes/messages elsewhere
class SuccessCodes {
  // ===== CONNECTION SUCCESS =====
  static const connectionSuccess = SuccessCode(
    code: 'CONNECTION_SUCCESS',
    messageTemplate: 'Successfully connected to printer',
    category: ResultCategory.connection,
    description: 'Printer connection established successfully',
  );

  static const connectionRetrySuccess = SuccessCode(
    code: 'CONNECTION_RETRY_SUCCESS',
    messageTemplate: 'Successfully connected to printer after {0} attempts',
    category: ResultCategory.connection,
    description: 'Printer connection established after retry attempts',
  );

  static const disconnectSuccess = SuccessCode(
    code: 'DISCONNECT_SUCCESS',
    messageTemplate: 'Successfully disconnected from printer',
    category: ResultCategory.connection,
    description: 'Printer connection terminated successfully',
  );

  // ===== DISCOVERY SUCCESS =====
  static const discoverySuccess = SuccessCode(
    code: 'DISCOVERY_SUCCESS',
    messageTemplate: 'Successfully discovered {0} printers',
    category: ResultCategory.discovery,
    description: 'Printer discovery completed successfully',
  );

  static const discoveryTimeoutSuccess = SuccessCode(
    code: 'DISCOVERY_TIMEOUT_SUCCESS',
    messageTemplate: 'Discovery completed within {0} seconds',
    category: ResultCategory.discovery,
    description: 'Discovery completed within specified timeout',
  );

  // ===== PRINT SUCCESS =====
  static const printSuccess = SuccessCode(
    code: 'PRINT_SUCCESS',
    messageTemplate: 'Print operation completed successfully',
    category: ResultCategory.print,
    description: 'Print job completed successfully',
  );

  static const printRetrySuccess = SuccessCode(
    code: 'PRINT_RETRY_SUCCESS',
    messageTemplate:
        'Print operation completed successfully after {0} attempts',
    category: ResultCategory.print,
    description: 'Print job completed after retry attempts',
  );

  static const printDataSent = SuccessCode(
    code: 'PRINT_DATA_SENT',
    messageTemplate: 'Successfully sent {0} bytes of print data',
    category: ResultCategory.print,
    description: 'Print data transmitted successfully',
  );

  // ===== STATUS SUCCESS =====
  static const statusCheckSuccess = SuccessCode(
    code: 'STATUS_CHECK_SUCCESS',
    messageTemplate: 'Successfully retrieved printer status',
    category: ResultCategory.status,
    description: 'Printer status check completed successfully',
  );

  static const statusTimeoutSuccess = SuccessCode(
    code: 'STATUS_TIMEOUT_SUCCESS',
    messageTemplate: 'Status check completed within {0} seconds',
    category: ResultCategory.status,
    description: 'Status check completed within specified timeout',
  );

  // ===== COMMAND SUCCESS =====
  static const commandSuccess = SuccessCode(
    code: 'COMMAND_SUCCESS',
    messageTemplate: 'Command executed successfully: {0}',
    category: ResultCategory.command,
    description: 'Printer command executed successfully',
  );

  static const commandTimeoutSuccess = SuccessCode(
    code: 'COMMAND_TIMEOUT_SUCCESS',
    messageTemplate: 'Command completed within {0} seconds',
    category: ResultCategory.command,
    description: 'Command completed within specified timeout',
  );

  // ===== OPERATION SUCCESS =====
  static const operationSuccess = SuccessCode(
    code: 'OPERATION_SUCCESS',
    messageTemplate: 'Operation completed successfully',
    category: ResultCategory.operation,
    description: 'General operation completed successfully',
  );

  static const operationTimeoutSuccess = SuccessCode(
    code: 'OPERATION_TIMEOUT_SUCCESS',
    messageTemplate: 'Operation completed within {0} seconds',
    category: ResultCategory.operation,
    description: 'Operation completed within specified timeout',
  );

  static const retrySuccess = SuccessCode(
    code: 'RETRY_SUCCESS',
    messageTemplate: 'Operation succeeded after {0} attempts',
    category: ResultCategory.operation,
    description: 'Operation completed successfully after retry attempts',
  );

  // ===== VALIDATION SUCCESS =====
  static const validationSuccess = SuccessCode(
    code: 'VALIDATION_SUCCESS',
    messageTemplate: 'Validation passed: {0}',
    category: ResultCategory.validation,
    description: 'Input validation completed successfully',
  );

  static const dataValidationSuccess = SuccessCode(
    code: 'DATA_VALIDATION_SUCCESS',
    messageTemplate: 'Data validation passed for {0}',
    category: ResultCategory.validation,
    description: 'Data validation completed successfully',
  );

  // ===== CONFIGURATION SUCCESS =====
  static const configurationSuccess = SuccessCode(
    code: 'CONFIGURATION_SUCCESS',
    messageTemplate: 'Configuration applied successfully: {0}',
    category: ResultCategory.configuration,
    description: 'Configuration change applied successfully',
  );

  static const settingsApplied = SuccessCode(
    code: 'SETTINGS_APPLIED',
    messageTemplate: 'Printer settings applied successfully',
    category: ResultCategory.configuration,
    description: 'Printer settings updated successfully',
  );

  // ===== UTILITY METHODS =====

  /// Get success code by code string
  static SuccessCode? fromCode(String code) {
    // This is a simplified approach - manually check each success code
    final allCodes = [
      connectionSuccess,
      connectionRetrySuccess,
      disconnectSuccess,
      discoverySuccess,
      discoveryTimeoutSuccess,
      printSuccess,
      printRetrySuccess,
      printDataSent,
      statusCheckSuccess,
      statusTimeoutSuccess,
      commandSuccess,
      commandTimeoutSuccess,
      operationSuccess,
      operationTimeoutSuccess,
      retrySuccess,
      validationSuccess,
      dataValidationSuccess,
      configurationSuccess,
      settingsApplied,
    ];

    try {
      return allCodes.firstWhere((successCode) => successCode.code == code);
    } catch (e) {
      return null;
    }
  }
}

/// Comprehensive error codes used throughout the plugin
/// All error messages must be defined here - never define error codes/messages elsewhere
class ErrorCodes {
  // ===== CONNECTION ERRORS =====
  static const connectionError = ErrorCode(
    code: 'CONNECTION_ERROR',
    messageTemplate: 'Failed to connect to printer',
    category: ResultCategory.connection,
    description: 'General connection failure',
    recoveryHint: 'Check network connection and ensure printer is powered on.',
  );

  static const connectionTimeout = ErrorCode(
    code: 'CONNECTION_TIMEOUT',
    messageTemplate: 'Connection timed out after {0} seconds',
    category: ResultCategory.connection,
    description: 'Connection attempt exceeded timeout',
    recoveryHint: 'Ensure printer is within range and not obstructed.',
  );

  static const connectionLost = ErrorCode(
    code: 'CONNECTION_LOST',
    messageTemplate: 'Connection to printer was lost',
    category: ResultCategory.connection,
    description: 'Active connection was unexpectedly terminated',
    recoveryHint: 'Re-establish connection by attempting to connect again.',
  );

  static const notConnected = ErrorCode(
    code: 'NOT_CONNECTED',
    messageTemplate: 'No printer is currently connected',
    category: ResultCategory.connection,
    description: 'Operation requires an active connection',
    recoveryHint: 'Connect to a printer using the connect method.',
  );

  static const alreadyConnected = ErrorCode(
    code: 'ALREADY_CONNECTED',
    messageTemplate: 'Already connected to printer at {0}',
    category: ResultCategory.connection,
    description: 'Attempt to connect when already connected',
    recoveryHint:
        'Disconnect from the current printer before attempting to connect to a new one.',
  );

  static const invalidDeviceAddress = ErrorCode(
    code: 'INVALID_DEVICE_ADDRESS',
    messageTemplate: 'Invalid device address: {0}',
    category: ResultCategory.connection,
    description: 'Device address format is invalid',
    recoveryHint:
        'Ensure the device address is correct and matches the printer model.',
  );

  static const connectionRetryFailed = ErrorCode(
    code: 'CONNECTION_RETRY_FAILED',
    messageTemplate: 'Failed to connect after {0} attempts',
    category: ResultCategory.connection,
    description: 'Connection failed after maximum retry attempts',
    recoveryHint: 'Review connection settings and ensure printer is reachable.',
  );

  // ===== DISCOVERY ERRORS =====
  static const discoveryError = ErrorCode(
    code: 'DISCOVERY_ERROR',
    messageTemplate: 'Failed to discover printers',
    category: ResultCategory.discovery,
    description: 'General discovery failure',
    recoveryHint: 'Ensure Bluetooth is enabled and try again.',
  );

  static const discoveryTimeout = ErrorCode(
    code: 'DISCOVERY_TIMEOUT',
    messageTemplate: 'Discovery timed out after {0} seconds',
    category: ResultCategory.discovery,
    description: 'Discovery operation exceeded timeout',
    recoveryHint: 'Increase the discovery timeout or ensure network is stable.',
  );

  static const noPermission = ErrorCode(
    code: 'NO_PERMISSION',
    messageTemplate: 'Permission denied: {0}',
    category: ResultCategory.discovery,
    description: 'Required permissions not granted',
    recoveryHint: 'Grant necessary permissions in your app\'s manifest.',
  );

  static const bluetoothDisabled = ErrorCode(
    code: 'BLUETOOTH_DISABLED',
    messageTemplate: 'Bluetooth is disabled',
    category: ResultCategory.discovery,
    description: 'Bluetooth must be enabled for discovery',
    recoveryHint: 'Enable Bluetooth in your device settings.',
  );

  static const networkError = ErrorCode(
    code: 'NETWORK_ERROR',
    messageTemplate: 'Network error: {0}',
    category: ResultCategory.discovery,
    description: 'Network-related discovery failure',
    recoveryHint: 'Check your internet connection and try again.',
  );

  static const noPrintersFound = ErrorCode(
    code: 'NO_PRINTERS_FOUND',
    messageTemplate: 'No printers found during discovery',
    category: ResultCategory.discovery,
    description: 'Discovery completed but no printers were found',
    recoveryHint: 'Ensure the printer is within range and powered on.',
  );

  static const multiplePrintersFound = ErrorCode(
    code: 'MULTIPLE_PRINTERS_FOUND',
    messageTemplate: 'Multiple printers found ({0}), specify device explicitly',
    category: ResultCategory.discovery,
    description: 'Ambiguous printer selection',
    recoveryHint:
        'Specify the exact printer model or address to avoid ambiguity.',
  );

  // ===== PRINT ERRORS =====
  static const printError = ErrorCode(
    code: 'PRINT_ERROR',
    messageTemplate: 'Print operation failed',
    category: ResultCategory.print,
    description: 'General print failure',
    recoveryHint: 'Check printer status and ensure it is ready for printing.',
  );

  static const printTimeout = ErrorCode(
    code: 'PRINT_TIMEOUT',
    messageTemplate: 'Print operation timed out after {0} seconds',
    category: ResultCategory.print,
    description: 'Print operation exceeded timeout',
    recoveryHint: 'Ensure printer is responsive and not busy.',
  );

  static const printerNotReady = ErrorCode(
    code: 'PRINTER_NOT_READY',
    messageTemplate: 'Printer is not ready: {0}',
    category: ResultCategory.print,
    description: 'Printer cannot accept print jobs',
    recoveryHint:
        'Ensure the printer is turned on, has paper, and is not jammed.',
  );

  static const outOfPaper = ErrorCode(
    code: 'OUT_OF_PAPER',
    messageTemplate: 'Printer is out of paper',
    category: ResultCategory.print,
    description: 'No paper available for printing',
    recoveryHint: 'Add more paper to the printer.',
  );

  static const headOpen = ErrorCode(
    code: 'HEAD_OPEN',
    messageTemplate: 'Printer head is open',
    category: ResultCategory.print,
    description: 'Printer head must be closed for printing',
    recoveryHint: 'Close the printer head to resume printing.',
  );

  static const printerPaused = ErrorCode(
    code: 'PRINTER_PAUSED',
    messageTemplate: 'Printer is paused',
    category: ResultCategory.print,
    description: 'Printer must be unpaused for printing',
    recoveryHint: 'Unpause the printer to continue printing.',
  );

  static const ribbonError = ErrorCode(
    code: 'RIBBON_ERROR',
    messageTemplate: 'Ribbon error: {0}',
    category: ResultCategory.print,
    description: 'Ribbon-related print failure',
    recoveryHint:
        'Replace the ribbon or check the printer\'s ribbon alignment.',
  );

  static const printDataError = ErrorCode(
    code: 'PRINT_DATA_ERROR',
    messageTemplate: 'Invalid print data: {0}',
    category: ResultCategory.print,
    description: 'Print data format or content error',
    recoveryHint:
        'Ensure the print data is valid and follows the correct format.',
  );

  static const printRetryFailed = ErrorCode(
    code: 'PRINT_RETRY_FAILED',
    messageTemplate: 'Failed to print after {0} attempts',
    category: ResultCategory.print,
    description: 'Print failed after maximum retry attempts',
    recoveryHint: 'Review print settings and ensure printer is ready.',
  );

  static const printDataInvalidFormat = ErrorCode(
    code: 'PRINT_DATA_INVALID_FORMAT',
    messageTemplate: 'Invalid print data format',
    category: ResultCategory.print,
    description: 'Print data format is invalid',
    recoveryHint:
        'Ensure the print data is in a valid format (e.g., ZPL, CPCL).',
  );

  static const printDataTooLarge = ErrorCode(
    code: 'PRINT_DATA_TOO_LARGE',
    messageTemplate: 'Print data too large: {0} bytes',
    category: ResultCategory.print,
    description: 'Print data exceeds maximum allowed size',
    recoveryHint:
        'Reduce the size of the print data or increase the printer\'s buffer size.',
  );

  // ===== DATA ERRORS =====
  static const invalidData = ErrorCode(
    code: 'INVALID_DATA',
    messageTemplate: 'Invalid data provided',
    category: ResultCategory.data,
    description: 'General data validation failure',
    recoveryHint:
        'Ensure the data you are sending is valid and meets the requirements.',
  );

  static const invalidFormat = ErrorCode(
    code: 'INVALID_FORMAT',
    messageTemplate: 'Invalid format: {0}',
    category: ResultCategory.data,
    description: 'Data format is not supported',
    recoveryHint: 'Ensure the data format is compatible with the printer.',
  );

  static const encodingError = ErrorCode(
    code: 'ENCODING_ERROR',
    messageTemplate: 'Encoding error: {0}',
    category: ResultCategory.data,
    description: 'Character encoding failure',
    recoveryHint:
        'Ensure the character encoding of your data matches the printer\'s settings.',
  );

  static const emptyData = ErrorCode(
    code: 'EMPTY_DATA',
    messageTemplate: 'No data provided for printing',
    category: ResultCategory.data,
    description: 'Print data is empty or null',
    recoveryHint: 'Provide valid print data to the printer.',
  );

  // ===== OPERATION ERRORS =====
  static const operationTimeout = ErrorCode(
    code: 'OPERATION_TIMEOUT',
    messageTemplate: 'Operation timed out after {0} seconds',
    category: ResultCategory.operation,
    description: 'Operation exceeded timeout',
    recoveryHint: 'Ensure the operation completes within the specified time.',
  );

  static const operationCancelled = ErrorCode(
    code: 'OPERATION_CANCELLED',
    messageTemplate: 'Operation was cancelled',
    category: ResultCategory.operation,
    description: 'Operation was cancelled by user or system',
    recoveryHint:
        'Check if the operation was explicitly cancelled by the user.',
  );

  static const invalidArgument = ErrorCode(
    code: 'INVALID_ARGUMENT',
    messageTemplate: 'Invalid argument: {0}',
    category: ResultCategory.operation,
    description: 'Invalid parameter provided',
    recoveryHint: 'Review the parameters passed to the operation.',
  );

  static const operationError = ErrorCode(
    code: 'OPERATION_ERROR',
    messageTemplate: 'Operation failed: {0}',
    category: ResultCategory.operation,
    description: 'General operation failure',
    recoveryHint: 'Investigate the cause of the operation failure.',
  );

  static const retryLimitExceeded = ErrorCode(
    code: 'RETRY_LIMIT_EXCEEDED',
    messageTemplate: 'Retry limit exceeded ({0} attempts)',
    category: ResultCategory.operation,
    description: 'Maximum retry attempts reached',
    recoveryHint:
        'Review the retry logic and consider increasing the retry limit.',
  );

  // ===== STATUS ERRORS =====
  static const statusCheckFailed = ErrorCode(
    code: 'STATUS_CHECK_FAILED',
    messageTemplate: 'Failed to check printer status: {0}',
    category: ResultCategory.status,
    description: 'Printer status check failure',
    recoveryHint: 'Re-check the printer\'s status or try again later.',
  );

  static const statusTimeout = ErrorCode(
    code: 'STATUS_TIMEOUT',
    messageTemplate: 'Status check timed out after {0} seconds',
    category: ResultCategory.status,
    description: 'Status check exceeded timeout',
    recoveryHint:
        'Increase the status check timeout or ensure printer is responsive.',
  );

  static const invalidStatusResponse = ErrorCode(
    code: 'INVALID_STATUS_RESPONSE',
    messageTemplate: 'Invalid status response from printer',
    category: ResultCategory.status,
    description: 'Printer returned invalid status data',
    recoveryHint:
        'Review the printer\'s status response and ensure it\'s valid.',
  );

  static const detailedStatusCheckFailed = ErrorCode(
    code: 'DETAILED_STATUS_CHECK_FAILED',
    messageTemplate: 'Failed to get detailed printer status: {0}',
    category: ResultCategory.status,
    description: 'Detailed printer status check failure',
    recoveryHint: 'Re-check the printer\'s detailed status or try again later.',
  );

  static const basicStatusCheckFailed = ErrorCode(
    code: 'BASIC_STATUS_CHECK_FAILED',
    messageTemplate: 'Failed to get basic printer status: {0}',
    category: ResultCategory.status,
    description: 'Basic printer status check failure',
    recoveryHint: 'Re-check the printer\'s basic status or try again later.',
  );

  static const statusResponseFormatError = ErrorCode(
    code: 'STATUS_RESPONSE_FORMAT_ERROR',
    messageTemplate: 'Invalid response format for {0} status',
    category: ResultCategory.status,
    description: 'Status response format is invalid or unexpected',
    recoveryHint: 'Check printer firmware version and ensure compatibility.',
  );

  static const statusConnectionError = ErrorCode(
    code: 'STATUS_CONNECTION_ERROR',
    messageTemplate: 'Connection error during status check: {0}',
    category: ResultCategory.status,
    description: 'Connection lost during status check',
    recoveryHint: 'Reconnect to the printer and try the status check again.',
  );

  static const statusTimeoutError = ErrorCode(
    code: 'STATUS_TIMEOUT_ERROR',
    messageTemplate: 'Status check timed out: {0}',
    category: ResultCategory.status,
    description: 'Status check operation timed out',
    recoveryHint: 'Increase timeout or check printer responsiveness.',
  );

  // ===== COMMAND ERRORS =====
  static const commandError = ErrorCode(
    code: 'COMMAND_ERROR',
    messageTemplate: 'Command failed: {0}',
    category: ResultCategory.command,
    description: 'Printer command execution failure',
    recoveryHint: 'Review the command syntax and ensure it\'s correct.',
  );

  static const commandTimeout = ErrorCode(
    code: 'COMMAND_TIMEOUT',
    messageTemplate: 'Command timed out after {0} seconds',
    category: ResultCategory.command,
    description: 'Command execution exceeded timeout',
    recoveryHint: 'Ensure the command completes within the specified time.',
  );

  static const invalidCommand = ErrorCode(
    code: 'INVALID_COMMAND',
    messageTemplate: 'Invalid command: {0}',
    category: ResultCategory.command,
    description: 'Command format or syntax error',
    recoveryHint: 'Check the command syntax and ensure it\'s valid.',
  );

  // ===== PLATFORM ERRORS =====
  static const platformError = ErrorCode(
    code: 'PLATFORM_ERROR',
    messageTemplate: 'Platform error: {0}',
    category: ResultCategory.platform,
    description: 'Platform-specific error',
    recoveryHint:
        'Investigate the platform-specific error and ensure it\'s handled.',
  );

  static const notImplemented = ErrorCode(
    code: 'NOT_IMPLEMENTED',
    messageTemplate: 'Feature not implemented on this platform',
    category: ResultCategory.platform,
    description: 'Feature is not available on current platform',
    recoveryHint: 'This feature is not yet supported on your platform.',
  );

  static const unsupportedPlatform = ErrorCode(
    code: 'UNSUPPORTED_PLATFORM',
    messageTemplate: 'Platform not supported: {0}',
    category: ResultCategory.platform,
    description: 'Current platform is not supported',
    recoveryHint:
        'This plugin only supports the platforms listed in its documentation.',
  );

  // ===== SYSTEM ERRORS =====
  static const unknownError = ErrorCode(
    code: 'UNKNOWN_ERROR',
    messageTemplate: 'Unknown error occurred',
    category: ResultCategory.system,
    description: 'Unclassified or unexpected error',
    recoveryHint: 'Review the logs and ensure all dependencies are up to date.',
  );

  static const internalError = ErrorCode(
    code: 'INTERNAL_ERROR',
    messageTemplate: 'Internal error: {0}',
    category: ResultCategory.system,
    description: 'Internal system error',
    recoveryHint:
        'This is a bug in the plugin. Please report it to the developer.',
  );

  static const resourceError = ErrorCode(
    code: 'RESOURCE_ERROR',
    messageTemplate: 'Resource error: {0}',
    category: ResultCategory.system,
    description: 'System resource allocation failure',
    recoveryHint: 'Check your device\'s memory and storage.',
  );

  static const memoryError = ErrorCode(
    code: 'MEMORY_ERROR',
    messageTemplate: 'Memory allocation failed',
    category: ResultCategory.system,
    description: 'Insufficient memory for operation',
    recoveryHint: 'Free up memory on your device or increase available RAM.',
  );

  // ===== CONFIGURATION ERRORS =====
  static const configurationError = ErrorCode(
    code: 'CONFIGURATION_ERROR',
    messageTemplate: 'Configuration error: {0}',
    category: ResultCategory.configuration,
    description: 'Invalid or missing configuration',
    recoveryHint:
        'Review the plugin\'s configuration and ensure it\'s correct.',
  );

  static const invalidSettings = ErrorCode(
    code: 'INVALID_SETTINGS',
    messageTemplate: 'Invalid printer settings: {0}',
    category: ResultCategory.configuration,
    description: 'Printer settings are invalid',
    recoveryHint: 'Check the printer\'s settings and ensure they are valid.',
  );

  // ===== VALIDATION ERRORS =====
  static const validationError = ErrorCode(
    code: 'VALIDATION_ERROR',
    messageTemplate: 'Validation failed: {0}',
    category: ResultCategory.validation,
    description: 'Input validation failure',
    recoveryHint:
        'Review the input data and ensure it meets the validation requirements.',
  );

  static const requiredFieldMissing = ErrorCode(
    code: 'REQUIRED_FIELD_MISSING',
    messageTemplate: 'Required field missing: {0}',
    category: ResultCategory.validation,
    description: 'Required parameter not provided',
    recoveryHint: 'Ensure all required parameters are provided.',
  );

  // ===== UTILITY METHODS =====

  /// Get error code by code string
  static ErrorCode? fromCode(String code) {
    // This is a simplified approach - manually check each error code
    final allCodes = [
      connectionError,
      connectionTimeout,
      connectionLost,
      notConnected,
      alreadyConnected,
      invalidDeviceAddress,
      connectionRetryFailed,
      discoveryError,
      discoveryTimeout,
      noPermission,
      bluetoothDisabled,
      networkError,
      noPrintersFound,
      multiplePrintersFound,
      printError,
      printTimeout,
      printerNotReady,
      outOfPaper,
      headOpen,
      printerPaused,
      ribbonError,
      printDataError,
      printRetryFailed,
      printDataInvalidFormat,
      printDataTooLarge,
      invalidData,
      invalidFormat,
      encodingError,
      emptyData,
      operationTimeout,
      operationCancelled,
      invalidArgument,
      operationError,
      retryLimitExceeded,
      statusCheckFailed,
      statusTimeout,
      invalidStatusResponse,
      detailedStatusCheckFailed,
      basicStatusCheckFailed,
      statusResponseFormatError,
      statusConnectionError,
      statusTimeoutError,
      commandError,
      commandTimeout,
      invalidCommand,
      platformError,
      notImplemented,
      unsupportedPlatform,
      unknownError,
      internalError,
      resourceError,
      memoryError,
      configurationError,
      invalidSettings,
      validationError,
      requiredFieldMissing,
      // Custom error scenarios
      connectionFailed,
      disconnectFailed,
      printFailed,
      ribbonErrorDetected,
      printCompletionHardwareError,
      statusUnknownError,
      printUnknownError,
      connectionUnknownError,
      disconnectUnknownError,
      statusCheckUnknownError,
      detailedStatusUnknownError,
      waitCompletionUnknownError,
      // Additional error scenarios
      printerBusy,
      printerOffline,
      printerJammed,
      ribbonOut,
      mediaError,
      calibrationRequired,
      bufferFull,
      languageMismatch,
      settingsConflict,
      firmwareUpdateRequired,
      temperatureError,
      sensorError,
      printHeadError,
      powerError,
      communicationError,
      authenticationError,
      encryptionError,
      dataCorruptionError,
      unsupportedFeature,
      maintenanceRequired,
      consumableLow,
      consumableEmpty,
      zebraNoConnection,
      zebraWriteFailure,
      zebraReadFailure,
      zebraUnknownPrinterLanguage,
      zebraInvalidPrinterLanguage,
      zebraMalformedNetworkDiscoveryAddress,
      zebraNetworkErrorDuringDiscovery,
      zebraInvalidDiscoveryHopCount,
      zebraMalformedPrinterStatusResponse,
      zebraInvalidFormatName,
      zebraBadFileDirectoryEntry,
      zebraMalformedFormatFieldNumber,
      zebraInvalidFileName,
      zebraInvalidPrinterDriveLetter,
      printerReadyToPrint,
      writeFailure,
      readFailure,
      discoveryMalformedAddress,
      discoveryNetworkError,
      invalidHopCount,
      malformedFieldNumber,
      invalidDriveLetter,
      badDirectoryEntry,
      connectionSpecificTimeout,
      printSpecificTimeout,
      statusSpecificTimeout,
      commandSpecificTimeout,
    ];
    
    try {
      return allCodes.firstWhere((errorCode) => errorCode.code == code);
    } catch (e) {
      return null;
    }
  }

  // ===== CUSTOM ERROR SCENARIOS FOR FORMAT ARGS =====
  static const connectionFailed = ErrorCode(
    code: 'CONNECTION_FAILED',
    messageTemplate: 'Connection failed: {0}',
    category: ResultCategory.connection,
    description: 'Connection failed with error',
    recoveryHint: 'Check network connection and ensure printer is powered on.',
  );
  static const disconnectFailed = ErrorCode(
    code: 'DISCONNECT_FAILED',
    messageTemplate: 'Disconnect failed: {0}',
    category: ResultCategory.connection,
    description: 'Disconnect failed with error',
    recoveryHint: 'Re-establish connection by attempting to connect again.',
  );
  static const printFailed = ErrorCode(
    code: 'PRINT_FAILED',
    messageTemplate: 'Print failed: {0}',
    category: ResultCategory.print,
    description: 'Print failed with error',
    recoveryHint: 'Review print settings and ensure printer is ready.',
  );
  static const ribbonErrorDetected = ErrorCode(
    code: 'RIBBON_ERROR_DETECTED',
    messageTemplate: 'Ribbon error detected: {0}',
    category: ResultCategory.print,
    description: 'Ribbon error detected',
    recoveryHint:
        'Replace the ribbon or check the printer\'s ribbon alignment.',
  );
  static const printCompletionHardwareError = ErrorCode(
    code: 'PRINT_COMPLETION_HARDWARE_ERROR',
    messageTemplate: 'Print completion failed due to hardware issues',
    category: ResultCategory.print,
    description: 'Print completion failed due to hardware issues',
    recoveryHint:
        'Ensure the printer\'s hardware components are functioning correctly.',
  );
  static const statusUnknownError = ErrorCode(
    code: 'STATUS_UNKNOWN_ERROR',
    messageTemplate: 'Unknown status error: {0}',
    category: ResultCategory.status,
    description: 'Unknown error occurred during status check',
    recoveryHint: 'Re-check the printer\'s status or try again later.',
  );
  static const printUnknownError = ErrorCode(
    code: 'PRINT_UNKNOWN_ERROR',
    messageTemplate: 'Unknown print error: {0}',
    category: ResultCategory.print,
    description: 'Unknown error occurred during print',
    recoveryHint: 'Review the print operation and ensure it\'s valid.',
  );
  static const connectionUnknownError = ErrorCode(
    code: 'CONNECTION_UNKNOWN_ERROR',
    messageTemplate: 'Unknown connection error: {0}',
    category: ResultCategory.connection,
    description: 'Unknown error occurred during connection',
    recoveryHint: 'Re-establish connection by attempting to connect again.',
  );
  static const disconnectUnknownError = ErrorCode(
    code: 'DISCONNECT_UNKNOWN_ERROR',
    messageTemplate: 'Unknown disconnect error: {0}',
    category: ResultCategory.connection,
    description: 'Unknown error occurred during disconnect',
    recoveryHint: 'Re-establish connection by attempting to connect again.',
  );
  static const statusCheckUnknownError = ErrorCode(
    code: 'STATUS_CHECK_UNKNOWN_ERROR',
    messageTemplate: 'Unknown status check error: {0}',
    category: ResultCategory.status,
    description: 'Unknown error occurred during status check',
    recoveryHint: 'Re-check the printer\'s status or try again later.',
  );
  static const detailedStatusUnknownError = ErrorCode(
    code: 'DETAILED_STATUS_UNKNOWN_ERROR',
    messageTemplate: 'Unknown detailed status error: {0}',
    category: ResultCategory.status,
    description: 'Unknown error occurred during detailed status check',
    recoveryHint: 'Re-check the printer\'s status or try again later.',
  );
  static const waitCompletionUnknownError = ErrorCode(
    code: 'WAIT_COMPLETION_UNKNOWN_ERROR',
    messageTemplate: 'Unknown error while waiting for print completion: {0}',
    category: ResultCategory.print,
    description: 'Unknown error while waiting for print completion',
    recoveryHint: 'Ensure the printer is ready for the next print job.',
  );

  // ===== ADDITIONAL ERROR SCENARIOS WITH RECOVERY HINTS =====
  static const printerBusy = ErrorCode(
    code: 'PRINTER_BUSY',
    messageTemplate: 'Printer is busy processing another job',
    category: ResultCategory.print,
    description: 'Printer cannot accept new print jobs',
    recoveryHint: 'Wait for the current print job to complete, then try again.',
  );

  static const printerOffline = ErrorCode(
    code: 'PRINTER_OFFLINE',
    messageTemplate: 'Printer is offline',
    category: ResultCategory.print,
    description: 'Printer is not available for printing',
    recoveryHint:
        'Check if the printer is powered on and connected to the network.',
  );

  static const printerJammed = ErrorCode(
    code: 'PRINTER_JAMMED',
    messageTemplate: 'Printer has a paper jam',
    category: ResultCategory.print,
    description: 'Paper is stuck in the printer mechanism',
    recoveryHint: 'Clear the paper jam and ensure the paper path is clear.',
  );

  static const ribbonOut = ErrorCode(
    code: 'RIBBON_OUT',
    messageTemplate: 'Printer ribbon is out or needs replacement',
    category: ResultCategory.print,
    description: 'No ribbon available for printing',
    recoveryHint: 'Replace the printer ribbon with a new one.',
  );

  static const mediaError = ErrorCode(
    code: 'MEDIA_ERROR',
    messageTemplate: 'Media error: {0}',
    category: ResultCategory.print,
    description: 'Issue with print media (labels, paper, etc.)',
    recoveryHint: 'Check the media type and ensure it\'s properly loaded.',
  );

  static const calibrationRequired = ErrorCode(
    code: 'CALIBRATION_REQUIRED',
    messageTemplate: 'Printer requires calibration',
    category: ResultCategory.print,
    description: 'Printer needs to be calibrated for current media',
    recoveryHint: 'Run the printer calibration process for the current media.',
  );

  static const bufferFull = ErrorCode(
    code: 'BUFFER_FULL',
    messageTemplate: 'Printer buffer is full',
    category: ResultCategory.print,
    description: 'Printer cannot accept more data',
    recoveryHint:
        'Wait for the printer to process current data or clear the buffer.',
  );

  static const languageMismatch = ErrorCode(
    code: 'LANGUAGE_MISMATCH',
    messageTemplate: 'Print language mismatch: expected {0}, got {1}',
    category: ResultCategory.print,
    description: 'Printer language does not match print data format',
    recoveryHint:
        'Set the printer language to match your print data format (ZPL/CPCL).',
  );

  static const settingsConflict = ErrorCode(
    code: 'SETTINGS_CONFLICT',
    messageTemplate: 'Printer settings conflict: {0}',
    category: ResultCategory.configuration,
    description: 'Conflicting printer settings detected',
    recoveryHint: 'Review and adjust conflicting printer settings.',
  );

  static const firmwareUpdateRequired = ErrorCode(
    code: 'FIRMWARE_UPDATE_REQUIRED',
    messageTemplate: 'Printer firmware update required',
    category: ResultCategory.system,
    description: 'Printer firmware is outdated',
    recoveryHint: 'Update the printer firmware to the latest version.',
  );

  static const temperatureError = ErrorCode(
    code: 'TEMPERATURE_ERROR',
    messageTemplate: 'Printer temperature error: {0}',
    category: ResultCategory.print,
    description: 'Printer temperature is outside operating range',
    recoveryHint:
        'Allow the printer to cool down or warm up to operating temperature.',
  );

  static const sensorError = ErrorCode(
    code: 'SENSOR_ERROR',
    messageTemplate: 'Printer sensor error: {0}',
    category: ResultCategory.print,
    description: 'Printer sensor malfunction',
    recoveryHint: 'Check and clean the printer sensors, or contact support.',
  );

  static const printHeadError = ErrorCode(
    code: 'PRINT_HEAD_ERROR',
    messageTemplate: 'Print head error: {0}',
    category: ResultCategory.print,
    description: 'Print head malfunction or damage',
    recoveryHint: 'Clean the print head or replace it if damaged.',
  );

  static const powerError = ErrorCode(
    code: 'POWER_ERROR',
    messageTemplate: 'Power error: {0}',
    category: ResultCategory.system,
    description: 'Power-related printer error',
    recoveryHint: 'Check power supply and ensure stable power connection.',
  );

  static const communicationError = ErrorCode(
    code: 'COMMUNICATION_ERROR',
    messageTemplate: 'Communication error: {0}',
    category: ResultCategory.connection,
    description: 'Communication protocol error',
    recoveryHint:
        'Check connection settings and ensure proper communication protocol.',
  );

  static const authenticationError = ErrorCode(
    code: 'AUTHENTICATION_ERROR',
    messageTemplate: 'Authentication failed: {0}',
    category: ResultCategory.connection,
    description: 'Printer authentication failed',
    recoveryHint:
        'Check authentication credentials and network security settings.',
  );

  static const encryptionError = ErrorCode(
    code: 'ENCRYPTION_ERROR',
    messageTemplate: 'Encryption error: {0}',
    category: ResultCategory.connection,
    description: 'Data encryption/decryption failure',
    recoveryHint:
        'Check encryption settings and ensure compatible security protocols.',
  );

  static const dataCorruptionError = ErrorCode(
    code: 'DATA_CORRUPTION_ERROR',
    messageTemplate: 'Data corruption detected: {0}',
    category: ResultCategory.data,
    description: 'Print data is corrupted or incomplete',
    recoveryHint: 'Regenerate the print data and ensure data integrity.',
  );

  static const unsupportedFeature = ErrorCode(
    code: 'UNSUPPORTED_FEATURE',
    messageTemplate: 'Unsupported feature: {0}',
    category: ResultCategory.platform,
    description: 'Feature not supported by this printer model',
    recoveryHint: 'Use a printer model that supports this feature.',
  );

  static const maintenanceRequired = ErrorCode(
    code: 'MAINTENANCE_REQUIRED',
    messageTemplate: 'Printer maintenance required: {0}',
    category: ResultCategory.system,
    description: 'Printer requires maintenance',
    recoveryHint:
        'Perform the required maintenance or contact service technician.',
  );

  static const consumableLow = ErrorCode(
    code: 'CONSUMABLE_LOW',
    messageTemplate: 'Consumable running low: {0}',
    category: ResultCategory.print,
    description: 'Printer consumable (ribbon, media) is running low',
    recoveryHint: 'Replace the consumable soon to avoid print quality issues.',
  );

  static const consumableEmpty = ErrorCode(
    code: 'CONSUMABLE_EMPTY',
    messageTemplate: 'Consumable empty: {0}',
    category: ResultCategory.print,
    description: 'Printer consumable is completely empty',
    recoveryHint: 'Replace the empty consumable to continue printing.',
  );

  // ===== ZEBRA SDK SPECIFIC ERRORS =====
  // Based on official Zebra Link-OS SDK v1.6.1158 error codes

  static const zebraNoConnection = ErrorCode(
    code: 'ZEBRA_ERROR_NO_CONNECTION',
    messageTemplate: 'Unable to create a connection to a printer',
    category: ResultCategory.connection,
    description: 'Zebra SDK: No connection to printer could be established',
    recoveryHint:
        'Check printer power, network connectivity, and device address.',
  );

  static const zebraWriteFailure = ErrorCode(
    code: 'ZEBRA_ERROR_WRITE_FAILURE',
    messageTemplate: 'Write to a connection failed',
    category: ResultCategory.connection,
    description: 'Zebra SDK: Failed to write data to printer connection',
    recoveryHint: 'Check connection stability and retry the operation.',
  );

  static const zebraReadFailure = ErrorCode(
    code: 'ZEBRA_ERROR_READ_FAILURE',
    messageTemplate: 'Read from a connection failed',
    category: ResultCategory.connection,
    description: 'Zebra SDK: Failed to read data from printer connection',
    recoveryHint: 'Check connection stability and retry the operation.',
  );

  static const zebraUnknownPrinterLanguage = ErrorCode(
    code: 'ZEBRA_UNKNOWN_PRINTER_LANGUAGE',
    messageTemplate: 'Unable to determine the control language of a printer',
    category: ResultCategory.configuration,
    description: 'Zebra SDK: Printer control language could not be detected',
    recoveryHint:
        'Ensure printer firmware is up to date and supports ZPL/CPCL.',
  );

  static const zebraInvalidPrinterLanguage = ErrorCode(
    code: 'ZEBRA_INVALID_PRINTER_LANGUAGE',
    messageTemplate: 'Invalid printer language specified',
    category: ResultCategory.configuration,
    description: 'Zebra SDK: Specified printer language is not supported',
    recoveryHint: 'Use a supported printer language (ZPL or CPCL).',
  );

  static const zebraMalformedNetworkDiscoveryAddress = ErrorCode(
    code: 'ZEBRA_MALFORMED_NETWORK_DISCOVERY_ADDRESS',
    messageTemplate: 'Malformed discovery address',
    category: ResultCategory.discovery,
    description: 'Zebra SDK: Network discovery address format is invalid',
    recoveryHint: 'Verify the network address format and ensure it is valid.',
  );

  static const zebraNetworkErrorDuringDiscovery = ErrorCode(
    code: 'ZEBRA_NETWORK_ERROR_DURING_DISCOVERY',
    messageTemplate: 'Network error during discovery',
    category: ResultCategory.discovery,
    description: 'Zebra SDK: Network error occurred during printer discovery',
    recoveryHint: 'Check network connectivity and firewall settings.',
  );

  static const zebraInvalidDiscoveryHopCount = ErrorCode(
    code: 'ZEBRA_INVALID_DISCOVERY_HOP_COUNT',
    messageTemplate: 'Invalid multicast hop count',
    category: ResultCategory.discovery,
    description: 'Zebra SDK: Multicast hop count parameter is invalid',
    recoveryHint: 'Use a valid hop count value for multicast discovery.',
  );

  static const zebraMalformedPrinterStatusResponse = ErrorCode(
    code: 'ZEBRA_MALFORMED_PRINTER_STATUS_RESPONSE',
    messageTemplate:
        'Malformed status response - unable to determine printer status',
    category: ResultCategory.status,
    description: 'Zebra SDK: Printer status response format is invalid',
    recoveryHint: 'Check printer firmware version and ensure compatibility.',
  );

  static const zebraInvalidFormatName = ErrorCode(
    code: 'ZEBRA_INVALID_FORMAT_NAME',
    messageTemplate: 'Invalid format name',
    category: ResultCategory.data,
    description: 'Zebra SDK: Print format name is invalid',
    recoveryHint: 'Use a valid format name for the print data.',
  );

  static const zebraBadFileDirectoryEntry = ErrorCode(
    code: 'ZEBRA_BAD_FILE_DIRECTORY_ENTRY',
    messageTemplate: 'Bad file directory entry',
    category: ResultCategory.data,
    description: 'Zebra SDK: File directory entry is corrupted or invalid',
    recoveryHint: 'Check file system integrity on the printer.',
  );

  static const zebraMalformedFormatFieldNumber = ErrorCode(
    code: 'ZEBRA_MALFORMED_FORMAT_FIELD_NUMBER',
    messageTemplate: '^FN integer must be between 1 and 9999',
    category: ResultCategory.data,
    description: 'Zebra SDK: Format field number is outside valid range',
    recoveryHint: 'Use a field number between 1 and 9999 in ZPL format.',
  );

  static const zebraInvalidFileName = ErrorCode(
    code: 'ZEBRA_INVALID_FILE_NAME',
    messageTemplate: 'Invalid file name',
    category: ResultCategory.data,
    description: 'Zebra SDK: File name format is invalid',
    recoveryHint: 'Use a valid file name format supported by the printer.',
  );

  static const zebraInvalidPrinterDriveLetter = ErrorCode(
    code: 'ZEBRA_INVALID_PRINTER_DRIVE_LETTER',
    messageTemplate: 'Invalid drive specified',
    category: ResultCategory.data,
    description: 'Zebra SDK: Printer drive letter is invalid',
    recoveryHint:
        'Use a valid drive letter (e.g., R:, E:, B:) for the printer.',
  );

  // ===== ENHANCED ERROR CLASSIFICATIONS =====
  // More specific error codes for better hardware mapping

  static const printerReadyToPrint = ErrorCode(
    code: 'PRINTER_READY_TO_PRINT',
    messageTemplate: 'Printer is ready to print',
    category: ResultCategory.status,
    description: 'Printer status indicates ready state',
    recoveryHint: 'Printer is ready for print operations.',
  );

  static const writeFailure = ErrorCode(
    code: 'WRITE_FAILURE',
    messageTemplate: 'Failed to write data to printer',
    category: ResultCategory.connection,
    description: 'Data transmission to printer failed',
    recoveryHint: 'Check connection stability and retry the write operation.',
  );

  static const readFailure = ErrorCode(
    code: 'READ_FAILURE',
    messageTemplate: 'Failed to read data from printer',
    category: ResultCategory.connection,
    description: 'Data reception from printer failed',
    recoveryHint: 'Check connection stability and retry the read operation.',
  );

  static const discoveryMalformedAddress = ErrorCode(
    code: 'DISCOVERY_MALFORMED_ADDRESS',
    messageTemplate: 'Malformed discovery address: {0}',
    category: ResultCategory.discovery,
    description: 'Discovery address format is invalid',
    recoveryHint:
        'Verify the address format and ensure it matches the expected pattern.',
  );

  static const discoveryNetworkError = ErrorCode(
    code: 'DISCOVERY_NETWORK_ERROR',
    messageTemplate: 'Network error during printer discovery: {0}',
    category: ResultCategory.discovery,
    description: 'Network-related error during discovery process',
    recoveryHint: 'Check network connectivity and try discovery again.',
  );

  static const invalidHopCount = ErrorCode(
    code: 'INVALID_HOP_COUNT',
    messageTemplate: 'Invalid multicast hop count: {0}',
    category: ResultCategory.discovery,
    description: 'Multicast hop count parameter is out of valid range',
    recoveryHint:
        'Use a hop count value appropriate for your network topology.',
  );

  static const malformedFieldNumber = ErrorCode(
    code: 'MALFORMED_FIELD_NUMBER',
    messageTemplate: 'Format field number must be between 1 and 9999',
    category: ResultCategory.data,
    description: 'ZPL format field number is outside valid range',
    recoveryHint:
        'Ensure field numbers in ZPL commands are between 1 and 9999.',
  );

  static const invalidDriveLetter = ErrorCode(
    code: 'INVALID_DRIVE_LETTER',
    messageTemplate: 'Invalid printer drive letter: {0}',
    category: ResultCategory.data,
    description: 'Specified printer drive letter is not valid',
    recoveryHint: 'Use a valid drive letter supported by the printer model.',
  );

  static const badDirectoryEntry = ErrorCode(
    code: 'BAD_DIRECTORY_ENTRY',
    messageTemplate: 'Bad file directory entry on printer',
    category: ResultCategory.data,
    description: 'Printer file system directory entry is corrupted',
    recoveryHint:
        'Check printer file system integrity or reformat if necessary.',
  );

  // ===== TIMEOUT CLASSIFICATION ERRORS =====
  // More specific timeout errors for better classification

  static const connectionSpecificTimeout = ErrorCode(
    code: 'CONNECTION_SPECIFIC_TIMEOUT',
    messageTemplate: 'Connection operation timed out after {0} seconds',
    category: ResultCategory.connection,
    description: 'Connection-specific operation exceeded timeout',
    recoveryHint: 'Increase connection timeout or check network latency.',
  );

  static const printSpecificTimeout = ErrorCode(
    code: 'PRINT_SPECIFIC_TIMEOUT',
    messageTemplate: 'Print operation timed out after {0} seconds',
    category: ResultCategory.print,
    description: 'Print-specific operation exceeded timeout',
    recoveryHint: 'Increase print timeout or check printer processing speed.',
  );

  static const statusSpecificTimeout = ErrorCode(
    code: 'STATUS_SPECIFIC_TIMEOUT',
    messageTemplate: 'Status check timed out after {0} seconds',
    category: ResultCategory.status,
    description: 'Status-specific operation exceeded timeout',
    recoveryHint:
        'Increase status check timeout or verify printer responsiveness.',
  );

  static const commandSpecificTimeout = ErrorCode(
    code: 'COMMAND_SPECIFIC_TIMEOUT',
    messageTemplate: 'Command execution timed out after {0} seconds',
    category: ResultCategory.command,
    description: 'Command-specific operation exceeded timeout',
    recoveryHint: 'Increase command timeout or check command complexity.',
  );
}
