import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send generic flush buffer command to the printer
/// Note: This is a generic command that should be replaced with language-specific commands
/// Use SendZplFlushBufferCommand or SendCpclFlushBufferCommand instead
class SendGenericFlushBufferCommand extends SendCommandCommand {
  /// Constructor
  SendGenericFlushBufferCommand(ZebraPrinter printer)
      : super(printer, '\x03'); // ETX character
  
  @override
  String get operationName => 'Send Generic Flush Buffer Command';
} 