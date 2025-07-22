import 'dart:async'; // Added for TimeoutException
import 'package:flutter/services.dart'; // Added for PlatformException and MissingPluginException

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
/// 
/// // Execute operations with automatic exception handling
/// final result = await ZebraErrorBridge.executeAndHandle(
///   operation: () => someOperation(),
///   operationType: OperationType.connection,
/// );
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

  /// Centralized operation execution with automatic exception handling
  ///
  /// This method wraps any operation and automatically converts exceptions
  /// to appropriate Result.failure() objects using the bridge pattern.
  /// Handles specific exception types for more precise error classification.
  ///
  /// **Usage:**
  /// ```dart
  /// final result = await ZebraErrorBridge.executeAndHandle<String>(
  ///   operation: () => printer.getSetting('device.language'),
  ///   operationType: OperationType.command,
  ///   context: {'setting': 'device.language'},
  /// );
  /// ```
  static Future<Result<T>> executeAndHandle<T>({
    required Future<T> Function() operation,
    required OperationType operationType,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) async {
    try {
      final data = await operation();
      return Result.success(data);
    } on TimeoutException catch (error, stackTrace) {
      return _handleTimeoutError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } on PlatformException catch (error, stackTrace) {
      return _handlePlatformError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } on MissingPluginException catch (error, stackTrace) {
      return _handleMissingPluginError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } on FormatException catch (error, stackTrace) {
      return _handleFormatError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } on ArgumentError catch (error, stackTrace) {
      return _handleArgumentError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } on StateError catch (error, stackTrace) {
      return _handleStateError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } catch (error, stackTrace) {
      // Fallback for any other exception types
      return _handleOperationError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    }
  }

  /// Synchronous version of executeAndHandle for non-async operations
  static Result<T> executeAndHandleSync<T>({
    required T Function() operation,
    required OperationType operationType,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) {
    try {
      final data = operation();
      return Result.success(data);
    } on PlatformException catch (error, stackTrace) {
      return _handlePlatformError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } on MissingPluginException catch (error, stackTrace) {
      return _handleMissingPluginError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } on FormatException catch (error, stackTrace) {
      return _handleFormatError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } on ArgumentError catch (error, stackTrace) {
      return _handleArgumentError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } on StateError catch (error, stackTrace) {
      return _handleStateError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    } catch (error, stackTrace) {
      // Fallback for any other exception types
      return _handleOperationError<T>(
        error,
        operationType: operationType,
        stackTrace: stackTrace,
        context: context,
        deviceAddress: deviceAddress,
        command: command,
        printData: printData,
        isDetailed: isDetailed,
        timeout: timeout,
      );
    }
  }

  /// Handle TimeoutException with operation-specific timeout errors
  static Result<T> _handleTimeoutError<T>(
    TimeoutException error, {
    required OperationType operationType,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) {
    final enrichedContext = <String, dynamic>{
      ...?context,
      'exceptionType': 'TimeoutException',
      'timeoutDuration': error.duration?.inSeconds,
      'operationType': operationType.name,
    };

    // Choose specific timeout error based on operation type
    final ErrorCode timeoutErrorCode;
    switch (operationType) {
      case OperationType.connection:
        timeoutErrorCode = ErrorCodes.connectionSpecificTimeout;
        break;
      case OperationType.print:
        timeoutErrorCode = ErrorCodes.printSpecificTimeout;
        break;
      case OperationType.status:
        timeoutErrorCode = ErrorCodes.statusSpecificTimeout;
        break;
      case OperationType.command:
        timeoutErrorCode = ErrorCodes.commandSpecificTimeout;
        break;
      case OperationType.discovery:
        timeoutErrorCode = ErrorCodes.discoveryTimeout;
        break;
      case OperationType.general:
        timeoutErrorCode = ErrorCodes.operationTimeout;
        break;
    }

    return _createFailureResult<T>(
      timeoutErrorCode,
      error,
      errorNumber: null,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }

  /// Handle PlatformException with extracted error codes
  static Result<T> _handlePlatformError<T>(
    PlatformException error, {
    required OperationType operationType,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) {
    final enrichedContext = <String, dynamic>{
      ...?context,
      'exceptionType': 'PlatformException',
      'platformCode': error.code,
      'platformMessage': error.message,
      'operationType': operationType.name,
      if (deviceAddress != null) 'deviceAddress': deviceAddress,
      if (command != null) 'command': command,
    };

    final errorNumber = int.tryParse(error.code);

    // Route to specific bridge method based on operation type
    switch (operationType) {
      case OperationType.connection:
        return fromConnectionError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          deviceAddress: deviceAddress,
          context: enrichedContext,
        );
      case OperationType.discovery:
        return fromDiscoveryError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          timeout: timeout,
          context: enrichedContext,
        );
      case OperationType.print:
        return fromPrintError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          printData: printData,
          context: enrichedContext,
        );
      case OperationType.status:
        return fromStatusError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          isDetailed: isDetailed,
          context: enrichedContext,
        );
      case OperationType.command:
        return fromCommandError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          command: command,
          context: enrichedContext,
        );
      case OperationType.general:
        return fromError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          context: enrichedContext,
        );
    }
  }

  /// Handle MissingPluginException (development/testing scenarios)
  static Result<T> _handleMissingPluginError<T>(
    MissingPluginException error, {
    required OperationType operationType,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) {
    final enrichedContext = <String, dynamic>{
      ...?context,
      'exceptionType': 'MissingPluginException',
      'missingPluginMessage': error.message,
      'operationType': operationType.name,
    };

    return _createFailureResult<T>(
      ErrorCodes.notImplemented,
      error,
      errorNumber: null,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }

  /// Handle FormatException (data format issues)
  static Result<T> _handleFormatError<T>(
    FormatException error, {
    required OperationType operationType,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) {
    final enrichedContext = <String, dynamic>{
      ...?context,
      'exceptionType': 'FormatException',
      'formatMessage': error.message,
      'source': error.source,
      'offset': error.offset,
      'operationType': operationType.name,
    };

    return _createFailureResult<T>(
      ErrorCodes.invalidFormat,
      error,
      errorNumber: null,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }

  /// Handle ArgumentError (invalid arguments)
  static Result<T> _handleArgumentError<T>(
    ArgumentError error, {
    required OperationType operationType,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) {
    final enrichedContext = <String, dynamic>{
      ...?context,
      'exceptionType': 'ArgumentError',
      'argumentName': error.name,
      'argumentMessage': error.message,
      'invalidValue': error.invalidValue,
      'operationType': operationType.name,
    };

    return _createFailureResult<T>(
      ErrorCodes.invalidArgument,
      error,
      errorNumber: null,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }

  /// Handle StateError (invalid state operations)
  static Result<T> _handleStateError<T>(
    StateError error, {
    required OperationType operationType,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) {
    final enrichedContext = <String, dynamic>{
      ...?context,
      'exceptionType': 'StateError',
      'stateMessage': error.message,
      'operationType': operationType.name,
    };

    // Choose appropriate error code based on operation type
    final ErrorCode stateErrorCode;
    switch (operationType) {
      case OperationType.connection:
        stateErrorCode = ErrorCodes.connectionError;
        break;
      case OperationType.print:
        stateErrorCode = ErrorCodes.printerNotReady;
        break;
      case OperationType.discovery:
        stateErrorCode = ErrorCodes.discoveryError;
        break;
      case OperationType.status:
      case OperationType.command:
      case OperationType.general:
        stateErrorCode = ErrorCodes.operationError;
        break;
    }

    return _createFailureResult<T>(
      stateErrorCode,
      error,
      errorNumber: null,
      stackTrace: stackTrace,
      context: enrichedContext,
    );
  }

  /// Handle operation errors by routing to appropriate bridge method (fallback)
  static Result<T> _handleOperationError<T>(
    dynamic error, {
    required OperationType operationType,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) {
    final enrichedContext = <String, dynamic>{
      ...?context,
      'exceptionType': error.runtimeType.toString(),
      'operationType': operationType.name,
    };

    // Extract error number if available (legacy support)
    int? errorNumber;
    if (error is PlatformException) {
      errorNumber = int.tryParse(error.code);
    }

    // Route to appropriate bridge method based on operation type
    switch (operationType) {
      case OperationType.connection:
        return fromConnectionError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          deviceAddress: deviceAddress,
          context: enrichedContext,
        );

      case OperationType.discovery:
        return fromDiscoveryError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          timeout: timeout,
          context: enrichedContext,
        );

      case OperationType.print:
        return fromPrintError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          printData: printData,
          context: enrichedContext,
        );

      case OperationType.status:
        return fromStatusError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          isDetailed: isDetailed,
          context: enrichedContext,
        );

      case OperationType.command:
        return fromCommandError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          command: command,
          context: enrichedContext,
        );

      case OperationType.general:
        return fromError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          context: enrichedContext,
        );
    }
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

/// Operation type enumeration for executeAndHandle routing
enum OperationType {
  connection,
  discovery,
  print,
  status,
  command,
  general,
}
