import 'dart:async';

import '../../models/communication_policy_event.dart';
import '../../models/communication_policy_options.dart';
import '../../models/result.dart';
import '../../zebra_printer.dart';
import '../../zebra_printer_manager.dart';
import 'logger.dart';
import 'zebra_error_bridge.dart';

/// Centralized communication policy for printer operations with optimistic execution
/// 
/// This class provides an integrated command execution workflow that:
/// - Uses optimistic execution (run first, react to failures)
/// - Performs preemptive connection checks only when needed (5+ minute timeout)
/// - Handles connection failures and reconnection automatically
/// - Provides real-time status updates through callbacks
/// 
/// **Usage:**
/// ```dart
/// final policy = CommunicationPolicy(printer, onStatusUpdate: (status) {
///   print('Status: $status');
/// });
/// 
/// // Execute command with integrated connection management
/// final result = await policy.executeCommand(command);
/// 
/// // Or execute custom operation
/// final result = await policy.executeOperation(
///   () => printer.print(data: 'test'),
///   'Print Operation'
/// );
/// ```
class CommunicationPolicy {
  /// Constructor
  CommunicationPolicy(this._printer, {this.onStatusUpdate});
  
  /// The printer instance to manage
  final ZebraPrinter _printer;
  
  /// Logger for this policy
  final Logger _logger = Logger.withPrefix('CommunicationPolicy');
  
  /// Status update callback for real-time updates
  final void Function(String status)? onStatusUpdate;
  
  /// Execution state tracking to prevent policy nesting
  bool _isExecuting = false;
  
  /// Connection timeout settings
  static const Duration _connectionCheckTimeout = Duration(minutes: 5);
  static const Duration _operationTimeout = Duration(seconds: 10);
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const int _maxRetries = 2;
  
  /// Last connection check timestamp
  DateTime? _lastConnectionCheck;
  
  /// Unified public execute method for all command execution scenarios
  Future<Result<T>> execute<T>(
    Future<Result<T>> Function() operation,
    String operationName, {
    CommunicationPolicyOptions? options,
  }) async {
    // ✅ NEW: Detect nested execution
    if (_isExecuting) {
      _logger.debug(
          'Policy already executing - using pass-through mode for $operationName');
      try {
        return await operation(); // Simple execution, no retry logic
      } catch (e, stack) {
        return ZebraErrorBridge.fromError<T>(e, stackTrace: stack);
      }
    }

    // ✅ NEW: Mark as executing
    _isExecuting = true;
    try {
    // Define the default options
    const defaultOptions = CommunicationPolicyOptions(
      skipConnectionCheck: false,
      skipConnectionRetry: false,
      maxAttempts: 3,
      timeout: null, // Will be handled below
      onEvent: null,
    );
    // Merge user options with defaults
    final effectiveOptions = defaultOptions.mergeWith(options);
    final finalTimeout = effectiveOptions.timeout ?? _operationTimeout;

    if (effectiveOptions.skipConnectionRetry == true) {
      // Single attempt, with or without connection check
      return await _executeOperation(
        operation,
        operationName,
        skipConnectionCheck: effectiveOptions.skipConnectionCheck ?? false,
        timeout: finalTimeout,
      );
    } else {
      // Full retry logic, event callbacks, and timeout
      return await _executeWithRetry(
        operation,
        operationName,
        maxAttempts: effectiveOptions.maxAttempts ?? 3,
        timeout: finalTimeout,
        skipConnectionCheck: effectiveOptions.skipConnectionCheck ?? false,
        onEvent: effectiveOptions.onEvent,
          cancellationToken: effectiveOptions.cancellationToken,
      );
    }
    } finally {
      _isExecuting = false;
    }
  }

