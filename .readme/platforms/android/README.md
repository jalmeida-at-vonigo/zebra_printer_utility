# Android Platform Documentation

Documentation for Android implementation of the Zebra Printer Plugin.

## ⚠️ Limited Support

The Android implementation currently has limited functionality compared to iOS.

## ✅ Supported Features

| Feature | Status | Notes |
|---------|--------|-------|
| Network Discovery | ✅ Partial | Basic UDP discovery |
| Network Printing | ✅ Full | TCP/IP printing works |
| ZPL Printing | ✅ Full | Complete support |
| CPCL Printing | ⚠️ Partial | Basic support |

## ❌ Not Yet Implemented

| Feature | Status | Notes |
|---------|--------|-------|
| Bluetooth Discovery | ❌ Missing | Code exists but incomplete |
| Bluetooth Printing | ❌ Missing | Not implemented |
| Bi-directional Communication | ❌ Missing | No SGD response reading |
| Background Printing | ❌ Missing | Not implemented |

## 🔧 Current Implementation

- **ZebraUtilPlugin.java** - Main plugin class
- **Printer.java** - Printer operations
- **BluetoothDiscoverer.java** - Bluetooth discovery (incomplete)
- **SocketManager.java** - Network communication

## 📱 Requirements

- Android API 21+
- Network permissions in manifest

## 🚧 Known Issues

1. Bluetooth discovery finds devices but connection fails
2. No status checking capability
3. No error recovery mechanisms
4. Thread management needs improvement

## 🔗 Related Documentation

- [Main README](../../../README.md)
- [API Reference](../../api/README.md)
- [Development TODO](../../development/TODO.md)

---

**Note**: For production use, iOS is recommended until Android implementation is complete. 