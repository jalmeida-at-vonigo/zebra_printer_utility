import '../../models/result.dart';
import 'printer_command.dart';

/// Command to get printer status from the printer
class GetPrinterStatusCommand extends PrinterCommand<Map<String, dynamic>> {
  /// Constructor
  GetPrinterStatusCommand(super.printer);
  
  @override
  String get operationName => 'Get Printer Status Command';

  @override
  Future<Result<Map<String, dynamic>>> execute() async {
    try {
      logger.debug('Getting printer status');
      
      // Use the operation manager to call the native method
      final result = await printer.channel.invokeMethod('getPrinterStatus');
      
      if (result is Map<String, dynamic>) {
        logger.debug('Printer status retrieved successfully');
        return Result.success(result);
      } else {
        throw Exception('Invalid response format for printer status');
      }
    } catch (e) {
      logger.error('Failed to get printer status', e);
      return Result.error('Failed to get printer status: $e');
    }
  }
} 