  // Privatized old methods for internal use only
  Future<Result<T>> _executeOperation<T>(
    Future<Result<T>> Function() operation,
    String operationName, {
    bool skipConnectionCheck = false,
    Duration? timeout,
  }) async {
    _logger.info('Executing $operationName with optimistic workflow');
    onStatusUpdate?.call('Starting $operationName...');
    final opTimeout = timeout ?? _operationTimeout;
    // Step 1: Preemptive connection check (only if needed)
    final shouldCheckConnection = !skipConnectionCheck && _shouldCheckConnection();
    if (shouldCheckConnection) {
      _logger.debug('Performing preemptive connection check');
      onStatusUpdate?.call('Checking connection...');
      final connectionResult = await _checkConnection();
      if (!connectionResult.success) {
        _logger.warning('Preemptive connection check failed: ${connectionResult.error?.message}');
        onStatusUpdate?.call('Connection check failed');
        return Result.errorFromResult(
            connectionResult, 'Connection check failed');
      }
    }
    // Step 2: Optimistic execution (run first, react to failures)
    _logger.debug('Executing $operationName optimistically');
    onStatusUpdate?.call('Executing $operationName...');
    try {
      final result = await operation().timeout(opTimeout);
      if (result.success) {
        _logger.info('$operationName completed successfully');
        onStatusUpdate?.call('$operationName completed');
        return result;
      }
      // Step 3: React to failures - check if it's connection-related
      final errorMessage = result.error!.message.toLowerCase();
      if (errorMessage.contains('connection') ||
          errorMessage.contains('timeout') ||
          errorMessage.contains('network') ||
          errorMessage.contains('bluetooth')) {
        _logger.warning('Connection error detected in $operationName: ${result.error?.message}');
        onStatusUpdate?.call('Connection error - attempting recovery...');
        // Step 4: Handle connection failure and retry
        return await _handleConnectionFailureAndRetry(operation, operationName);
      }
      // Non-connection error, return immediately
      _logger.debug('Non-connection error in $operationName: ${result.error?.message}');
      onStatusUpdate?.call('$operationName failed: ${result.error?.message}');
      return result;
    } catch (e) {
      _logger.error('Unexpected error in $operationName: $e');
      onStatusUpdate?.call('Unexpected error: $e');
      
      // Use centralized error bridge for better error handling
      return ZebraErrorBridge.fromError<T>(e);
    }
  }

  Future<Result<T>> _executeWithRetry<T>(
    Future<Result<T>> Function() operation,
    String operationName, {
    int maxAttempts = 3,
    Duration? timeout,
    bool skipConnectionCheck = false,
    void Function(CommunicationPolicyEvent event)? onEvent,
    CancellationToken? cancellationToken,
  }) async {
    int attempt = 1;
    final opTimeout = timeout ?? _operationTimeout;
    while (attempt <= maxAttempts) {
      // Check for cancellation before each attempt
      if (cancellationToken?.isCancelled == true) {
        _logger.info(
            '[$operationName] Operation cancelled before attempt $attempt');
        onEvent?.call(CommunicationPolicyEvent(
          type: CommunicationPolicyEventType.failed,
          attempt: attempt,
          maxAttempts: maxAttempts,
          message: '$operationName cancelled by token',
        ));
        return ZebraErrorBridge.fromError<T>(
          Exception('$operationName cancelled'),
          stackTrace: StackTrace.current,
        );
      }

      onEvent?.call(CommunicationPolicyEvent(
        type: CommunicationPolicyEventType.attempt,
        attempt: attempt,
        maxAttempts: maxAttempts,
        message: 'Attempt $attempt/$maxAttempts for $operationName',
      ));
      _logger.info('[$operationName] Attempt $attempt/$maxAttempts');
      try {
        final result = await _executeOperation(
          operation,
          operationName,
          skipConnectionCheck: skipConnectionCheck,
          timeout: opTimeout,
        );
        if (result.success) {
          onEvent?.call(CommunicationPolicyEvent(
            type: CommunicationPolicyEventType.success,
            attempt: attempt,
            maxAttempts: maxAttempts,
            message: '$operationName succeeded on attempt $attempt',
          ));
          return result;
        } else {
          onEvent?.call(CommunicationPolicyEvent(
            type: CommunicationPolicyEventType.error,
            attempt: attempt,
            maxAttempts: maxAttempts,
            message: '$operationName failed: ${result.error?.message}',
            error: result.error,
          ));
          
          // Use type-safe Result properties to determine if we should abort early
          if (result.isPermissionError) {
            _logger.warning(
                'Permission error detected - aborting retries for $operationName');
            onEvent?.call(CommunicationPolicyEvent(
              type: CommunicationPolicyEventType.failed,
              attempt: attempt,
              maxAttempts: maxAttempts,
              message: '$operationName aborted due to permission error',
              error: result.error,
            ));
            return result; // Don't re-bridge, preserve original ZebraPrinter error
          } else if (result.isHardwareError) {
            _logger.warning(
                'Hardware error detected - aborting retries for $operationName');
            onEvent?.call(CommunicationPolicyEvent(
              type: CommunicationPolicyEventType.failed,
              attempt: attempt,
              maxAttempts: maxAttempts,
              message: '$operationName aborted due to hardware error',
              error: result.error,
            ));
            return result; // Don't re-bridge, preserve original ZebraPrinter error
          }
        }
      } catch (e) {
        onEvent?.call(CommunicationPolicyEvent(
          type: CommunicationPolicyEventType.error,
          attempt: attempt,
          maxAttempts: maxAttempts,
          message: '$operationName threw: $e',
          error: e,
        ));
        _logger.error('[$operationName] Error on attempt $attempt: $e');
      }
      
      if (attempt < maxAttempts) {
        // Check for cancellation before retry delay
        if (cancellationToken?.isCancelled == true) {
          _logger
              .info('[$operationName] Operation cancelled during retry delay');
          onEvent?.call(CommunicationPolicyEvent(
            type: CommunicationPolicyEventType.failed,
            attempt: attempt,
            maxAttempts: maxAttempts,
            message: '$operationName cancelled during retry',
          ));
          return ZebraErrorBridge.fromError<T>(
            Exception('$operationName cancelled during retry'),
            stackTrace: StackTrace.current,
          );
        }

        onEvent?.call(CommunicationPolicyEvent(
          type: CommunicationPolicyEventType.retry,
          attempt: attempt,
          maxAttempts: maxAttempts,
          message: 'Retrying $operationName after failure',
        ));
        await Future.delayed(_retryDelay * attempt);
      }
      attempt++;
    }
    onEvent?.call(CommunicationPolicyEvent(
      type: CommunicationPolicyEventType.failed,
      attempt: maxAttempts,
      maxAttempts: maxAttempts,
      message: '$operationName failed after $maxAttempts attempts',
    ));
    // Use bridge for final failure with context about what types of errors were encountered
    return ZebraErrorBridge.fromError<T>(
      Exception('$operationName failed after $maxAttempts attempts'),
      stackTrace: StackTrace.current,
    );
  }
  
