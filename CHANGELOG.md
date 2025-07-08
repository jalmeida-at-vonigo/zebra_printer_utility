# Changelog

## [2.0.40] - 2024-12-19

### Fixed
- **Error Code Centralization**: Eliminated all hardcoded error and success strings throughout the codebase
- **SmartPrintManager**: Replaced hardcoded error code comparisons with ErrorCodes constants
- **ZebraPrinter**: Replaced hardcoded 'DISCOVERY_ERROR' and 'SCAN_ERROR' with ErrorCodes constants
- **Mobile Service**: Replaced hardcoded error strings with centralized ErrorCodes constants
- **Readiness Manager**: Replaced hardcoded 'OPERATION_ERROR' with ErrorCodes.operationError

### Enhanced
- **Code Quality**: All error and success codes now use centralized constants from result.dart
- **Maintainability**: Single source of truth for all error and success codes
- **Consistency**: Uniform error handling across all components
- **Documentation**: Added comprehensive error-code-centralization.mdc Cursor rule

### Technical
- **Architecture**: Enforced centralized error code management pattern
- **Standards**: All error/success strings must be defined in result.dart only
- **Validation**: Analyzer confirms no hardcoded error strings remain
- **Enforcement**: Cursor rule prevents future hardcoded error strings

## [2.0.39] - 2024-12-19

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
  - `PrintStepInfo` properties: `isRetry`, `retryCount`, `isFinalAttempt`, `progress`
  - Detailed retry messages: "Retry X of Y - Z attempts remaining" or "Final attempt"
  - Visual retry indicators in UI with retry count and attempt information
  - Retry information displayed in progress panel, error panel, and main status

### Features
- **Step Tracking**: Tracks all print operation states with detailed messages
- **Automatic Retry**: Intelligently retries recoverable errors (connection issues, timeouts)
- **Error Classification**: Analyzes error messages to determine recoverability
- **Progress Visualization**: Shows progress bar, current operation, and time estimates
- **Comprehensive Logging**: Detailed logging of all print operations and events
- **Retry Visibility**: Prominent display of retry attempts with clear countdown and status

### UI Enhancements
- **Retry Indicator**: Dedicated retry badge showing "Retry X of Y" with warning color
- **Progress Panel**: Enhanced with retry count display alongside time information
- **Error Panel**: Shows retry attempt information when errors occur during retries
- **Status Messages**: Detailed retry messages with remaining attempts or final attempt indication

### Technical
- **Event Stream**: Broadcast stream of PrintEvent objects with step, error, and progress information
- **Timeout Handling**: Configurable connection and print timeouts with proper error handling
- **Resource Management**: Proper disposal of timers and stream controllers
- **Thread Safety**: Safe event emission and state management
- **Retry Tracking**: Comprehensive retry state management with attempt counting and final attempt detection

## [2.0.35] - 2025-01-07

### Fixed
- **Printer Name Display**: Fixed "Unknown Printer" issue in example apps
  - Corrected key name mismatch between native iOS code and Dart side
  - Updated ZSDKWrapper to send correct uppercase keys (`Address`, `Name`, `Status`, `IsWifi`)
  - Fixed network discovery to use proper key names
  - Restored printer name display functionality to match version 2.0.32
- **Connection Logic**: Restored simple connection logic to match version 2.0.32
  - Removed complex printer lookup logic that was causing connection issues
  - Fixed address parsing logic to properly distinguish between network and Bluetooth addresses
  - Network addresses contain "." (IP address), Bluetooth addresses contain ":" but no "."
  - Native iOS code now correctly determines connection type based on address format

### Technical Details
- Root cause was key name mismatch: Dart expected `Address`, `Name`, `Status`, `IsWifi` but native code sent `address`, `name`, `status`, `isWifi`
- Connection logic restored to simple approach that was working in version 2.0.32
- Address parsing logic fixed to properly identify network vs Bluetooth connections
- All changes maintain backward compatibility while restoring working functionality

## [2.0.34] - 2025-01-05

### Added
- **Official ZSDK MFi Bluetooth Implementation**: Complete MFi Bluetooth support using official ZSDK
  - MFi Bluetooth discovery using ExternalAccessory framework and ZSDK
  - Network discovery using ZSDK NetworkDiscoverer for enhanced reliability
  - Enhanced Zebra branding with rich printer information
  - Model information, manufacturer details, firmware and hardware revision
  - Connection type identification (MFi Bluetooth vs Network)
