# Printer Readiness Manager & Commands Architecture Refactor Plan

## Progress Tracking
**Started**: 1:05 AM  
**Current Time**: 1:05 AM  
**Total Estimated Time**: 4-5 hours  
**Expected Completion**: 5:05-6:05 AM

### Phase 1: New Commands Architecture (1.5 hours) - COMPLETED
- [x] **Task 1.1**: Create Commands Base Classes - COMPLETED (1:10 AM)
- [x] **Task 1.2**: Implement Atomic Printer Commands - COMPLETED (1:25 AM)
- [x] **Task 1.3**: Create Command Factory - COMPLETED (1:30 AM)

### Phase 2: ReadinessOptions Model (30 minutes) - COMPLETED
- [x] **Task 2.1**: Create ReadinessOptions Class - COMPLETED (1:35 AM)
- [x] **Task 2.2**: Create ReadinessResult Class - COMPLETED (1:40 AM)

### Phase 3: PrinterReadinessManager Implementation (2 hours) - COMPLETED
- [x] **Task 3.1**: Create PrinterReadinessManager Class - COMPLETED (1:45 AM)
- [x] **Task 3.2**: Implement Simple Private Check/Fix Methods - COMPLETED (2:00 AM)
- [x] **Task 3.3**: Implement Main Readiness Method - COMPLETED (2:05 AM)
- [x] **Task 3.4**: Implement Diagnostics Using Commands - COMPLETED (2:10 AM)

### Phase 4: Integration and Migration (1 hour) - COMPLETED
- [x] **Task 4.1**: Update ZebraPrinter to Use New Manager - COMPLETED (2:15 AM)
- [x] **Task 4.2**: Update ZebraPrinterService - COMPLETED (2:20 AM)

### Phase 5: Remove Old Architecture (30 minutes) - IN PROGRESS
- [x] **Task 5.1**: Remove PrinterStateManager - COMPLETED (2:25 AM)
- [x] **Task 5.2**: Remove AutoCorrectionOptions - STARTED (2:25 AM)
- [ ] **Task 5.3**: Update Exports
- [ ] **Task 5.4**: Update Imports

### Phase 6: Testing and Documentation (1 hour)
- [ ] **Task 6.1**: Create Unit Tests
- [ ] **Task 6.2**: Update Documentation

## Overview
Implement the new architectural approach discussed: create a `PrinterReadinessManager` that consolidates all readiness operations into a single options-based operation, and implement the new commands architecture for better separation of concerns.

## Goals
- Create a unified `PrinterReadinessManager` that handles all readiness operations
- Implement new commands architecture for atomic printer operations
- Consolidate readiness checking and fixing into single operations
- Improve maintainability and reduce code duplication
- **Full migration** - replace old architecture completely

## Timeline
**Total Estimated Time: 4-5 hours**
- Planning and architecture design: 1 hour
- Implementation: 2.5-3 hours
- Testing and validation: 1 hour

## Detailed Tasks

### Phase 1: New Commands Architecture (1.5 hours)

#### Task 1.1: Create Commands Base Classes
- **Files**: 
  - `lib/internal/commands/base_command.dart`
  - `lib/internal/commands/printer_command.dart`
- **Changes**: Create abstract base classes for command pattern
- **Implementation Details**:
  ```dart
  // base_command.dart
  abstract class BaseCommand<T> {
    Future<Result<T>> execute();
    String get operationName;
  }
  
  // printer_command.dart
  abstract class PrinterCommand<T> extends BaseCommand<T> {
    final ZebraPrinter printer;
    final Logger logger;
    
    PrinterCommand(this.printer) : logger = Logger.withPrefix('PrinterCommand');
  }
  ```
- **ETA**: 30 minutes
- **Dependencies**: None
- **Impact**: High - new architecture foundation

#### Task 1.2: Implement Atomic Printer Commands
- **Files**: `lib/internal/commands/`
- **Commands to implement** (each is a single printer operation):
  - `GetSettingCommand` - Returns `String?` (gets any printer setting)
  - `SendCommandCommand` - Returns `void` (sends any command)
  - `CheckConnectionCommand` - Returns `bool`
  - `GetMediaStatusCommand` - Returns `String?`
  - `GetHeadStatusCommand` - Returns `String?`
  - `GetPauseStatusCommand` - Returns `String?`
  - `GetHostStatusCommand` - Returns `String?`
  - `GetLanguageCommand` - Returns `String?`
  - `SendUnpauseCommand` - Returns `void`
  - `SendClearErrorsCommand` - Returns `void`
  - `SendCalibrationCommand` - Returns `void`
  - `SendClearBufferCommand` - Returns `void`
  - `SendFlushBufferCommand` - Returns `void`
