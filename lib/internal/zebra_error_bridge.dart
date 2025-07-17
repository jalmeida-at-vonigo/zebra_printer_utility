import '../models/result.dart';

/// Bridge pattern for converting Zebra SDK operation failures to structured Result objects
/// 
/// This class acts as a bridge between the Zebra Link-OS SDK error system
/// and our internal Result-based error handling system. It converts ZSDK
/// operation failures into complete Result.failure() objects with appropriate
/// ErrorCode constants.
/// 
/// **Based on**: Zebra Link-OS SDK v1.6.1158 iOS Documentation
/// **Focus**: Operation failures only (not PrinterStatus which is for getStatusDetails)
/// 
/// **Usage:**
/// ```dart
/// // Convert ZSDK operation failure to Result.failure()
/// final result = ZebraErrorBridge.fromError(exception);
/// 
/// // Convert specific operation failures
/// final connectionResult = ZebraErrorBridge.fromConnectionError(error);
/// final printResult = ZebraErrorBridge.fromPrintError(error);
/// final statusResult = ZebraErrorBridge.fromStatusError(error);
/// ```
class ZebraErrorBridge {
  /// Private constructor to prevent instantiation
  ZebraErrorBridge._();

  /// Official Zebra SDK Error Code mappings (from ZebraErrorCodeI interface)
  /// Maps exact SDK error codes to our ErrorCode constants
  static const _zebraSDKErrorMappings = {
    // Connection errors - ZEBRA_ERROR_NO_CONNECTION
    'ZEBRA_ERROR_NO_CONNECTION': ErrorCodes.zebraNoConnection,
    'Unable to create a connection to a printer': ErrorCodes.zebraNoConnection,
    
    // Read/Write errors
    'ZEBRA_ERROR_WRITE_FAILURE': ErrorCodes.zebraWriteFailure,
    'Write to a connection failed': ErrorCodes.zebraWriteFailure,
    'ZEBRA_ERROR_READ_FAILURE': ErrorCodes.zebraReadFailure,
    'Read from a connection failed': ErrorCodes.zebraReadFailure,
    
    // Language errors
    'ZEBRA_UNKNOWN_PRINTER_LANGUAGE': ErrorCodes.zebraUnknownPrinterLanguage,
    'Unable to determine the control language of a printer': ErrorCodes.zebraUnknownPrinterLanguage,
    'ZEBRA_INVALID_PRINTER_LANGUAGE': ErrorCodes.zebraInvalidPrinterLanguage,
    'Invalid printer language': ErrorCodes.zebraInvalidPrinterLanguage,
    
    // Network discovery errors
    'ZEBRA_MALFORMED_NETWORK_DISCOVERY_ADDRESS': ErrorCodes.zebraMalformedNetworkDiscoveryAddress,
    'Malformed discovery address': ErrorCodes.zebraMalformedNetworkDiscoveryAddress,
    'ZEBRA_NETWORK_ERROR_DURING_DISCOVERY': ErrorCodes.zebraNetworkErrorDuringDiscovery,
    'Network error during discovery': ErrorCodes.zebraNetworkErrorDuringDiscovery,
    'ZEBRA_INVALID_DISCOVERY_HOP_COUNT': ErrorCodes.zebraInvalidDiscoveryHopCount,
    'Invalid multicast hop count': ErrorCodes.zebraInvalidDiscoveryHopCount,
    
    // Status response errors
    'ZEBRA_MALFORMED_PRINTER_STATUS_RESPONSE': ErrorCodes.zebraMalformedPrinterStatusResponse,
    'Malformed status response - unable to determine printer status': ErrorCodes.zebraMalformedPrinterStatusResponse,
    
    // Data format errors
    'ZEBRA_INVALID_FORMAT_NAME': ErrorCodes.zebraInvalidFormatName,
    'Invalid format name': ErrorCodes.zebraInvalidFormatName,
    'ZEBRA_BAD_FILE_DIRECTORY_ENTRY': ErrorCodes.zebraBadFileDirectoryEntry,
    'Bad file directory entry': ErrorCodes.zebraBadFileDirectoryEntry,
    'ZEBRA_MALFORMED_FORMAT_FIELD_NUMBER': ErrorCodes.zebraMalformedFormatFieldNumber,
    '^FN\' integer must be between 1 and 9999': ErrorCodes.zebraMalformedFormatFieldNumber,
    'ZEBRA_INVALID_FILE_NAME': ErrorCodes.zebraInvalidFileName,
    'Invalid file name': ErrorCodes.zebraInvalidFileName,
    'ZEBRA_INVALID_PRINTER_DRIVE_LETTER': ErrorCodes.zebraInvalidPrinterDriveLetter,
    'Invalid drive specified': ErrorCodes.zebraInvalidPrinterDriveLetter,
  };

