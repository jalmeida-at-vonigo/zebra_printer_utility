/// Result class for consistent error handling across the plugin
class Result<T> {
  final bool success;
  final T? data;
  final ErrorInfo? error;
  final SuccessInfo? successInfo;

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

  /// Get data or throw exception
  /// 
  /// @Deprecated - Avoid using this method as it throws exceptions.
  /// Use [getOrElse] or check [success] before accessing [data] instead.
  @Deprecated(
      'Use getOrElse or check success before accessing data to avoid exceptions')
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

/// Structured success code with formatable message template
class SuccessCode {
  final String code;
  final String messageTemplate;
  final String category;
  final String description;

  const SuccessCode({
    required this.code,
    required this.messageTemplate,
    required this.category,
    required this.description,
  });

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
  /// Human-readable success message
  final String message;

  /// Success code (e.g., 'CONNECTION_SUCCESS', 'PRINT_SUCCESS')
  final String? code;

  /// Timestamp when success occurred
  final DateTime timestamp;

  /// Original success code if created from SuccessCode
  final SuccessCode? originalSuccessCode;

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
  final String code;
  final String messageTemplate;
  final String category;
  final String description;

  const ErrorCode({
    required this.code,
    required this.messageTemplate,
    required this.category,
    required this.description,
  });

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

  ErrorInfo({
    required this.message,
    this.code,
    this.errorNumber,
    this.nativeError,
    this.dartStackTrace,
    this.nativeStackTrace,
    DateTime? timestamp,
    this.originalErrorCode,
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
    );
  }

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

/// Comprehensive success codes used throughout the plugin
/// All success messages must be defined here - never define success codes/messages elsewhere
class SuccessCodes {
  // ===== CONNECTION SUCCESS =====
  static const connectionSuccess = SuccessCode(
    code: 'CONNECTION_SUCCESS',
    messageTemplate: 'Successfully connected to printer',
    category: 'Connection',
    description: 'Printer connection established successfully',
  );

  static const connectionRetrySuccess = SuccessCode(
    code: 'CONNECTION_RETRY_SUCCESS',
    messageTemplate: 'Successfully connected to printer after {0} attempts',
    category: 'Connection',
    description: 'Printer connection established after retry attempts',
  );

  static const disconnectSuccess = SuccessCode(
    code: 'DISCONNECT_SUCCESS',
    messageTemplate: 'Successfully disconnected from printer',
    category: 'Connection',
    description: 'Printer connection terminated successfully',
  );

  // ===== DISCOVERY SUCCESS =====
  static const discoverySuccess = SuccessCode(
    code: 'DISCOVERY_SUCCESS',
    messageTemplate: 'Successfully discovered {0} printers',
    category: 'Discovery',
    description: 'Printer discovery completed successfully',
  );

  static const discoveryTimeoutSuccess = SuccessCode(
    code: 'DISCOVERY_TIMEOUT_SUCCESS',
    messageTemplate: 'Discovery completed within {0} seconds',
    category: 'Discovery',
    description: 'Discovery completed within specified timeout',
  );

  // ===== PRINT SUCCESS =====
  static const printSuccess = SuccessCode(
    code: 'PRINT_SUCCESS',
    messageTemplate: 'Print operation completed successfully',
    category: 'Print',
    description: 'Print job completed successfully',
  );

  static const printRetrySuccess = SuccessCode(
    code: 'PRINT_RETRY_SUCCESS',
    messageTemplate:
        'Print operation completed successfully after {0} attempts',
    category: 'Print',
    description: 'Print job completed after retry attempts',
  );

  static const printDataSent = SuccessCode(
    code: 'PRINT_DATA_SENT',
    messageTemplate: 'Successfully sent {0} bytes of print data',
    category: 'Print',
    description: 'Print data transmitted successfully',
  );

  // ===== STATUS SUCCESS =====
  static const statusCheckSuccess = SuccessCode(
    code: 'STATUS_CHECK_SUCCESS',
    messageTemplate: 'Successfully retrieved printer status',
    category: 'Status',
    description: 'Printer status check completed successfully',
  );

  static const statusTimeoutSuccess = SuccessCode(
    code: 'STATUS_TIMEOUT_SUCCESS',
    messageTemplate: 'Status check completed within {0} seconds',
    category: 'Status',
    description: 'Status check completed within specified timeout',
  );

