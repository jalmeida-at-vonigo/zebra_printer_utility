### Zebra Printer Utility - Wiring Audit and Action Plan (Dart → iOS)

Date: 2025-08-08
Scope: Validate end-to-end wiring from `lib/ZebraPrinter` through operation manager and callback handler down to iOS native (`ZebraPrinterInstance.swift`) for printing, discovery (stream-based), error handling, and events. Classify findings and list concrete actions.

---

## Executive Summary

- Printing: Correctly wired. Typed operations, status events, and completion callbacks flow end-to-end.
- Discovery: Refactor to per-operation streams is correctly implemented. Multiple concurrent network discovery methods orchestrated at the service level; warnings stream upwards as designed.
- Error Handling: Centralized `ZebraErrorBridge` integration is in place at the primitive level; operation manager returns structured `Result<T>`; native emits enriched error context; mapping is comprehensive.
- Eventing: Operation-scoped events are correctly routed via `operationId`, no cross-talk between concurrent operations. Unsolicited status events (connection status) are received and applied to `ZebraController`.

Overall verdict: Architecture will work as designed. A few consistency and polish items remain (naming, constant usage, and one permission API alignment) that do not block functionality but should be resolved for long-term maintainability and rule compliance.

---

## Findings by Severity
 
### Severe
- None blocking functionality identified.

### High
- ~~iOS permission method naming inconsistency vs constants~~
  - ~~Native exposes `checkPermission` (returns `getBluetoothPermissionStatus_onResult`). Constants define `getBluetoothPermissionStatusMethod = 'getBluetoothPermissionStatus'`.~~
  - ~~Risk: Depending on `PermissionManager` implementation, permission checks may call a different method name and fail at runtime on iOS.~~
  - ~~Evidence: `ZebraPrinterInstance.handle` has case `"checkPermission"`; Dart constants do not include `checkPermission`.~~
  **RESOLVED**: Removed unused channel-based permission method completely.

### Medium
- ~~Method name divergence between constants and invocations~~ **RESOLVED**: All method names now use `MethodChannelConstants` consistently across Dart and Swift.
  - Example: `isPrinterConnected` (Dart + iOS) vs constant `isConnectedMethod = 'isConnected'`.
  - Impact: Not a runtime bug (strings match across layers), but drifts from the “single source of truth” standard and increases maintenance cost.

- Discovery warning event coverage is partial
  - Subnet and directed broadcast emit `discovery_logWarning` per target/range; others (local broadcast, multicast) return errors via onError but do not emit warnings for partial/network failures.
  - Impact: Inconsistent UX in aggregated discovery status when certain methods fail mid-scan.

- Enriched errors return as a single formatted string to Dart operation manager
  - `ZebraPrinterOperationCallbackHandler._handleEnrichedError` builds a single concatenated error string. While the manager returns a structured `Result.errorCode`, the raw fields (e.g., `nativeErrorCode`, `nativeErrorDomain`) are not parsed back into typed error context.
  - Impact: Slightly less granular error analytics in Dart unless the `ZebraErrorBridge` can re-parse the concatenated string.

### Low
- Printer connection lost event not used
  - `MethodChannelConstants.connectionEventLost` exists but is not emitted by native. Only `connection_statusChanged` is sent. Consider signaling explicit loss for better UX.

- ~~Discovery result tracking duplication~~
  - ~~`ZebraPrinter` both tracks `_discoveryResults[operationId]` and also emits via per-operation streams; the tracked list is not exposed. Not harmful, but can be simplified.~~
  **RESOLVED**: Removed unused `_discoveryResults` tracking map completely.

- Minor formatting/consistency
  - `print()` returns `Result.errorCode(ErrorCodes.printError, formatArgs: [message])` where template does not use `{0}`; the arg is ignored.
  - ~~Constants exist for channel methods but several calls use raw string literals. Allowed by rules, but consistency would help.~~ **RESOLVED**: All method calls now use constants.

### Notes
- Timeout handling: `ZebraPrinterOperationManager` uses a timeout policy; discovery streams correctly close after onComplete. Resource cleanup occurs in `finally` and on stop.
- Orchestration: `ZebraPrinterDiscovery` composes multiple discovery streams (Bluetooth + 4 network methods) concurrently, dedupes, and exposes a unified per-service stream. Cancellation and timeout are handled.
- Result architecture: `Result<T>`, `ErrorCodes`, `ZebraErrorBridge` are consistently used for single-response ops. Streaming discovery uses per-operation streams with explicit onWarning callbacks.

