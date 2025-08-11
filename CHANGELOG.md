# Changelog

All notable changes to this project will be documented in this file.

## [2.0.58] - 2024-12-20

### Changed
- **Error System Cleanup**: Removed 45+ unused error codes and improved error categorization
  - Removed unused error codes: `alreadyConnected`, `authenticationError`, `configurationError`, etc.
  - Enhanced `ErrorType` enum with proper categorization (hardware, timeout, data, etc.)
  - Improved error classification extensions for better error handling
  - Added missing `EnrichedNativeError.fromNative()` factory method

## [2.0.57] - 2024-12-20

### Changed
- **Naming Consistency**: Standardized all connection-related method and property names
  - `Zebra.isConnected()` → `Zebra.isPrinterConnected()`
  - `ZebraPrinterManager.isConnected()` → `ZebraPrinterManager.isPrinterConnected()`
  - `ZebraPrinter.isConnectedCached` → `ZebraPrinter.isPrinterConnectedCached`
  - `CommunicationPolicy.getConnectionStatus()` → `CommunicationPolicy.getPrinterConnectionStatus()`

## [2.0.56] - 2024-12-20

### Fixed
- **Operation Manager Callback Restoration**: Fixed all native operations to use original callback patterns
  - **Permission**: Now properly uses `onPermissionResult` with `granted` argument
  - **Discovery**: Uses `onDiscoveryDone` for completion and `onDiscoveryError` for errors
  - **Connection**: Uses `onConnectComplete` and `onConnectError`
  - **Disconnect**: Uses `onDisconnectComplete`
  - **Print**: Uses `onPrintComplete` and `onPrintError`
  - **Settings**: Uses `onSettingsComplete`, `onSettingsResult`, and `onSettingsError`
  - **Status**: Uses `onStatusResult` and `onStatusError`
  - **Connection Status**: Uses `onConnectionStatusResult`
  - **Locate Value**: Uses `onLocateValueResult`
  - **Stop Scan**: Uses `onStopScanComplete`
- **Utility Method Enhancement**: Updated `_operationSuccessResult` and `_operationErrorResult` to support custom callback names
  - Added `callbackMethod` parameter to specify the exact callback to invoke
  - Added `resultValue` parameter to explicitly set the return value
  - Automatically adds `operationId` to arguments if not present
  - Maintains backward compatibility with existing callback handlers

## [2.0.55] - 2024-12-20

### Changed
- **Radical Operation Manager Enforcement**: Implemented strict operation manager pattern enforcement
  - **REQUIRED operationId**: All native method calls now require operationId parameter
  - **No Fallback Calls**: Removed all fallback `result()` calls when operationId is missing
  - **Architecture Violation Detection**: Added error logging for missing operationId
  - **Method Signature Updates**: All method signatures now require non-optional operationId
  - **Utility Method Renaming**: Renamed `_sendOperationManagerSuccessResult` → `_operationSuccessResult`
  - **Utility Method Renaming**: Renamed `_sendOperationManagerErrorResult` → `_operationErrorResult`
  - **Enhanced Error Handling**: Both utility methods now validate operationId presence
  - **Prevented Hanging**: Eliminated potential for Dart-side hanging due to missing callbacks

### Technical
- **Architecture Compliance**: Enforces 100% operation manager pattern usage
- **Error Prevention**: Prevents hanging scenarios where Dart waits for callbacks that never come
- **Consistent Pattern**: All native operations follow the same completion pattern
- **Validation**: Runtime validation ensures architectural compliance

## [2.0.54] - 2024-12-20

### Fixed
- **Complete Operation Manager Refactoring**: Finalized the refactoring of all native operations
  - Removed deprecated `sendConnectionSuccess` and `sendConnectionError` methods
  - Removed deprecated `createEnrichedError` method (logic inlined into `_sendOperationManagerErrorResult`)
  - All operations now exclusively use `_sendOperationManagerSuccessResult` and `_sendOperationManagerErrorResult`
  - Ensured 100% consistency across all native methods for operation completion and error handling
  - Cleaned up codebase by removing redundant utility methods

## [2.0.53] - 2024-12-20

### Fixed
- **Operation Manager Integration**: Refactored all native operations to use proper operation manager utilities
  - Created `_sendOperationManagerSuccessResult` and `_sendOperationManagerErrorResult` utility methods
  - All operations now call `completeOperation` and `failOperation` via operation manager instead of direct channel calls
  - Inlined `createEnrichedError` logic into `_sendOperationManagerErrorResult` for better performance
  - Updated all discovery, connection, print, settings, and status operations to use the new utility methods
  - Ensured consistent error handling and operation completion across all native methods

## [2.0.52] - 2024-12-20

### Fixed
- **Operation Manager Integration**: Fixed discovery methods to properly integrate with ZebraPrinterOperationManager
  - All discovery methods now extract `operationId` from arguments and use proper completion callbacks
  - Fixed `stopScan` to properly complete operations via operation manager
  - Removed dead code (`startNetworkDiscovery` method) and `discoverNetworkPrinters` primitive
  - Updated cancellation logic to use `Set<DispatchWorkItem>` for proper tracking
  - Ensured all discovery operations follow the async/await pattern with proper timeout handling

