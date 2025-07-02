import 'dart:async';
import 'package:flutter/services.dart';
import 'package:zebrautil/zebra_printer.dart';

// Export the simple API as the main interface
export 'zebra.dart';

// Export supporting classes
export 'zebra_device.dart';
export 'zebra_printer.dart' show EnumMediaType, PrintFormat;
export 'zebra_printer_service.dart';

// Keep the legacy API for backwards compatibility
class ZebraUtil {
  static const MethodChannel _channel = const MethodChannel('zebrautil');

  static Future<ZebraPrinter> getPrinterInstance(
      {Function(String, String?)? onDiscoveryError,
      Function? onPermissionDenied,
      ZebraController? controller}) async {
    String id = await _channel.invokeMethod("getInstance");
    ZebraPrinter printer = ZebraPrinter(
      id,
      controller: controller,
      onDiscoveryError: onDiscoveryError,
      onPermissionDenied: onPermissionDenied);
    return printer;
  }
}