- **Implementation Details**:
  ```dart
  // Example: GetSettingCommand
  class GetSettingCommand extends PrinterCommand<String?> {
    final String setting;
    
    GetSettingCommand(ZebraPrinter printer, this.setting) : super(printer);
    
    @override
    String get operationName => 'Get Setting: $setting';
    
    @override
    Future<Result<String?>> execute() async {
      try {
        final value = await printer.getSetting(setting);
        if (value != null && value.isNotEmpty) {
          final parsed = ZebraSGDCommands.parseResponse(value);
          return Result.success(parsed);
        }
        return Result.success(null);
      } catch (e) {
        return Result.error('Failed to get setting $setting: $e');
      }
    }
  }
  
  // Example: SendUnpauseCommand
  class SendUnpauseCommand extends PrinterCommand<void> {
    SendUnpauseCommand(ZebraPrinter printer) : super(printer);
    
    @override
    String get operationName => 'Send Unpause Command';
    
    @override
    Future<Result<void>> execute() async {
      try {
        printer.sendCommand('! U1 setvar "device.pause" "false"');
        return Result.success();
      } catch (e) {
        return Result.error('Failed to send unpause command: $e');
      }
    }
  }
  ```
- **ETA**: 45 minutes
- **Dependencies**: Task 1.1
- **Impact**: High - core functionality

#### Task 1.3: Create Command Factory
- **File**: `lib/internal/commands/command_factory.dart`
- **Changes**: Factory to create and manage commands with individual methods
- **Implementation Details**:
  ```dart
  class CommandFactory {
    // Individual create methods for each command type
    static GetSettingCommand createGetSettingCommand(
      ZebraPrinter printer,
      String setting,
    ) => GetSettingCommand(printer, setting);
    
    static SendCommandCommand createSendCommandCommand(
      ZebraPrinter printer,
      String command,
    ) => SendCommandCommand(printer, command);
    
    static CheckConnectionCommand createCheckConnectionCommand(
      ZebraPrinter printer,
    ) => CheckConnectionCommand(printer);
    
    static GetMediaStatusCommand createGetMediaStatusCommand(
      ZebraPrinter printer,
    ) => GetMediaStatusCommand(printer);
    
    static GetHeadStatusCommand createGetHeadStatusCommand(
      ZebraPrinter printer,
    ) => GetHeadStatusCommand(printer);
    
    static GetPauseStatusCommand createGetPauseStatusCommand(
      ZebraPrinter printer,
    ) => GetPauseStatusCommand(printer);
    
    static GetHostStatusCommand createGetHostStatusCommand(
      ZebraPrinter printer,
    ) => GetHostStatusCommand(printer);
    
    static GetLanguageCommand createGetLanguageCommand(
      ZebraPrinter printer,
    ) => GetLanguageCommand(printer);
    
    static SendUnpauseCommand createSendUnpauseCommand(
      ZebraPrinter printer,
    ) => SendUnpauseCommand(printer);
    
    static SendClearErrorsCommand createSendClearErrorsCommand(
      ZebraPrinter printer,
    ) => SendClearErrorsCommand(printer);
    
    static SendCalibrationCommand createSendCalibrationCommand(
      ZebraPrinter printer,
    ) => SendCalibrationCommand(printer);
    
    static SendClearBufferCommand createSendClearBufferCommand(
      ZebraPrinter printer,
    ) => SendClearBufferCommand(printer);
    
    static SendFlushBufferCommand createSendFlushBufferCommand(
      ZebraPrinter printer,
    ) => SendFlushBufferCommand(printer);
  }
  ```
- **ETA**: 15 minutes
- **Dependencies**: Task 1.2
- **Impact**: Medium - command management

### Phase 2: ReadinessOptions Model (30 minutes)

#### Task 2.1: Create ReadinessOptions Class
- **File**: `lib/models/readiness_options.dart`
- **Changes**: New options class that consolidates all readiness settings
- **Implementation Details**:
  ```dart
  class ReadinessOptions {
    // Check options
    final bool checkConnection;
    final bool checkMedia;
    final bool checkHead;
    final bool checkPause;
    final bool checkErrors;
    final bool checkLanguage;
    
    // Fix options
    final bool fixPausedPrinter;
    final bool fixPrinterErrors;
    final bool fixMediaCalibration;
    final bool fixLanguageMismatch;
    final bool fixBufferIssues;
    final bool clearBuffer;
    final bool flushBuffer;
    
    // Behavior options
    final Duration checkDelay;
    final int maxAttempts;
    final bool verboseLogging;
    
    // Factory constructors
    factory ReadinessOptions.quick() => ReadinessOptions(
      checkConnection: true,
      checkMedia: true,
      checkHead: true,
      checkPause: true,
      fixPausedPrinter: true,
      fixPrinterErrors: true,
    );
    
    factory ReadinessOptions.comprehensive() => ReadinessOptions(
      checkConnection: true,
      checkMedia: true,
      checkHead: true,
      checkPause: true,
      checkErrors: true,
      checkLanguage: true,
      fixPausedPrinter: true,
      fixPrinterErrors: true,
      fixMediaCalibration: true,
      fixLanguageMismatch: true,
      fixBufferIssues: true,
      clearBuffer: true,
      flushBuffer: true,
    );
    
    factory ReadinessOptions.forPrinting() => ReadinessOptions(
      checkConnection: true,
      checkMedia: true,
      checkHead: true,
      checkPause: true,
      checkErrors: true,
      fixPausedPrinter: true,
      fixPrinterErrors: true,
      clearBuffer: true,
      flushBuffer: true,
    );
  }
  ```