  // ===== COMMAND SUCCESS =====
  static const commandSuccess = SuccessCode(
    code: 'COMMAND_SUCCESS',
    messageTemplate: 'Command executed successfully: {0}',
    category: 'Command',
    description: 'Printer command executed successfully',
  );

  static const commandTimeoutSuccess = SuccessCode(
    code: 'COMMAND_TIMEOUT_SUCCESS',
    messageTemplate: 'Command completed within {0} seconds',
    category: 'Command',
    description: 'Command completed within specified timeout',
  );

  // ===== OPERATION SUCCESS =====
  static const operationSuccess = SuccessCode(
    code: 'OPERATION_SUCCESS',
    messageTemplate: 'Operation completed successfully',
    category: 'Operation',
    description: 'General operation completed successfully',
  );

  static const operationTimeoutSuccess = SuccessCode(
    code: 'OPERATION_TIMEOUT_SUCCESS',
    messageTemplate: 'Operation completed within {0} seconds',
    category: 'Operation',
    description: 'Operation completed within specified timeout',
  );

  static const retrySuccess = SuccessCode(
    code: 'RETRY_SUCCESS',
    messageTemplate: 'Operation succeeded after {0} attempts',
    category: 'Operation',
    description: 'Operation completed successfully after retry attempts',
  );

  // ===== VALIDATION SUCCESS =====
  static const validationSuccess = SuccessCode(
    code: 'VALIDATION_SUCCESS',
    messageTemplate: 'Validation passed: {0}',
    category: 'Validation',
    description: 'Input validation completed successfully',
  );

  static const dataValidationSuccess = SuccessCode(
    code: 'DATA_VALIDATION_SUCCESS',
    messageTemplate: 'Data validation passed for {0}',
    category: 'Validation',
    description: 'Data validation completed successfully',
  );

  // ===== CONFIGURATION SUCCESS =====
  static const configurationSuccess = SuccessCode(
    code: 'CONFIGURATION_SUCCESS',
    messageTemplate: 'Configuration applied successfully: {0}',
    category: 'Configuration',
    description: 'Configuration change applied successfully',
  );

  static const settingsApplied = SuccessCode(
    code: 'SETTINGS_APPLIED',
    messageTemplate: 'Printer settings applied successfully',
    category: 'Configuration',
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
    category: 'Connection',
    description: 'General connection failure',
  );

  static const connectionTimeout = ErrorCode(
    code: 'CONNECTION_TIMEOUT',
    messageTemplate: 'Connection timed out after {0} seconds',
    category: 'Connection',
    description: 'Connection attempt exceeded timeout',
  );

  static const connectionLost = ErrorCode(
    code: 'CONNECTION_LOST',
    messageTemplate: 'Connection to printer was lost',
    category: 'Connection',
    description: 'Active connection was unexpectedly terminated',
  );

  static const notConnected = ErrorCode(
    code: 'NOT_CONNECTED',
    messageTemplate: 'No printer is currently connected',
    category: 'Connection',
    description: 'Operation requires an active connection',
  );

  static const alreadyConnected = ErrorCode(
    code: 'ALREADY_CONNECTED',
    messageTemplate: 'Already connected to printer at {0}',
    category: 'Connection',
    description: 'Attempt to connect when already connected',
  );

  static const invalidDeviceAddress = ErrorCode(
    code: 'INVALID_DEVICE_ADDRESS',
    messageTemplate: 'Invalid device address: {0}',
    category: 'Connection',
    description: 'Device address format is invalid',
  );

  static const connectionRetryFailed = ErrorCode(
    code: 'CONNECTION_RETRY_FAILED',
    messageTemplate: 'Failed to connect after {0} attempts',
    category: 'Connection',
    description: 'Connection failed after maximum retry attempts',
  );

  // ===== DISCOVERY ERRORS =====
  static const discoveryError = ErrorCode(
    code: 'DISCOVERY_ERROR',
    messageTemplate: 'Failed to discover printers',
    category: 'Discovery',
    description: 'General discovery failure',
  );