## [2.0.51] - 2024-12-20

### Added
- **Network Discovery Enhancement**: Implemented multiple concurrent network discovery methods
  - Added `discoverBTClassic` for MFi Bluetooth discovery on iOS
  - Added `discoverLocalBroadcast` for local network discovery
  - Added `discoverSubnet` for subnet-based discovery with iPad hotspot support (172.20.10.*)
  - Added `discoverDirectedBroadcast` for directed broadcast discovery
  - Added `discoverMulticast` for multicast discovery
- **Native Model Architecture**: Introduced type-safe native models
  - Created `PrinterInfo.swift` for iOS native printer information
  - Created `NativePrinterInfo.dart` for Dart-side printer information
  - Improved type safety between native and Dart layers
- **Discovery Streaming**: Printers now stream immediately as discovered
  - Native layer streams printers via `printerFound` events
  - Dart layer handles streaming updates in real-time
  - Improved user experience with faster printer visibility

### Changed
- **Full Migration**: Removed deprecated `startScan` and `stopScan` methods
  - Replaced with individual discovery primitives
  - All discovery operations now run concurrently
  - Better control over discovery methods
- **iOS Implementation**: Enhanced ZebraPrinterInstance.swift
  - Added cancellation support with DispatchWorkItem
  - Implemented unified `stopScan` method
  - Explicit iPad hotspot IP range support (172.20.10.*)

### Fixed
- **iPad Hotspot Discovery**: Explicitly includes iPad hotspot subnet in discovery
  - Subnet search includes 172.20.10.*
  - Directed broadcast includes 172.20.10.255
  - Resolves issues with printers not found on iPad hotspots

### Technical
- **Architecture Compliance**: Enforces no direct channel calls outside ZebraPrinter
- **Concurrent Discovery**: All discovery methods run in parallel for < 2.5s total time
- **Native Standards**: Created comprehensive native layer standards documentation
- **Test Updates**: Updated all tests to use new discovery primitives

## [2.0.50] - 2025-08-06

### Fixed
- **Architecture**: Fixed SmartPrintManager dependency injection to prevent duplicate state management
  - **Single Source of Truth**: SmartPrintManager now accepts ZebraPrinterManager instance instead of creating its own
  - **Shared State**: Both managers now share the same connection state, discovery state, and resources
  - **Resource Efficiency**: Eliminated duplicate stream controllers, communication policies, and other resources
  - **Consistent State**: Connection state, discovery state, and other shared data are now consistent between managers
- **Constructor Updates**: Updated SmartPrintManager constructor signature
  - Changed from `SmartPrintManager({required ZebraPrinter printer})` to `SmartPrintManager({required ZebraPrinterManager manager})`
  - Updated Zebra class to pass manager instance to SmartPrintManager
  - Updated all usage sites in example app and mobile app
- **Documentation**: Updated architecture documentation and examples
  - Fixed constructor examples in event-system.mdc
  - Updated architecture documentation in zebra-printer-architecture.mdc
  - Ensured all documentation reflects the new dependency injection pattern

### Technical
- **Dependency Direction**: Enforced proper dependency direction (SmartPrintManager → ZebraPrinterManager → ZebraPrinter)
- **State Management**: Eliminated potential state inconsistencies between multiple ZebraPrinterManager instances
- **Resource Management**: Reduced memory usage and eliminated resource duplication
- **Test Coverage**: All tests continue to pass with the new architecture

## [2.0.49] - 2025-08-05

### Fixed
- **Code Quality**: Fixed all lint and analysis warnings in lib/ directory
  - Fixed directive ordering in zebra_printer_manager.dart
  - Removed unnecessary null-aware operator in zebra_printer_manager.dart
  - Fixed unnecessary null comparison in zebra_printer_manager.dart
  - Fixed constructor ordering in zebra.dart
  - Fixed HTML interpretation warning in zebra_printer_discovery.dart
  - Removed unnecessary null check in smart_print_manager.dart
- **Test Suite**: Fixed all test compilation and lint issues
  - Fixed ZebraPrinter constructor usage in all command tests using mocks
  - Fixed directive ordering in test files
  - Removed tests for non-existent classes (OperationCallbackHandler)
  - Updated test files to use proper mocking instead of invalid constructors
  - Fixed unused imports and undefined references in test files
- **Example App**: Fixed discovery screen and printer selector issues
  - Fixed Stream vs Result confusion in discovery_screen.dart
  - Fixed Stream vs Result confusion in printer_selector.dart
  - Added const constructor for Duration to improve performance
- **Duplicate Type Cleanup**: Removed redundant enum definitions
  - Removed unused `PrinterMode` enum that duplicated `PrintFormat` functionality
  - Removed unused `EnumMediaType` enum with no usage in codebase
  - Removed unused `Command` enum with no usage in codebase
  - Updated tests to remove references to deleted enums
- **Analysis Compliance**: Code now passes `flutter analyze` with zero issues across all directories

