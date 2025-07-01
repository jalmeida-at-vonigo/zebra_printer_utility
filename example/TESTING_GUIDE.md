# iOS Zebra Printer Plugin Testing Guide

## 🎯 Testing Checklist

### Initial Setup
- [ ] App launches successfully on iOS device
- [ ] No crash on startup
- [ ] UI displays correctly

### Permissions
- [ ] App requests Bluetooth permission when needed
- [ ] App requests Local Network permission when scanning
- [ ] Permissions dialog shows correct descriptions

### Network Printer Discovery
1. **Start Scanning**
   - [ ] Tap the play button (floating action button)
   - [ ] "Searching for printers..." message appears
   - [ ] No crashes during scanning

2. **Printer Discovery**
   - [ ] Network printers appear in the list
   - [ ] Printer names are displayed correctly
   - [ ] Printer addresses are shown

3. **Stop Scanning**
   - [ ] Tap the stop button
   - [ ] Scanning stops
   - [ ] Discovered printers remain in list

### Bluetooth Printer Discovery
1. **Enable Bluetooth**
   - [ ] Ensure Bluetooth is enabled on device
   - [ ] Start scanning
   - [ ] Bluetooth printers appear (if available)

### Printer Connection
1. **Connect to Network Printer**
   - [ ] Tap the Bluetooth icon next to a printer
   - [ ] Connection status updates
   - [ ] Icon color changes to indicate connection

2. **Connection Error Handling**
   - [ ] Try connecting to offline printer
   - [ ] Error is handled gracefully
   - [ ] App doesn't crash

### Printing
1. **Print Test Label**
   - [ ] Connect to a printer first
   - [ ] Tap the print icon
   - [ ] Label prints successfully
   - [ ] No errors displayed

2. **Print Without Connection**
   - [ ] Disconnect from printer
   - [ ] Try to print
   - [ ] Error is handled properly

## 🐛 Common Issues and Solutions

### "No printers found"
1. **Network Printers**:
   - Ensure iOS device and printer are on same network
   - Check if printer is powered on
   - Verify printer has network connectivity
   - Try pinging printer IP from another device

2. **Bluetooth Printers**:
   - Ensure Bluetooth is enabled
   - Printer must be in pairing mode
   - Check if printer supports MFi (Made for iPhone)

### "Connection Failed"
- Verify printer IP address/port
- Default Zebra port is 9100
- Check firewall settings
- Ensure printer isn't already connected to another device

### "Print Failed"
- Verify connection is active
- Check if printer has media/labels loaded
- Ensure ZPL data is correctly formatted
- Try simpler ZPL command first: `^XA^FO50,50^ADN,36,20^FDHello World^FS^XZ`

## 📊 Expected Test Results

### Successful Network Discovery
```
Printer Name: ZTC GK420d-0123
Address: 192.168.1.100:9100
Status: Disconnected (gray)
```

### After Successful Connection
```
Status: Connected (green)
Print icon: Enabled (green)
```

### Sample ZPL Output
The test label should print:
- Company logo placeholder (box)
- "Intershipping, Inc."
- Address details
- Horizontal line

## 🔍 Debug Information

### Check Console Logs
In Xcode or using `flutter logs`:
```bash
flutter logs
```

Look for:
- `[ZebraPrinter] Starting scan`
- `[ZebraPrinter] Found printer: <address>`
- `[ZebraPrinter] Connected to: <address>`
- `[ZebraPrinter] Print sent successfully`

### Network Debugging
1. Use iOS Settings → Wi-Fi → (i) next to network
2. Note device IP address
3. Ensure it's in same subnet as printer

### Bluetooth Debugging
1. iOS Settings → Bluetooth
2. Look for Zebra printer in device list
3. Note if it shows as "Connected" or "Not Connected"

## 📝 Test Report Template

```
Device: [iPhone/iPad model]
iOS Version: [version]
Network Type: [WiFi/Bluetooth]
Printer Model: [Zebra model]

Test Results:
- App Launch: ✅/❌
- Permissions: ✅/❌
- Discovery: ✅/❌
- Connection: ✅/❌
- Printing: ✅/❌

Issues Found:
1. [Issue description]
2. [Steps to reproduce]
3. [Error messages]

Notes:
[Any additional observations]
``` 