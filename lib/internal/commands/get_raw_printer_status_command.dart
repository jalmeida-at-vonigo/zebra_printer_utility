import '../../models/result.dart';
import 'printer_command.dart';

/// Command to get raw printer status (atomic operation)
class GetRawPrinterStatusCommand extends PrinterCommand<Map<String, dynamic>> {
  GetRawPrinterStatusCommand(super.printer);
  
  @override
  String get operationName => 'Get Raw Printer Status';
  
  @override
  Future<Result<Map<String, dynamic>>> execute() async {
    logger.debug('Getting raw printer status');
    
    // ZebraPrinter method is exception-free and already bridged
    final result = await printer.getPrinterStatus();
    
    if (result.success) {
      // Return raw status without enhancement (business logic: no processing)
      logger.debug('Raw printer status retrieved successfully');
      return Result.success(result.data!);
    } else {
      // Propagate ZebraPrinter error, don't re-bridge
      return Result.errorFromResult(result, 'Raw status check failed');
    }
  }
} 