  /// Bridge method: Convert any ZSDK operation failure to Result.failure()
  static Result<T> fromError<T>(
    dynamic error, {
    int? errorNumber,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final errorCode = _classifyError(error);
    return _createFailureResult<T>(
      errorCode,
      error,
      errorNumber: errorNumber,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Bridge method: Convert ZSDK connection operation failure to Result.failure()
  static Result<T> fromConnectionError<T>(
    dynamic error, {
    int? errorNumber,
    StackTrace? stackTrace,
    String? deviceAddress,
    Map<String, dynamic>? context,
  }) {
    final errorCode = _classifyConnectionError(error);
    final enrichedContext = <String, dynamic>{
      ...?context,
      if (deviceAddress != null) 'deviceAddress': deviceAddress,
      'operationType': 'connection',
    };
    
    return _createFailureResult<T>(
      errorCode,
      error,
      errorNumber: errorNumber,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }

  /// Bridge method: Convert ZSDK print operation failure to Result.failure()
  static Result<T> fromPrintError<T>(
    dynamic error, {
    int? errorNumber,
    StackTrace? stackTrace,
    String? printData,
    Map<String, dynamic>? context,
  }) {
    final errorCode = _classifyPrintError(error);
    final enrichedContext = <String, dynamic>{
      ...?context,
      if (printData != null) 'printDataLength': printData.length,
      'operationType': 'print',
    };
    
    return _createFailureResult<T>(
      errorCode,
      error,
      errorNumber: errorNumber,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }

  /// Bridge method: Convert ZSDK status check operation failure to Result.failure()
  static Result<T> fromStatusError<T>(
    dynamic error, {
    int? errorNumber,
    StackTrace? stackTrace,
    bool isDetailed = false,
    Map<String, dynamic>? context,
  }) {
    final errorCode = isDetailed 
        ? _classifyDetailedStatusError(error)
        : _classifyStatusError(error);
    
    final enrichedContext = <String, dynamic>{
      ...?context,
      'operationType': 'status',
      'isDetailed': isDetailed,
    };
    
    return _createFailureResult<T>(
      errorCode,
      error,
      errorNumber: errorNumber,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }

  /// Bridge method: Convert ZSDK discovery operation failure to Result.failure()
  static Result<T> fromDiscoveryError<T>(
    dynamic error, {
    int? errorNumber,
    StackTrace? stackTrace,
    Duration? timeout,
    Map<String, dynamic>? context,
  }) {
    final message = _normalizeErrorMessage(error);
    
    // Check for documented ZSDK discovery errors
    final discoveryError = _findErrorInMappings(message, _zebraSDKErrorMappings);
    final errorCode = discoveryError ?? ErrorCodes.discoveryError;
    
    final enrichedContext = <String, dynamic>{
      ...?context,
      'operationType': 'discovery',
      if (timeout != null) 'timeoutSeconds': timeout.inSeconds,
    };
    
    return _createFailureResult<T>(
      errorCode,
      error,
      errorNumber: errorNumber,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }

  /// Bridge method: Convert ZSDK command operation failure to Result.failure()
  static Result<T> fromCommandError<T>(
    dynamic error, {
    int? errorNumber,
    StackTrace? stackTrace,
    String? command,
    Map<String, dynamic>? context,
  }) {
    final message = _normalizeErrorMessage(error);
    
    // Check for documented ZSDK errors
    final sdkError = _findErrorInMappings(message, _zebraSDKErrorMappings);
    final errorCode = sdkError ?? ErrorCodes.commandError;
    
    final enrichedContext = <String, dynamic>{
      ...?context,
      if (command != null) 'command': command,
      'operationType': 'command',
    };
    
    return _createFailureResult<T>(
      errorCode,
      error,
      errorNumber: errorNumber,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }



  // ===== PRIVATE IMPLEMENTATION METHODS =====

  /// Create a structured Result.failure() with complete error context
  static Result<T> _createFailureResult<T>(
    ErrorCode errorCode,
    dynamic originalError, {
    int? errorNumber,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    return Result.errorCode(
      errorCode,
      formatArgs: context != null ? _extractFormatArgs(context) : null,
      errorNumber: errorNumber,
      nativeError: originalError,
      dartStackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// Extract format arguments from context for error message formatting
  static List<Object>? _extractFormatArgs(Map<String, dynamic> context) {
    final args = <Object>[];
    
    // Extract common format arguments based on context
    if (context['deviceAddress'] != null) args.add(context['deviceAddress']);
    if (context['timeoutSeconds'] != null) args.add(context['timeoutSeconds']);
    if (context['printDataLength'] != null) args.add(context['printDataLength']);
    if (context['command'] != null) args.add(context['command']);
    
    return args.isEmpty ? null : args;
  }

  /// Classify ZSDK operation failure using documented error codes
  static ErrorCode _classifyError(dynamic error) {
    final message = _normalizeErrorMessage(error);

    // Check documented ZSDK error codes first
    final sdkError = _findErrorInMappings(message, _zebraSDKErrorMappings);
    if (sdkError != null) return sdkError;

    // Fallback for undocumented errors
    if (message.contains('timeout')) {
      return ErrorCodes.operationTimeout;
    } else if (message.contains('connection')) {
      return ErrorCodes.connectionError;
    } else if (message.contains('permission')) {
      return ErrorCodes.noPermission;
    }

    return ErrorCodes.operationError;
  }

  /// Classify ZSDK connection operation failures
  static ErrorCode _classifyConnectionError(dynamic error) {
    final message = _normalizeErrorMessage(error);

    // Check documented ZSDK connection errors first
    final sdkError = _findErrorInMappings(message, _zebraSDKErrorMappings);
    if (sdkError != null) return sdkError;
    
    // Fallback patterns
    if (message.contains('timeout')) {
      return ErrorCodes.connectionTimeout;
    } else if (message.contains('permission')) {
      return ErrorCodes.noPermission;
    } else if (message.contains('not found') || message.contains('unavailable')) {
      return ErrorCodes.invalidDeviceAddress;
    }

    return ErrorCodes.connectionError;
  }

  /// Classify ZSDK print operation failures
  static ErrorCode _classifyPrintError(dynamic error) {
    final message = _normalizeErrorMessage(error);

    // Check documented ZSDK print-related errors
    final sdkError = _findErrorInMappings(message, _zebraSDKErrorMappings);
    if (sdkError != null) return sdkError;
    
    // Fallback patterns
    if (message.contains('timeout')) {
      return ErrorCodes.printTimeout;
    }

    return ErrorCodes.printError;
  }

  /// Classify ZSDK status check operation failures
  static ErrorCode _classifyStatusError(dynamic error) {
    final message = _normalizeErrorMessage(error);

    // Check documented ZSDK status errors
    final sdkError = _findErrorInMappings(message, _zebraSDKErrorMappings);
    if (sdkError != null) return sdkError;
    
    // Fallback patterns
    if (message.contains('timeout')) {
      return ErrorCodes.statusTimeoutError;
    } else if (message.contains('connection')) {
      return ErrorCodes.statusConnectionError;
    }

    return ErrorCodes.basicStatusCheckFailed;
  }

  /// Classify ZSDK detailed status check operation failures
  static ErrorCode _classifyDetailedStatusError(dynamic error) {
    final message = _normalizeErrorMessage(error);

    // Check documented ZSDK status errors
    final sdkError = _findErrorInMappings(message, _zebraSDKErrorMappings);
    if (sdkError != null) return sdkError;
    
    // Fallback patterns
    if (message.contains('timeout')) {
      return ErrorCodes.statusTimeoutError;
    } else if (message.contains('connection')) {
      return ErrorCodes.statusConnectionError;
    }

    return ErrorCodes.detailedStatusCheckFailed;
  }

  /// Normalize error message for consistent classification
  static String _normalizeErrorMessage(dynamic error) {
    final message = error.toString().toLowerCase().trim();
    
    // Remove common prefixes but preserve Zebra-specific codes
    return message
        .replaceAll(RegExp(r'^(exception|error|failed):\s*'), '')
        .trim();
  }

  /// Find error in mapping dictionary - returns null if not found
  static ErrorCode? _findErrorInMappings(String message, Map<String, ErrorCode?> mappings) {
    for (final entry in mappings.entries) {
      if (message.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }
} 