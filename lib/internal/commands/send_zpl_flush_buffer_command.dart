import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send ZPL flush buffer command to the printer
class SendZplFlushBufferCommand extends SendCommandCommand {
  /// Constructor
  SendZplFlushBufferCommand(ZebraPrinter printer) : super(printer, '\x03'); // ETX character
  
  @override
  String get operationName => 'Send ZPL Flush Buffer Command';
} 