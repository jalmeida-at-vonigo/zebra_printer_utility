/// Zebra Printer Utility - Flutter Plugin
///
/// This library provides a comprehensive interface for interacting with Zebra printers
/// on both iOS and Android platforms. It supports printer discovery, connection management,
/// and printing operations for both ZPL and CPCL formats.
///
/// ## Smart API (v2.3+) - Recommended
/// For high-performance printing with 60-80% performance improvements:
/// ```dart
/// // Simple smart print - handles everything automatically
/// await Zebra.smartPrint('^XA^FO50,50^A0N,50,50^FDHello World^FS^XZ');
/// 
/// // Smart discovery
/// final result = await Zebra.smartDiscover();
/// 
/// // Batch printing
/// await Zebra.smartPrintBatch(labels);
/// ```
///
/// ## Legacy API (v2.2 and earlier)
/// For backward compatibility and advanced control:
/// ```dart
/// final service = ZebraPrinterService();
/// await service.initialize();
/// await service.print(data);
/// ```
library zebrautil;

// Main API exports
export 'zebra.dart' show Zebra;
export 'zebra_printer.dart' show ZebraPrinter, ZebraController, PrinterMode;

// Smart API exports (v2.3+)
export 'smart/smart.dart';
export 'smart/zebra_printer_smart.dart' show ZebraPrinterSmart;
export 'smart/options/smart_print_options.dart' show SmartPrintOptions;
export 'smart/options/smart_batch_options.dart' show SmartBatchOptions;
export 'smart/options/connect_options.dart' show ConnectOptions;
export 'smart/options/discovery_options.dart' show DiscoveryOptions;
export 'smart/models/zebra_printer_smart_status.dart' show ZebraPrinterSmartStatus;

// Legacy API exports (v2.2 and earlier)
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
