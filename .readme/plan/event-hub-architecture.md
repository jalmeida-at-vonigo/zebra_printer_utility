# Event Hub Architecture Refactoring Plan

## Problem Analysis

### Current Issues:
1. **Broadcast stream concerns** - Multiple listeners could miss events during high-frequency updates
2. **DiagnosticPanel direct event handling** - Should not handle events directly, should use DiagnosticLogManager
3. **Multiple subscriptions** - ZebraPrintingPopup and DiagnosticPanel both subscribing to same stream
4. **Type safety** - DiagnosticLogManager getting Map<String, dynamic> instead of typed events
5. **Architecture violation** - DiagnosticPanel._handlePrintEvent should not exist

### Root Cause:
- SmartPrintManager emits events through broadcast stream
- Multiple widgets subscribe directly to the stream
- DiagnosticPanel bypasses DiagnosticLogManager for event handling
- No centralized event routing

## Solution: Single Subscription Hub Architecture

### Design Principles:
- **KISS**: Single subscription point in ZebraPrintingPopup
- **Single Responsibility**: Each component has one clear role
- **Type Safety**: DiagnosticLogManager receives typed events
- **No Event Loss**: Single subscription ensures no missed events

### Architecture Flow:
```
SmartPrintManager.eventStream 
    ↓ (single subscription)
ZebraPrintingPopup (Hub)
    ↓ (routed events)
├── DiagnosticLogManager (typed events)
├── UI State Updates
└── Other handlers
```

## Implementation Plan

### Phase 1: Centralize Subscription
1. **Remove DiagnosticPanel subscription** - Delete _subscribeToEvents() and _handlePrintEvent()
2. **Make ZebraPrintingPopup the hub** - Single subscription point
3. **Route events to DiagnosticLogManager** - Pass typed events, not maps

### Phase 2: Type-Safe Event Handling
1. **Update DiagnosticLogManager** - Accept PrintEvent objects directly
2. **Remove map serialization** - Use typed event properties
3. **Keep JSON serialization only for storage** - DiagnosticLogManager handles this internally

### Phase 3: Clean Architecture
1. **Remove DiagnosticPanel._handlePrintEvent** - Method should not exist
2. **Update DiagnosticPanel** - Only consume logs from DiagnosticLogManager
3. **Verify no other subscriptions** - Ensure single subscription point

## Benefits:
- ✅ **No event loss** - Single subscription guarantees delivery
- ✅ **Type safety** - DiagnosticLogManager gets typed events
- ✅ **Clean separation** - Each component has clear responsibility
- ✅ **KISS** - Simple, centralized event routing
- ✅ **Maintainable** - Clear data flow and responsibilities

## Files to Modify:
1. `ZebraPrintingPopup.dart` - Add event hub functionality
2. `DiagnosticPanel.dart` - Remove event handling, use DiagnosticLogManager
3. `DiagnosticLogManager.dart` - Accept typed PrintEvent objects

## Success Criteria:
- ✅ Single subscription to SmartPrintManager.eventStream
- ✅ DiagnosticPanel only consumes logs from DiagnosticLogManager
- ✅ No direct event handling in DiagnosticPanel
- ✅ Type-safe event passing to DiagnosticLogManager
- ✅ No event loss or double subscription errors
- ✅ Reactive communication between DiagnosticLogManager and DiagnosticPanel
- ✅ No timing issues - immediate updates on subscription
- ✅ Gets everything on first time - no missed updates
- ✅ Efficient updates - individual log entries instead of entire lists
- ✅ Smart session handling - pauses new log subscription for historical sessions
- ✅ Race condition safe - subscribe first, then get initial data to prevent event loss
- ✅ Duplicate prevention - sequence-based deduplication handles subscribe+load scenarios
- ✅ Robust file operations - try-catch handling prevents PathNotFoundException during housekeeping
- ✅ Concurrency safe - completer-based synchronization prevents multiple concurrent session creation and housekeeping
- ✅ Simplified session management - single session creation per popup lifecycle, no aggressive calls

## Implementation Status: ✅ COMPLETED

### Changes Made:
1. **DiagnosticLogManager.dart**:
   - Added `addPrintEvent(PrintEvent event)` method for type-safe event handling
   - Added `_getStepNameFromEvent()` and `_buildEventDetails()` helper methods
   - Removed dependency on raw maps, now uses typed event properties
   - **Added reactive streams**: `logsStream`, `sessionsStream`, and `newLogStream` for real-time updates
   - **Added `emitInitialData()`** method to provide initial state to listeners
   - **Efficient updates**: Emit individual log entries via `newLogStream` instead of entire lists
   - **Sequence-based deduplication**: Added `sequence` field to `DiagnosticLogEntry` for duplicate prevention
   - **Robust file operations**: Added try-catch handling in `_housekeep()` and `clearAllSessions()` to prevent PathNotFoundException
   - **Concurrency protection**: Added `_sessionCreationCompleter` to synchronize multiple concurrent `startNewSession()` calls using futures
   - **Simplified session management**: Single session creation in `ZebraPrintingPopup._initializeService()`, removed all other session creation calls

2. **ZebraPrintingPopup.dart**:
   - Simplified `_handlePrintEvent()` to act as event hub
   - Routes events to DiagnosticLogManager via `addPrintEvent()`
   - Removed complex event parsing logic (moved to DiagnosticLogManager)

3. **DiagnosticPanel.dart**:
   - Removed `_subscribeToEvents()` and `_handlePrintEvent()` methods
   - **Replaced timer with reactive streams**: Subscribes to `newLogStream`, `logsStream`, and `sessionsStream`
   - **Efficient updates**: Uses `newLogStream` for individual log entries, `logsStream` for clearing/initial load
   - **Smart session handling**: Pauses new log subscription when viewing historical sessions
   - **Race condition safe**: Subscribe first, then get initial data immediately to prevent event loss
   - **Sequence-based deduplication**: Tracks `_highestSequenceSeen` to prevent duplicate log entries
   - **Immediate updates**: No timing issues, gets everything on first subscription
   - No longer handles events directly - only displays logs

### Architecture Benefits:
- **Single Subscription**: Only ZebraPrintingPopup subscribes to SmartPrintManager.eventStream
- **Type Safety**: DiagnosticLogManager receives typed PrintEvent objects, not maps
- **Clean Separation**: Each component has clear, single responsibility
- **No Event Loss**: Single subscription guarantees event delivery
- **KISS Principle**: Simple, centralized event routing
- **Production Ready**: No dummy comments, incomplete code, or placeholders
- **Reactive Communication**: Stream-based updates between DiagnosticLogManager and DiagnosticPanel
- **Efficient Updates**: Individual log entries emitted instead of entire lists for additive operations
- **Race Condition Safe**: Subscribe first, then get initial data to prevent event loss
- **Duplicate Prevention**: Sequence-based deduplication to handle subscribe+load scenarios
- **Robust File Operations**: Try-catch handling for file deletion to prevent PathNotFoundException
- **Concurrency Safe**: Completer-based synchronization prevents multiple concurrent session creation and housekeeping operations
- **Simplified Session Management**: Single session creation per popup lifecycle, no aggressive session creation calls 