- **Enhanced Printer Information**: Rich printer discovery data
  - Zebra brand identification and display names
  - Model information for better printer identification
  - Manufacturer details and firmware version information
  - Hardware revision and connection type details
  - Improved printer selection UI with enhanced information display

### Changed
- **iOS Native Implementation**: Refactored to use only official ZSDK APIs
  - Removed all CoreBluetooth usage in favor of ZSDK MFi Bluetooth
  - Updated `ZSDKWrapper` to include MFi Bluetooth discovery methods
  - Enhanced network discovery using ZSDK NetworkDiscoverer
  - Improved printer information extraction and formatting
- **Printer Discovery**: Enhanced discovery with rich Zebra information
  - Network printers now include Zebra branding and model information
  - MFi Bluetooth printers include comprehensive device details
  - Better printer identification and user experience
- **UI Enhancements**: Updated printer selection popup with enhanced information
  - Display Zebra brand and model information prominently
  - Show connection type (MFi Bluetooth vs Network)
  - Improved visual hierarchy and information presentation

### Fixed
- **iOS Build Issues**: Resolved all Swift compiler errors and warnings
  - Fixed method signature issues in ZSDKWrapper
  - Resolved availability annotation problems
  - All iOS builds pass without errors or warnings
- **Lint and Analysis**: Fixed all lint errors and analysis warnings
  - Updated ZebraDevice model to include new properties
  - Fixed all Flutter analysis warnings
  - All tests pass with no warnings or errors

### Technical Details
- MFi Bluetooth discovery uses ExternalAccessory framework with ZSDK integration
- Network discovery enhanced with ZSDK NetworkDiscoverer for better reliability
- Rich printer information includes brand, model, manufacturer, firmware, and hardware details
- All changes maintain backward compatibility while providing enhanced user experience
- iOS implementation now uses only official ZSDK APIs for maximum compatibility

## [2.0.33] - 2025-01-05

### Added
- **Smart Device Discovery and Selection**: Implemented intelligent printer discovery and selection system
  - `SmartDeviceSelector` class for optimal printer selection based on multiple criteria
  - Prioritizes previously selected printers, WiFi over BLE, and higher model priority
  - Connection success history tracking for reliability-based selection
  - Persistent storage of printer preferences and connection history
- **Enhanced Printer Selection Popup**: Completely redesigned popup-based printing workflow
  - Visual hierarchy with previously selected printer prominently displayed
  - Compact layout with other printers as boxes and expandable list
  - One-tap printing with immediate feedback and status updates
  - Real-time connection and print status with animated progress indicators
  - Clear success/failure feedback with visual cues and error messages
  - Smooth animations and transitions for enhanced user experience
- **Printer Preferences System**: Added persistent storage for printer selection and connection history
  - `PrinterPreferences` class for managing last selected printer and connection success counts
  - Automatic saving of successful printer selections for future use
  - Connection history tracking to improve reliability-based selection
  - Configurable preference for WiFi vs BLE connections

### Changed
- **iOS Native Code**: Removed all MFi (Made for iPhone) dependencies
  - Eliminated Bluetooth Classic and ExternalAccessory framework usage
  - Implemented BLE and WiFi-only discovery and connection
  - Fixed Swift compiler error with `NWInterface.address` property
  - Updated network discovery to use service name-based addressing
- **Printing Workflow**: Popup-based printing is now the only print flow
  - Removed fallback to `simplifiedPrint` method
  - All printing goes through the enhanced popup interface
  - Improved error handling and user feedback
  - Smart printer saving only when selection changes
- **ZebraPrinterService**: Updated to use new popup-based workflow
  - `print()` method now requires BuildContext for popup display
  - Removed automatic fallback mechanisms
  - Enhanced error handling and status reporting

### Fixed
- **iOS Build Issues**: Fixed Swift compiler error in network discovery
  - Replaced invalid `NWInterface.address` usage with service name-based addressing
  - Updated network discovery logic to work with mDNS/Bonjour services
- **Lint and Analysis**: Fixed all lint errors and analysis warnings
  - Removed unnecessary braces in string interpolation
  - Fixed unreachable switch default cases in readiness manager
  - Updated super parameter usage in example code
  - All tests pass with no warnings or errors

### Technical Details
- Smart device selection uses scoring algorithm based on connection type, history, and model priority
- Printer preferences are stored using SharedPreferences for persistence across app sessions
- Popup provides comprehensive visual feedback with connection status, print progress, and error handling
- iOS native code now supports only BLE and WiFi connections, avoiding MFi requirements
- All changes maintain backward compatibility while providing enhanced user experience