---

## Compliance With Project Rules

- Library style (Dart/iOS): Follows layered design. Native is thin; Dart primitives provide typed APIs with `Result<T>` and Streams.
- UX and logging: `ZebraPrinter` uses `Logger.withPrefix`; discovery service emits status messages and real-time updates; status events reflected in `ZebraController`.
- Rules adherence:
  - Async/Streams: Per-operation streams, operationId isolation, proper cleanup. ✔
  - Error/Result centralization: `ZebraErrorBridge` and `ErrorCodes` are used; no thrown exceptions from public API; structured mapping. ✔
  - Native layer standards: Single channel per instance, method-channel only via `ZebraPrinter`, no business logic in native beyond thin wrappers and SDK calls. ✔
  - CommunicationPolicy: Managers should wrap primitives; primitives themselves don’t duplicate policy logic. Current code respects this (policy not in primitives; discovery uses TimeoutPolicy only). ✔

---

## Concrete Actions

### High Priority
1) ~~Align iOS permission method naming~~
   - ~~Option A (preferred): Rename native `checkPermission` handler to `getBluetoothPermissionStatus` and keep callback as-is (`getBluetoothPermissionStatus_onResult`).~~
   - ~~Option B: Update `PermissionManager` on iOS to invoke `checkPermission` instead of `getBluetoothPermissionStatus`.~~
   - ~~Add a unit/integration test to validate the permission flow.~~
   **RESOLVED**: Removed unused channel-based permission method completely.

### Medium Priority
2) ~~Standardize method constant usage~~
   - ~~Replace raw string method names in `ZebraPrinter` invocations with `MethodChannelConstants.*Method` where available (e.g., print, connect, disconnect, discovery methods, stopScan).~~
   - ~~Ensure the constants and Swift `MethodChannelConstants` stay mirrored.~~
   **RESOLVED**: All method names now use `MethodChannelConstants` consistently across Dart and Swift.

3) ~~Expand discovery warning coverage~~
   - ~~Emit `discovery_logWarning` in native for local broadcast and multicast partial failures (mirroring subnet/directBroadcast behavior).~~
   - ~~In Dart, ensure `onWarning` propagates from all discovery primitives.~~
   **RESOLVED**: All discovery primitives now forward onError events as warnings via onWarning callback and status stream.

4) Preserve structured error fields
   - **Current Issue**: The `_handleEnrichedError` method in `ZebraPrinterOperationCallbackHandler` receives rich error data from native (code, nativeError, nativeErrorCode, nativeErrorDomain, context, timestamp, stackTrace) but concatenates everything into a single string message before passing to `manager.failOperation()`.
   - **Impact**: `ZebraErrorBridge` loses the ability to make intelligent decisions based on structured error fields. It must parse the concatenated string to extract error codes, which is fragile and loses context.
   - **Example Scenario**: 
     - Native sends: `{code: "NETWORK_ERROR", nativeError: "Socket timeout", nativeErrorCode: -1001, context: {ip: "192.168.1.100", port: 9100}}`
     - Current: Becomes string `"Network error | Code: NETWORK_ERROR | Native: Socket timeout | Native Code: -1001 | Context: {ip: 192.168.1.100, port: 9100}"`
     - Desired: Pass structured map to `ZebraErrorBridge` which can then check `code` field directly and preserve context for UI
   - **Solution Options**:
     a) Modify `manager.failOperation()` to accept a structured error object/map
     b) Create an `EnrichedError` class to wrap the error data
     c) Pass the entire `arguments` map to `ZebraErrorBridge.fromError()` and let it extract what it needs
   - **Benefits**: Better error categorization, preserved context for debugging, ability to show rich error details in UI

### Low Priority
5) Emit `connection_lost` when appropriate
   - **Current Issue**: The iOS native layer doesn't emit `connection_lost` events when the printer connection is unexpectedly terminated (e.g., printer powered off, Bluetooth out of range, network disconnect).
   - **Impact**: The UI may still show "connected" status even when the printer is no longer reachable, leading to confusing user experience when print operations fail.
   - **Example Scenarios**:
     - User connected to Bluetooth printer, then walks out of range
     - Network printer is powered off while app shows connected status
     - WiFi connection drops during active session
   - **Implementation Details**:
     - iOS: Monitor `printerConnection` state changes and SDK connection callbacks
     - When connection becomes nil or operations fail with connection errors, emit `connection_lost` event once
     - Include last known printer info in the event for UI identification
   - **Dart Side Changes**:
     - Add handler in `ZebraPrinterOperationCallbackHandler` for `connection_lost` event
     - Update `ZebraController` to mark printer status as disconnected
     - Trigger UI update to show red/disconnected status
   - **Testing**: Simulate connection loss scenarios (airplane mode, printer power off, Bluetooth disable)

