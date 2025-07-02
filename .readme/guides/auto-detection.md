# Printer Language Auto-Detection

## Overview

The Zebra Printer Plugin automatically detects the format of print data and ensures the printer is in the correct mode before printing.

## How It Works

### 1. Format Detection

The plugin examines the print data to determine its format:

```dart
// In ZebraSGDCommands.detectDataLanguage()
- ZPL: Data starts with '^XA' or contains '^XA'
- CPCL: Data starts with '!', '! 0', or '! U1'
- Unknown: Neither ZPL nor CPCL markers found
```

### 2. Printer Mode Verification

When printing with auto-detection enabled (default):

```dart
// In ZebraPrinterService._doPrint()
1. Detect data format (ZPL or CPCL)
2. Query current printer mode via SGD
3. If modes don't match, switch printer mode
4. Send print data
```

### 3. Mode Switching

The plugin automatically switches printer modes using SGD commands:

```dart
// Switch to ZPL
! U1 setvar "device.languages" "zpl"

// Switch to CPCL/Line Print
! U1 setvar "device.languages" "line_print"
```

## Usage

### Automatic Mode (Default)

```dart
// Auto-detection is enabled by default
await printerService.print(zplData);  // Detects ZPL, switches if needed
await printerService.print(cpclData); // Detects CPCL, switches if needed
```

### Manual Mode

```dart
// Disable auto-detection for performance
await printerService.print(
  data,
  ensureMode: false  // Skip detection and mode switching
);
```

## Detection Rules

### ZPL Detection
- Must start with `^XA` or contain `^XA` anywhere in the data
- Case sensitive
- Whitespace is trimmed before checking

### CPCL Detection
- Must start with one of:
  - `!` (basic CPCL)
  - `! 0` (standard CPCL header)
  - `! U1` (SGD command)
- Case sensitive
- Whitespace is trimmed before checking

## Performance Considerations

1. **Mode Switching Overhead**: Switching modes adds ~500ms delay
2. **Detection Cost**: Minimal (string inspection only)
3. **Optimization**: Disable auto-detection if printing same format repeatedly

```dart
// For bulk printing of same format
final service = ZebraPrinterService();
await service.connect(address);

// First print switches mode if needed
await service.print(firstLabel);

// Subsequent prints skip detection
for (final label in labels) {
  await service._doPrint(label, ensureMode: false);
}
```

## Limitations

1. **Raw Text**: Plain text without ZPL/CPCL markers is not auto-detected
2. **Mixed Formats**: Cannot print mixed ZPL/CPCL in single job
3. **Mode Persistence**: Printer remains in last mode after disconnect

## Troubleshooting

**Print data appears as text**
- Auto-detection failed to identify format
- Printer is in wrong mode and auto-detection disabled
- Solution: Ensure data has proper format markers

**Slow printing**
- Mode switching happening on every print
- Solution: Group same-format prints together

**Detection failures**
- Check data starts with correct markers
- Verify data encoding (UTF-8)
- Enable debug logging to see detection results 