  /// Check if connection check is needed based on timeout
  bool _shouldCheckConnection() {
    if (_lastConnectionCheck == null) {
      return true; // Never checked before
    }
    
    final timeSinceLastCheck = DateTime.now().difference(_lastConnectionCheck!);
    return timeSinceLastCheck > _connectionCheckTimeout;
  }
  
  /// Check connection with timeout and retry logic
  Future<Result<bool>> _checkConnection() async {
    _lastConnectionCheck = DateTime.now();
    
    int attempts = 0;
    while (attempts <= _maxRetries) {
      attempts++;
      _logger.debug('Connection check attempt $attempts/${_maxRetries + 1}');
      
      try {
        final connectionResult =
            await _printer.isPrinterConnected().timeout(_operationTimeout);
        
        if (connectionResult.success && (connectionResult.data ?? false)) {
          _logger.info('Connection verified successfully');
          return Result.success(true);
        }
        
        _logger.warning(
            'Connection check failed on attempt $attempts: ${connectionResult.error?.message}');
        if (attempts > _maxRetries) {
          return Result.errorFromResult(connectionResult,
              'Connection check failed after $_maxRetries attempts');
        }
        
        await Future.delayed(_retryDelay * attempts);
        
      } catch (e) {
        _logger.error('Connection check error on attempt $attempts: $e');
        
        // Check error type for better error handling
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('timeout')) {
          _logger.warning('Connection check timed out on attempt $attempts');
        } else if (errorMessage.contains('permission')) {
          _logger.error(
              'Permission error during connection check - aborting retries');
          return ZebraErrorBridge.fromConnectionError<bool>(
            e,
            stackTrace: StackTrace.current,
          );
        }
        
        if (attempts > _maxRetries) {
          return ZebraErrorBridge.fromConnectionError<bool>(
            e,
            stackTrace: StackTrace.current,
          );
        }
        await Future.delayed(_retryDelay * attempts);
      }
    }
    