- **ETA**: 20 minutes
- **Dependencies**: None
- **Impact**: High - new options model

#### Task 2.2: Create ReadinessResult Class
- **File**: `lib/models/readiness_result.dart`
- **Changes**: New result class for readiness operations
- **Implementation Details**:
  ```dart
  class ReadinessResult {
    final bool isReady;
    final PrinterReadiness readiness;
    final List<String> appliedFixes;
    final List<String> failedFixes;
    final Map<String, String> fixErrors;
    final Duration totalTime;
    final DateTime timestamp;
    
    // Computed properties
    bool get hasFixes => appliedFixes.isNotEmpty;
    bool get hasFailedFixes => failedFixes.isNotEmpty;
    String get summary => 'Ready: $isReady, Fixes: ${appliedFixes.length}, Failed: ${failedFixes.length}';
    
    // Factory constructor
    factory ReadinessResult.fromReadiness(
      PrinterReadiness readiness,
      List<String> appliedFixes,
      List<String> failedFixes,
      Map<String, String> fixErrors,
      Duration totalTime,
    ) => ReadinessResult(
      isReady: readiness.isReady,
      readiness: readiness,
      appliedFixes: appliedFixes,
      failedFixes: failedFixes,
      fixErrors: fixErrors,
      totalTime: totalTime,
      timestamp: DateTime.now(),
    );
  }
  ```
- **ETA**: 10 minutes
- **Dependencies**: Task 2.1
- **Impact**: Medium - result handling

### Phase 3: PrinterReadinessManager Implementation (2 hours)

#### Task 3.1: Create PrinterReadinessManager Class
- **File**: `lib/zebra_printer_readiness_manager.dart`
- **Changes**: New manager class that consolidates all readiness operations
- **Implementation Details**:
  ```dart
  class PrinterReadinessManager {
    final ZebraPrinter _printer;
    final Logger _logger = Logger.withPrefix('PrinterReadinessManager');
    final void Function(String)? _statusCallback;
    final CommandFactory _commandFactory;
    
    PrinterReadinessManager({
      required ZebraPrinter printer,
      void Function(String)? statusCallback,
    }) : _printer = printer,
         _statusCallback = statusCallback,
         _commandFactory = CommandFactory();
    
    void _log(String message) {
      _statusCallback?.call(message);
      _logger.debug(message);
    }
  }
  ```
- **ETA**: 45 minutes
- **Dependencies**: Phase 1 complete
- **Impact**: High - new main interface

#### Task 3.2: Implement Simple Private Check/Fix Methods
- **File**: `lib/zebra_printer_readiness_manager.dart`
- **Changes**: Simple private methods that use commands
- **Implementation Details**:
  ```dart
  // Private check methods - each uses a single command
  Future<Result<bool>> _checkConnection() async {
    final command = _commandFactory.createCheckConnectionCommand(_printer);
    return await command.execute();
  }
  
  Future<Result<String?>> _checkMediaStatus() async {
    final command = _commandFactory.createGetMediaStatusCommand(_printer);
    return await command.execute();
  }
  
  Future<Result<String?>> _checkHeadStatus() async {
    final command = _commandFactory.createGetHeadStatusCommand(_printer);
    return await command.execute();
  }
  
  Future<Result<String?>> _checkPauseStatus() async {
    final command = _commandFactory.createGetPauseStatusCommand(_printer);
    return await command.execute();
  }
  
  Future<Result<String?>> _checkHostStatus() async {
    final command = _commandFactory.createGetHostStatusCommand(_printer);
    return await command.execute();
  }
  
  Future<Result<String?>> _checkLanguage() async {
    final command = _commandFactory.createGetLanguageCommand(_printer);
    return await command.execute();
  }
  
  // Private fix methods - each uses a single command
  Future<Result<void>> _fixPausedPrinter() async {
    final command = _commandFactory.createSendUnpauseCommand(_printer);
    return await command.execute();
  }
  
  Future<Result<void>> _fixPrinterErrors() async {
    final command = _commandFactory.createSendClearErrorsCommand(_printer);
    return await command.execute();
  }
  
  Future<Result<void>> _fixMediaCalibration() async {
    final command = _commandFactory.createSendCalibrationCommand(_printer);
    return await command.execute();
  }
  
  Future<Result<void>> _fixBufferIssues() async {
    final command = _commandFactory.createSendClearBufferCommand(_printer);
    return await command.execute();
  }
  
  Future<Result<void>> _flushBuffer() async {
    final command = _commandFactory.createSendFlushBufferCommand(_printer);
    return await command.execute();
  }
  ```