### Technical
- Consolidated all format-related operations to use `PrintFormat` enum consistently
- Improved code maintainability by removing dead code
- Enhanced test coverage for remaining enums
- Fixed all test compilation issues with proper mocking
- Resolved Stream vs Result API confusion in example app

## [2.0.48] - 2025-08-05

### Enhanced
- **Real-time Streaming Discovery**: Implemented streaming discovery API that provides immediate UI updates
  - **No UI Freezing**: Discovery operations run asynchronously without blocking the main thread
  - **Immediate Results**: Printers appear in UI as soon as they are discovered, not after completion
  - **Progressive Discovery**: Users see printers being found in real-time during the discovery process
  - **Automatic Cleanup**: Discovery stops automatically when a printer is selected for better UX
- **Stream Subscription Management**: Added proper lifecycle management for discovery streams
  - **Memory Leak Prevention**: Subscriptions are properly cancelled and disposed
  - **Resource Cleanup**: Discovery processes are stopped when widgets are disposed
- **iPad Hotspot Network Discovery**: Enhanced network discovery specifically optimized for iOS HotSpot scenarios
  - **Parallel Discovery Methods**: Multiple discovery techniques run simultaneously for faster results
  - **Subnet Search Optimization**: Focused on 172.20.10.x range for iPad hotspots

### Technical
- Migrated network discovery from native iOS to pure Dart implementation for better control
- Implemented real-time streaming in `ZebraPrinterDiscovery.discoverPrintersStream()`
- Added automatic discovery termination when printers are selected
- Enhanced `NetworkDiscovery` class with streaming capabilities and iOS HotSpot support
- Updated example app to demonstrate best practices for streaming discovery API

## [2.0.47] - 2025-01-22

### Fixed
- **Code Quality**: Fixed all lint and analysis warnings in network discovery
  - Fixed import ordering in network_discovery.dart
  - Applied const constructors for Duration and other constant values
  - Removed incomplete TODO comment and replaced with documentation note
- **Analysis Compliance**: Code now passes `flutter analyze` with zero issues

### Technical
- Improved const usage for better performance
- Enhanced code documentation quality

## [2.0.46] - 2025-01-22

### Fixed
- **Code Quality**: Fixed all lint and analysis warnings to ensure clean codebase
  - Fixed import ordering issues in policy files
  - Removed unnecessary imports in smart_print_manager.dart
  - Fixed const constructor usage in test files
  - Fixed await usage on non-Future values
  - Made unused error fields in printer_readiness.dart accessible through cachedValues
  - Fixed constructor ordering in zebra_printer_discovery.dart
- **Test Suite**: All tests passing with proper mock generation
- **Analysis Compliance**: Code now passes `flutter analyze` with no issues

### Technical
- Regenerated mock files to fix compilation issues
- Improved code organization and maintainability
- Enhanced error tracking in PrinterReadiness class

## [2.0.45] - 2025-01-17

### Changed
- **Enhanced Smart Print Workflow**: Improved real-time status updates and UI feedback during print operations
  - Added comprehensive realTimeStatusUpdate event handling with enhanced metadata
  - Improved progress hints and issue details display in PrintingPanel
  - Enhanced error handling UI to show recovery hints and auto-resume capabilities
  - Better utilization of SmartPrintManager's state properties in UI components

### Technical
- Refactored print event handling to utilize the simplified status model for better clarity and maintainability
- Enhanced DiagnosticPanel to properly log realTimeStatusUpdate events with full metadata
- Improved error classification with ErrorRecoverability.possiblyRecoverable support
- Streamlined the codebase by leveraging existing SmartPrintManager state management

## [2.0.44] - 2024-12-19

### Changed
- **Smart Print Workflow**: Now detects print data format (CPCL or ZPL) before printing, checks printer language, and sets the correct mode if needed before sending data.
- **Status Logic**: Ensures printer is in the correct mode before sending print data, and only sends data after all checks pass.
- **Code Quality**: Fixed all linter and analysis warnings; codebase is clean and up to standards.

### Technical
- Implemented smart waiting logic based on print data size and language.
- Updated command factory and print manager integration for robust, error-free operation.
- **Type-Safe Error Classification**: Unified ErrorCode and SuccessCode categories using ResultCategory enum
  - Renamed ErrorCategory to ResultCategory for unified categorization system
  - Updated all 200+ error codes and 19 success codes to use ResultCategory enum instead of strings
  - Enhanced type safety with compile-time category checking
  - Simplified Result classification extensions with direct enum access
  - Updated SmartPrintManager to work with enum-based category mapping
  - Eliminated string parsing and mapping logic for better performance

## [2.0.43] - 2024-12-19

### Fixed
- **Merge Conflict Resolution**: Successfully resolved merge conflicts from cherry-pick operation
  - Resolved conflicts in `command_factory.dart` by removing reference to non-existent `wait_for_print_completion_command.dart`
  - Resolved conflicts in `smart_print_manager.dart` by choosing the existing implementation approach
  - Resolved conflicts in `zebra_printer_manager.dart` by renaming method to avoid naming conflicts
  - Updated `models/print_event.dart` to include new `realTimeStatusUpdate` event type from incoming changes