## [2.0.32] - 2025-01-03

### Documentation
- **Comprehensive Documentation**: Updated all documentation to include `simplifiedPrint` method
  - Added detailed examples in README.md with workflow explanation
  - Updated API reference with complete method documentation
  - Added usage examples for different scenarios (auto-detection, specific format, address)
  - Updated best practices to recommend `simplifiedPrint` for simplest use cases
  - Enhanced example app documentation to highlight new feature

### Technical Details
- No code changes - documentation updates only
- All examples tested and verified
- Maintains backward compatibility

## [2.0.31] - 2025-01-03

### Added
- **Simplified Print Workflow**: Added `simplifiedPrint` method to `Zebra` class for streamlined printing
  - Single-call workflow that handles discovery, connection, and printing
  - Maintains connection between prints by default (`disconnectAfter = false`)
  - Smart connection management that checks if already connected to target printer
  - Proper delays after connection to ensure printer readiness
  - Support for both ZPL and CPCL formats with auto-detection

### Fixed
- **Connection State Management**: Fixed alternating print failure issue in simplified workflow
  - Eliminated unnecessary disconnections between prints
  - Added proper connection verification before printing
  - Implemented connection state checking to avoid redundant connections
  - Added stability delays after new connections

### Changed
- **Default Behavior**: Changed `disconnectAfter` default to `false` in `simplifiedPrint` to maintain connection
- **Connection Logic**: Improved connection handling to check if already connected to target printer
- **Error Handling**: Enhanced error messages for better debugging

### Technical Details
- `simplifiedPrint` now properly manages printer connection state
- Connection is only established if not already connected to the target printer
- 250ms delay after new connections ensures printer stability
- No breaking changes to existing API

## [2.0.30] - 2025-01-03

### Added
- **Command Architecture**: Implemented clean command architecture with format-specific commands
  - One command per file with descriptive naming (e.g., `SendZplClearBufferCommand`, `SendCpclClearBufferCommand`)
  - `CommandFactory` pattern for centralized command creation
  - Automatic format selection based on detected printer language
- **Format-Specific Commands**: Properly separated ZPL and CPCL commands
  - `SendZplClearBufferCommand` / `SendCpclClearBufferCommand`
  - `SendZplClearErrorsCommand` / `SendCpclClearErrorsCommand`
  - `SendZplFlushBufferCommand` / `SendCpclFlushBufferCommand`
  - `SendSetZplModeCommand` / `SendSetCpclModeCommand`
  - `SendClearAlertsCommand` for generic alert clearing
- **Comprehensive Unit Tests**: Added unit tests for all command classes
  - Tests for CommandFactory and all format-specific commands
  - Proper test structure with `TestWidgetsFlutterBinding.ensureInitialized()`
  - Coverage for command strings and operation names

### Changed
- **ZebraSGDCommands Refactoring**: Converted to utility-only class
  - Removed all command string methods (`getCommand`, `setCommand`, `doCommand`, etc.)
  - Kept only utility methods: `isZPLData`, `isCPCLData`, `detectDataLanguage`, `parseResponse`, `isLanguageMatch`
  - Updated all usages to use CommandFactory instead
- **Command Pattern Enforcement**: Updated all printer operations to use CommandFactory
  - Replaced direct ZebraSGDCommands usage with proper command instances
  - Updated `zebra_printer.dart` to use CommandFactory for mode setting
  - Updated `zebra_printer_readiness_manager.dart` to use format-specific commands
- **Cursor Rules**: Added comprehensive development rules
  - Command file architecture rules (one command per file)
  - ZebraSGDCommands utility-only usage rules
  - Format-specific command naming and usage rules

### Technical Details
- All commands now follow the one-command-per-file pattern
- Command strings are defined within their respective command classes
- CommandFactory serves as the single source for command creation
- Automatic format detection ensures correct command selection
- No breaking changes to public API - all changes are internal architecture improvements

## [2.0.29] - 2025-07-03
### Changed
- **Major Refactoring**: Renamed `AutoCorrectionOptions` to `ReadinessOptions` for better semantic clarity
- **Architecture Improvement**: Moved `PrinterStateManager` to `PrinterReadinessManager` with enhanced functionality
- **Command Pattern Implementation**: Introduced comprehensive command pattern for printer operations
  - Added 15 new command classes for specific printer operations
  - Implemented `CommandFactory` for centralized command creation
  - Created `BaseCommand` abstract class for consistent command structure
