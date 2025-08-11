import 'dart:async';
import 'package:flutter/services.dart';

import '../models/result.dart';
import 'native_models/enriched_native_error.dart';

/// Central error factory bridge for converting all error types to structured Result objects
/// 
/// This class serves as the central factory for all error handling in the Zebra Printer Utility.
/// **NO Result.errorCode calls should exist outside of this class** - all errors must go through
/// this bridge to ensure consistent error handling and proper error classification.
/// 
/// **Error Sources Handled:**
/// 1. Native layer errors (EnrichedNativeError from iOS/Android)
/// 2. Method channel infrastructure errors (PlatformException, MissingPluginException)
/// 3. Dart operation errors (TimeoutException, FormatException, etc.)
/// 4. Operation manager errors (both EnrichedNativeError and string errors)
/// 
/// **Usage:**
/// ```dart
/// // Handle native errors
/// final result = ZebraErrorBridge.fromEnrichedNativeError(enrichedError);
/// 
/// // Handle Dart exceptions
/// final result = ZebraErrorBridge.fromDartError(exception);
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

  /// Centralized helper to determine if an error indicates connection loss/failure
  /// This method provides a single source of truth for connection error detection
  /// across the entire codebase.
  static bool isConnectionRelatedError(Result result) {
    if (result.success) return false;

    final error = result.error;
    if (error == null) return false;

    // Check error codes - definitive connection-related errors
    final connectionErrorCodes = [
      ErrorCodes.connectionError,
      ErrorCodes.connectionTimeout,
      ErrorCodes.connectionLost,
      ErrorCodes.notConnected,
      ErrorCodes.zebraNoConnection,
      ErrorCodes.connectionRetryFailed,
      ErrorCodes.statusConnectionError,
      ErrorCodes.connectionFailed,
      ErrorCodes.connectionUnknownError,
      ErrorCodes.connectionSpecificTimeout,
      ErrorCodes.zebraWriteFailure,
      ErrorCodes.zebraReadFailure,
    ];

    if (connectionErrorCodes.contains(error.originalErrorCode)) {
      return true;
    }

    // Check error message patterns as fallback
    final message = error.message.toLowerCase();
    return message.contains('connection') ||
        message.contains('disconnect') ||
        message.contains('timeout') ||
        message.contains('not connected') ||
        message.contains('network') ||
        message.contains('bluetooth') ||
        message.contains('wifi') ||
        message.contains('socket') ||
        message.contains('communication') ||
        message.contains('unable to create a connection') ||
        message.contains('write to a connection failed') ||
        message.contains('read from a connection failed');
  }

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

  /// Bridge method: Convert EnrichedNativeError to Result.failure()
  /// This is the primary method for handling ALL native layer errors
  static Result<T> fromEnrichedNativeError<T>(
    EnrichedNativeError error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalContext,
  }) {
    // Determine operation type from context or error code
    final operationType = _determineOperationTypeFromError(error);

    // Choose appropriate error code based on operation type and error data
    final errorCode = _classifyEnrichedError(error, operationType);

    return Result.errorCode(
      errorCode,
      formatArgs: _extractFormatArgsFromEnrichedError(error),
      errorNumber: error.nativeErrorCode,
      nativeError: error.nativeError,
      dartStackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// Bridge method: Convert Dart exceptions to Result.failure()
  /// This method handles Dart exceptions (not native errors)
  static Result<T> fromDartError<T>(
    dynamic error, {
    required StackTrace stackTrace,
    int? errorNumber,
    Map<String, dynamic>? context,
  }) {
    final errorCode = _classifyDartError(error);
    return _createFailureResult<T>(
      errorCode,
      error,
      errorNumber: errorNumber,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Bridge method: Convert an inner Result into a new Result with different error classification
  /// This method wraps an existing Result (success or failure) into a new Result with a new ErrorCode
  /// while preserving the inner Result in error.innerResult for context
  static Result<T> fromInnerResult<T>(
    Result innerResult,
    ErrorCode newErrorCode, {
    List<Object>? formatArgs,
    Map<String, dynamic>? context,
  }) {
    return Result.errorCode(
      newErrorCode,
      formatArgs: formatArgs,
      dartStackTrace: StackTrace.current,
      innerResult: innerResult,
    );
  }

  /// Bridge method: Convert ZSDK connection operation failure to Result.failure()
  /// This method provides connection-specific context enrichment
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
  /// This method provides print-specific context enrichment
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
  /// This method provides status-specific context enrichment
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
  /// This method provides discovery-specific context enrichment
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
  /// This method provides command-specific context enrichment
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

  /// Execute an operation that already returns Result<T> and ensure no exceptions leak
  /// This method handles operations that return Result<T> and provides additional
  /// error context enrichment if the result indicates failure
  ///
  /// Example usage:
  /// ```dart
  /// final result = await ZebraErrorBridge.executeAndHandleResult<String>(
  ///   operation: () => operationManager.execute(...),
  ///   operationType: OperationType.command,
  ///   context: {'setting': 'device.language'},
  /// );
  /// ```
  static Future<Result<T>> executeAndHandleResult<T>({
    required Future<Result<T>> Function() operation,
    required OperationType operationType,
    Map<String, dynamic>? context,
    String? deviceAddress,
    String? command,
    String? printData,
    bool isDetailed = false,
    Duration? timeout,
  }) async {
    try {
      final result = await operation();

      // If the result is successful, return it as-is
      if (result.success) {
        return result;
      }

      // For failed results, we can optionally enrich with additional context
      // but preserve the original error information
      return result;
    } catch (error, stackTrace) {
      // This should rarely happen since operations should return Result<T>
      // but we handle it as a safety net
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

  // ===== PRIVATE IMPLEMENTATION METHODS =====

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
        return fromDartError<T>(
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
        return fromDartError<T>(
          error,
          errorNumber: errorNumber,
          stackTrace: stackTrace,
          context: enrichedContext,
        );
    }
  }

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

  /// Classify Dart exceptions using documented error codes
  static ErrorCode _classifyDartError(dynamic error) {
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

  /// Determine operation type from enriched error context
  static OperationType _determineOperationTypeFromError(
      EnrichedNativeError error) {
    // Check context first for explicit operation type
    if (error.context != null) {
      final operationType = error.context!['operationType'] as String?;
      if (operationType != null) {
        switch (operationType.toLowerCase()) {
          case 'connection':
            return OperationType.connection;
          case 'print':
            return OperationType.print;
          case 'status':
            return OperationType.status;
          case 'command':
            return OperationType.command;
          case 'discovery':
            return OperationType.discovery;
          case 'general':
            return OperationType.general;
        }
      }
    }

    // Infer from error code
    final code = error.code.toLowerCase();
    if (code.contains('connection') || code.contains('connect')) {
      return OperationType.connection;
    } else if (code.contains('print')) {
      return OperationType.print;
    } else if (code.contains('status')) {
      return OperationType.status;
    } else if (code.contains('discovery')) {
      return OperationType.discovery;
    } else if (code.contains('command') || code.contains('setting')) {
      return OperationType.command;
    }

    return OperationType.general;
  }

  /// Classify enriched error based on operation type and error data
  static ErrorCode _classifyEnrichedError(
      EnrichedNativeError error, OperationType operationType) {
    // Check for documented ZSDK error codes first
    if (error.nativeError != null) {
      final sdkError =
          _findErrorInMappings(error.nativeError!, _zebraSDKErrorMappings);
      if (sdkError != null) return sdkError;
    }

    // Check error message for patterns
    final message = error.message.toLowerCase();
    final sdkError = _findErrorInMappings(message, _zebraSDKErrorMappings);
    if (sdkError != null) return sdkError;

    // Choose error code based on operation type
    switch (operationType) {
      case OperationType.connection:
        if (message.contains('timeout')) {
          return ErrorCodes.connectionTimeout;
        } else if (message.contains('permission')) {
          return ErrorCodes.noPermission;
        } else if (message.contains('not found') ||
            message.contains('unavailable')) {
          return ErrorCodes.invalidDeviceAddress;
        }
        return ErrorCodes.connectionError;

      case OperationType.print:
        if (message.contains('timeout')) {
          return ErrorCodes.printTimeout;
        }
        return ErrorCodes.printError;

      case OperationType.status:
        if (message.contains('timeout')) {
          return ErrorCodes.statusTimeoutError;
        } else if (message.contains('connection')) {
          return ErrorCodes.statusConnectionError;
        }
        return ErrorCodes.basicStatusCheckFailed;

      case OperationType.discovery:
        if (message.contains('timeout')) {
          return ErrorCodes.discoveryTimeout;
        }
        return ErrorCodes.discoveryError;

      case OperationType.command:
        if (message.contains('timeout')) {
          return ErrorCodes.commandSpecificTimeout;
        }
        return ErrorCodes.commandError;

      case OperationType.general:
        if (message.contains('timeout')) {
          return ErrorCodes.operationTimeout;
        }
        return ErrorCodes.operationError;
    }
  }

  /// Extract format arguments from enriched error for message formatting
  static List<Object>? _extractFormatArgsFromEnrichedError(
      EnrichedNativeError error) {
    final args = <Object>[];

    // Extract common format arguments from context
    if (error.context != null) {
      if (error.context!['deviceAddress'] != null) {
        args.add(error.context!['deviceAddress']);
      }
      if (error.context!['timeoutSeconds'] != null) {
        args.add(error.context!['timeoutSeconds']);
      }
      if (error.context!['printDataLength'] != null) {
        args.add(error.context!['printDataLength']);
      }
      if (error.context!['command'] != null) {
        args.add(error.context!['command']);
      }
    }

    return args.isEmpty ? null : args;
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
