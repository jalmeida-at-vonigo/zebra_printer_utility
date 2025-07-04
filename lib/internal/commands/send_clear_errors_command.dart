import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send clear errors command to the printer
class SendClearErrorsCommand extends SendCommandCommand {
  /// Constructor
  SendClearErrorsCommand(ZebraPrinter printer) : super(printer, '~JA');
  
  @override
  String get operationName => 'Send Clear Errors Command';
} 