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
- Method name divergence between constants and invocations
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

- Discovery result tracking duplication
  - `ZebraPrinter` both tracks `_discoveryResults[operationId]` and also emits via per-operation streams; the tracked list is not exposed. Not harmful, but can be simplified.

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

3) Expand discovery warning coverage
   - Emit `discovery_logWarning` in native for local broadcast and multicast partial failures (mirroring subnet/directBroadcast behavior).
   - In Dart, ensure `onWarning` propagates from all discovery primitives.

4) Preserve structured error fields
   - Extend `ZebraPrinterOperationCallbackHandler` to forward enriched error maps to `ZebraErrorBridge` instead of concatenated strings where possible. Example: attach structured fields via manager.failOperation with a map, or define a lightweight error wrapper to preserve fields.

### Low Priority
5) Emit `connection_lost` when appropriate
   - In iOS, when connection state transitions to nil or write/read fails irrecoverably, emit `connection_lost` once. Update Dart handler to mark UI red and reset internal state if needed.

6) Simplify discovery result tracking in `ZebraPrinter`
   - Remove `_discoveryResults` map unless needed for future aggregation. Rely on per-operation streams only.

7) Minor consistency fixes
   - Remove unused formatArgs in `print()` failure return or switch to a template that uses `{0}`.
   - Add a lightweight test ensuring event routing honors operationId isolation under concurrent scans.

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

- iOS permission integration test: Ensure permission result callback is received and mapped to `Result<bool>`.
- Concurrent discovery stream isolation test: Start 3 parallel discovery ops; verify no cross-talk and correct counts.
- Connection loss signaling test: Simulate connection drop and assert UI status update and `Result` classification.
- Error mapping snapshot tests: Ensure `ZebraErrorBridge` maps common native error messages to the expected `ErrorCodes`.

---

## Closing Notes

The refactor to per-operation streams with an operation manager and callback handler is solid. Addressing the high and medium items will improve consistency, observability, and long-term maintainability without altering the core design.
