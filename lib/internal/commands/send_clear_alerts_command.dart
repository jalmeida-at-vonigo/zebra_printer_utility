import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to clear all printer alerts
class SendClearAlertsCommand extends SendCommandCommand {
  /// Constructor
  SendClearAlertsCommand(ZebraPrinter printer) : super(printer, '! U1 setvar "alerts.clear" "ALL"\r\n');
  
  @override
  String get operationName => 'Send Clear Alerts Command';
} 