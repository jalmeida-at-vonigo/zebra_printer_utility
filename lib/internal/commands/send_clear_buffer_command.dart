import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send clear buffer command to the printer (generic)
class SendClearBufferCommand extends SendCommandCommand {
  /// Constructor
  SendClearBufferCommand(ZebraPrinter printer) : super(printer, '\x18'); // CAN character
  
  @override
  String get operationName => 'Send Clear Buffer Command';
} 