# Changelog

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