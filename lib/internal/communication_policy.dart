import 'dart:async';

import '../../models/communication_policy_event.dart';
import '../../models/communication_policy_options.dart';
import '../../models/result.dart';
import '../../zebra_printer.dart';
import '../../zebra_printer_manager.dart';
import 'logger.dart';
import 'policies/policies.dart' as policies;
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
  static const Duration _operationTimeout = Duration(seconds: 7);
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
    
    // Step 2: Use policy system for timeout handling
    _logger.debug('Executing $operationName with policy system');
    onStatusUpdate?.call('Executing $operationName...');
    
    final effectiveTimeout = timeout ?? _operationTimeout;
    final timeoutPolicy = policies.TimeoutPolicy.of(effectiveTimeout);
    
    try {
      final result = await timeoutPolicy.execute<T>(
        () async {
          final operationResult = await operation();

          if (operationResult.success) {
            _logger.info('$operationName completed successfully');
            onStatusUpdate?.call('$operationName completed');
            return operationResult.data as T;
          }
          
          // Step 3: React to failures - check if it's connection-related
          final errorMessage = operationResult.error!.message.toLowerCase();
          if (errorMessage.contains('connection') ||
              errorMessage.contains('timeout') ||
              errorMessage.contains('network') ||
              errorMessage.contains('bluetooth')) {
            _logger.warning(
                'Connection error detected in $operationName: ${operationResult.error?.message}');
            onStatusUpdate?.call('Connection error - attempting recovery...');
            // Step 4: Handle connection failure and retry
            final retryResult = await _handleConnectionFailureAndRetry(
                operation, operationName);
            if (retryResult.success) {
              return retryResult.data as T;
            } else {
              throw Exception(retryResult.error ?? 'Retry failed');
            }
          }

          // Non-connection error, throw exception
          _logger.debug(
              'Non-connection error in $operationName: ${operationResult.error?.message}');
          onStatusUpdate?.call(
              '$operationName failed: ${operationResult.error?.message}');
          throw Exception(operationResult.error ?? 'Operation failed');
        },
        operationName: operationName,
      );

      // Convert T back to Result<T>
      return Result.success(result);
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
    _logger.info('[$operationName] Using policy system for retry logic');
    _logger.debug(
        '[$operationName] Retry configuration: maxAttempts=$maxAttempts, timeout=${timeout?.inSeconds}s, retryDelay=${_retryDelay.inMilliseconds}ms');

    // Create policy wrapper with timeout and retry
    final policy = policies.PolicyWrapper.withTimeoutAndRetryWithDelay(
      timeout ?? _operationTimeout,
      maxAttempts,
      _retryDelay,
    );

    // Emit initial attempt event
    onEvent?.call(CommunicationPolicyEvent(
      type: CommunicationPolicyEventType.attempt,
      attempt: 1,
      maxAttempts: maxAttempts,
      message: 'Starting $operationName with policy system',
    ));

    try {
      // Use policy system for the entire retry logic
      final result = await policy.execute<T>(
        () async {
          _logger.debug('[$operationName] Executing operation attempt');

          // Execute the operation with connection check if needed
          final operationResult = await _executeOperation(
            operation,
            operationName,
            skipConnectionCheck: skipConnectionCheck,
            timeout: timeout,
          );
          
          // Convert Result<T> to T or throw exception
          if (operationResult.success) {
            _logger.debug('[$operationName] Operation succeeded');
            return operationResult.data as T;
          } else {
            _logger.debug(
                '[$operationName] Operation failed: ${operationResult.error?.message}');
            throw Exception(operationResult.error ?? 'Operation failed');
          }
        },
        operationName: operationName,
        cancellationToken: cancellationToken,
      );

      // Emit success event
      onEvent?.call(CommunicationPolicyEvent(
        type: CommunicationPolicyEventType.success,
        attempt: 1,
        maxAttempts: maxAttempts,
        message: '$operationName succeeded',
      ));
      
      // Convert T back to Result<T>
      return Result.success(result);
    } catch (e) {
      _logger.error('[$operationName] Policy execution failed: $e');
      _logger.debug(
          '[$operationName] This failure may trigger retry attempts by the policy system');
      
      onEvent?.call(CommunicationPolicyEvent(
        type: CommunicationPolicyEventType.failed,
        attempt: maxAttempts,
        maxAttempts: maxAttempts,
        message: '$operationName failed with exception: $e',
        error: e,
      ));
      return ZebraErrorBridge.fromError<T>(e, stackTrace: StackTrace.current);
    }
  }
  
  /// Check if connection check is needed based on timeout
  bool _shouldCheckConnection() {
    if (_lastConnectionCheck == null) {
      _logger.debug('Connection check needed: never checked before');
      return true; // Never checked before
    }
    
    final timeSinceLastCheck = DateTime.now().difference(_lastConnectionCheck!);
    final shouldCheck = timeSinceLastCheck > _connectionCheckTimeout;

    if (shouldCheck) {
      _logger.debug(
          'Connection check needed: ${timeSinceLastCheck.inMinutes} minutes since last check (timeout: ${_connectionCheckTimeout.inMinutes} minutes)');
    } else {
      _logger.debug(
          'Connection check skipped: ${timeSinceLastCheck.inMinutes} minutes since last check (timeout: ${_connectionCheckTimeout.inMinutes} minutes)');
    }

    return shouldCheck;
  }
  
  /// Check connection with timeout and retry logic
  Future<Result<bool>> _checkConnection() async {
    _lastConnectionCheck = DateTime.now();
    
    _logger.debug(
        'Starting connection check (triggered by policy timeout or explicit call)');
    
    // Use policy system for connection check with timeout and retry
    final policy = policies.PolicyWrapper.withTimeoutAndRetryWithDelay(
      const Duration(seconds: 7),
      _maxRetries + 1,
      _retryDelay,
    );

    try {
      await policy.execute<bool>(
        () async {
          final connectionResult = await _printer.isPrinterConnected();
          if (connectionResult.success && (connectionResult.data ?? false)) {
            return true;
          } else {
            throw Exception(
                connectionResult.error?.message ?? 'Connection check failed');
          }
        },
        operationName: 'Connection Check',
        cancellationToken: null, // Connection check doesn't need cancellation
      );
      
      _logger.info('Connection verified successfully');
      return Result.success(true);
    } catch (e) {
      _logger.error('Connection check error: $e');

      // Check error type for better error handling
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission')) {
        _logger.error('Permission error during connection check');
        return ZebraErrorBridge.fromConnectionError<bool>(
          e,
          stackTrace: StackTrace.current,
        );
      }
      
      return ZebraErrorBridge.fromConnectionError<bool>(
        e,
        stackTrace: StackTrace.current,
      );
    }
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
      // For operations that already have native timeouts, don't add another timeout
      final retryResult = await operation();
      
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