### Changed
- **SmartPrintManager**: Updated to use existing `waitForPrintCompletion` method from ZebraPrinterManager
  - Removed duplicate class definitions that were already defined in `models/print_event.dart`
  - Removed duplicate `_waitForPrintCompletion` method and now calls the manager's implementation
  - The manager's implementation provides format-specific delays (CPCL: 2.5s base, ZPL: 2s base, plus 1s per KB)
  - Added proper import for `models/print_event.dart`
  - Removed unused fields and methods related to status polling approach
- **ZebraPrinterManager**: Kept only the delay-based `waitForPrintCompletion` method
  - Removed status polling version that was checking printer status after delay
  - Method calculates delay based on data size and format for optimal performance
- **CommandFactory**: Removed reference to non-existent `wait_for_print_completion_command.dart`
  - Cleaned up imports and removed duplicate references

## [2.0.42] - 2024-12-19

### Fixed
- **Hardcoded Error Codes**: Replaced all hardcoded error code strings in SmartPrintManager with centralized ErrorCodes constants from result.dart
- **Code Quality**: Now uses proper ErrorCode constants instead of string literals for error code comparisons
- **Smart Print Deadlock**: Fixed async generator issue in `smartPrint` method
  - Fixed deadlock caused by yielding event stream before starting workflow
  - Workflow now starts before yielding events, preventing UI blocking
  - Smart print now executes immediately instead of waiting for cancellation
- **Smart Print Readiness Options**: Aligned smart print with regular print behavior
  - Removed aggressive readiness overrides in smart print workflow
  - Now uses same `ReadinessOptions.quickWithLanguage()` as regular print
  - Fixed issue where smart print was failing due to hardware error checks that regular print skips
  - User requested no additional safety checks in smart print vs regular print
- **Smart Print Event Stream**: Fixed potential event loss issue
  - Changed from broadcast stream to regular (buffering) stream controller
  - Ensures early events (like initialization) are not lost due to race conditions
  - All events are now buffered until a listener subscribes, preventing any event loss
- **Test Suite**: Fixed all failing tests
  - Regenerated mocks to fix type mismatch issues with `onDiscoveryError` callback
  - Fixed "Operation cancelled" errors by adding proper async teardown delays
  - All tests now pass successfully without errors

### Changed
- **Smart Recovery Hint Management**: SmartPrintManager now intercepts and removes recovery hints from errors it automatically handles
- **User Experience**: Users only see recovery hints for errors that actually require manual intervention
- **Auto-Recovery Transparency**: Errors that SmartPrintManager auto-retries (connection, timeout, status, discovery) no longer show recovery hints

### Added
- **Centralized Recovery Hints**: Added `recoveryHint` field to `ErrorCode` class for centralized user intervention guidance
- **New Error Constants**: Added comprehensive set of new error constants with proper recovery hints:
  - `printerBusy` - Printer processing another job
  - `printerOffline` - Printer not available
  - `printerJammed` - Paper jam detected
  - `ribbonOut` - Ribbon needs replacement
  - `mediaError` - Media-related issues
  - `calibrationRequired` - Printer needs calibration
  - `bufferFull` - Printer buffer overflow
  - `languageMismatch` - Print language format mismatch
  - `settingsConflict` - Conflicting printer settings
  - `firmwareUpdateRequired` - Outdated firmware
  - `temperatureError` - Temperature outside operating range
  - `sensorError` - Sensor malfunction
  - `printHeadError` - Print head issues
  - `powerError` - Power-related problems
  - `communicationError` - Communication protocol issues
  - `authenticationError` - Authentication failures
  - `encryptionError` - Encryption/decryption failures
  - `dataCorruptionError` - Corrupted print data
  - `unsupportedFeature` - Feature not supported
  - `maintenanceRequired` - Maintenance needed
  - `consumableLow` - Consumables running low
  - `consumableEmpty` - Consumables completely empty

### Technical
- Updated `_shouldRemoveRecoveryHint()` method to use `ErrorCodes.constant` instead of hardcoded strings
- Fixed linter errors by using if-else statements instead of switch cases with non-constant expressions
- Maintains centralized error code management as per architecture rules
- Added `_shouldRemoveRecoveryHint()` method to determine which error codes should have recovery hints removed
- Recovery hints are removed for auto-recoverable errors:
  - Connection errors (timeout, network, bluetooth, permission)
  - Print errors (timeout, paused state)
  - Operation errors (timeout, general)
  - Status errors (check failures, timeouts)
  - Discovery errors (timeout, network, bluetooth, permission)
- Recovery hints are preserved for hardware issues requiring user intervention (head open, out of paper, ribbon errors, etc.)
- **ErrorInfo Enhancement**: Updated `ErrorInfo` class to include `recoveryHint` field from `ErrorCode`
- **SmartPrintManager**: Removed local `_getRecoveryHint` method in favor of centralized recovery hints
- **UI Integration**: Recovery hints now flow directly from error codes to UI for consistent user guidance
- All error constants now include appropriate recovery hints where user intervention is possible
- Recovery hints are null for errors that don't require user action
- Enhanced error code lookup with comprehensive coverage of all error scenarios

