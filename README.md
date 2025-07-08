# Zebra Printer Utility Flutter Plugin

A professional Flutter plugin for robust, cross-platform Zebra printer integration. Supports iOS (MFi Bluetooth, Network) and Android (Network), with modern event-driven architecture, command pattern, centralized communication policies, and comprehensive diagnostics.

---

## Features

- **Cross-platform**: iOS (MFi Bluetooth, Network), Android (Network)
- **Modern Architecture**: Command pattern, event-driven workflows, manager-based API, and centralized communication policies
- **Robust Communication**: Centralized connection assurance, timeout handling, and retry logic with policy depth protection
- **Automatic Format Detection & Language Management**: ZPL/CPCL auto-detection, printer language check/set, and mode switching before printing
- **Smart Device Discovery**: Intelligent, real-time printer discovery and selection
- **Comprehensive Diagnostics**: Status, error, and readiness checks with actionable recommendations
- **Advanced Error Handling**: Retry logic, error classification, and progress tracking
- **Buffer & State Management**: Auto-correction, buffer clearing, calibration, and more
- **Rich Example App**: Demonstrates all major workflows and best practices

---

## Architecture

```
┌─────────────────────┐
│   SmartPrintManager │
│   (Workflow Logic)  │
└─────────────────────┘
           │
           ▼
┌─────────────────────┐
│ ZebraPrinterManager │
│ (Instance Manager)  │
└─────────────────────┘
           │
           ▼
┌─────────────────────┐    ┌─────────────────────┐
│   ZebraPrinter      │    │ ZebraPrinterDiscovery│
│ (Native Wrapper)    │    │ (Discovery Logic)   │
└─────────────────────┘    └─────────────────────┘
           │
           ▼
┌─────────────────────┐
│ CommunicationPolicy │
│ (Connection Logic)  │
└─────────────────────┘
```

- **ZebraPrinter**: Low-level native wrapper for ZSDK operations (primitive, stateless)
- **CommunicationPolicy**: Centralized connection assurance, timeout handling, and retry logic
- **ZebraPrinterManager**: Manages printer instances, state, and exposes primitive operations
- **SmartPrintManager**: Orchestrates complex workflows, event streaming, and error handling
- **Command Pattern**: All printer operations are encapsulated as commands (one per file, created via CommandFactory)

---

## Quick Start

### Installation

```yaml
dependencies:
  zebrautil: ^2.0.0
```

### Basic Usage (Manager-Based API)

```dart
import 'package:zebrautil/zebrautil.dart';

final manager = ZebraPrinterManager();
await manager.initialize();

// Discover printers
final discoveryStream = manager.discovery.discoverPrintersStream();
discoveryStream.listen((devices) {
  print('Discovered: ${devices.length} printers');
});

// Connect to a printer
final result = await manager.connect('192.168.1.100');
if (!result.success) {
  print('Failed to connect: ${result.error?.message}');
}

// Print data (primitive)
final printResult = await manager.print('^XA^FO50,50^FDHello World^FS^XZ');
if (!printResult.success) {
  print('Print failed: ${printResult.error?.message}');
}
```

### Advanced Usage (Direct Control with CommunicationPolicy)

```dart
import 'package:zebrautil/zebrautil.dart';

// Create printer instance
final printer = ZebraPrinter('instance_id');

// Create communication policy for robust operations
final policy = CommunicationPolicy(printer);

// Execute commands with connection assurance
final command = CommandFactory.createGetPrinterStatusCommand(printer);
final result = await policy.executeCommand(command);

if (result.success) {
  print('Printer status: ${result.data}');
} else {
  print('Error: ${result.error?.message}');
}

// Execute custom operations with assurance
final languageResult = await policy.executeWithAssurance(
  () => printer.getSetting('device.languages'),
  'Get Language Setting'
);
```

### Event-Driven Smart Print

```dart
final eventStream = manager.smartPrint(
  '^XA^FO50,50^FDHello World^FS^XZ',
  maxAttempts: 3,
);
eventStream.listen((event) {
  // Handle PrintEvent: step changes, errors, progress, completion
  switch (event.type) {
    case PrintEventType.realTimeStatusUpdate:
      // NEW in 2.0.45: Enhanced real-time status updates
      final metadata = event.metadata;
      if (metadata['hasIssues'] == true) {
        final issueDetails = metadata['issueDetails'] as List;
        final canAutoResume = metadata['canAutoResume'] as bool;
        // Handle issues with recovery hints
      }
      break;
    // ... other event types
  }
});
```

