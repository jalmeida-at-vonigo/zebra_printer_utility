import '../../zebra_printer.dart';
import '../logger.dart';
import 'base_command.dart';

/// Abstract base class for printer-specific commands
abstract class PrinterCommand<T> extends BaseCommand<T> {
  /// Constructor that takes a printer instance
  PrinterCommand(this.printer) : logger = Logger.withPrefix('PrinterCommand');
  
  /// The printer instance to operate on
  final ZebraPrinter printer;
  
  /// Logger instance for this command
  final Logger logger;
} 