## [2.0.40] - 2025-07-10

### Redesigned
- **CommunicationPolicy**: Complete redesign with optimistic execution workflow
  - **Optimistic Execution**: Run commands first, react to failures instead of checking connection before every operation
  - **Preemptive Timeout Check**: Only check connection if last check was more than 5 minutes ago
  - **Integrated Workflow**: Connection health and failure handling become part of the command execution flow
  - **Real-time Status Updates**: Status callback for live operation feedback with detailed event information
  - **Reactive Failure Handling**: Automatic reconnection and retry when connection errors occur
- **Ideal Command Execution**: Single integrated workflow for all printer operations
  - **executeCommand()**: Execute commands with integrated connection management
  - **executeOperation()**: Execute custom operations with integrated connection management
  - **getConnectionStatus()**: Get current connection status with timeout checking
  - **forceConnectionCheck()**: Force fresh connection check when needed

### Added
- **Printer Readiness Architecture**: Implemented comprehensive lazy caching pattern with single hardware read per property
  - **PrinterReadiness Class**: Lazy status caching with options-driven communication
  - **PrinterReadinessManager Class**: Orchestrates readiness checks and automatic corrections with enhanced event system
  - **Reset Operations**: Individual and complete reset methods for force re-reading when needed
  - **ReadinessResult Integration**: Comprehensive result structure with applied fixes tracking
  - **Enhanced Event System**: Detailed readiness operation events with operation type, kind, and result tracking
- **Hardware Communication Optimization**: Just-enough communication principle with minimal hardware calls
  - **Single Read Pattern**: Each property is read only once and cached for subsequent access
  - **Options Respect**: Only reads hardware for properties enabled in ReadinessOptions
  - **Manager Efficiency**: Uses cached values, never makes duplicate hardware calls
  - **Fix Flags Integration**: Fix flags implicitly allow reading corresponding status
- **Comprehensive Reset Capability**: Full reset functionality for all readiness properties
  - **Individual Resets**: `resetConnection()`, `resetMediaStatus()`, `resetHeadStatus()`, etc.
  - **Complete Reset**: `resetAllStatuses()` for comprehensive re-reading
  - **External Control**: Reset operations available for external code when hardware state changes
- **Result API Enhancements**: Added overloaded constructors for better error/success propagation
  - `Result.errorFromResult(Result source, [String? additionalMessage])` - Creates error Result copying all error details from another Result
  - `Result.successFromResult(Result source, [T? data])` - Creates success Result preserving success info
  - Preserves complete error context (code, stack traces, timestamps)
  - Reduces boilerplate when propagating errors
  - Maintains error chain for better debugging
  - Allows adding context to errors without losing original details

### Enhanced
- **PrinterReadinessManager Class**:
  - **Enhanced Event System**: Detailed readiness operation events with operation type, kind, and result tracking
  - **Cached Value Usage**: All check and fix methods use cached values from PrinterReadiness
  - **No Reset Operations**: Removed automatic reset calls after applying fixes
  - **Fix Logic**: Applies corrections based on options and format requirements
  - **Efficient Communication**: No duplicate hardware calls during manager operations
- **SmartPrintManager Class**:
  - **Connection Optimization**: Avoids unnecessary disconnect/reconnect when already connected to same printer
  - **Language Support**: Enabled language checking and fixing for proper ZPL/CPCL interpretation
  - **Comprehensive Status Checks**: Enhanced readiness options to include essential language and error operations
  - **Trusted Memory Status**: Optimistically trusts connection status while letting readiness manager verify
  - **Enhanced Event Forwarding**: Forwards detailed readiness events to the event stream for comprehensive UI feedback
- **ZebraPrinter Class**:
  - **Connection Efficiency**: Only disconnects when connecting to a different printer
  - **Same Printer Detection**: Skips reconnection when already connected to the same printer
  - **Memory Status Trust**: Relies on cached connection status for efficiency
- **Hardware Communication Flow**:
  - **Initial Read (Lazy)**: Hardware communication only on first property access
  - **Manager Check (Uses Cache)**: Manager operations use cached values exclusively
  - **External Reset (When Needed)**: External code can reset and re-read when needed
- **Performance Optimization**:
  - **Reduced Hardware Calls**: Single read per property per session
  - **Memory Efficiency**: Minimal memory overhead for cached values
  - **Time Complexity**: O(1) for cached access, O(1) for reset operations
  - **Connection Efficiency**: Eliminated unnecessary disconnect/reconnect cycles

### Simplified
- **Connection Management**: Centralized all connection management, health checks, retries, and timeout policies in `CommunicationPolicy`
  - **Removed Duplicate Logic**: Eliminated connection health caching, retry logic, and timeout handling from `ZebraPrinterManager`
  - **Simplified Methods**: Streamlined `ensureConnectionHealth()` and `handleConnectionFailure()` to use `CommunicationPolicy` exclusively
  - **Clean Architecture**: Clear separation between connection assurance (CommunicationPolicy) and operation timeouts (OperationManager)
  - **Reduced Complexity**: Removed `_isConnectionHealthy`, `_lastConnectionCheck`, `_connectionCheckValidity`, and `_maxReconnectionAttempts` fields