- **ETA**: 45 minutes
- **Dependencies**: Task 3.1
- **Impact**: High - core functionality

#### Task 3.3: Implement Main Readiness Method
- **File**: `lib/zebra_printer_readiness_manager.dart`
- **Method**: `prepareForPrint(ReadinessOptions options)`
- **Changes**: Main method that calls specific check and fix methods
- **Implementation Details**:
  ```dart
  Future<Result<ReadinessResult>> prepareForPrint(
    ReadinessOptions options,
  ) async {
    final stopwatch = Stopwatch()..start();
    _log('Starting printer preparation for print...');
    
    try {
      final appliedFixes = <String>[];
      final failedFixes = <String>[];
      final fixErrors = <String, String>{};
      
      // 1. Check and fix connection
      if (options.checkConnection) {
        await _checkAndFixConnection(appliedFixes, failedFixes, fixErrors);
      }
      
      // 2. Check and fix media
      if (options.checkMedia) {
        await _checkAndFixMedia(appliedFixes, failedFixes, fixErrors);
      }
      
      // 3. Check and fix head
      if (options.checkHead) {
        await _checkAndFixHead(appliedFixes, failedFixes, fixErrors);
      }
      
      // 4. Check and fix pause
      if (options.checkPause) {
        await _checkAndFixPause(appliedFixes, failedFixes, fixErrors);
      }
      
      // 5. Check and fix errors
      if (options.checkErrors) {
        await _checkAndFixErrors(appliedFixes, failedFixes, fixErrors);
      }
      
      // 6. Check and fix language
      if (options.checkLanguage) {
        await _checkAndFixLanguage(appliedFixes, failedFixes, fixErrors);
      }
      
      // 7. Handle buffer operations
      if (options.clearBuffer) {
        await _checkAndFixBuffer(appliedFixes, failedFixes, fixErrors);
      }
      
      if (options.flushBuffer) {
        await _checkAndFixFlush(appliedFixes, failedFixes, fixErrors);
      }
      
      // 8. Create readiness result
      final readiness = await _buildReadinessStatus();
      final result = ReadinessResult.fromReadiness(
        readiness,
        appliedFixes,
        failedFixes,
        fixErrors,
        stopwatch.elapsed,
      );
      
      _log('Printer preparation completed: ${result.summary}');
      return Result.success(result);
      
    } catch (e, stack) {
      _logger.error('Error during printer preparation', e);
      return Result.error(
        'Printer preparation failed: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }
  
  // Individual check and fix methods using printer commands
  Future<void> _checkAndFixConnection(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    final command = _commandFactory.createCheckConnectionCommand(_printer);
    final result = await command.execute();
    
    if (!result.success || result.data == false) {
      failedFixes.add('connection');
      fixErrors['connection'] = result.error?.message ?? 'Connection failed';
      _log('Connection check failed: ${fixErrors['connection']}');
    } else {
      _log('Connection check passed');
    }
  }
  
  Future<void> _checkAndFixMedia(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    final command = _commandFactory.createGetMediaStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      final hasMedia = ParserUtil.hasMedia(result.data);
      if (hasMedia == false) {
        // Try to fix media calibration
        if (_options.fixMediaCalibration) {
          final calibrateCommand = _commandFactory.createSendCalibrationCommand(_printer);
          final calibrateResult = await calibrateCommand.execute();
          
          if (calibrateResult.success) {
            appliedFixes.add('mediaCalibration');
            _log('Media calibration applied');
          } else {
            failedFixes.add('mediaCalibration');
            fixErrors['mediaCalibration'] = calibrateResult.error?.message ?? 'Calibration failed';
            _log('Media calibration failed: ${fixErrors['mediaCalibration']}');
          }
        } else {
          failedFixes.add('media');
          fixErrors['media'] = 'No media detected';
          _log('No media detected');
        }
      } else {
        _log('Media check passed');
      }
    } else {
      failedFixes.add('media');
      fixErrors['media'] = result.error?.message ?? 'Media status check failed';
      _log('Media status check failed: ${fixErrors['media']}');
    }
  }
  
  Future<void> _checkAndFixHead(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    final command = _commandFactory.createGetHeadStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      final headClosed = ParserUtil.isHeadClosed(result.data);
      if (headClosed == false) {
        failedFixes.add('head');
        fixErrors['head'] = 'Print head is open';
        _log('Print head is open');
      } else {
        _log('Head check passed');
      }
    } else {
      failedFixes.add('head');
      fixErrors['head'] = result.error?.message ?? 'Head status check failed';
      _log('Head status check failed: ${fixErrors['head']}');
    }
  }
  
  Future<void> _checkAndFixPause(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    final command = _commandFactory.createGetPauseStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      final isPaused = ParserUtil.toBool(result.data);
      if (isPaused == true) {
        // Try to unpause
        if (_options.fixPausedPrinter) {
          final unpauseCommand = _commandFactory.createSendUnpauseCommand(_printer);
          final unpauseResult = await unpauseCommand.execute();
          
          if (unpauseResult.success) {
            appliedFixes.add('unpause');
            _log('Printer unpaused');
          } else {
            failedFixes.add('unpause');
            fixErrors['unpause'] = unpauseResult.error?.message ?? 'Unpause failed';
            _log('Unpause failed: ${fixErrors['unpause']}');
          }
        } else {
          failedFixes.add('pause');
          fixErrors['pause'] = 'Printer is paused';
          _log('Printer is paused');
        }
      } else {
        _log('Pause check passed');
      }
    } else {
      failedFixes.add('pause');
      fixErrors['pause'] = result.error?.message ?? 'Pause status check failed';
      _log('Pause status check failed: ${fixErrors['pause']}');
    }
  }
  
  Future<void> _checkAndFixErrors(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    final command = _commandFactory.createGetHostStatusCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      if (!ParserUtil.isStatusOk(result.data)) {
        // Try to clear errors
        if (_options.fixPrinterErrors) {
          final clearCommand = _commandFactory.createSendClearErrorsCommand(_printer);
          final clearResult = await clearCommand.execute();
          
          if (clearResult.success) {
            appliedFixes.add('clearErrors');
            _log('Printer errors cleared');
          } else {
            failedFixes.add('clearErrors');
            fixErrors['clearErrors'] = clearResult.error?.message ?? 'Error clearing failed';
            _log('Error clearing failed: ${fixErrors['clearErrors']}');
          }
        } else {
          final errorMsg = ParserUtil.parseErrorFromStatus(result.data) ?? 'Printer error';
          failedFixes.add('errors');
          fixErrors['errors'] = errorMsg;
          _log('Printer has errors: $errorMsg');
        }
      } else {
        _log('Error check passed');
      }
    } else {
      failedFixes.add('errors');
      fixErrors['errors'] = result.error?.message ?? 'Error status check failed';
      _log('Error status check failed: ${fixErrors['errors']}');
    }
  }
  
  Future<void> _checkAndFixLanguage(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    final command = _commandFactory.createGetLanguageCommand(_printer);
    final result = await command.execute();
    
    if (result.success && result.data != null) {
      _log('Current printer language: ${result.data}');
      // Language switching would need data context, so we log but don't apply fixes
      // This would be handled in prepareForPrint with actual data context
    } else {
      failedFixes.add('language');
      fixErrors['language'] = result.error?.message ?? 'Language check failed';
      _log('Language check failed: ${fixErrors['language']}');
    }
  }
  
  Future<void> _checkAndFixBuffer(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    final command = _commandFactory.createSendClearBufferCommand(_printer);
    final result = await command.execute();
    
    if (result.success) {
      appliedFixes.add('clearBuffer');
      _log('Buffer cleared');
    } else {
      failedFixes.add('clearBuffer');
      fixErrors['clearBuffer'] = result.error?.message ?? 'Buffer clear failed';
      _log('Buffer clear failed: ${fixErrors['clearBuffer']}');
    }
  }
  
  Future<void> _checkAndFixFlush(
    List<String> appliedFixes,
    List<String> failedFixes,
    Map<String, String> fixErrors,
  ) async {
    final command = _commandFactory.createSendFlushBufferCommand(_printer);
    final result = await command.execute();
    
    if (result.success) {
      appliedFixes.add('flushBuffer');
      _log('Buffer flushed');
    } else {
      failedFixes.add('flushBuffer');
      fixErrors['flushBuffer'] = result.error?.message ?? 'Buffer flush failed';
      _log('Buffer flush failed: ${fixErrors['flushBuffer']}');
    }
  }
  
  Future<PrinterReadiness> _buildReadinessStatus() async {
    final readiness = PrinterReadiness();
    
    // Build readiness status from the checks we performed
    // This could be enhanced to store state during the check/fix process
    // For now, we'll do a final status check
    
    final connectionResult = await _commandFactory.createCheckConnectionCommand(_printer).execute();
    readiness.isConnected = connectionResult.success ? connectionResult.data : false;
    
    final mediaResult = await _commandFactory.createGetMediaStatusCommand(_printer).execute();
    if (mediaResult.success && mediaResult.data != null) {
      readiness.mediaStatus = mediaResult.data;
      readiness.hasMedia = ParserUtil.hasMedia(mediaResult.data);
    }
    
    final headResult = await _commandFactory.createGetHeadStatusCommand(_printer).execute();
    if (headResult.success && headResult.data != null) {
      readiness.headStatus = headResult.data;
      readiness.headClosed = ParserUtil.isHeadClosed(headResult.data);
    }
    
    final pauseResult = await _commandFactory.createGetPauseStatusCommand(_printer).execute();
    if (pauseResult.success && pauseResult.data != null) {
      readiness.pauseStatus = pauseResult.data;
      readiness.isPaused = ParserUtil.toBool(pauseResult.data);
    }
    
    final hostResult = await _commandFactory.createGetHostStatusCommand(_printer).execute();
    if (hostResult.success && hostResult.data != null) {
      readiness.hostStatus = hostResult.data;
      if (!ParserUtil.isStatusOk(hostResult.data)) {
        final errorMsg = ParserUtil.parseErrorFromStatus(hostResult.data) ?? 
                        'Printer error: ${hostResult.data}';
        readiness.errors.add(errorMsg);
      }
    }
    
    return readiness;
  }
  ```
