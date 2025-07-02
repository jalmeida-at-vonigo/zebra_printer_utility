# Result Pattern Implementation Plan

## Overview
Update Dart and iOS code to implement the Result pattern and match the documentation.

## Phase 1: Update Core Service Methods (Dart)

### 1.1 Update ZebraPrinterService Return Types
- [ ] Change `Future<bool> connect()` → `Future<Result<void>>`
- [ ] Change `Future<bool> disconnect()` → `Future<Result<void>>`
- [ ] Change `Future<bool> print()` → `Future<Result<void>>`
- [ ] Change `Future<List<ZebraDevice>> discoverPrinters()` → `Future<Result<List<ZebraDevice>>>`
- [ ] Change `Future<bool> autoPrint()` → `Future<Result<void>>`

### 1.2 Update Internal Methods
- [ ] Change `_doConnect()` to return Result
- [ ] Change `_doDisconnect()` to return Result
- [ ] Change `_doPrint()` to return Result
- [ ] Change `_doGetSetting()` to return Result<String?>
- [ ] Change `_doSetSetting()` to return Result

### 1.3 Update Operation Queue
- [ ] Modify ZebraOperation to store Result in completer
- [ ] Update operation execution to handle Results

## Phase 2: Update ZebraPrinter Methods (Dart)

### 2.1 Core Methods
- [ ] Change `connectToPrinter()` to return Result
- [ ] Change `disconnect()` to return Result
- [ ] Change `print()` to return Result
- [ ] Change `isPrinterConnected()` to return Result<bool>

### 2.2 Discovery Methods
- [ ] Update `startScanning()` to handle Result errors
- [ ] Create discovery result stream

## Phase 3: Update iOS Native Layer

### 3.1 Method Channel Results
- [ ] Update all FlutterResult calls to include error info
- [ ] Add error codes to match ErrorCodes class
- [ ] Include native stack traces in errors

### 3.2 Error Handling
- [ ] Create consistent error structure
- [ ] Map ZSDK errors to our error codes
- [ ] Add proper error context

## Phase 4: Example App Updates

### 4.1 Update UI Code
- [ ] Replace try-catch with Result handling
- [ ] Update error displays
- [ ] Add Result pattern examples

## Phase 5: Testing & Validation

### 5.1 Test Each Component
- [ ] Test connection with various error scenarios
- [ ] Test printing with error cases
- [ ] Test discovery timeouts
- [ ] Verify error information completeness

## Implementation Order

1. **Start with Result integration in ZebraPrinterService**
   - Keep backward compatibility temporarily
   - Add new Result-based methods alongside old ones

2. **Update ZebraPrinter to use Results**
   - Propagate Results from service layer
   - Handle platform exceptions properly

3. **Update iOS native code**
   - Consistent error reporting
   - Rich error information

4. **Update example app**
   - Show proper Result usage
   - Demonstrate error handling

5. **Remove old methods**
   - Clean up boolean returns
   - Remove legacy error handling

## Success Criteria

- [ ] All public methods return Result<T>
- [ ] Error information includes code, message, and stack traces
- [ ] No exceptions thrown to users (except via dataOrThrow)
- [ ] Example app demonstrates all patterns
- [ ] Documentation matches implementation exactly 