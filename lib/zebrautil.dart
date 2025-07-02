/// Zebra Printer Utility - Flutter Plugin
///
/// This library provides a comprehensive interface for interacting with Zebra printers
/// on both iOS and Android platforms. It supports printer discovery, connection management,
/// and printing operations for both ZPL and CPCL formats.
library zebrautil;

// Main API exports
export 'zebra.dart';
export 'zebra_printer.dart';
export 'zebra_printer_service.dart';
export 'zebra_sgd_commands.dart';

// Model exports
export 'models/zebra_device.dart';
export 'models/result.dart';
export 'models/printer_readiness.dart';
export 'models/print_enums.dart';
export 'models/auto_correction_options.dart';

// Internal framework exports (advanced usage)
export 'internal/state_change_verifier.dart' show StateChangeVerifier;
// These are exported for internal plugin use only
export 'internal/native_operation.dart' hide NativeOperation;
export 'internal/operation_manager.dart' hide OperationManager;
export 'internal/operation_callback_handler.dart' hide OperationCallbackHandler;
