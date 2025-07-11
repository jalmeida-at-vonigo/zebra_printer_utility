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
        
        // Add statusDescription if not present
        if (!result.containsKey('statusDescription')) {
          result['statusDescription'] = _generateStatusDescription(result);
        }
        
        return Result.success(result);
      } else {
        throw Exception('Invalid response format for printer status');
      }
    } catch (e) {
      logger.error('Failed to get printer status', e);
      return Result.error('Failed to get printer status: $e');
    }
  }
  
  /// Generate human-readable status description
  String _generateStatusDescription(Map<String, dynamic> status) {
    final isReadyToPrint = status['isReadyToPrint'] == true;
    final isHeadOpen = status['isHeadOpen'] == true;
    final isPaperOut = status['isPaperOut'] == true;
    final isPaused = status['isPaused'] == true;
    final isRibbonOut = status['isRibbonOut'] == true;
    final isHeadCold = status['isHeadCold'] == true;
    final isHeadTooHot = status['isHeadTooHot'] == true;

    final messages = <String>[];

    if (isReadyToPrint) {
      return 'Ready to print';
    }

    if (isHeadOpen) messages.add('Head open');
    if (isPaperOut) messages.add('Paper out');
    if (isPaused) messages.add('Paused');
    if (isRibbonOut) messages.add('Ribbon out');
    if (isHeadCold) messages.add('Head cold');
    if (isHeadTooHot) messages.add('Head too hot');

    return messages.isNotEmpty ? messages.join('; ') : 'Unknown status';
  }
} 