// NEW in 2.0.45:
// Enhanced real-time status updates with comprehensive metadata including issue details, progress hints, and auto-resume capabilities. The SmartPrintManager now provides richer status information for better UI feedback and error recovery.

// NEW in 2.0.44:
// The smart print workflow now automatically detects the print data format (CPCL or ZPL), checks the printer's current language, sets the correct mode if needed, and only sends data after all checks pass. This ensures robust, error-free printing for all supported Zebra printers.

---

## Communication Policy

The `CommunicationPolicy` provides centralized connection assurance, timeout handling, and retry logic for all printer operations.

### Key Features

- **Connection Assurance**: Automatic connection checking before operations
- **Timeout Handling**: Configurable timeouts (5s connection, 10s operation)
- **Retry Logic**: Automatic retry for connection-related errors
- **Policy Depth Protection**: Prevents infinite loops in nested operations
- **Error Classification**: Intelligent error detection and retry decisions

### Configuration

```dart
// Default settings (can be modified in CommunicationPolicy)
const maxRetries = 2;
const connectionTimeout = Duration(seconds: 5);
const operationTimeout = Duration(seconds: 10);
const retryDelay = Duration(milliseconds: 500);
```

### Error Classification

Connection-related errors are automatically detected and retried:
- connection, connected, disconnect
- timeout, network, bluetooth, wifi
- socket, communication

---

## Command Factory

The `CommandFactory` provides a centralized way to create and execute printer commands with built-in connection assurance.

### Available Commands

#### Status Commands
```dart
CommandFactory.createGetPrinterStatusCommand(printer)
CommandFactory.createGetDetailedPrinterStatusCommand(printer)
CommandFactory.createCheckConnectionCommand(printer)
CommandFactory.createGetMediaStatusCommand(printer)
CommandFactory.createGetHeadStatusCommand(printer)
CommandFactory.createGetPauseStatusCommand(printer)
CommandFactory.createGetHostStatusCommand(printer)
CommandFactory.createGetLanguageCommand(printer)
```

#### Control Commands
```dart
// Clear operations
CommandFactory.createSendClearErrorsCommand(printer)
CommandFactory.createSendClearBufferCommand(printer)
CommandFactory.createSendClearAlertsCommand(printer)

// Format-specific operations
CommandFactory.createSendZplClearErrorsCommand(printer)
CommandFactory.createSendCpclClearErrorsCommand(printer)
CommandFactory.createSendZplClearBufferCommand(printer)
CommandFactory.createSendCpclClearBufferCommand(printer)

// Mode operations
CommandFactory.createSendSetZplModeCommand(printer)
CommandFactory.createSendSetCpclModeCommand(printer)

// Other operations
CommandFactory.createSendUnpauseCommand(printer)
CommandFactory.createSendCalibrationCommand(printer)
```

#### Settings Commands
```dart
CommandFactory.createGetSettingCommand(printer, 'setting.name')
CommandFactory.createSendCommandCommand(printer, 'command string')
```

### Usage Examples

```dart
// Execute command with connection assurance
final command = CommandFactory.createGetPrinterStatusCommand(printer);
final result = await policy.executeCommand(command);

// Execute multiple commands
final commands = [
  CommandFactory.createGetPrinterStatusCommand(printer),
  CommandFactory.createGetMediaStatusCommand(printer),
  CommandFactory.createGetLanguageCommand(printer),
];

for (final command in commands) {
  final result = await policy.executeCommand(command);
  print('${command.operationName}: ${result.success}');
}
```

---

## Example App

A comprehensive example app is provided in the `/example` folder. It demonstrates all major workflows and best practices:

- **CPCL Test**: Manual CPCL label editing and direct printing, with device selection and connection.
- **Result-Based**: Demonstrates the operation manager and result-based async operations.
- **Smart Discovery**: Real-time device discovery, listing, and connection using the new manager/event system.
- **Smart Print**: Full event-driven, robust print workflow with real-time progress, error handling, and retry logic.

