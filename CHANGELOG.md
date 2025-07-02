# Changelog

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
- New `printWithCallback()` method that waits for actual print completion
- Print operation timeout handling (30 seconds)

### Fixed
- Replaced artificial 2-second delay with proper print completion callbacks
- More reliable print completion detection using native printer feedback
- Improved print timing accuracy

## [2.0.5] - 2024-12-19

### Fixed
- Fixed autoPrint not reconnecting when printer gets disconnected during print
- Added connection verification before each print attempt in retry logic
- Added automatic reconnection when connection is lost during print retries
- Improved connection verification with better status messages
- Added forceReconnect method for manual reconnection when needed
- Fixed connection state synchronization between printer and internal state

### Added
- Automatic reconnection logic in _printWithRetry method
- Better error handling and status messages for connection issues
- Connection verification before each print attempt

## [2.0.4] - 2024-12-19

### Fixed
- Fixed autoPrint disconnecting before print operation completes
- Added delay after printing to ensure operation completes before disconnection
- Fixed autoPrint reconnecting unnecessarily when already connected to the right printer
- Improved connection management to avoid "Not connected to printer" errors
- Added proper connection verification before attempting print operations

## [2.0.3] - 2024-12-19

### Fixed
- Fixed type casting error in operation queue causing print operations to fail
- Fixed `Future<dynamic>` to `Future<bool>` type cast issue in `ZebraOperationQueue.enqueue`
- Added proper type conversion using Completer to handle generic return types

## [2.0.2] - 2024-12-19

### Fixed
- Fixed print operations failing due to Result type handling in operation implementations
- Fixed disconnect operation not returning proper Result type
- Added directPrint method for testing without operation queue
- Temporarily disabled getSetting calls to isolate printing issues
- Fixed return type handling in _doSetSetting, _doSetPrinterMode, and _doCheckStatus methods

### Added
- Test buttons in simplified screen to help diagnose printing issues
- Direct print method that bypasses operation queue for debugging

## [2.0.1] - 2024-01-XX

### Fixed
- Standardized getInstance to expect String (iOS returns UUID string)
- Improved ZSDK compatibility by using SGD commands instead of ZPL-specific commands
- Auto-correction commands now work in both ZPL and CPCL modes
- Replaced `~JR` (ZPL) with `alerts.clear` (SGD) for clearing errors
- Removed redundant `~PS` command, using only SGD `device.pause = 0`

## [2.0.0] - 2024-01-XX

### Added
- **Configurable Auto-Correction System**
  - New `AutoCorrectionOptions` class for fine-grained control
  - Factory methods: `.safe()`, `.all()`, `.none()`
  - Individual flags for each correction type
  - Configurable retry attempts and delays
  
- **Robust Parser Utilities**
  - New `ParserUtil` class that never fails
  - Handles multiple boolean formats ('true', 'on', '1', 'yes', etc.)
  - Smart status interpretation for media, head, and error states
  - Safe number extraction from strings

- **Internal Architecture Improvements**
  - Created `lib/internal/` folder for implementation details
  - New `AutoCorrector` class handles all correction logic
  - Better separation of concerns

- **Enhanced Auto-Corrections**
  - Auto-unpause paused printers
  - Clear recoverable errors
  - Reconnect on connection loss
  - Auto-switch printer language based on data format
  - Auto-calibrate on media detection issues

- **Comprehensive Documentation**
  - Architecture diagram and detailed documentation
  - Usage examples for all scenarios
  - Parser capabilities documentation

### Changed
- `autoPrint` now accepts optional `AutoCorrectionOptions` parameter
- Printer readiness checks now use `ParserUtil` for robust parsing
- Version numbering scheme: patch versions for each significant change in v2.0+

### Fixed
- More reliable pause detection (handles '1', 'on', 'true' values)
- Better error message extraction from printer status
- Safer parsing that never throws exceptions

## Previous Versions

See [.readme/development/CHANGELOG.md](.readme/development/CHANGELOG.md) for pre-2.0 versions. 