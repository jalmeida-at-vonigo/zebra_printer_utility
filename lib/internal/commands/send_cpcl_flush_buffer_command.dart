import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send CPCL flush buffer command to the printer
class SendCpclFlushBufferCommand extends SendCommandCommand {
  /// Constructor
  SendCpclFlushBufferCommand(ZebraPrinter printer) : super(printer, '\x03'); // ETX character
  
  @override
  String get operationName => 'Send CPCL Flush Buffer Command';
} 