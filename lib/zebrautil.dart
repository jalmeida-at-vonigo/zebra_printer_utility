/// Zebra Printer Utility - Flutter Plugin
///
/// This library provides a comprehensive interface for interacting with Zebra printers
/// on both iOS and Android platforms. It supports printer discovery, connection management,
/// and printing operations for both ZPL and CPCL formats.
library zebrautil;

// Main API exports
export 'zebra.dart' show Zebra;
export 'zebra_printer.dart' show ZebraPrinter, ZebraController, PrinterMode;
export 'smart/smart.dart';
export 'zebra_printer_service.dart' show ZebraPrinterService;
export 'zebra_printer_discovery.dart' show ZebraPrinterDiscovery;
export 'zebra_printer_readiness_manager.dart' show PrinterReadinessManager;
export 'zebra_sgd_commands.dart' show ZebraSGDCommands;

// Model exports
export 'models/zebra_device.dart' show ZebraDevice;
export 'models/result.dart'
    show Result, ErrorInfo, ZebraPrinterException, ErrorCodes;
export 'models/print_enums.dart' 
    show PrintFormat, EnumMediaType, Command;
export 'models/printer_readiness.dart' show PrinterReadiness;
export 'models/readiness_options.dart' show ReadinessOptions;
export 'models/readiness_result.dart' show ReadinessResult;

// Internal utilities (for advanced usage)
export 'internal/state_change_verifier.dart' show StateChangeVerifier;
export 'internal/parser_util.dart' show ParserUtil;
export 'internal/logger.dart' show Logger;
