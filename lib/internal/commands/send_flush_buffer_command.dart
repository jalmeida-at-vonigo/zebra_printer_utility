import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send flush buffer command to the printer (generic)
class SendFlushBufferCommand extends SendCommandCommand {
  /// Constructor
  SendFlushBufferCommand(ZebraPrinter printer) : super(printer, '\x03'); // ETX character
  
  @override
  String get operationName => 'Send Flush Buffer Command';
} 