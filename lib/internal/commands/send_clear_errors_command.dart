import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send generic clear errors command to the printer
/// Note: This is a generic command that should be replaced with language-specific commands
/// Use SendZplClearErrorsCommand or SendCpclClearErrorsCommand instead
class SendGenericClearErrorsCommand extends SendCommandCommand {
  /// Constructor
  SendGenericClearErrorsCommand(ZebraPrinter printer)
      : super(printer, '~JA'); // ZPL clear errors command (generic fallback)
  
  @override
  String get operationName => 'Send Generic Clear Errors Command';
} 