- **OperationManager Timeout**: Kept native operation timeout handling in `OperationManager` for tracking individual operation timeouts
  - **Distinct Responsibilities**: CommunicationPolicy handles connection assurance, OperationManager handles operation tracking
  - **No Duplication**: Each component has a single, clear responsibility for timeout handling

### Integrated
- **ZebraPrinterManager**: Updated to use new CommunicationPolicy integrated workflow
  - **Removed Old Methods**: Eliminated `ensureConnectionHealth()` and `handleConnectionFailure()` methods
  - **Public Access**: Added `communicationPolicy` getter for external access
  - **Simplified Print Logic**: Print operations now use integrated workflow automatically
- **SmartPrintManager**: Updated to use CommunicationPolicy directly
  - **Direct Integration**: Uses communication policy for connection health and reconnection
  - **Consistent Workflow**: All connection management goes through CommunicationPolicy
- **PrinterReadiness**: Updated to use new CommunicationPolicy API
  - **executeCommand()**: All status reading uses the new command execution API
  - **getConnectionStatus()**: Connection checking uses the new status API
- **PrinterReadinessManager**: Updated to use new CommunicationPolicy API
  - **ensureConnection()**: Uses new connection status API
  - **executeCommandWithAssurance()**: Uses new operation execution API

### Fixed
- **CorrectedReadiness Class**: Fixed constructor to properly extend PrinterReadiness with super parameters
- **Multiple Hardware Reads**: Eliminated duplicate hardware calls in manager operations
- **Options Violation**: Ensured all property access respects ReadinessOptions settings
- **Reset Logic**: Removed unnecessary reset operations from manager after applying fixes
- **Code Quality**: Fixed all linter errors and removed unused imports
- **Connection Efficiency**: Eliminated unnecessary disconnect/reconnect cycles in smart print workflow
- **Language Interpretation**: Fixed printer printing raw ZPL instead of interpreting it by enabling language checking/fixing
- **Smart Print Workflow**: Optimized connection logic to trust memory status and avoid redundant operations
- **Legacy Code Cleanup**: Removed redundant `_checkPrinterStatus` method from SmartPrintManager in favor of centralized readiness management

### iOS Native Code Refactoring
- **ZSDKWrapper.m**: Removed all business logic to create a pure ZSDK wrapper
  - Removed discovery data formatting, branding, and model querying logic
  - Removed CPCL-specific delays (sleepForTimeInterval) from sendData method
  - Removed complex response reading logic with multiple retries
  - Removed language parsing business logic from getPrinterLanguage
  - Removed status formatting and human-readable messages from getPrinterStatus
  - Removed waitForPrintCompletion method with complex polling logic
  - Removed status analysis and recommendations from getDetailedPrinterStatus
  - Simplified all methods to just call ZSDK APIs and return raw data
- **ZebraPrinterInstance.swift**: Refactored to be a thin channel communication wrapper
  - Removed CPCL-specific delays in printData method
  - Removed command parsing logic (key=value vs raw) from setSettings
  - Removed broken waitForPrintCompletion implementation
  - Kept error enrichment as appropriate for middleware layer
  - Simplified all methods to just forward calls to ZSDKWrapper
- **Dart Side Enhancements**: Moved all business logic to Dart for platform independence
  - Enhanced printerFound handler to generate displayName and connectionType when not provided
  - Added status analysis and recommendations to GetDetailedPrinterStatusCommand
  - Added human-readable status description generation to GetPrinterStatusCommand
  - All CPCL delays and format-specific handling remain in Dart (ZebraPrinterManager)
  - Print completion verification logic remains in Dart (waitForPrintCompletion)

### Thread Safety and Exception Handling
- **Zero Exception Tolerance**: All operations now return Result<T> types, never throw exceptions
  - Removed throw statement from zebra.dart initialization
  - Removed throw statement from get_detailed_printer_status_command.dart
  - Added safer alternatives: getOrElse, getOrElseCall, dataOrNull
  - dataOrThrow remains a public API for advanced consumers who want exception-based access, but is never used internally in the library
- **Thread Safety Improvements**:
  - Added synchronization flags to prevent concurrent operations
  - Ensured proper disposal of StreamControllers and Timers with null-safety
  - Fixed race conditions in SmartPrintManager
  - Added _isRunning flag to prevent concurrent smart print operations
- **UI Non-Blocking Guarantees**:
  - All operations are properly async
  - Event-based architecture for real-time updates
  - No synchronous heavy operations that could block UI
- **Library User Experience**:
  - Users can call any method without try-catch blocks
  - All async operations return Result<T> for safe error handling
  - Proper cancellation support for long-running operations

