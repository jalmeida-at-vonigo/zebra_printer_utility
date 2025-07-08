import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send generic clear buffer command to the printer
/// Note: This is a generic command that should be replaced with language-specific commands
/// Use SendZplClearBufferCommand or SendCpclClearBufferCommand instead
class SendGenericClearBufferCommand extends SendCommandCommand {
  /// Constructor
  SendGenericClearBufferCommand(ZebraPrinter printer)
      : super(printer, '\x18'); // CAN character
  
  @override
  String get operationName => 'Send Generic Clear Buffer Command';
} 