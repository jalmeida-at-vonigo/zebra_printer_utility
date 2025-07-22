# Polly-like Policy System for Dart

This directory contains a policy-based timeout and retry system inspired by .NET's Polly library. The system provides configurable timeout and retry policies that can be combined to create robust operation handling.

## Overview

The policy system consists of three main components:

1. **TimeoutPolicy** - Handles operation timeouts
2. **RetryPolicy** - Handles operation retries with configurable backoff
3. **PolicyWrapper** - Combines multiple policies together

## Usage Examples

### Simple Timeout Policy

```dart
import 'package:zebrautil/internal/policies/timeout_policy.dart';

final policy = TimeoutPolicy.of(const Duration(seconds: 7));

try {
  final result = await policy.execute(
    () => someAsyncOperation(),
    operationName: 'My Operation',
  );
  print('Operation completed: $result');
} catch (e) {
  print('Operation timed out: $e');
}
```

### Simple Retry Policy

```dart
import 'package:zebrautil/internal/policies/retry_policy.dart';

final policy = RetryPolicy.of(3); // 3 attempts

final result = await policy.execute(
  () => someAsyncOperation(),
  operationName: 'My Operation',
);

if (result.success) {
  print('Operation succeeded after ${result.attempts} attempts');
} else {
  print('Operation failed: ${result.errorMessage}');
}
```

### Combined Timeout and Retry Policy

```dart
import 'package:zebrautil/internal/policies/policy_wrapper.dart';

final policy = PolicyWrapper.withTimeoutAndRetry(
  const Duration(seconds: 7), // 7 second timeout
  3, // 3 retry attempts
);

try {
  final result = await policy.execute(
    () => someAsyncOperation(),
    operationName: 'My Operation',
  );
  print('Operation completed: $result');
} catch (e) {
  print('Operation failed: $e');
}
```

### Exponential Backoff Retry

```dart
final policy = PolicyWrapper.withTimeoutAndExponentialBackoff(
  const Duration(seconds: 7), // 7 second timeout
  3, // 3 retry attempts
  const Duration(seconds: 1), // 1 second base delay
  backoffMultiplier: 2.0, // Double the delay each retry
  maxDelay: const Duration(seconds: 5), // Max 5 second delay
);
```

## Policy Configuration

### TimeoutPolicy Options

- `timeout` - Duration before operation times out
- `throwOnTimeout` - Whether to throw exception on timeout (default: true)
- `timeoutMessage` - Custom timeout message

### RetryPolicy Options

- `maxAttempts` - Maximum number of retry attempts (default: 3)
- `delay` - Base delay between retries
- `maxDelay` - Maximum delay between retries
- `backoffMultiplier` - Multiplier for exponential backoff (default: 2.0)
- `retryOnTimeout` - Whether to retry on timeout (default: true)
- `retryOnException` - Whether to retry on exceptions (default: true)
- `retryOnExceptionTypes` - Specific exception types to retry on

## Why This Approach is Better

### Before (Using Future.timeout())

```dart
// ❌ WRONG - Creates artificial delays
final result = await someOperation().timeout(Duration(seconds: 7));
```

**Problems:**
- Operations complete immediately but wait for full timeout
- No retry capability
- Difficult to configure
- No proper error handling

### After (Using Policy System)

```dart
// ✅ CORRECT - Proper policy-based approach
final policy = PolicyWrapper.withTimeoutAndRetry(
  const Duration(seconds: 7),
  3,
);

final result = await policy.execute(
  () => someOperation(),
  operationName: 'My Operation',
);
```

**Benefits:**
- Operations complete immediately when ready
- Configurable retry logic
- Proper error handling and logging
- Reusable policies across the codebase
- Easy to test and maintain

## Integration with Zebra Printer Operations

This policy system is designed to replace the current timeout approach in the communication policy:

```dart
// Current approach (to be replaced)
await _printer.isPrinterConnected().timeout(_operationTimeout);

// New approach
final policy = TimeoutPolicy.of(const Duration(seconds: 7));
await policy.execute(
  () => _printer.isPrinterConnected(),
  operationName: 'Connection Check',
);
```

This ensures that operations complete immediately upon native response rather than waiting for artificial timeouts. 