    return ZebraErrorBridge.fromConnectionError<bool>(
      Exception('Unexpected: exceeded maximum connection attempts'),
      stackTrace: StackTrace.current,
    );
  }
  
  /// Handle connection failure and retry the operation
  Future<Result<T>> _handleConnectionFailureAndRetry<T>(
    Future<Result<T>> Function() operation,
    String operationName,
  ) async {
    _logger.info('Handling connection failure for $operationName');
    onStatusUpdate?.call('Connection lost - attempting reconnection...');
    
    // Attempt reconnection
    final reconnectResult = await _attemptReconnection();
    
    if (!reconnectResult.success) {
      _logger.error('Failed to reconnect: ${reconnectResult.error?.message}');
      onStatusUpdate?.call('Reconnection failed');
      return Result.errorFromResult(reconnectResult, 'Failed to reconnect');
    }
    
    _logger.info('Successfully reconnected, retrying $operationName');
    onStatusUpdate?.call('Reconnected - retrying $operationName...');
    
    // Retry the operation
    try {
      final retryResult = await operation().timeout(_operationTimeout);
      
      if (retryResult.success) {
        _logger.info('$operationName completed successfully after reconnection');
        onStatusUpdate?.call('$operationName completed after reconnection');
        return retryResult;
      } else {
        _logger.error('$operationName failed after reconnection: ${retryResult.error?.message}');
        onStatusUpdate?.call('$operationName failed after reconnection');
        return retryResult;
      }
    } catch (e) {
      _logger.error('Unexpected error in $operationName retry: $e');
      onStatusUpdate?.call('Unexpected error during retry: $e');
      
      // Use centralized error bridge for better error handling
      return ZebraErrorBridge.fromError<T>(e);
    }
  }
  
  /// Attempt to reconnect to the printer
  Future<Result<bool>> _attemptReconnection() async {
    try {
      // First check if connection is actually lost
      final connectionResult = await _checkConnection();
      if (connectionResult.success) {
        return Result.success(true);
      }
      
      // Try to force reconnection
      _logger.info('Attempting to reconnect to printer');
      try {
        // Call disconnect to clean up any stale connections
        await _printer.disconnect();
      } catch (e) {
        _logger.debug('Disconnect during reconnection attempt: $e');
        // Ignore disconnect errors as connection may already be lost
      }

      // Wait a moment before reconnecting
      await Future.delayed(const Duration(milliseconds: 500));

      // Attempt to reconnect - Since ZebraPrinter manages its own connection
      // we'll just check if it can re-establish connection
      try {
        // Get the currently selected address from the printer controller
        final selectedAddress = _printer.controller.selectedAddress;
        if (selectedAddress == null) {
          _logger.warning('No printer address available for reconnection');
          return Result.error('No printer address available for reconnection');
        }

        // Attempt to reconnect to the same printer
        final reconnectResult =
            await _printer.connectToPrinter(selectedAddress);

        if (reconnectResult.success) {
          _logger.info('Successfully reconnected to printer');
          return Result.success(true);
        } else {
          _logger.warning(
              'Reconnection failed: ${reconnectResult.error?.message}');
          return Result.success(false);
        }
      } catch (e) {
        _logger.error('Failed to reconnect: $e');
        return Result.error('Failed to reconnect: $e');
      }
    } catch (e) {
      _logger.error('Reconnection error: $e');
      return Result.error('Reconnection error: $e');
    }
  }
  
  /// Get connection status (for external use)
  Future<Result<bool>> getConnectionStatus() async {
    return await _checkConnection();
  }
  
  /// Force a fresh connection check (for external use)
  void forceConnectionCheck() {
    _lastConnectionCheck = null;
    _logger.debug('Connection check forced - will check on next operation');
  }
  
  /// Get policy statistics for debugging
  Map<String, dynamic> getPolicyStats() {
    return {
      'lastConnectionCheck': _lastConnectionCheck?.toIso8601String(),
      'connectionCheckTimeout': _connectionCheckTimeout.inMinutes,
      'operationTimeout': _operationTimeout.inSeconds,
      'retryDelay': _retryDelay.inMilliseconds,
      'maxRetries': _maxRetries,
    };
  }
} 