- **ETA**: 30 minutes
- **Dependencies**: Task 3.2
- **Impact**: High - main operation

#### Task 3.4: Implement Diagnostics Using Commands
- **File**: `lib/zebra_printer_readiness_manager.dart`
- **Methods**: `runDiagnostics()`, `getDetailedStatus()`, `validatePrinterState()`
- **Changes**: Diagnostics should use the command architecture
- **Implementation Details**:
  ```dart
  Future<Result<Map<String, dynamic>>> runDiagnostics() async {
    _log('Running comprehensive diagnostics...');
    
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'connected': false,
      'printerInfo': {},
      'status': {},
      'settings': {},
      'errors': [],
      'recommendations': [],
    };
    
    try {
      // Check connection using command
      final connectionResult = await _checkConnection();
      diagnostics['connected'] = connectionResult.success ? connectionResult.data : false;
      
      if (!diagnostics['connected']) {
        diagnostics['errors'].add('Connection lost');
        diagnostics['recommendations'].add('Reconnect to the printer');
        return Result.success(diagnostics);
      }
      
      // Run comprehensive status checks using commands
      final statusChecks = [
        ('media.status', 'Media Status'),
        ('head.latch', 'Head Status'),
        ('device.pause', 'Pause Status'),
        ('device.host_status', 'Host Status'),
        ('device.languages', 'Printer Language'),
        ('device.unique_id', 'Device ID'),
        ('device.product_name', 'Product Name'),
        ('appl.name', 'Firmware Version'),
      ];
      
      for (final (setting, label) in statusChecks) {
        try {
          final command = _commandFactory.createGetSettingCommand(_printer, setting);
          final result = await command.execute();
          if (result.success && result.data != null) {
            diagnostics['status'][label] = result.data;
          }
        } catch (e) {
          // Continue with other checks
        }
      }
      
      // Analyze and provide recommendations
      _analyzeDiagnostics(diagnostics);
      
      _log('Diagnostics complete');
      return Result.success(diagnostics);
      
    } catch (e, stack) {
      diagnostics['errors'].add('Diagnostic error: $e');
      return Result.error(
        'Failed to run diagnostics: $e',
        code: ErrorCodes.operationError,
        dartStackTrace: stack,
      );
    }
  }
  
  Future<Result<PrinterReadiness>> getDetailedStatus() async {
    final options = ReadinessOptions.comprehensive();
    final readiness = await _checkReadiness(options);
    return Result.success(readiness);
  }
  
  Future<Result<bool>> validatePrinterState() async {
    final result = await getDetailedStatus();
    if (!result.success) {
      return Result.failure(result.error!);
    }
    
    final readiness = result.data!;
    return Result.success(readiness.isReady);
  }
  ```