- **Enhanced Readiness Management**: 
  - Renamed `checkPrinterReadiness` to `correctForPrinting` for clarity
  - Added `ReadinessResult` model for detailed correction feedback
  - Improved error handling and status reporting in readiness operations
- **API Consistency**: Updated all references to use new naming conventions
- **Test Updates**: Updated all tests to use new class names and methods
- **Documentation**: Updated API documentation to reflect new naming and structure
- All tests pass; no breaking changes to public API functionality

## [2.0.28] - 2025-07-03
### Changed
- Comprehensive DRY refactoring of status-related calls across `PrinterStateManager`
- Created dedicated helper methods for common status queries:
  - `_getHostStatus()` for `device.host_status`
  - `_getPauseStatus()` for `device.pause`
  - `_getPrinterLanguage()` for `device.languages`
- Eliminated duplicate status calls in `_performPrePrintCorrections`, `checkPrinterReadiness`, `runDiagnostics`, and `switchLanguageForData` methods
- Removed unused SGD command constants from `ZebraSGDCommands` class
- Preserved original exception behavior in helper methods to maintain test compatibility
- Improved code maintainability by centralizing status retrieval logic
- Fixed logger test expectations to match actual logger format
- Cleaned up trailing whitespace in modified files
- All tests pass; no breaking changes to public API

## [2.0.27] - 2025-07-03
### Changed
- Optimized `autoPrint` workflow to eliminate redundant readiness checks and corrections
- Removed `_ensurePrinterReady` method as `print()` method already handles all readiness checks
- Replaced full readiness check with direct connection check (`isPrinterConnected()`) in `autoPrint`
- Reduced readiness checks from 3+ per autoPrint to 0 (connection check only)
- Improved performance by eliminating duplicate correction attempts and unnecessary status queries
- All tests pass; no breaking changes to public API

## [2.0.26] - 2025-07-03
### Changed
- Moved `runDiagnostics` method to `PrinterStateManager` as a responsibility
- Made `doGetSetting` private again (`_doGetSetting`) as it's primarily used internally
- Further consolidated state and diagnostic operations in `PrinterStateManager`
- `ZebraPrinterService.runDiagnostics()` now delegates to `PrinterStateManager`
- All tests pass; no breaking changes to public API

## [2.0.25] - 2025-07-03
### Changed
- Moved `checkPrinterReadiness` method to `PrinterStateManager` as a responsibility
- Improved architecture by consolidating state-related operations in one place
- `ZebraPrinterService.checkPrinterReadiness()` now delegates to `PrinterStateManager`
- Added `doGetSetting` public method to `PrinterStateManager` for advanced usage
- All tests pass; no breaking changes to public API

## [2.0.24] - 2025-07-03
### Changed
- Moved PrinterStateManager to `lib/zebra_printer_state_manager.dart` (was `lib/internal/printer_state_manager.dart`)
- Exposed PrinterStateManager via `zebrautil.dart` for advanced/low-level state, readiness, and buffer management
- Updated documentation and API reference to reflect new location and usage
- All tests and analysis pass; no breaking changes

## [2.0.23] - 2024-12-20
### Fixed
- Fixed connection state synchronization issue where UI showed "pending to connect" while logs showed "Connected"
- Fixed index out of bounds error in updatePrinterStatus when printer not found in list
- Ensured connected printer is added to the device list before updating its status
- Improved connection state management between native code and Flutter UI

## [2.0.22] - 2024-12-20
### Fixed
- Properly implemented buffer clearing using sendCommand instead of print
- Buffer clearing now uses ESC and CAN characters for CPCL, and ~JA for ZPL
- ETX character is sent as a command after CPCL printing for proper termination
- Removed all instances of control characters being sent as print data
- Fixed tests to reflect proper buffer clearing implementation

## [2.0.21] - 2024-12-20
### Fixed
- Fixed CPCL printing issues where "^XZ" was being printed on labels
- Removed ZPL termination commands from CPCL print flow
- Simplified CPCL termination to use only line feeds for buffer flushing
- Disabled buffer clearing temporarily to prevent interference with printing

## [2.0.20] - 2025-01-03

### Added
- Integrated buffer clearing into AutoCorrector for more reliable printing
- Added `enableBufferClear` option to AutoCorrectionOptions
- New factory constructors for AutoCorrectionOptions:
  - `AutoCorrectionOptions.print()` - Optimized for regular print operations
  - `AutoCorrectionOptions.autoPrint()` - Optimized for autoPrint operations with all safety features
