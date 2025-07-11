import 'printer_command.dart';
import '../parser_util.dart';
import '../../models/result.dart';
import '../../models/host_status_info.dart';

/// Command to get host status from the printer
class GetHostStatusCommand extends PrinterCommand<HostStatusInfo> {
  /// Constructor
  GetHostStatusCommand(super.printer);

  @override
  String get operationName => 'Get Host Status';

  @override
  Future<Result<HostStatusInfo>> execute() async {
    try {
      logger.debug('Getting host status');
      final value = await printer.getSetting('device.host_status');
      if (value != null && value.isNotEmpty) {
        final parsed = ParserUtil.parseHostStatus(value);
        logger.debug('Host status parsed: \n');
        return Result.success(parsed);
      }
      logger.debug('Host status returned null or empty');
      return Result.success(ParserUtil.parseHostStatus(null));
    } catch (e) {
      logger.error('Failed to get host status', e);
      return Result.error('Failed to get host status: $e');
    }
  }
} 