- **ETA**: 30 minutes
- **Dependencies**: Task 3.3
- **Impact**: Medium - diagnostic capabilities

### Phase 4: Integration and Migration (1 hour)

#### Task 4.1: Update ZebraPrinter to Use New Manager
- **File**: `lib/zebra_printer.dart`
- **Changes**: Integrate PrinterReadinessManager and remove old methods
- **Implementation Details**:
  ```dart
  class ZebraPrinter {
    // ... existing code ...
    
    late final PrinterReadinessManager _readinessManager;
    
    ZebraPrinter({
      required String instanceId,
      void Function(String)? statusCallback,
    }) : _instanceId = instanceId {
      _readinessManager = PrinterReadinessManager(
        printer: this,
        statusCallback: statusCallback,
      );
    }
    
    // New API - replaces all old readiness methods
    Future<Result<ReadinessResult>> prepareForPrint({
      ReadinessOptions? options,
    }) async {
      final opts = options ?? ReadinessOptions.forPrinting();
      return await _readinessManager.prepareForPrint(opts);
    }
    
    Future<Result<Map<String, dynamic>>> runDiagnostics() async {
      return await _readinessManager.runDiagnostics();
    }
    
    Future<Result<PrinterReadiness>> getDetailedStatus() async {
      return await _readinessManager.getDetailedStatus();
    }
    
    Future<Result<bool>> validatePrinterState() async {
      return await _readinessManager.validatePrinterState();
    }
    
    // Remove old methods completely:
    // - checkPrinterReadiness()
    // - correctReadiness()
    // - correctForPrinting()
    // - checkReadinessAndCorrect()
  }
  ```