  static const discoveryTimeout = ErrorCode(
    code: 'DISCOVERY_TIMEOUT',
    messageTemplate: 'Discovery timed out after {0} seconds',
    category: 'Discovery',
    description: 'Discovery operation exceeded timeout',
  );

  static const noPermission = ErrorCode(
    code: 'NO_PERMISSION',
    messageTemplate: 'Permission denied: {0}',
    category: 'Discovery',
    description: 'Required permissions not granted',
  );

  static const bluetoothDisabled = ErrorCode(
    code: 'BLUETOOTH_DISABLED',
    messageTemplate: 'Bluetooth is disabled',
    category: 'Discovery',
    description: 'Bluetooth must be enabled for discovery',
  );

  static const networkError = ErrorCode(
    code: 'NETWORK_ERROR',
    messageTemplate: 'Network error: {0}',
    category: 'Discovery',
    description: 'Network-related discovery failure',
  );

  static const noPrintersFound = ErrorCode(
    code: 'NO_PRINTERS_FOUND',
    messageTemplate: 'No printers found during discovery',
    category: 'Discovery',
    description: 'Discovery completed but no printers were found',
  );

  static const multiplePrintersFound = ErrorCode(
    code: 'MULTIPLE_PRINTERS_FOUND',
    messageTemplate: 'Multiple printers found ({0}), specify device explicitly',
    category: 'Discovery',
    description: 'Ambiguous printer selection',
  );

  // ===== PRINT ERRORS =====
  static const printError = ErrorCode(
    code: 'PRINT_ERROR',
    messageTemplate: 'Print operation failed',
    category: 'Print',
    description: 'General print failure',
  );

  static const printTimeout = ErrorCode(
    code: 'PRINT_TIMEOUT',
    messageTemplate: 'Print operation timed out after {0} seconds',
    category: 'Print',
    description: 'Print operation exceeded timeout',
  );

  static const printerNotReady = ErrorCode(
    code: 'PRINTER_NOT_READY',
    messageTemplate: 'Printer is not ready: {0}',
    category: 'Print',
    description: 'Printer cannot accept print jobs',
  );

  static const outOfPaper = ErrorCode(
    code: 'OUT_OF_PAPER',
    messageTemplate: 'Printer is out of paper',
    category: 'Print',
    description: 'No paper available for printing',
  );

  static const headOpen = ErrorCode(
    code: 'HEAD_OPEN',
    messageTemplate: 'Printer head is open',
    category: 'Print',
    description: 'Printer head must be closed for printing',
  );

  static const printerPaused = ErrorCode(
    code: 'PRINTER_PAUSED',
    messageTemplate: 'Printer is paused',
    category: 'Print',
    description: 'Printer must be unpaused for printing',
  );

  static const ribbonError = ErrorCode(
    code: 'RIBBON_ERROR',
    messageTemplate: 'Ribbon error: {0}',
    category: 'Print',
    description: 'Ribbon-related print failure',
  );

  static const printDataError = ErrorCode(
    code: 'PRINT_DATA_ERROR',
    messageTemplate: 'Invalid print data: {0}',
    category: 'Print',
    description: 'Print data format or content error',
  );

  static const printRetryFailed = ErrorCode(
    code: 'PRINT_RETRY_FAILED',
    messageTemplate: 'Failed to print after {0} attempts',
    category: 'Print',
    description: 'Print failed after maximum retry attempts',
  );

  static const printDataInvalidFormat = ErrorCode(
    code: 'PRINT_DATA_INVALID_FORMAT',
    messageTemplate: 'Invalid print data format',
    category: 'Print',
    description: 'Print data format is invalid',
  );

  static const printDataTooLarge = ErrorCode(
    code: 'PRINT_DATA_TOO_LARGE',
    messageTemplate: 'Print data too large: {0} bytes',
    category: 'Print',
    description: 'Print data exceeds maximum allowed size',
  );

  // ===== DATA ERRORS =====
  static const invalidData = ErrorCode(
    code: 'INVALID_DATA',
    messageTemplate: 'Invalid data provided',
    category: 'Data',
    description: 'General data validation failure',
  );

  static const invalidFormat = ErrorCode(
    code: 'INVALID_FORMAT',
    messageTemplate: 'Invalid format: {0}',
    category: 'Data',
    description: 'Data format is not supported',
  );

