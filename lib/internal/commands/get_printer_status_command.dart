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
    logger.debug('Getting printer status');
    
    // ZebraPrinter method is exception-free and already bridged
    final result = await printer.getPrinterStatus();
    
    if (result.success) {
      // Add business logic (status description generation)
      final enhanced = _enhanceStatusWithDescription(result.data!);
      return Result.success(enhanced);
    } else {
      // Propagate ZebraPrinter error, don't re-bridge
      return Result.errorFromResult(result, 'Status check failed');
    }
  }
  
  // Business logic stays in command
  Map<String, dynamic> _enhanceStatusWithDescription(
      Map<String, dynamic> status) {
    if (!status.containsKey('statusDescription')) {
      status['statusDescription'] = _generateStatusDescription(status);
    }
    return status;
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