- **ETA**: 30 minutes
- **Dependencies**: Phase 3 complete
- **Impact**: High - main integration

#### Task 4.2: Update ZebraPrinterService
- **File**: `lib/zebra_printer_service.dart`
- **Changes**: Use new readiness manager and remove old methods
- **Implementation Details**:
  ```dart
  class ZebraPrinterService {
    // ... existing code ...
    
    // New API - replaces all old readiness methods
    Future<Result<ReadinessResult>> prepareForPrint({
      ReadinessOptions? options,
    }) async {
      final printer = await _getPrinterInstance();
      if (printer == null) {
        return Result.error('No printer instance available');
      }
      
      return await printer.prepareForPrint(options: options);
    }
    
    Future<Result<Map<String, dynamic>>> runDiagnostics() async {
      final printer = await _getPrinterInstance();
      if (printer == null) {
        return Result.error('No printer instance available');
      }
      
      return await printer.runDiagnostics();
    }
    
    Future<Result<PrinterReadiness>> getDetailedStatus() async {
      final printer = await _getPrinterInstance();
      if (printer == null) {
        return Result.error('No printer instance available');
      }
      
      return await printer.getDetailedStatus();
    }
    
    Future<Result<bool>> validatePrinterState() async {
      final printer = await _getPrinterInstance();
      if (printer == null) {
        return Result.error('No printer instance available');
      }
      
      return await printer.validatePrinterState();
    }
    
    // Remove old methods completely:
    // - checkPrinterReadiness()
    // - correctReadiness()
    // - correctForPrinting()
    // - checkReadinessAndCorrect()
  }
  ```
- **ETA**: 30 minutes
- **Dependencies**: Task 4.1
- **Impact**: Medium - service layer

### Phase 5: Remove Old Architecture (30 minutes)

#### Task 5.1: Remove PrinterStateManager
- **File**: `lib/zebra_printer_state_manager.dart`
- **Changes**: Delete the entire file
- **ETA**: 5 minutes
- **Dependencies**: Phase 4 complete
- **Impact**: High - removes old architecture

#### Task 5.2: Remove AutoCorrectionOptions
- **File**: `lib/models/auto_correction_options.dart`
- **Changes**: Delete the entire file
- **ETA**: 5 minutes
- **Dependencies**: Task 5.1
- **Impact**: High - removes old options

#### Task 5.3: Update Exports
- **File**: `lib/zebrautil.dart`
- **Changes**: Export new classes and remove old exports
- **Implementation Details**:
  ```dart
  // Export new classes
  export 'zebra_printer_readiness_manager.dart';
  export 'models/readiness_options.dart';
  export 'models/readiness_result.dart';
  export 'internal/commands/command_factory.dart';
  
  // Remove old exports completely:
  // - zebra_printer_state_manager.dart
  // - models/auto_correction_options.dart
  ```
- **ETA**: 10 minutes
- **Dependencies**: Task 5.2
- **Impact**: Medium - public API

#### Task 5.4: Update Imports
- **Files**: All files that import old classes
- **Changes**: Update imports to use new classes
- **ETA**: 10 minutes
- **Dependencies**: Task 5.3
- **Impact**: Medium - dependency cleanup

### Phase 6: Testing and Documentation (1 hour)

#### Task 6.1: Create Unit Tests
- **Files**: `test/` directory
- **Changes**: Tests for new commands and manager
- **Implementation Details**:
  ```dart
  // test/zebra_printer_readiness_manager_test.dart
  group('PrinterReadinessManager', () {
    late MockZebraPrinter mockPrinter;
    late PrinterReadinessManager manager;
    
    setUp(() {
      mockPrinter = MockZebraPrinter();
      manager = PrinterReadinessManager(
        printer: mockPrinter,
        statusCallback: (msg) => print(msg),
      );
    });
    
    test('checkAndFixReadiness with quick options', () async {
      // Test implementation
    });
    
    test('checkAndFixReadiness with comprehensive options', () async {
      // Test implementation
    });
    
    test('runDiagnostics returns valid data', () async {
      // Test implementation
    });
  });
  
  // test/internal/commands/command_factory_test.dart
  group('CommandFactory', () {
    test('creates correct command instances', () {
      final mockPrinter = MockZebraPrinter();
      
      final getSettingCommand = CommandFactory.createGetSettingCommand(mockPrinter, 'test.setting');
      expect(getSettingCommand, isA<GetSettingCommand>());
      
      final checkConnectionCommand = CommandFactory.createCheckConnectionCommand(mockPrinter);
      expect(checkConnectionCommand, isA<CheckConnectionCommand>());
      
      final sendUnpauseCommand = CommandFactory.createSendUnpauseCommand(mockPrinter);
      expect(sendUnpauseCommand, isA<SendUnpauseCommand>());
    });
  });
  
  // test/internal/commands/get_setting_command_test.dart
  group('GetSettingCommand', () {
    test('executes successfully', () async {
      // Test implementation
    });
  });
  ```
