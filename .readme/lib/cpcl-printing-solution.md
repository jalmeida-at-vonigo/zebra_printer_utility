# CPCL Printing Solution

This document provides comprehensive guidance for implementing CPCL (Common Printer Command Language) printing in the Zebra Printer Utility plugin.

## Quick Navigation

- [Main Project README](../../README.md)
- [Library Documentation](README.md)
- [iOS Implementation](../ios/README.md)
- [Example App Documentation](../example/README.md)
- [Development Documentation](../development/README.md)

## Overview

CPCL (Common Printer Command Language) is a printing language used by many Zebra printers, particularly for receipt and label printing. This document covers the implementation and usage of CPCL printing in the plugin.

## CPCL Basics

### Language Structure
CPCL commands are text-based and follow a specific format:
- Commands start with `!` or specific keywords
- Parameters are space-separated
- Commands end with carriage return (`\r\n`)
- Print jobs end with `FORM` and `PRINT` commands

### Common Commands
```cpcl
! 0 200 200 210 1    # Initialize printer
TEXT 4 0 0 0 Hello   # Print text
FORM                 # End form
PRINT                # Print job
```

## Implementation Details

### Language Detection
The plugin automatically detects CPCL commands and switches the printer to CPCL mode:

```dart
// CPCL commands are detected by:
// 1. Starting with '!' character
// 2. Containing CPCL keywords (TEXT, FORM, PRINT, etc.)
// 3. Manual mode selection
```

### Printer Mode Switching
Before printing CPCL, the plugin:
1. Detects the command format
2. Queries current printer language
3. Switches to CPCL mode if needed
4. Sends the CPCL data
5. Optionally switches back to previous mode

## CPCL Examples

### Basic Text Label
```dart
String cpcl = '''
! 0 200 200 210 1
TEXT 4 0 0 0 Hello World
FORM
PRINT
''';
await printer.print(cpcl);
```

### Multi-line Text
```dart
String cpcl = '''
! 0 200 200 210 1
TEXT 4 0 0 0 Line 1
TEXT 4 0 0 50 Line 2
TEXT 4 0 0 100 Line 3
FORM
PRINT
''';
await printer.print(cpcl);
```

### Receipt Format
```dart
String cpcl = '''
! 0 200 200 210 1
TEXT 4 0 0 0 RECEIPT
TEXT 4 0 0 50 ================
TEXT 4 0 0 100 Item 1: $10.00
TEXT 4 0 0 150 Item 2: $15.50
TEXT 4 0 0 200 ================
TEXT 4 0 0 250 Total: $25.50
FORM
PRINT
''';
await printer.print(cpcl);
```

### Barcode Printing
```dart
String cpcl = '''
! 0 200 200 210 1
TEXT 4 0 0 0 Product Label
BARCODE 128 1 1 50 0 0 123456789
TEXT 4 0 0 100 123456789
FORM
PRINT
''';
await printer.print(cpcl);
```

## Platform Support

### iOS
- ✅ Full CPCL support
- ✅ Automatic language detection
- ✅ Manual mode switching
- ✅ Error handling

### Android
- ❌ CPCL not currently supported
- ⚠️ Limited to ZPL printing only

## Testing CPCL

### Test Mode
Use the example app's test mode to test CPCL without physical printers:

1. Enable test mode in the app
2. Navigate to CPCL test screen
3. Try different CPCL examples
4. Verify command formatting

### Real Device Testing
1. Connect to a CPCL-capable Zebra printer
2. Send CPCL commands
3. Verify printer language switching
4. Check print output quality

## Common Issues

### Printer Not Responding
- Verify printer supports CPCL
- Check command syntax
- Ensure proper line endings (`\r\n`)

### Wrong Language Mode
- Check automatic detection logic
- Use manual mode switching
- Verify printer capabilities

### Print Quality Issues
- Adjust print density
- Check media type settings
- Verify printer calibration

## Best Practices

### Command Formatting
1. Always start with initialization command
2. Use proper spacing between parameters
3. End with FORM and PRINT commands
4. Include proper line endings

### Error Handling
1. Check printer capabilities before printing
2. Handle language switching errors
3. Provide fallback to ZPL if needed
4. Log CPCL-specific errors

### Performance
1. Batch multiple CPCL commands
2. Minimize language switching
3. Use appropriate print density
4. Optimize command length

## Advanced Features

### Dynamic Content
```dart
String generateCPCLReceipt(Map<String, dynamic> items) {
  String cpcl = '! 0 200 200 210 1\n';
  cpcl += 'TEXT 4 0 0 0 RECEIPT\n';
  
  int yPosition = 50;
  for (var item in items.entries) {
    cpcl += 'TEXT 4 0 0 $yPosition ${item.key}: \$${item.value}\n';
    yPosition += 50;
  }
  
  cpcl += 'FORM\nPRINT\n';
  return cpcl;
}
```

### Conditional Printing
```dart
String generateConditionalCPCL(bool includeBarcode) {
  String cpcl = '! 0 200 200 210 1\n';
  cpcl += 'TEXT 4 0 0 0 Product Label\n';
  
  if (includeBarcode) {
    cpcl += 'BARCODE 128 1 1 50 0 0 123456789\n';
    cpcl += 'TEXT 4 0 0 100 123456789\n';
  }
  
  cpcl += 'FORM\nPRINT\n';
  return cpcl;
}
```

## Documentation Links

- [Main Project README](../../README.md)
- [Library Documentation](README.md)
- [iOS Implementation](../ios/README.md)
- [Example App Documentation](../example/README.md)
- [Development Documentation](../development/README.md) 