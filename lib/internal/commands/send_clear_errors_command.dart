import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send clear errors command to the printer (generic)
class SendClearErrorsCommand extends SendCommandCommand {
  /// Constructor
  SendClearErrorsCommand(ZebraPrinter printer)
      : super(printer, '~JA'); // ZPL clear errors command
  
  @override
  String get operationName => 'Send Clear Errors Command';
} 