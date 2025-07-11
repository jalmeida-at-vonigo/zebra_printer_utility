/// Zebra Printer Utility - Flutter Plugin
///
/// This library provides a comprehensive interface for interacting with Zebra printers
/// on both iOS and Android platforms. It supports printer discovery, connection management,
/// and printing operations for both ZPL and CPCL formats.
library zebrautil;

// Core functionality
export 'zebra.dart';
export 'zebra_printer.dart';
export 'zebra_printer_manager.dart';
export 'zebra_printer_discovery.dart';
export 'zebra_printer_readiness_manager.dart';
export 'zebra_sgd_commands.dart';
export 'smart_print_manager.dart';

// Models
export 'models/models.dart';

// Internal utilities (for advanced users)
export 'internal/communication_policy.dart';
export 'internal/commands/command_factory.dart';