### Result-Based API Improvements
- **zebra.dart Fully Result-Based**: All methods now properly return Result types
  - _ensureInitialized now returns Result<void> with proper error propagation
  - Stream getters (devices, connection, status) now return Result<Stream<T>>
  - stopDiscovery now returns Result<void> instead of void
  - discoverPrintersStream now returns Result<Stream<List<ZebraDevice>>>
  - isConnected now returns Result<bool> instead of bool
  - cancelSmartPrint now returns Result<void> instead of void
  - smartPrintManager getter now returns Result<SmartPrintManager>
- **Initialization Error Handling**: 
  - Cached initialization result to avoid redundant attempts
  - Proper error propagation from manager initialization
  - Reset on dispose to allow re-initialization
- **Breaking Changes**:
  - Stream getters now return Result<Stream<T>> - users need to check Result before accessing stream
  - isConnected returns Result<bool> - users need to check Result before accessing value
  - cancelSmartPrint returns Result<void> - users can check if cancellation succeeded

### Code Cleanup
- **ZebraSGDCommands**: Converted to utility-only class as per architectural guidelines
  - Removed all command methods (getCommand, setCommand, doCommand, etc.)
  - Kept only utility methods: isZPLData, isCPCLData, detectDataLanguage, parseResponse, isLanguageMatch
  - All command generation now uses CommandFactory pattern
- **Command Pattern Refinement**: Removed generic SetSettingCommand in favor of specific commands
  - Removed SetSettingCommand class and factory method
  - Library uses specific commands (SendUnpauseCommand, SendSetZplModeCommand, etc.)
  - ZebraPrinter.setSetting remains as public API for external use, sends SGD directly
- **Media Calibration**: Enabled fixMediaCalibration in SmartPrintManager for comprehensive media handling
- **DRY Improvements**: Refactored code to eliminate duplication
  - Added helper methods in PrinterReadinessManager (_reportCheckResult, _reportFixResult)
  - Centralized all command execution through CommunicationPolicy
  - Removed duplicate connection checks and status operations
- **Test Improvements**: Enhanced test coverage and implementation
  - Removed skipped tests and implemented proper Mockito mocks
  - Added test coverage for async operations in ZebraPrinter
  - All tests now pass without warnings or errors
- **Architecture Consistency**: Ensured all components use centralized patterns
  - All command execution uses CommunicationPolicy for connection assurance
  - Fixed ZebraPrinterManager to use CommunicationPolicy for all operations
  - Fixed ZebraPrinter.setSetting to return proper Result type
  - Removed direct command execution in favor of policy-wrapped execution
- **Result Constructor Usage**: Applied new Result constructors throughout codebase
  - Updated `zebra_printer.dart`: Use `Result.successFromResult` in `getPrinterStatus`
  - Updated `zebra.dart`: Use `Result.errorFromResult` in `_ensureInitialized`
  - Consistent use of new constructors for better error propagation
  - Preserved complete error context when creating new Result objects
- **Documentation**: Removed TODO.md file and all references as per no-TODOs rule

### Technical
- **Architecture**: Clear separation between status caching (PrinterReadiness) and fix orchestration (PrinterReadinessManager)
- **Efficiency**: Just-enough hardware communication with single read per property pattern
- **Flexibility**: Reset operations available for external use when hardware state changes
- **Maintainability**: Comprehensive documentation and cursor rules for architecture patterns
- **Performance**: Optimized hardware communication with minimal calls and maximum caching
- **Standards**: Enforced single hardware read pattern and options-driven communication
- **Event System**: Enhanced readiness events provide detailed operation tracking for UI and debugging
- **Code Quality**: DRY, SRP, and KISS principles enforced throughout the architecture
- **Platform Independence**: All business logic now resides in Dart for consistent behavior
- **Error Handling**: Native layer provides enriched errors, Dart layer handles business logic
- **No Breaking Changes**: All existing functionality preserved, just moved to appropriate layers

### Code Quality Improvements
- **DRY Improvements**: Added helper methods _reportCheckResult and _reportFixResult in PrinterReadinessManager for consistent check/fix result handling
- **Test Improvements**: 
  - Removed all skipped tests
  - Added proper mocking with Mockito
  - Created MockOperationManager for testing
  - Removed obsolete connection test
- **Model Extraction**: Extracted all model classes to dedicated `lib/models/` folder for better organization
  - Moved `ReadinessOperationEvent` and related enums from zebra_printer_readiness_manager.dart
  - Moved `CommunicationPolicyEvent` and `CommunicationPolicyOptions` from communication_policy.dart
  - Moved `OperationLogEntry` from operation_manager.dart
  - Moved `HostStatusInfo` from parser_util.dart
  - Moved `PrintOptions` from zebra_printer_manager.dart
  - Moved print event models (`PrintStepInfo`, `PrintErrorInfo`, `PrintProgressInfo`, `PrintEvent`) from smart_print_manager.dart
  - Moved `SmartDiscoveryResult` and `ScoredDevice` from smart_device_selector.dart
  - Created `models.dart` barrel export file for all models
  - Updated all imports throughout the codebase

## [2.0.39] - 2025-07-10

