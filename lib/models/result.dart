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
  final String? recoveryHint;

  const ErrorCode({
    required this.code,
    required this.messageTemplate,
    required this.category,
    required this.description,
    this.recoveryHint,
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

  /// Recovery hint for user intervention
  final String? recoveryHint;

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
    recoveryHint: 'Check network connection and ensure printer is powered on.',
  );

  static const connectionTimeout = ErrorCode(
    code: 'CONNECTION_TIMEOUT',
    messageTemplate: 'Connection timed out after {0} seconds',
    category: 'Connection',
    description: 'Connection attempt exceeded timeout',
    recoveryHint: 'Ensure printer is within range and not obstructed.',
  );

  static const connectionLost = ErrorCode(
    code: 'CONNECTION_LOST',
    messageTemplate: 'Connection to printer was lost',
    category: 'Connection',
    description: 'Active connection was unexpectedly terminated',
    recoveryHint: 'Re-establish connection by attempting to connect again.',
  );

  static const notConnected = ErrorCode(
    code: 'NOT_CONNECTED',
    messageTemplate: 'No printer is currently connected',
    category: 'Connection',
    description: 'Operation requires an active connection',
    recoveryHint: 'Connect to a printer using the connect method.',
  );

  static const alreadyConnected = ErrorCode(
    code: 'ALREADY_CONNECTED',
    messageTemplate: 'Already connected to printer at {0}',
    category: 'Connection',
    description: 'Attempt to connect when already connected',
    recoveryHint:
        'Disconnect from the current printer before attempting to connect to a new one.',
  );

  static const invalidDeviceAddress = ErrorCode(
    code: 'INVALID_DEVICE_ADDRESS',
    messageTemplate: 'Invalid device address: {0}',
    category: 'Connection',
    description: 'Device address format is invalid',
    recoveryHint:
        'Ensure the device address is correct and matches the printer model.',
  );

  static const connectionRetryFailed = ErrorCode(
    code: 'CONNECTION_RETRY_FAILED',
    messageTemplate: 'Failed to connect after {0} attempts',
    category: 'Connection',
    description: 'Connection failed after maximum retry attempts',
    recoveryHint: 'Review connection settings and ensure printer is reachable.',
  );

  // ===== DISCOVERY ERRORS =====
  static const discoveryError = ErrorCode(
    code: 'DISCOVERY_ERROR',
    messageTemplate: 'Failed to discover printers',
    category: 'Discovery',
    description: 'General discovery failure',
    recoveryHint: 'Ensure Bluetooth is enabled and try again.',
  );

  static const discoveryTimeout = ErrorCode(
    code: 'DISCOVERY_TIMEOUT',
    messageTemplate: 'Discovery timed out after {0} seconds',
    category: 'Discovery',
    description: 'Discovery operation exceeded timeout',
    recoveryHint: 'Increase the discovery timeout or ensure network is stable.',
  );

  static const noPermission = ErrorCode(
    code: 'NO_PERMISSION',
    messageTemplate: 'Permission denied: {0}',
    category: 'Discovery',
    description: 'Required permissions not granted',
    recoveryHint: 'Grant necessary permissions in your app\'s manifest.',
  );

  static const bluetoothDisabled = ErrorCode(
    code: 'BLUETOOTH_DISABLED',
    messageTemplate: 'Bluetooth is disabled',
    category: 'Discovery',
    description: 'Bluetooth must be enabled for discovery',
    recoveryHint: 'Enable Bluetooth in your device settings.',
  );

  static const networkError = ErrorCode(
    code: 'NETWORK_ERROR',
    messageTemplate: 'Network error: {0}',
    category: 'Discovery',
    description: 'Network-related discovery failure',
    recoveryHint: 'Check your internet connection and try again.',
  );

  static const noPrintersFound = ErrorCode(
    code: 'NO_PRINTERS_FOUND',
    messageTemplate: 'No printers found during discovery',
    category: 'Discovery',
    description: 'Discovery completed but no printers were found',
    recoveryHint: 'Ensure the printer is within range and powered on.',
  );

  static const multiplePrintersFound = ErrorCode(
    code: 'MULTIPLE_PRINTERS_FOUND',
    messageTemplate: 'Multiple printers found ({0}), specify device explicitly',
    category: 'Discovery',
    description: 'Ambiguous printer selection',
    recoveryHint:
        'Specify the exact printer model or address to avoid ambiguity.',
  );

  // ===== PRINT ERRORS =====
  static const printError = ErrorCode(
    code: 'PRINT_ERROR',
    messageTemplate: 'Print operation failed',
    category: 'Print',
    description: 'General print failure',
    recoveryHint: 'Check printer status and ensure it is ready for printing.',
  );

  static const printTimeout = ErrorCode(
    code: 'PRINT_TIMEOUT',
    messageTemplate: 'Print operation timed out after {0} seconds',
    category: 'Print',
    description: 'Print operation exceeded timeout',
    recoveryHint: 'Ensure printer is responsive and not busy.',
  );

  static const printerNotReady = ErrorCode(
    code: 'PRINTER_NOT_READY',
    messageTemplate: 'Printer is not ready: {0}',
    category: 'Print',
    description: 'Printer cannot accept print jobs',
    recoveryHint:
        'Ensure the printer is turned on, has paper, and is not jammed.',
  );

  static const outOfPaper = ErrorCode(
    code: 'OUT_OF_PAPER',
    messageTemplate: 'Printer is out of paper',
    category: 'Print',
    description: 'No paper available for printing',
    recoveryHint: 'Add more paper to the printer.',
  );

  static const headOpen = ErrorCode(
    code: 'HEAD_OPEN',
    messageTemplate: 'Printer head is open',
    category: 'Print',
    description: 'Printer head must be closed for printing',
    recoveryHint: 'Close the printer head to resume printing.',
  );

  static const printerPaused = ErrorCode(
    code: 'PRINTER_PAUSED',
    messageTemplate: 'Printer is paused',
    category: 'Print',
    description: 'Printer must be unpaused for printing',
    recoveryHint: 'Unpause the printer to continue printing.',
  );

  static const ribbonError = ErrorCode(
    code: 'RIBBON_ERROR',
    messageTemplate: 'Ribbon error: {0}',
    category: 'Print',
    description: 'Ribbon-related print failure',
    recoveryHint:
        'Replace the ribbon or check the printer\'s ribbon alignment.',
  );

  static const printDataError = ErrorCode(
    code: 'PRINT_DATA_ERROR',
    messageTemplate: 'Invalid print data: {0}',
    category: 'Print',
    description: 'Print data format or content error',
    recoveryHint:
        'Ensure the print data is valid and follows the correct format.',
  );

  static const printRetryFailed = ErrorCode(
    code: 'PRINT_RETRY_FAILED',
    messageTemplate: 'Failed to print after {0} attempts',
    category: 'Print',
    description: 'Print failed after maximum retry attempts',
    recoveryHint: 'Review print settings and ensure printer is ready.',
  );

  static const printDataInvalidFormat = ErrorCode(
    code: 'PRINT_DATA_INVALID_FORMAT',
    messageTemplate: 'Invalid print data format',
    category: 'Print',
    description: 'Print data format is invalid',
    recoveryHint:
        'Ensure the print data is in a valid format (e.g., ZPL, CPCL).',
  );

  static const printDataTooLarge = ErrorCode(
    code: 'PRINT_DATA_TOO_LARGE',
    messageTemplate: 'Print data too large: {0} bytes',
    category: 'Print',
    description: 'Print data exceeds maximum allowed size',
    recoveryHint:
        'Reduce the size of the print data or increase the printer\'s buffer size.',
  );

  // ===== DATA ERRORS =====
  static const invalidData = ErrorCode(
    code: 'INVALID_DATA',
    messageTemplate: 'Invalid data provided',
    category: 'Data',
    description: 'General data validation failure',
    recoveryHint:
        'Ensure the data you are sending is valid and meets the requirements.',
  );

  static const invalidFormat = ErrorCode(
    code: 'INVALID_FORMAT',
    messageTemplate: 'Invalid format: {0}',
    category: 'Data',
    description: 'Data format is not supported',
    recoveryHint: 'Ensure the data format is compatible with the printer.',
  );

  static const encodingError = ErrorCode(
    code: 'ENCODING_ERROR',
    messageTemplate: 'Encoding error: {0}',
    category: 'Data',
    description: 'Character encoding failure',
    recoveryHint:
        'Ensure the character encoding of your data matches the printer\'s settings.',
  );

  static const emptyData = ErrorCode(
    code: 'EMPTY_DATA',
    messageTemplate: 'No data provided for printing',
    category: 'Data',
    description: 'Print data is empty or null',
    recoveryHint: 'Provide valid print data to the printer.',
  );

  // ===== OPERATION ERRORS =====
  static const operationTimeout = ErrorCode(
    code: 'OPERATION_TIMEOUT',
    messageTemplate: 'Operation timed out after {0} seconds',
    category: 'Operation',
    description: 'Operation exceeded timeout',
    recoveryHint: 'Ensure the operation completes within the specified time.',
  );

  static const operationCancelled = ErrorCode(
    code: 'OPERATION_CANCELLED',
    messageTemplate: 'Operation was cancelled',
    category: 'Operation',
    description: 'Operation was cancelled by user or system',
    recoveryHint:
        'Check if the operation was explicitly cancelled by the user.',
  );

  static const invalidArgument = ErrorCode(
    code: 'INVALID_ARGUMENT',
    messageTemplate: 'Invalid argument: {0}',
    category: 'Operation',
    description: 'Invalid parameter provided',
    recoveryHint: 'Review the parameters passed to the operation.',
  );

  static const operationError = ErrorCode(
    code: 'OPERATION_ERROR',
    messageTemplate: 'Operation failed: {0}',
    category: 'Operation',
    description: 'General operation failure',
    recoveryHint: 'Investigate the cause of the operation failure.',
  );

  static const retryLimitExceeded = ErrorCode(
    code: 'RETRY_LIMIT_EXCEEDED',
    messageTemplate: 'Retry limit exceeded ({0} attempts)',
    category: 'Operation',
    description: 'Maximum retry attempts reached',
    recoveryHint:
        'Review the retry logic and consider increasing the retry limit.',
  );

  // ===== STATUS ERRORS =====
  static const statusCheckFailed = ErrorCode(
    code: 'STATUS_CHECK_FAILED',
    messageTemplate: 'Failed to check printer status: {0}',
    category: 'Status',
    description: 'Printer status check failure',
    recoveryHint: 'Re-check the printer\'s status or try again later.',
  );

  static const statusTimeout = ErrorCode(
    code: 'STATUS_TIMEOUT',
    messageTemplate: 'Status check timed out after {0} seconds',
    category: 'Status',
    description: 'Status check exceeded timeout',
    recoveryHint:
        'Increase the status check timeout or ensure printer is responsive.',
  );

  static const invalidStatusResponse = ErrorCode(
    code: 'INVALID_STATUS_RESPONSE',
    messageTemplate: 'Invalid status response from printer',
    category: 'Status',
    description: 'Printer returned invalid status data',
    recoveryHint:
        'Review the printer\'s status response and ensure it\'s valid.',
  );

  static const detailedStatusCheckFailed = ErrorCode(
    code: 'DETAILED_STATUS_CHECK_FAILED',
    messageTemplate: 'Failed to get detailed printer status: {0}',
    category: 'Status',
    description: 'Detailed printer status check failure',
    recoveryHint: 'Re-check the printer\'s detailed status or try again later.',
  );

  static const basicStatusCheckFailed = ErrorCode(
    code: 'BASIC_STATUS_CHECK_FAILED',
    messageTemplate: 'Failed to get basic printer status: {0}',
    category: 'Status',
    description: 'Basic printer status check failure',
    recoveryHint: 'Re-check the printer\'s basic status or try again later.',
  );

  static const statusResponseFormatError = ErrorCode(
    code: 'STATUS_RESPONSE_FORMAT_ERROR',
    messageTemplate: 'Invalid response format for {0} status',
    category: 'Status',
    description: 'Status response format is invalid or unexpected',
    recoveryHint: 'Check printer firmware version and ensure compatibility.',
  );

  static const statusConnectionError = ErrorCode(
    code: 'STATUS_CONNECTION_ERROR',
    messageTemplate: 'Connection error during status check: {0}',
    category: 'Status',
    description: 'Connection lost during status check',
    recoveryHint: 'Reconnect to the printer and try the status check again.',
  );

  static const statusTimeoutError = ErrorCode(
    code: 'STATUS_TIMEOUT_ERROR',
    messageTemplate: 'Status check timed out: {0}',
    category: 'Status',
    description: 'Status check operation timed out',
    recoveryHint: 'Increase timeout or check printer responsiveness.',
  );

  // ===== COMMAND ERRORS =====
  static const commandError = ErrorCode(
    code: 'COMMAND_ERROR',
    messageTemplate: 'Command failed: {0}',
    category: 'Command',
    description: 'Printer command execution failure',
    recoveryHint: 'Review the command syntax and ensure it\'s correct.',
  );

  static const commandTimeout = ErrorCode(
    code: 'COMMAND_TIMEOUT',
    messageTemplate: 'Command timed out after {0} seconds',
    category: 'Command',
    description: 'Command execution exceeded timeout',
    recoveryHint: 'Ensure the command completes within the specified time.',
  );

  static const invalidCommand = ErrorCode(
    code: 'INVALID_COMMAND',
    messageTemplate: 'Invalid command: {0}',
    category: 'Command',
    description: 'Command format or syntax error',
    recoveryHint: 'Check the command syntax and ensure it\'s valid.',
  );

  // ===== PLATFORM ERRORS =====
  static const platformError = ErrorCode(
    code: 'PLATFORM_ERROR',
    messageTemplate: 'Platform error: {0}',
    category: 'Platform',
    description: 'Platform-specific error',
    recoveryHint:
        'Investigate the platform-specific error and ensure it\'s handled.',
  );

  static const notImplemented = ErrorCode(
    code: 'NOT_IMPLEMENTED',
    messageTemplate: 'Feature not implemented on this platform',
    category: 'Platform',
    description: 'Feature is not available on current platform',
    recoveryHint: 'This feature is not yet supported on your platform.',
  );

  static const unsupportedPlatform = ErrorCode(
    code: 'UNSUPPORTED_PLATFORM',
    messageTemplate: 'Platform not supported: {0}',
    category: 'Platform',
    description: 'Current platform is not supported',
    recoveryHint:
        'This plugin only supports the platforms listed in its documentation.',
  );

  // ===== SYSTEM ERRORS =====
  static const unknownError = ErrorCode(
    code: 'UNKNOWN_ERROR',
    messageTemplate: 'Unknown error occurred',
    category: 'System',
    description: 'Unclassified or unexpected error',
    recoveryHint: 'Review the logs and ensure all dependencies are up to date.',
  );

  static const internalError = ErrorCode(
    code: 'INTERNAL_ERROR',
    messageTemplate: 'Internal error: {0}',
    category: 'System',
    description: 'Internal system error',
    recoveryHint:
        'This is a bug in the plugin. Please report it to the developer.',
  );

  static const resourceError = ErrorCode(
    code: 'RESOURCE_ERROR',
    messageTemplate: 'Resource error: {0}',
    category: 'System',
    description: 'System resource allocation failure',
    recoveryHint: 'Check your device\'s memory and storage.',
  );

  static const memoryError = ErrorCode(
    code: 'MEMORY_ERROR',
    messageTemplate: 'Memory allocation failed',
    category: 'System',
    description: 'Insufficient memory for operation',
    recoveryHint: 'Free up memory on your device or increase available RAM.',
  );

  // ===== CONFIGURATION ERRORS =====
  static const configurationError = ErrorCode(
    code: 'CONFIGURATION_ERROR',
    messageTemplate: 'Configuration error: {0}',
    category: 'Configuration',
    description: 'Invalid or missing configuration',
    recoveryHint:
        'Review the plugin\'s configuration and ensure it\'s correct.',
  );

  static const invalidSettings = ErrorCode(
    code: 'INVALID_SETTINGS',
    messageTemplate: 'Invalid printer settings: {0}',
    category: 'Configuration',
    description: 'Printer settings are invalid',
    recoveryHint: 'Check the printer\'s settings and ensure they are valid.',
  );

  // ===== VALIDATION ERRORS =====
  static const validationError = ErrorCode(
    code: 'VALIDATION_ERROR',
    messageTemplate: 'Validation failed: {0}',
    category: 'Validation',
    description: 'Input validation failure',
    recoveryHint:
        'Review the input data and ensure it meets the validation requirements.',
  );

  static const requiredFieldMissing = ErrorCode(
    code: 'REQUIRED_FIELD_MISSING',
    messageTemplate: 'Required field missing: {0}',
    category: 'Validation',
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
    recoveryHint: 'Check network connection and ensure printer is powered on.',
  );
  static const disconnectFailed = ErrorCode(
    code: 'DISCONNECT_FAILED',
    messageTemplate: 'Disconnect failed: {0}',
    category: 'Connection',
    description: 'Disconnect failed with error',
    recoveryHint: 'Re-establish connection by attempting to connect again.',
  );
  static const printFailed = ErrorCode(
    code: 'PRINT_FAILED',
    messageTemplate: 'Print failed: {0}',
    category: 'Print',
    description: 'Print failed with error',
    recoveryHint: 'Review print settings and ensure printer is ready.',
  );
  static const ribbonErrorDetected = ErrorCode(
    code: 'RIBBON_ERROR_DETECTED',
    messageTemplate: 'Ribbon error detected: {0}',
    category: 'Print',
    description: 'Ribbon error detected',
    recoveryHint:
        'Replace the ribbon or check the printer\'s ribbon alignment.',
  );
  static const printCompletionHardwareError = ErrorCode(
    code: 'PRINT_COMPLETION_HARDWARE_ERROR',
    messageTemplate: 'Print completion failed due to hardware issues',
    category: 'Print',
    description: 'Print completion failed due to hardware issues',
    recoveryHint:
        'Ensure the printer\'s hardware components are functioning correctly.',
  );
  static const statusUnknownError = ErrorCode(
    code: 'STATUS_UNKNOWN_ERROR',
    messageTemplate: 'Unknown status error: {0}',
    category: 'Status',
    description: 'Unknown error occurred during status check',
    recoveryHint: 'Re-check the printer\'s status or try again later.',
  );
  static const printUnknownError = ErrorCode(
    code: 'PRINT_UNKNOWN_ERROR',
    messageTemplate: 'Unknown print error: {0}',
    category: 'Print',
    description: 'Unknown error occurred during print',
    recoveryHint: 'Review the print operation and ensure it\'s valid.',
  );
  static const connectionUnknownError = ErrorCode(
    code: 'CONNECTION_UNKNOWN_ERROR',
    messageTemplate: 'Unknown connection error: {0}',
    category: 'Connection',
    description: 'Unknown error occurred during connection',
    recoveryHint: 'Re-establish connection by attempting to connect again.',
  );
  static const disconnectUnknownError = ErrorCode(
    code: 'DISCONNECT_UNKNOWN_ERROR',
    messageTemplate: 'Unknown disconnect error: {0}',
    category: 'Connection',
    description: 'Unknown error occurred during disconnect',
    recoveryHint: 'Re-establish connection by attempting to connect again.',
  );
  static const statusCheckUnknownError = ErrorCode(
    code: 'STATUS_CHECK_UNKNOWN_ERROR',
    messageTemplate: 'Unknown status check error: {0}',
    category: 'Status',
    description: 'Unknown error occurred during status check',
    recoveryHint: 'Re-check the printer\'s status or try again later.',
  );
  static const detailedStatusUnknownError = ErrorCode(
    code: 'DETAILED_STATUS_UNKNOWN_ERROR',
    messageTemplate: 'Unknown detailed status error: {0}',
    category: 'Status',
    description: 'Unknown error occurred during detailed status check',
    recoveryHint: 'Re-check the printer\'s status or try again later.',
  );
  static const waitCompletionUnknownError = ErrorCode(
    code: 'WAIT_COMPLETION_UNKNOWN_ERROR',
    messageTemplate: 'Unknown error while waiting for print completion: {0}',
    category: 'Print',
    description: 'Unknown error while waiting for print completion',
    recoveryHint: 'Ensure the printer is ready for the next print job.',
  );

  // ===== ADDITIONAL ERROR SCENARIOS WITH RECOVERY HINTS =====
  static const printerBusy = ErrorCode(
    code: 'PRINTER_BUSY',
    messageTemplate: 'Printer is busy processing another job',
    category: 'Print',
    description: 'Printer cannot accept new print jobs',
    recoveryHint: 'Wait for the current print job to complete, then try again.',
  );

  static const printerOffline = ErrorCode(
    code: 'PRINTER_OFFLINE',
    messageTemplate: 'Printer is offline',
    category: 'Print',
    description: 'Printer is not available for printing',
    recoveryHint:
        'Check if the printer is powered on and connected to the network.',
  );

  static const printerJammed = ErrorCode(
    code: 'PRINTER_JAMMED',
    messageTemplate: 'Printer has a paper jam',
    category: 'Print',
    description: 'Paper is stuck in the printer mechanism',
    recoveryHint: 'Clear the paper jam and ensure the paper path is clear.',
  );

  static const ribbonOut = ErrorCode(
    code: 'RIBBON_OUT',
    messageTemplate: 'Printer ribbon is out or needs replacement',
    category: 'Print',
    description: 'No ribbon available for printing',
    recoveryHint: 'Replace the printer ribbon with a new one.',
  );

  static const mediaError = ErrorCode(
    code: 'MEDIA_ERROR',
    messageTemplate: 'Media error: {0}',
    category: 'Print',
    description: 'Issue with print media (labels, paper, etc.)',
    recoveryHint: 'Check the media type and ensure it\'s properly loaded.',
  );

  static const calibrationRequired = ErrorCode(
    code: 'CALIBRATION_REQUIRED',
    messageTemplate: 'Printer requires calibration',
    category: 'Print',
    description: 'Printer needs to be calibrated for current media',
    recoveryHint: 'Run the printer calibration process for the current media.',
  );

  static const bufferFull = ErrorCode(
    code: 'BUFFER_FULL',
    messageTemplate: 'Printer buffer is full',
    category: 'Print',
    description: 'Printer cannot accept more data',
    recoveryHint:
        'Wait for the printer to process current data or clear the buffer.',
  );

  static const languageMismatch = ErrorCode(
    code: 'LANGUAGE_MISMATCH',
    messageTemplate: 'Print language mismatch: expected {0}, got {1}',
    category: 'Print',
    description: 'Printer language does not match print data format',
    recoveryHint:
        'Set the printer language to match your print data format (ZPL/CPCL).',
  );

  static const settingsConflict = ErrorCode(
    code: 'SETTINGS_CONFLICT',
    messageTemplate: 'Printer settings conflict: {0}',
    category: 'Configuration',
    description: 'Conflicting printer settings detected',
    recoveryHint: 'Review and adjust conflicting printer settings.',
  );

  static const firmwareUpdateRequired = ErrorCode(
    code: 'FIRMWARE_UPDATE_REQUIRED',
    messageTemplate: 'Printer firmware update required',
    category: 'System',
    description: 'Printer firmware is outdated',
    recoveryHint: 'Update the printer firmware to the latest version.',
  );

  static const temperatureError = ErrorCode(
    code: 'TEMPERATURE_ERROR',
    messageTemplate: 'Printer temperature error: {0}',
    category: 'Print',
    description: 'Printer temperature is outside operating range',
    recoveryHint:
        'Allow the printer to cool down or warm up to operating temperature.',
  );

  static const sensorError = ErrorCode(
    code: 'SENSOR_ERROR',
    messageTemplate: 'Printer sensor error: {0}',
    category: 'Print',
    description: 'Printer sensor malfunction',
    recoveryHint: 'Check and clean the printer sensors, or contact support.',
  );

  static const printHeadError = ErrorCode(
    code: 'PRINT_HEAD_ERROR',
    messageTemplate: 'Print head error: {0}',
    category: 'Print',
    description: 'Print head malfunction or damage',
    recoveryHint: 'Clean the print head or replace it if damaged.',
  );

  static const powerError = ErrorCode(
    code: 'POWER_ERROR',
    messageTemplate: 'Power error: {0}',
    category: 'System',
    description: 'Power-related printer error',
    recoveryHint: 'Check power supply and ensure stable power connection.',
  );

  static const communicationError = ErrorCode(
    code: 'COMMUNICATION_ERROR',
    messageTemplate: 'Communication error: {0}',
    category: 'Connection',
    description: 'Communication protocol error',
    recoveryHint:
        'Check connection settings and ensure proper communication protocol.',
  );

  static const authenticationError = ErrorCode(
    code: 'AUTHENTICATION_ERROR',
    messageTemplate: 'Authentication failed: {0}',
    category: 'Connection',
    description: 'Printer authentication failed',
    recoveryHint:
        'Check authentication credentials and network security settings.',
  );

  static const encryptionError = ErrorCode(
    code: 'ENCRYPTION_ERROR',
    messageTemplate: 'Encryption error: {0}',
    category: 'Connection',
    description: 'Data encryption/decryption failure',
    recoveryHint:
        'Check encryption settings and ensure compatible security protocols.',
  );

  static const dataCorruptionError = ErrorCode(
    code: 'DATA_CORRUPTION_ERROR',
    messageTemplate: 'Data corruption detected: {0}',
    category: 'Data',
    description: 'Print data is corrupted or incomplete',
    recoveryHint: 'Regenerate the print data and ensure data integrity.',
  );

  static const unsupportedFeature = ErrorCode(
    code: 'UNSUPPORTED_FEATURE',
    messageTemplate: 'Unsupported feature: {0}',
    category: 'Platform',
    description: 'Feature not supported by this printer model',
    recoveryHint: 'Use a printer model that supports this feature.',
  );

  static const maintenanceRequired = ErrorCode(
    code: 'MAINTENANCE_REQUIRED',
    messageTemplate: 'Printer maintenance required: {0}',
    category: 'System',
    description: 'Printer requires maintenance',
    recoveryHint:
        'Perform the required maintenance or contact service technician.',
  );

  static const consumableLow = ErrorCode(
    code: 'CONSUMABLE_LOW',
    messageTemplate: 'Consumable running low: {0}',
    category: 'Print',
    description: 'Printer consumable (ribbon, media) is running low',
    recoveryHint: 'Replace the consumable soon to avoid print quality issues.',
  );

  static const consumableEmpty = ErrorCode(
    code: 'CONSUMABLE_EMPTY',
    messageTemplate: 'Consumable empty: {0}',
    category: 'Print',
    description: 'Printer consumable is completely empty',
    recoveryHint: 'Replace the empty consumable to continue printing.',
  );
}