- **ETA**: 40 minutes
- **Dependencies**: Phase 5 complete
- **Impact**: High - validation

#### Task 6.2: Update Documentation
- **Files**: `README.md`, code comments
- **Changes**: Document new architecture
- **Implementation Details**:
  ```markdown
  ## Printer Readiness Management
  
  The new `PrinterReadinessManager` provides a unified interface for all printer readiness operations:
  
  ```dart
  // Quick printer preparation for print
  final result = await printer.prepareForPrint(
    options: ReadinessOptions.quick(),
  );
  
  // Comprehensive printer preparation for print
  final result = await printer.prepareForPrint(
    options: ReadinessOptions.comprehensive(),
  );
  
  // Custom printer preparation options
  final result = await printer.prepareForPrint(
    options: ReadinessOptions(
      checkConnection: true,
      checkMedia: true,
      fixPausedPrinter: true,
      clearBuffer: true,
    ),
  );
  ```
  
  ### Available Options
  
  - **Check Options**: `checkConnection`, `checkMedia`, `checkHead`, `checkPause`, `checkErrors`, `checkLanguage`
  - **Fix Options**: `fixPausedPrinter`, `fixPrinterErrors`, `fixMediaCalibration`, `fixLanguageMismatch`, `fixBufferIssues`, `clearBuffer`, `flushBuffer`
  - **Behavior Options**: `checkDelay`, `maxAttempts`, `verboseLogging`
  
  ### Factory Constructors
  
  - `ReadinessOptions.quick()` - Basic checks and fixes
  - `ReadinessOptions.comprehensive()` - All checks and fixes
  - `ReadinessOptions.forPrinting()` - Optimized for print operations
  
  ### Migration Guide
  
  **Old API (Removed):**
  ```dart
  // OLD - No longer available
  await printer.checkPrinterReadiness();
  await printer.correctReadiness(readiness);
  await printer.correctForPrinting(data: data);
  ```
  
  **New API:**
  ```dart
  // NEW - Use this instead
  final result = await printer.prepareForPrint();
  final result = await printer.prepareForPrint(
    options: ReadinessOptions.quick(),
  );
  ```
  ```
- **ETA**: 20 minutes
- **Dependencies**: Task 6.1
- **Impact**: Medium - user guidance

## New Architecture Overview

### Commands Pattern
```
BaseCommand<T> (abstract)
└── PrinterCommand<T> (abstract)
    ├── GetSettingCommand → String?
    ├── SendCommandCommand → void
    ├── CheckConnectionCommand → bool
    ├── GetMediaStatusCommand → String?
    ├── GetHeadStatusCommand → String?
    ├── GetPauseStatusCommand → String?
    ├── GetHostStatusCommand → String?
    ├── GetLanguageCommand → String?
    ├── SendUnpauseCommand → void
    ├── SendClearErrorsCommand → void
    ├── SendCalibrationCommand → void
    ├── SendClearBufferCommand → void
    └── SendFlushBufferCommand → void
```

### PrinterReadinessManager
- **Individual Check/Fix Methods**: `_checkAndFixConnection()`, `_checkAndFixMedia()`, etc.
- **Each Method Uses Commands**: Atomic printer operations
- **Single Entry Point**: `prepareForPrint(ReadinessOptions)`
- **Returns ReadinessResult**: Detailed information about the operation

### ReadinessOptions
- **Consolidates Settings**: All readiness settings in one place
- **Fine-grained Control**: Individual control over each check/fix
- **Factory Constructors**: Predefined configurations for common scenarios
- **Sensible Defaults**: Good defaults for most use cases

### Key Benefits
1. **Simplified API**: Single method for all readiness operations
2. **Atomic Commands**: Each command is a single printer operation
3. **Consistent Result Format**: All commands use Result<T>
4. **Simple Orchestration**: Private methods handle complex logic
5. **Clean Architecture**: No deprecated code, full migration

## Risk Assessment

### High Risk
- **Breaking Changes**: Complete API change requires user migration
- **Mitigation**: Clear migration guide and comprehensive documentation

### Medium Risk
- **Complexity**: New command pattern adds complexity
- **Mitigation**: Clear documentation and examples

### Low Risk
- **Testing**: New architecture needs comprehensive testing
- **Mitigation**: Extensive unit tests and integration tests

## Success Criteria
- [ ] All tests pass
- [ ] No lint errors or warnings
- [ ] New architecture is documented
- [ ] Old architecture completely removed
- [ ] Code is more maintainable and organized

## Rollback Plan
If issues arise:
1. Revert to previous commit
2. Document issues encountered
3. Plan incremental migration approach
4. Re-implement in smaller phases

## Post-Implementation Tasks
- [ ] Update CHANGELOG.md with breaking changes
- [ ] Increment version number (major increment for breaking changes)
- [ ] Create comprehensive migration guide for existing users
- [ ] Update example app to use new architecture
- [ ] Performance testing of new command pattern
- [ ] Notify users about breaking changes 