  static const encodingError = ErrorCode(
    code: 'ENCODING_ERROR',
    messageTemplate: 'Encoding error: {0}',
    category: 'Data',
    description: 'Character encoding failure',
  );

  static const emptyData = ErrorCode(
    code: 'EMPTY_DATA',
    messageTemplate: 'No data provided for printing',
    category: 'Data',
    description: 'Print data is empty or null',
  );

  // ===== OPERATION ERRORS =====
  static const operationTimeout = ErrorCode(
    code: 'OPERATION_TIMEOUT',
    messageTemplate: 'Operation timed out after {0} seconds',
    category: 'Operation',
    description: 'Operation exceeded timeout',
  );

  static const operationCancelled = ErrorCode(
    code: 'OPERATION_CANCELLED',
    messageTemplate: 'Operation was cancelled',
    category: 'Operation',
    description: 'Operation was cancelled by user or system',
  );

  static const invalidArgument = ErrorCode(
    code: 'INVALID_ARGUMENT',
    messageTemplate: 'Invalid argument: {0}',
    category: 'Operation',
    description: 'Invalid parameter provided',
  );

  static const operationError = ErrorCode(
    code: 'OPERATION_ERROR',
    messageTemplate: 'Operation failed: {0}',
    category: 'Operation',
    description: 'General operation failure',
  );

  static const retryLimitExceeded = ErrorCode(
    code: 'RETRY_LIMIT_EXCEEDED',
    messageTemplate: 'Retry limit exceeded ({0} attempts)',
    category: 'Operation',
    description: 'Maximum retry attempts reached',
  );

  // ===== STATUS ERRORS =====
  static const statusCheckFailed = ErrorCode(
    code: 'STATUS_CHECK_FAILED',
    messageTemplate: 'Failed to check printer status: {0}',
    category: 'Status',
    description: 'Printer status check failure',
  );

  static const statusTimeout = ErrorCode(
    code: 'STATUS_TIMEOUT',
    messageTemplate: 'Status check timed out after {0} seconds',
    category: 'Status',
    description: 'Status check exceeded timeout',
  );

  static const invalidStatusResponse = ErrorCode(
    code: 'INVALID_STATUS_RESPONSE',
    messageTemplate: 'Invalid status response from printer',
    category: 'Status',
    description: 'Printer returned invalid status data',
  );

  // ===== COMMAND ERRORS =====
  static const commandError = ErrorCode(
    code: 'COMMAND_ERROR',
    messageTemplate: 'Command failed: {0}',
    category: 'Command',
    description: 'Printer command execution failure',
  );

  static const commandTimeout = ErrorCode(
    code: 'COMMAND_TIMEOUT',
    messageTemplate: 'Command timed out after {0} seconds',
    category: 'Command',
    description: 'Command execution exceeded timeout',
  );

  static const invalidCommand = ErrorCode(
    code: 'INVALID_COMMAND',
    messageTemplate: 'Invalid command: {0}',
    category: 'Command',
    description: 'Command format or syntax error',
  );

  // ===== PLATFORM ERRORS =====
  static const platformError = ErrorCode(
    code: 'PLATFORM_ERROR',
    messageTemplate: 'Platform error: {0}',
    category: 'Platform',
    description: 'Platform-specific error',
  );

  static const notImplemented = ErrorCode(
    code: 'NOT_IMPLEMENTED',
    messageTemplate: 'Feature not implemented on this platform',
    category: 'Platform',
    description: 'Feature is not available on current platform',
  );

  static const unsupportedPlatform = ErrorCode(
    code: 'UNSUPPORTED_PLATFORM',
    messageTemplate: 'Platform not supported: {0}',
    category: 'Platform',
    description: 'Current platform is not supported',
  );

  // ===== SYSTEM ERRORS =====
  static const unknownError = ErrorCode(
    code: 'UNKNOWN_ERROR',
    messageTemplate: 'Unknown error occurred',
    category: 'System',
    description: 'Unclassified or unexpected error',
  );

  static const internalError = ErrorCode(
    code: 'INTERNAL_ERROR',
    messageTemplate: 'Internal error: {0}',
    category: 'System',
    description: 'Internal system error',
  );

