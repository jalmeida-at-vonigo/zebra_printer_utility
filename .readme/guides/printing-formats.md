# Printing Formats Guide

Complete guide to ZPL and CPCL printing formats for Zebra printers.

## Format Overview

| Format | Use Case | Printer Types |
|--------|----------|---------------|
| **ZPL** | Label printing, complex layouts | Desktop and industrial printers |
| **CPCL** | Mobile printing, simple receipts | Mobile and portable printers |

## ZPL (Zebra Programming Language)

### Basic Structure
```
^XA                 // Start format
^FO50,50           // Field origin (x,y)
^ADN,36,20         // Font selection
^FDHello World     // Field data
^FS                // Field separator
^XZ                // End format
```

### Common ZPL Commands

**Label Setup**
- `^XA` / `^XZ` - Start/End format
- `^LL<length>` - Label length in dots
- `^PW<width>` - Print width in dots
- `^PON` / `^POI` - Print orientation (Normal/Inverted)

**Text Printing**
- `^FO<x>,<y>` - Field origin
- `^A<font><orientation>,<height>,<width>` - Font settings
- `^FD<data>^FS` - Field data

**Barcodes**
- `^BY<width>,<ratio>,<height>` - Barcode settings
- `^BC<orientation>,<height>,<print_text>` - Code 128
- `^BQ<orientation>,<model>` - QR Code

### ZPL Examples

**Simple Label**
```zpl
^XA
^LL200
^FO50,50^ADN,36,20^FDProduct Label^FS
^FO50,100^ADN,18,10^FDSKU: 12345^FS
^XZ
```

**Barcode Label**
```zpl
^XA
^LL400
^BY2,2,100
^FO50,50^BC^FD123456789^FS
^FO50,200^ADN,18,10^FDItem #123456789^FS
^XZ
```

## CPCL (Common Printer Command Language)

### Basic Structure
```
! 0 200 200 210 1     // Initialize (x, y, height, qty)
TEXT 4 0 30 40 Hello  // Print text
FORM                  // Form feed
PRINT                 // Execute print
```

### Common CPCL Commands

**Initialization**
- `! <offset> <horiz_res> <vert_res> <height> <qty>`

**Text Commands**
- `TEXT <font> <size> <x> <y> <data>`
- `T <font> <size> <x> <y> <data>` (abbreviated)

**Barcode Commands**
- `BARCODE <type> <width> <ratio> <height> <x> <y> <data>`
- `B <type> <width> <ratio> <height> <x> <y> <data>` (abbreviated)

**Graphics**
- `LINE <x1> <y1> <x2> <y2> <width>`
- `BOX <x> <y> <x2> <y2> <width>`

### CPCL Examples

**Simple Receipt**
```cpcl
! 0 200 200 210 1
TEXT 4 0 30 20 Store Receipt
TEXT 4 0 30 60 Date: 2024-01-15
TEXT 4 0 30 100 Total: $25.00
FORM
PRINT
```

**Receipt with Barcode**
```cpcl
! 0 200 200 400 1
CENTER
TEXT 4 1 0 20 RECEIPT
TEXT 4 0 0 80 Order #12345
BARCODE 128 1 1 50 0 130 12345
TEXT 4 0 0 200 Thank You!
FORM
PRINT
```

## Format Detection

The plugin automatically detects the format based on content:

- **ZPL**: Starts with `^XA` or contains `^` commands
- **CPCL**: Starts with `!` or contains CPCL commands
- **Raw**: Neither ZPL nor CPCL markers

## Best Practices

### ZPL Best Practices
1. Always specify label length with `^LL`
2. Use `^PON` to ensure correct orientation
3. Test with different DPI settings
4. Keep labels concise for mobile printers

### CPCL Best Practices
1. Match resolution to printer specs (usually 200 DPI)
2. Calculate height based on content
3. Use `CENTER` for receipts
4. Add `FORM` and `PRINT` at the end

### General Tips
1. Test on actual printers - simulators may differ
2. Account for printer DPI in measurements
3. Use appropriate fonts for readability
4. Consider paper/label size constraints

## Troubleshooting

**Text appears as commands**
- Printer is in wrong mode
- Use format detection or manual mode switching

**Partial printing**
- Label height too small
- Increase height parameter

**Alignment issues**
- Check printer DPI settings
- Verify coordinate calculations

## Related Documentation

- [API Reference](../api/README.md)
- [Example App](example-app.md)
- [Testing Guide](testing.md) 