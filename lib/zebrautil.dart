/// Zebra Printer Utility - Flutter Plugin
///
/// This library provides a comprehensive interface for interacting with Zebra printers
/// on both iOS and Android platforms. It supports printer discovery, connection management,
/// and printing operations for both ZPL and CPCL formats.
library zebrautil;

// Main API exports
export 'zebra.dart';
export 'zebra_printer.dart' show ZebraPrinter, ZebraController;
export 'zebra_printer_service.dart' show ZebraPrinterService;
export 'zebra_sgd_commands.dart';

// Model exports
export 'models/zebra_device.dart' show ZebraDevice;
export 'models/result.dart'
    show Result, ErrorInfo, ZebraPrinterException, ErrorCodes;
export 'models/print_enums.dart' show PrintFormat, EnumMediaType, Command;
export 'models/printer_readiness.dart' show PrinterReadiness;
export 'models/auto_correction_options.dart' show AutoCorrectionOptions;

// Internal framework exports (advanced usage)
export 'internal/state_change_verifier.dart' show StateChangeVerifier;
// These are exported for internal plugin use only
export 'internal/native_operation.dart' hide NativeOperation;
export 'internal/operation_manager.dart' hide OperationManager;
export 'internal/operation_callback_handler.dart' hide OperationCallbackHandler;

// Internal utilities (not exported by default)
export 'internal/auto_corrector.dart';
export 'internal/parser_util.dart';
export 'internal/logger.dart';
