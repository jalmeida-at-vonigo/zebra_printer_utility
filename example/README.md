# Zebra Printer Utility Example App

A comprehensive example app demonstrating all major workflows and best practices for the Zebra Printer Utility Flutter plugin.

## Overview

This example app showcases the modern, event-driven architecture of the Zebra Printer Utility plugin. Each screen demonstrates a specific workflow and includes real-time logging for debugging and monitoring.

## Screens

### 1. CPCL Test
**File:** `lib/cpcl_screen.dart`

Demonstrates manual CPCL label editing and direct printing with device selection and connection.

**Features:**
- Manual CPCL label editing with syntax highlighting
- Device discovery and connection
- Direct print operations using primitive API
- Real-time status updates
- Shared log panel for debugging

**Use Case:** When you need direct control over CPCL commands and want to test specific label formats.

### 2. Result-Based
**File:** `lib/result_based_screen.dart`

Demonstrates the operation manager and result-based async operations for advanced users.

**Features:**
- Operation manager testing with various scenarios
- Success, failure, timeout, and concurrent operation testing
- Comprehensive operation logging
- Real-time operation status tracking

**Use Case:** For understanding the underlying operation management system and testing async operations.

### 3. Smart Discovery
**File:** `lib/smart_discovery_screen.dart`

Shows real-time device discovery, listing, and connection using the new manager/event system.

**Features:**
- Real-time printer discovery with streaming updates
- Device listing with connection status
- One-tap connection to discovered printers
- Comprehensive discovery logging

**Use Case:** When you need to discover and connect to printers dynamically.

### 4. Smart Print
**File:** `lib/smart_print_example_screen.dart`

Full event-driven, robust print workflow with real-time progress, error handling, and retry logic.

**Features:**
- Event-driven printing with real-time progress updates
- Automatic retry logic with configurable attempts
- Error classification and recovery
- Comprehensive print event streaming
- Print cancellation support

**Use Case:** Production-ready printing with full error handling and user feedback.

## Shared Components

### OperationLogPanel
**File:** `lib/operation_log_panel.dart`

A shared widget used by all screens to display real-time operation logs with:
- Color-coded log entries (success, error, warning, info)
- Timestamp and method information
- Clear logs functionality
- Reverse chronological display

### BTPrinterSelector
**File:** `lib/bt_printer_selector.dart`

A reusable device selection widget with:
- Device discovery and listing
- Connection management
- Manual IP entry for network printers
- Connection status display

## Running the Example

### Prerequisites
- Flutter SDK installed
- iOS device/simulator or Android device/emulator
- Zebra printer (optional, for actual printing)

### Setup
```bash
cd example
flutter pub get
```

### Run
```bash
flutter run
```

### Platform-Specific Notes

#### iOS
- Requires Bluetooth permissions for MFi devices
- Network discovery works on simulator and device
- MFi Bluetooth requires physical device

#### Android
- Network discovery only
- Requires network permissions
- Limited ZPL support

## Architecture

The example app follows the same 3-layer architecture as the main plugin:

1. **UI Layer**: Screen widgets and shared components
2. **Manager Layer**: ZebraPrinterManager for instance management
3. **Native Layer**: Low-level printer operations

All screens use the shared `OperationLogPanel` for consistent logging and debugging.

## Best Practices Demonstrated

- **Event-Driven Architecture**: Smart Print screen shows proper event handling
- **Error Handling**: All screens demonstrate proper error handling and user feedback
- **Resource Management**: Proper disposal of streams and managers
- **UI Consistency**: Shared components ensure consistent user experience
- **Real-time Feedback**: Log panels provide immediate operation feedback

## Troubleshooting

### Common Issues

1. **No printers discovered**
   - Check network connectivity
   - Ensure printer is powered on and connected
   - Verify platform-specific permissions

2. **Connection failures**
   - Check printer IP address
   - Verify network connectivity
   - Check printer status (paper, head, etc.)

3. **Print failures**
   - Check printer status using diagnostics
   - Verify print data format (ZPL/CPCL)
   - Check printer settings and configuration

### Debug Information

All screens include comprehensive logging. Check the log panel for:
- Operation status and progress
- Error messages and stack traces
- Connection and discovery events
- Print operation details

## Contributing

When adding new example screens:
1. Use the shared `OperationLogPanel` for logging
2. Follow the existing screen structure and patterns
3. Include comprehensive documentation
4. Test on both iOS and Android platforms
5. Update this README with screen description 