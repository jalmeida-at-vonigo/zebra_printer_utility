import '../../zebra_printer.dart';
import 'send_command_command.dart';

/// Command to send calibration command to the printer
class SendCalibrationCommand extends SendCommandCommand {
  /// Constructor
  SendCalibrationCommand(ZebraPrinter printer) : super(printer, '~jc^xa^jus^xz');
  
  @override
  String get operationName => 'Send Calibration Command';
} 