6) ~~Simplify discovery result tracking in `ZebraPrinter`~~
   - ~~Remove `_discoveryResults` map unless needed for future aggregation. Rely on per-operation streams only.~~
   **RESOLVED**: Removed unused `_discoveryResults` tracking map and all related assignments/cleanup calls.

7) Minor consistency fixes
   - **formatArgs Issue**:
     - **Current**: In `ZebraPrinter.print()`, error returns use `Result.errorCode(ErrorCodes.printError, formatArgs: [message])` but the error template doesn't have `{0}` placeholder
     - **Impact**: The error message passed is ignored, users don't see the actual failure reason
     - **Fix Options**: 
       a) Update `ErrorCodes.printError` template to include `{0}` placeholder for the message
       b) Remove the unused formatArgs parameter
       c) Use a different error code that accepts formatted messages
   - **Operation ID Isolation Test**:
     - **Need**: Verify that concurrent operations don't receive each other's events
     - **Test Scenario**: 
       1. Start 3 concurrent discovery operations with different operationIds
       2. Simulate events for each operation
       3. Verify each stream only receives its own events
       4. Verify event counts match expectations
     - **Why Important**: Prevents cross-talk bugs where one operation might receive another's results/errors

---

## Validation Checklist (Post-Fix)

- Discovery
  - Concurrent discovery methods emit events tagged with correct operationId.
  - Warning events emitted for all methods and surfaced via `onWarning`.
  - `stopDiscovery()` cancels all active discovery work and completes the stream.

- Printing
  - `print()` requires active connection and returns `Result<PrintOperationTracker>`.
  - Progress/status events are received; completion uses `print_onComplete`.

- Error Handling
  - Permission flow works on iOS returning structured result.
  - Platform errors mapped through `ZebraErrorBridge` produce categorized `ErrorCodes`.
  - Timeout cases yield specific timeout codes per operation type.

- Events
  - `connection_statusChanged` updates `ZebraController`.
  - Optional `connection_lost` handled if emitted.

- Compliance
  - Channel constants mirrored and used.
  - No direct channel access outside `ZebraPrinter`.
  - No TODOs or skipped tests; analysis passes with no issues.

---

## Suggested Test Additions

- **iOS permission integration test** (Note: May be N/A since channel-based permission was removed):
  - Test that `PermissionManager.checkBluetoothPermission()` returns proper Result
  - Verify permission denied/granted states map correctly
  - Ensure permission changes trigger appropriate UI updates

- **Concurrent discovery stream isolation test**:
  - Create test that starts 3 parallel discovery operations simultaneously
  - Mock native to send interspersed events with different operationIds
  - Assert each stream receives only its designated events
  - Verify final counts match per-operation expectations
  - Example test structure:
    ```dart
    test('concurrent discovery streams remain isolated', () async {
      final results = await Future.wait([
        printer.discoverBTClassic().toList(),
        printer.discoverSubnet(subnet: '192.168.1').toList(),
        printer.discoverMulticast(hops: 5).toList(),
      ]);
      // Verify each result list contains only appropriate devices
    });
    ```

- **Connection loss signaling test**:
  - Mock scenario where printer connection is established then lost
  - Verify `connection_lost` event is emitted exactly once
  - Assert `ZebraController` updates printer status to disconnected
  - Ensure subsequent operations return connection error Results
  - Test recovery: reconnection after loss should work properly

- **Error mapping snapshot tests**:
  - Create comprehensive test suite for `ZebraErrorBridge`
  - Test all known ZSDK error messages map to correct ErrorCodes
  - Include edge cases: null errors, unknown errors, malformed messages
  - Verify structured error data preservation (when implemented)
  - Example patterns to test:
    - "ZEBRA_ERROR_NO_CONNECTION" → ErrorCodes.zebraNoConnection
    - "Write to a connection failed" → ErrorCodes.zebraWriteFailure
    - Timeout exceptions → ErrorCodes.zebraOperationTimeout
    - Platform exceptions → appropriate error codes

---

## Closing Notes

The refactor to per-operation streams with an operation manager and callback handler is solid. Addressing the high and medium items will improve consistency, observability, and long-term maintainability without altering the core design.