**All screens use a shared log panel for real-time feedback and debugging.**

### Running the Example

```sh
cd example
flutter run
```

---

## Advanced Usage

### Command Pattern

All printer operations are encapsulated as commands. Use the `CommandFactory` to create and execute commands:

```dart
final command = CommandFactory.createSendZplClearBufferCommand(printer);
final result = await command.execute();
```

### SmartPrintManager

For advanced workflows, use the `SmartPrintManager` for event-driven printing, retries, and error handling:

```dart
final smartManager = manager.smartPrintManager;
final eventStream = smartManager.smartPrint(
  '^XA^FO50,50^FDHello World^FS^XZ',
  device: myPrinter,
);
eventStream.listen((event) {
  // Handle PrintEvent
  switch (event.type) {
    case PrintEventType.stepChanged:
      print('Step: ${event.stepInfo?.message}');
      break;
    case PrintEventType.errorOccurred:
      print('Error: ${event.errorInfo?.message}');
      break;
    case PrintEventType.realTimeStatusUpdate:
      // Enhanced status with metadata
      final hasIssues = event.metadata['hasIssues'];
      final progressHint = event.metadata['progressHint'];
      final canAutoResume = event.metadata['canAutoResume'];
      break;
    case PrintEventType.completed:
      print('Print completed successfully');
      break;
  }
});
```

### Real-Time Status Updates (v2.0.45+)

The `realTimeStatusUpdate` event provides enhanced printer status information:

```dart
// Event metadata includes:
{
  'status': Map<String, dynamic>,      // Full printer status
  'isCompleted': bool,                 // Print completion status
  'hasIssues': bool,                   // Whether issues detected
  'canAutoResume': bool,               // If auto-recovery possible
  'issueDetails': List<dynamic>,       // Detailed issue information
  'progressHint': String?,             // Human-readable progress hint
  'autoResumeAction': String?,         // Suggested recovery action
  'progress': double,                  // Overall progress (0.0-1.0)
  'currentStep': String,               // Current workflow step
  'consecutiveErrors': int?,           // Error count for stability tracking
  'enhancedMetadata': true,            // Indicates enhanced status
}
```

### Debugging and Monitoring

```dart
// Check policy statistics
final stats = CommunicationPolicy.getPolicyStats();
print('Policy depth: ${stats['policyDepth']}');
print('Max retries: ${stats['maxRetries']}');

// Reset policy depth (for testing)
CommunicationPolicy.resetPolicyDepth();
```

---

## Best Practices

### For Application Development
- ✅ Use managers for high-level operations (print, connect, etc.)
- ✅ Let managers handle connection and retry logic
- ✅ Use standardized result objects for error handling
- ✅ Trust the communication policy's robustness

### For Advanced Users
- ✅ Use CommandFactory + CommunicationPolicy for custom operations
- ✅ Always handle errors from command execution
- ✅ Use descriptive operation names for logging
- ✅ Don't bypass connection assurance for "simple" operations

### For Library Extension
- ✅ Create new commands using the command pattern
- ✅ Use CommunicationPolicy for all printer operations
- ✅ Follow the manager pattern for new workflows
- ✅ Implement proper error handling and result objects

---

## Documentation

- **[API Reference](.readme/api/README.md)**
- **[Error Handling](.readme/guides/error-handling.md)**
- **[Printing Formats](.readme/guides/printing-formats.md)**
- **[Example App Guide](.readme/guides/example-app.md)**
- **[Development Docs](.readme/development/README.md)**
- **[Changelog](CHANGELOG.md)**

---

## Platform Support

| Platform | Status | Features |
|----------|--------|----------|
| iOS      | ✅ Supported | Bluetooth (MFi), Network, ZPL, CPCL |
| Android  | ⚠️ Limited | Network only, basic ZPL support |

---

## Getting Help

- See the [Example App Guide](.readme/guides/example-app.md) for troubleshooting
- Review [iOS Implementation](.readme/platforms/ios/README.md) for iOS-specific issues
- See [CPCL Printing Solution](.readme/lib/cpcl-printing-solution.md) for printing format help

---

## Contributing



---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.