- Added `autoCorrectionOptions` parameter to print method for fine-grained control

### Changed
- Default behavior for `print()` method now includes basic auto-corrections (unpause, clear errors, language switch)
- Default behavior for `autoPrint()` method now uses comprehensive auto-corrections including buffer clearing
- Buffer is always cleared for CPCL printing to prevent cut-off issues
- Improved pre-print checks to ensure printer is in clean state

### Technical Details
- Based on Zebra SDK best practices, buffer clearing is essential for CPCL reliability
- Pre-print corrections prevent common issues like paused printers or pending data
- Language switching ensures print data format matches printer mode

## [2.0.19] - 2025-01-03

### Fixed
- Fixed CPCL printing cut-off issue based on Zebra developer forum insights
- Implemented separate packet transmission for CPCL termination sequences
- Send ETX (`\x03`) and `^XZ` as separate packets to release print engine
- Increased CPCL transmission delay to 1 second in iOS native code
- Added `clearPrinterBuffer()` method to clear any pending data before printing

### Added
- Optional `clearBufferFirst` parameter in print method to clear printer state
- Comprehensive buffer clearing that sends ETX, ^XZ, and CAN characters

### Technical Details
- Based on Zebra forum findings: the printer's print engine waits for data until it receives proper termination
- ETX character must be sent as a separate packet, not concatenated with print data
- This ensures the printer processes all CPCL data before considering the operation complete

## [2.0.18] - 2025-01-03

### Fixed
- Fixed CPCL printing cut-off issue by ensuring complete data transmission
- Added ETX (End of Text) character to CPCL data for proper termination
- Implemented transmission delays in iOS native code for CPCL data
- Added flushPrintBuffer() method to ensure all buffered data is processed
- Enhanced iOS ZSDK wrapper to verify connection after CPCL writes
- Added extra safeguards to prevent premature connection closure during CPCL printing

## [2.0.17] - 2025-01-03

### Fixed
- Further improvements to prevent print cut-off issues
- Added extra line feeds for CPCL to ensure buffer flush
- Removed all status queries during printing (including odometer tracking)

### Changed
- Simplified print completion to use delay-based approach only
- Increased base delays: CPCL 2500ms, ZPL 2000ms
- Added dynamic delay calculation based on data size (1s extra per KB)
- Increased disconnect delay to 3000ms to ensure complete processing

### Added
- `sendSGDCommand()` method for sending raw SGD commands
- `flushPrintBuffer()` method to ensure print buffer is processed
- Buffer flush line feeds for CPCL format to prevent truncation

### Improved
- Print reliability by completely avoiding any printer queries during active printing
- Dynamic delay calculation ensures larger print jobs get adequate processing time
- Better CPCL handling with proper termination and buffer flushing

## [2.0.16] - 2025-01-03

### Fixed
- **Critical**: Fixed print cut-off issue caused by status queries interrupting active print jobs
- Removed device status checking during print operations as per Zebra SDK best practices
- Status queries (device.host_status, device.print_state, device.buffer_full) can cause the printer to pause mid-print

### Changed
- Replaced intrusive status checking with odometer-based print tracking for ZPL
- Increased default print completion delays (ZPL: 1500ms, CPCL: 2000ms)
- Simplified print completion verification to avoid interrupting print jobs
- Removed status checking before disconnect to prevent print interruption

### Improved
- Print reliability by following Zebra SDK recommendation to avoid status queries during printing
- CPCL printing stability with longer default completion delay
- Overall print completion without cut-off issues

## [2.0.15] - 2025-01-03

### Fixed
- Fixed deprecated `color.alpha` usage in tests - now using `color.a * 255.0`
- Cleaned up exports in zebrautil.dart to use explicit show clauses
- Removed unnecessary hide clauses that were hiding the main classes
- Added missing PrinterMode export to print_enums exports

### Changed
- Improved test architecture to avoid operation manager timeout issues
- Removed integration tests that require plugin registration
- Focused unit tests on testable components without async operation dependencies
- Marked async operation tests as skipped with clear explanations

### Improved
- Test execution now completes in ~6 seconds instead of timing out
- All 223 tests passing with no lint warnings or analysis issues
- Better separation between unit tests and integration tests

## [2.0.14] - 2025-01-02

