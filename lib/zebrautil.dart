/// Zebra Printer Utility - Flutter Plugin
///
/// This library provides a comprehensive interface for interacting with Zebra printers
/// on both iOS and Android platforms. It supports printer discovery, connection management,
/// and printing operations for both ZPL and CPCL formats.
///
/// **Export Structure:**
/// - Core functionality: Direct exports of main classes and managers
/// - Models: Use barrel export 'models/models.dart' only - do not export individual model files
/// - Internal utilities: Direct exports for advanced users only
///
/// **Important:** Do not export individual model files here. Use only the barrel export
/// 'models/models.dart' to prevent duplicate exports.
library zebrautil;

// Core functionality
export 'internal/commands/command_factory.dart';
export 'internal/communication_policy.dart';
export 'models/models.dart';
export 'smart_print_manager.dart';
export 'zebra.dart';
export 'zebra_printer.dart';
export 'zebra_printer_discovery.dart';
export 'zebra_printer_manager.dart';
export 'zebra_printer_readiness_manager.dart';
export 'zebra_sgd_commands.dart';
