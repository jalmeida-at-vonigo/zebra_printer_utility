import '../../models/host_status_info.dart';
import '../../models/result.dart';
import '../parser_util.dart';
import 'printer_command.dart';

/// Command to get host status from the printer
class GetHostStatusCommand extends PrinterCommand<HostStatusInfo> {
  /// Constructor
  GetHostStatusCommand(super.printer);

  @override
  String get operationName => 'Get Host Status';

  @override
  Future<Result<HostStatusInfo>> execute() async {
    logger.debug('Getting host status');
    
    // ZebraPrinter method is exception-free and already bridged
    final result = await printer.getSetting('device.host_status');

    if (result.success) {
      final value = result.data;
      if (value != null && value.isNotEmpty) {
        final parsed = ParserUtil.parseHostStatus(value);
        logger.debug('Host status parsed: \n');
        return Result.success(parsed);
      }
      logger.debug('Host status returned null or empty');
      return Result.success(ParserUtil.parseHostStatus(null));
    } else {
      // Propagate ZebraPrinter error, preserve context
      return Result.errorFromResult(result, 'Host status retrieval failed');
    }
  }
} 