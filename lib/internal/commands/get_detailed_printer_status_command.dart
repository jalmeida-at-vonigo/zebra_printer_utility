import '../../models/result.dart';
import 'printer_command.dart';

/// Command to get detailed printer status with recommendations
class GetDetailedPrinterStatusCommand extends PrinterCommand<Map<String, dynamic>> {
  /// Constructor
  GetDetailedPrinterStatusCommand(super.printer);
  
  @override
  String get operationName => 'Get Detailed Printer Status Command';

  @override
  Future<Result<Map<String, dynamic>>> execute() async {
    try {
      logger.debug('Getting detailed printer status');
      
      final result = await printer.channel.invokeMethod('getDetailedPrinterStatus');
      
      if (result is Map<String, dynamic>) {
        logger.debug('Detailed printer status retrieved successfully');
        return Result.success(result);
      } else {
        throw Exception('Invalid response format for detailed printer status');
      }
    } catch (e) {
      logger.error('Failed to get detailed printer status', e);
      return Result.error('Failed to get detailed printer status: $e');
    }
  }
} 