### Added
- **Comprehensive Edge Case Error Handling**: Enhanced SmartPrintManager with robust error handling for all edge cases
- **Enhanced Print Steps**: Added validation, status checking, and completion waiting steps
- **Error Classification System**: Implemented ErrorRecoverability enum for better error categorization
- **Recovery Hints**: Added user-friendly recovery instructions for different error types
- **Data Validation**: Added comprehensive print data validation before sending
- **Status Monitoring**: Enhanced printer status detection and monitoring
- **Resource Management**: Improved cleanup and resource management
- **Mobile UI Enhancements**: Enhanced error presentation with recovery guidance and user decision points
- **New Cursor Rule**: Added edge-case-error-handling.mdc for comprehensive error handling architecture

### Enhanced
- **SmartPrintManager**: 
  - Added data validation step with format and size checking
  - Enhanced connection error classification and retry logic
  - Added printer status checking before printing
  - Implemented print completion waiting
  - Added exponential backoff for retries
  - Enhanced error information with recovery hints
- **Mobile UI**:
  - Enhanced error categorization using SmartPrintManager error info
  - Added user decision points for non-recoverable errors
  - Improved error presentation with recovery guidance
  - Added action buttons for manual error resolution
  - Enhanced status visualization and progress tracking

### Fixed
- **Error Handling**: Improved error classification and recovery strategies
- **Resource Leaks**: Fixed potential resource leaks with proper cleanup
- **Status Detection**: Enhanced printer status detection for hardware issues
- **UI Responsiveness**: Improved UI responsiveness during error scenarios

### Technical
- **Architecture**: Clear separation of responsibilities between library and UI layers
- **Error Recovery**: Auto-recovery for connection issues, manual guidance for hardware issues
- **Status Monitoring**: Real-time status updates and change detection
- **Testing**: Enhanced error scenario testing and validation

## [2.0.38] - 2024-12-19

### Added
- **Professional Documentation**: Complete rewrite of README.md with modern architecture overview
- **Example App Consolidation**: Streamlined example app with shared components and consistent logging
- **Example README**: Comprehensive documentation for the example app with screen descriptions and usage guides
- **Shared Log Panel**: All example screens now use the unified `OperationLogPanel` for consistent logging
- **Enhanced Cursor Rules**: Updated example maintenance rules to enforce shared components and logging standards

### Changed
- **Example App Structure**: Consolidated to 4 focused screens demonstrating specific workflows
- **Logging Standardization**: All screens now use `List<OperationLogEntry>` with proper status values
- **UI Consistency**: Unified device selection and logging across all example screens
- **Documentation Quality**: Professional, well-organized documentation with clear architecture explanations

### Removed
- **Legacy Example Screens**: Removed outdated legacy and simplified screens
- **Custom Logging**: Eliminated custom logging widgets in favor of shared `OperationLogPanel`
- **Inconsistent UI**: Removed custom device selectors in favor of shared `BTPrinterSelector`

## [2.0.37] - 2025-01-08

### Removed
- **Legacy Operations**: Removed direct, simplified, and legacy operations that were replaced by more robust APIs
  - Removed `printSimplified()` method from `Zebra` class - replaced by `smartPrint()` for comprehensive workflows
  - Removed `setPrinterForSimplified()` method - no longer needed with robust printer management
  - Removed legacy ZPL-specific commands from `ZebraSGDCommands` class - replaced by command factory pattern
  - Removed legacy and simplified example screens - replaced by modern smart print examples
  - Removed legacy error handling test - replaced by comprehensive error handling in robust APIs
- **Simplified API**: Cleaned up simplified API section that was marked as legacy
  - Removed backward compatibility methods that were replaced by more robust alternatives
  - Streamlined API to focus on modern, event-driven workflows

### Technical
- **Code Cleanup**: Removed deprecated and legacy code to improve maintainability
- **API Simplification**: Reduced API surface area by removing redundant methods
- **Example App**: Updated example app to focus on modern workflows only

## [2.0.36] - 2025-07-08

### Added
- **SmartPrintManager**: Comprehensive event-driven printing system with step tracking and error classification
  - Real-time events for step changes, errors, retry attempts, and progress updates
  - Automatic error categorization as recoverable, non-recoverable, or unknown
  - Progress tracking with elapsed time and estimated remaining time
  - Enhanced error handling with actionable guidance for users
  - Event-driven UI components that consume events from SmartPrintManager
- **PrintEvent System**: Complete event system for print operations
  - `PrintStep` enumeration: initializing, connecting, connected, sending, completed, failed, cancelled
  - `ErrorRecoverability` classification: recoverable, nonRecoverable, unknown
  - `PrintEventType` events: stepChanged, errorOccurred, retryAttempt, progressUpdate, completed, cancelled
  - `PrintStepInfo`, `PrintErrorInfo`, `PrintProgressInfo` data classes
  - Broadcast stream of `PrintEvent` objects with comprehensive metadata
- **Enhanced Retry Information**: Comprehensive retry tracking and display
  - `PrintStepInfo` properties: `isRetry`, `retryCount`, `isFinalAttempt`, `