### Fixed
- Fixed CPCL printing being cut off in the middle by ensuring proper line endings (\r\n)
- Added automatic PRINT command if CPCL data ends with FORM but missing PRINT
- Improved print completion verification for regular print method
- Print method now waits for printer to be idle before returning success

### Changed
- Regular print method now verifies printer completion by checking device status
- Default print completion delay is now 1500ms for CPCL (vs 1000ms for ZPL)
- Print method checks multiple status indicators (host_status, print_state, buffer_full)
- Waits up to 10 seconds for printer to become idle after sending data

### Added
- Automatic CPCL line ending conversion from \n to \r\n
- Print completion verification using printer status checking
- Warning messages for malformed CPCL data

## [2.0.13] - 2025-01-02

### Fixed
- Fixed printing getting cut off on the last line by adding configurable print completion delay
- Added comprehensive printer idle check before disconnecting to ensure all data is processed
- Default delay increased from 0ms to 1000ms to prevent truncated prints

### Added
- New `printCompletionDelay` parameter in autoPrint to customize wait time before disconnect
- Comprehensive printer busy detection checking multiple status indicators:
  - `device.host_status` for general busy states
  - `device.print_state` for active printing status
  - `device.buffer_full` for pending data in buffer
- New `isStatusBusy()` method in ParserUtil for detecting busy printer states
- Automatic retry loop (up to 5 seconds) waiting for printer to become idle

## [2.0.12] - 2025-01-02

### Fixed
- Fixed autoPrint not automatically connecting when an address is provided but printer is not connected
- Simplified autoPrint connection logic to ensure proper connection flow
- Fixed all Flutter lint issues including deprecated color.value usage and missing const constructors

### Changed
- Improved autoPrint logic to properly handle connection state when address is provided
- Fixed unnecessary imports and added const constructors throughout test files

## 2.0.10 - 2024-12-20

### Added
- Logger utility for consistent logging across the plugin
- Logger exports to zebrautil.dart for external usage

### Fixed
- Removed all TODO comments by implementing proper functionality
- Fixed getSetting implementation in ZebraPrinterService
- Implemented language switching in AutoCorrector
- Cleaned up all lint warnings and errors
- Removed unused imports and fields

### Changed
- Updated example app to use debugPrint instead of print
- Improved error logging with structured Logger class

## 2.0.9
- **Major Architecture Improvement**: Implemented callback-based operations framework
  - All native operations now use real callbacks instead of artificial delays
  - Each operation has a unique ID for tracking and proper callback routing
  - Removed ZebraOperationQueue in favor of natural async/await sequencing
  - Operations complete based on actual device state, not arbitrary timeouts
- **iOS Implementation**: Added operation ID support to all method handlers
  - All callbacks now include operation IDs for proper routing
  - Improved error handling with operation-specific callbacks
- **Performance**: Removed unnecessary delays, operations complete as fast as the hardware allows
- **Reliability**: Operations can no longer be left in pending state
- **Internal**: Extracted operation management into reusable internal framework

## 2.0.8
- **New Feature**: Added `StateChangeVerifier` utility for operations without callbacks
  - Intelligently verifies state changes instead of using fixed delays
  - Checks if state is already correct before sending commands (no-op optimization)
  - Retries up to 3 times with configurable delays
  - Provides better error messages when operations fail
- **Improvements**: 
  - Added `getSetting()` method to ZebraPrinter for reading printer settings
  - Added `setPrinterMode()` example showing verified mode switching
  - Updated AutoCorrector to use StateChangeVerifier for more reliable corrections
- **Examples**: Operations that benefit from StateChangeVerifier:
  - Mode switching (ZPL/CPCL)
  - Pause/unpause operations
  - Calibration verification
  - Any SGD setting changes

## [2.0.7] - 2024-12-20

### Added
- Integration of print completion callbacks with operation queue system
- Operation-specific completion tracking using operation IDs
- Proper callback-based print completion linked to calling context

### Changed
- Replaced global callback handler with operation-specific completion tracking
- Print operations now use native `onPrintComplete`/`onPrintError` callbacks instead of artificial delays
- Improved print completion accuracy using native printer feedback

### Fixed
- Print completion callbacks are now properly linked to their calling operations
- Removed artificial delays in favor of actual printer completion signals
- Better error handling for print operation timeouts

## [2.0.6] - 2024-12-20

### Added
- Callback-based print completion using native `onPrintComplete` and `onPrintError` events
- New `printWithCallback()`