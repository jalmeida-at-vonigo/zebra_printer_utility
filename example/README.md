# Zebra Printer Utility Example App

A clean, modern example app demonstrating the Zebra Printer Utility Flutter plugin with a consistent UI/UX design.

## Overview

This example app showcases the key features of the zebra_printer_utility plugin through focused demo screens. Each screen demonstrates specific API functionality while maintaining a consistent user experience across phones and tablets.

## Features

- **Responsive Design**: Adapts seamlessly to phones and tablets in both portrait and landscape orientations
- **Consistent UI Components**: Reusable widgets for common functionality
- **Real-time Logging**: All screens include operation logs for debugging and learning
- **Print Format Support**: Both ZPL and CPCL formats with built-in presets

## Screens

### 1. Basic Print
Demonstrates the simple print API with printer selection.

**Key Features:**
- Printer discovery and connection
- ZPL/CPCL editor with presets
- Direct print using `Zebra.print()`
- Real-time operation logging

**API Usage:**
```dart
final result = await Zebra.print(
  data,
  options: PrintOptions(format: PrintFormat.zpl),
);
```

### 2. Smart Print
Shows the event-driven print workflow with comprehensive error handling.

**Key Features:**
- Event stream processing
- Progress tracking with visual feedback
- Automatic retry logic
- Enhanced status updates

**API Usage:**
```dart
final eventStream = Zebra.smartPrint(
  data,
  device: selectedPrinter,
  maxAttempts: 3,
);
```

### 3. Discovery
Demonstrates printer discovery capabilities with advanced options.

**Key Features:**
- Configurable discovery timeout
- WiFi/Bluetooth filtering
- Real-time device listing
- Connection testing

**API Usage:**
```dart
final result = await Zebra.discoverPrintersStream(
  timeout: Duration(seconds: 15),
  includeWifi: true,
  includeBluetooth: true,
);
```

### 4. Direct Channel
Shows direct MethodChannel usage for advanced users (bypassing the library).

**Key Features:**
- Direct native platform calls
- Manual channel management
- Same UI consistency as other screens
- Low-level control demonstration

## Architecture

### Common Widgets

The app uses a set of reusable widgets for consistency:

- **`LogPanel`**: Displays operation logs with severity levels
- **`PrintDataEditor`**: ZPL/CPCL editor with format selection and presets
- **`PrinterSelector`**: Handles printer discovery and connection
- **`ResponsiveLayout`**: Manages adaptive layouts for different screen sizes

### Responsive Design

The app uses breakpoints to adapt the UI:
- **Mobile**: < 600px width
- **Tablet**: 600-900px width
- **Desktop**: > 900px width

Navigation automatically switches between:
- Bottom navigation bar (mobile)
- Navigation rail (tablet/desktop)

## Running the Example

1. **Connect a Zebra printer** to your network or pair via Bluetooth
2. **Run the app**:
   ```bash
   flutter run
   ```
3. **Select a screen** from the navigation
4. **Discover and connect** to your printer
5. **Test the functionality** specific to each screen

## Troubleshooting

### Common Issues

1. **No printers found**
   - Ensure printer is powered on
   - Check network connectivity
   - For iOS Bluetooth: Pair in Settings first
   - Check the log panel for errors

2. **Connection failures**
   - Verify printer IP address
   - Check firewall settings
   - Ensure printer is not in use by another device

3. **Print failures**
   - Check printer status (paper, ribbon, etc.)
   - Verify print data format matches printer language
   - Review logs for specific error messages

### Platform Notes

- **iOS**: Bluetooth printers must be paired in iOS Settings before discovery
- **Android**: Currently supports network printers only (Bluetooth coming soon)

## Code Structure

```
example/
├── lib/
│   ├── main.dart              # App entry point
│   ├── screens/              # Demo screens
│   │   ├── basic_print_screen.dart
│   │   ├── smart_print_screen.dart
│   │   ├── discovery_screen.dart
│   │   └── direct_print_screen.dart
│   └── widgets/              # Reusable components
│       ├── log_panel.dart
│       ├── print_data_editor.dart
│       ├── printer_selector.dart
│       └── responsive_layout.dart
└── README.md
```

## Contributing

When modifying the example app:
1. Maintain UI consistency with existing screens
2. Use the common widgets where applicable
3. Ensure responsive design works on all screen sizes
4. Add appropriate logging for operations
5. Test on both iOS and Android platforms

## License

This example is part of the zebra_printer_utility plugin and follows the same license terms. 