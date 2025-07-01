# Testing Guide

This guide provides comprehensive instructions for testing the Zebra Printer Utility plugin on both real devices and simulators.

## Quick Navigation

- [Main Project README](../../README.md)
- [Example App Documentation](README.md)
- [iOS Implementation](../ios/README.md)
- [Library Documentation](../lib/README.md)
- [Development Documentation](../development/README.md)

## Testing Overview

The plugin supports testing in multiple environments:
- **Real Devices**: Physical iOS/Android devices with Zebra printers
- **Simulators**: iOS Simulator and Android Emulator for basic testing
- **Test Mode**: Dummy printer responses for development

## Prerequisites

### For Real Device Testing
- Physical Zebra printer (ZPL or CPCL capable)
- iOS device (iPhone/iPad) or Android device
- Network connection (for network printers)
- Bluetooth connection (for MFi printers on iOS)

### For Simulator Testing
- Xcode (for iOS Simulator)
- Android Studio (for Android Emulator)
- No physical printer required

## Testing Setup

### 1. Build and Install
```bash
# Navigate to example directory
cd example

# Get dependencies
flutter pub get

# Run on device/simulator
flutter run
```

### 2. Configure Test Mode
The example app includes a test mode that provides dummy printer responses:

- **Test Mode On**: Uses simulated printer responses
- **Test Mode Off**: Connects to real printers

Toggle test mode in the app settings to test without physical printers.

## Testing Scenarios

### Discovery Testing
1. **Start Discovery**: Tap "Start Scan" button
2. **Check Results**: Verify printers appear in the list
3. **Test Modes**: Try both Bluetooth and Network discovery
4. **Error Handling**: Test with no printers available

### Connection Testing
1. **Connect to Printer**: Select a printer from the list
2. **Verify Connection**: Check connection status indicator
3. **Test Disconnect**: Verify clean disconnection
4. **Reconnection**: Test reconnecting to the same printer

### Printing Testing
1. **ZPL Printing**: Test ZPL command printing
2. **CPCL Printing**: Test CPCL command printing (iOS only)
3. **Raw Text**: Test plain text printing
4. **Large Data**: Test printing large amounts of data

### Error Testing
1. **Invalid Address**: Try connecting to non-existent printer
2. **Network Issues**: Test with network disconnected
3. **Permission Denied**: Test without required permissions
4. **Invalid Commands**: Test with malformed ZPL/CPCL

## Platform-Specific Testing

### iOS Testing
- **MFi Bluetooth**: Test with MFi-compatible Zebra printers
- **Network Printers**: Test with TCP/IP connected printers
- **Language Detection**: Verify automatic ZPL/CPCL detection
- **Permissions**: Test Bluetooth and network permissions

### Android Testing
- **Network Printers**: Test with TCP/IP connected printers
- **Basic ZPL**: Test ZPL printing functionality
- **Permissions**: Test network permissions

## Test Data

### Sample ZPL Commands
```zpl
^XA
^FO50,50^A0N,50,50^FDTest Label^FS
^XZ
```

### Sample CPCL Commands
```cpcl
! 0 200 200 210 1
TEXT 4 0 0 0 Test Label
FORM
PRINT
```

### Sample Raw Text
```
Hello World
This is a test print
```

## Troubleshooting

### Common Issues
1. **No printers found**: Check network connectivity and permissions
2. **Connection failed**: Verify printer address and network settings
3. **Print as text**: Check printer language settings
4. **Build errors**: Clean and rebuild the project

### Debug Information
Enable debug logging in the app to see detailed information about:
- Discovery process
- Connection attempts
- Print operations
- Error messages

## Performance Testing

### Discovery Performance
- Measure time to discover printers
- Test with multiple printers on network
- Verify discovery stops properly

### Print Performance
- Test print speed with different data sizes
- Measure connection establishment time
- Test concurrent print operations

## Reporting Issues

When reporting issues, include:
1. **Platform**: iOS/Android version
2. **Device**: Device model and OS version
3. **Printer**: Zebra printer model and firmware
4. **Steps**: Detailed reproduction steps
5. **Logs**: Debug logs if available
6. **Expected vs Actual**: What you expected vs what happened

## Documentation Links

- [Main Project README](../../README.md)
- [Example App Documentation](README.md)
- [iOS Implementation](../ios/README.md)
- [Library Documentation](../lib/README.md)
- [Development Documentation](../development/README.md) 