  static const resourceError = ErrorCode(
    code: 'RESOURCE_ERROR',
    messageTemplate: 'Resource error: {0}',
    category: 'System',
    description: 'System resource allocation failure',
  );

  static const memoryError = ErrorCode(
    code: 'MEMORY_ERROR',
    messageTemplate: 'Memory allocation failed',
    category: 'System',
    description: 'Insufficient memory for operation',
  );

  // ===== CONFIGURATION ERRORS =====
  static const configurationError = ErrorCode(
    code: 'CONFIGURATION_ERROR',
    messageTemplate: 'Configuration error: {0}',
    category: 'Configuration',
    description: 'Invalid or missing configuration',
  );

  static const invalidSettings = ErrorCode(
    code: 'INVALID_SETTINGS',
    messageTemplate: 'Invalid printer settings: {0}',
    category: 'Configuration',
    description: 'Printer settings are invalid',
  );

  // ===== VALIDATION ERRORS =====
  static const validationError = ErrorCode(
    code: 'VALIDATION_ERROR',
    messageTemplate: 'Validation failed: {0}',
    category: 'Validation',
    description: 'Input validation failure',
  );

  static const requiredFieldMissing = ErrorCode(
    code: 'REQUIRED_FIELD_MISSING',
    messageTemplate: 'Required field missing: {0}',
    category: 'Validation',
    description: 'Required parameter not provided',
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
    category: 'Connection',
    description: 'Connection failed with error',
  );
  static const disconnectFailed = ErrorCode(
    code: 'DISCONNECT_FAILED',
    messageTemplate: 'Disconnect failed: {0}',
    category: 'Connection',
    description: 'Disconnect failed with error',
  );
  static const printFailed = ErrorCode(
    code: 'PRINT_FAILED',
    messageTemplate: 'Print failed: {0}',
    category: 'Print',
    description: 'Print failed with error',
  );
  static const ribbonErrorDetected = ErrorCode(
    code: 'RIBBON_ERROR_DETECTED',
    messageTemplate: 'Ribbon error detected: {0}',
    category: 'Print',
    description: 'Ribbon error detected',
  );
  static const printCompletionHardwareError = ErrorCode(
    code: 'PRINT_COMPLETION_HARDWARE_ERROR',
    messageTemplate: 'Print completion failed due to hardware issues',
    category: 'Print',
    description: 'Print completion failed due to hardware issues',
  );
  static const statusUnknownError = ErrorCode(
    code: 'STATUS_UNKNOWN_ERROR',
    messageTemplate: 'Unknown status error: {0}',
    category: 'Status',
    description: 'Unknown error occurred during status check',
  );
  static const printUnknownError = ErrorCode(
    code: 'PRINT_UNKNOWN_ERROR',
    messageTemplate: 'Unknown print error: {0}',
    category: 'Print',
    description: 'Unknown error occurred during print',
  );
  static const connectionUnknownError = ErrorCode(
    code: 'CONNECTION_UNKNOWN_ERROR',
    messageTemplate: 'Unknown connection error: {0}',
    category: 'Connection',
    description: 'Unknown error occurred during connection',
  );
  static const disconnectUnknownError = ErrorCode(
    code: 'DISCONNECT_UNKNOWN_ERROR',
    messageTemplate: 'Unknown disconnect error: {0}',
    category: 'Connection',
    description: 'Unknown error occurred during disconnect',
  );
  static const statusCheckUnknownError = ErrorCode(
    code: 'STATUS_CHECK_UNKNOWN_ERROR',
    messageTemplate: 'Unknown status check error: {0}',
    category: 'Status',
    description: 'Unknown error occurred during status check',
  );
  static const detailedStatusUnknownError = ErrorCode(
    code: 'DETAILED_STATUS_UNKNOWN_ERROR',
    messageTemplate: 'Unknown detailed status error: {0}',
    category: 'Status',
    description: 'Unknown error occurred during detailed status check',
  );
  static const waitCompletionUnknownError = ErrorCode(
    code: 'WAIT_COMPLETION_UNKNOWN_ERROR',
    messageTemplate: 'Unknown error while waiting for print completion: {0}',
    category: 'Print',
    description: 'Unknown error while waiting for print completion',
  );
}
