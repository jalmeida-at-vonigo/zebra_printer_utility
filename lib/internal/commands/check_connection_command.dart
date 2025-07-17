import '../../models/result.dart';
import 'printer_command.dart';

/// Command to check if the printer is connected
class CheckConnectionCommand extends PrinterCommand<bool> {
  /// Constructor
  CheckConnectionCommand(super.printer);
  
  @override
  String get operationName => 'Check Connection';
  
  @override
  Future<Result<bool>> execute() async {
    logger.debug('Checking printer connection');
    
    // ZebraPrinter handles ALL ZSDK errors and returns Result<bool>
    // No try-catch needed - ZebraPrinter is exception-free
    final result = await printer.isPrinterConnected();

    if (result.success) {
      logger.debug('Connection status: ${result.data}');
      return Result.success(result.data!);
    } else {
      // Simply propagate the already-bridged error from ZebraPrinter
      return Result.errorFromResult(result, 'Connection check failed');
    }
  }
} 