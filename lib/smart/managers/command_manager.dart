import '../../internal/logger.dart';
import '../../models/result.dart';
import '../../internal/commands/command_factory.dart';
import '../../zebra_printer.dart';
import '../../models/print_enums.dart';

class CommandManager {
  final Logger _logger;
  CommandManager(this._logger);

  Future<Result<void>> executeFormatSpecificCommand(PrintFormat format, String commandType, ZebraPrinter printer) async {
    try {
      _logger.debug('Executing $commandType for $format');
      switch (commandType) {
        case 'clearBuffer':
          if (format == PrintFormat.zpl) {
            return await CommandFactory.createSendZplClearBufferCommand(printer).execute();
          } else {
            return await CommandFactory.createSendCpclClearBufferCommand(printer).execute();
          }
        case 'clearErrors':
          if (format == PrintFormat.zpl) {
            return await CommandFactory.createSendZplClearErrorsCommand(printer).execute();
          } else {
            return await CommandFactory.createSendCpclClearErrorsCommand(printer).execute();
          }
        case 'flushBuffer':
          if (format == PrintFormat.zpl) {
            return await CommandFactory.createSendZplFlushBufferCommand(printer).execute();
          } else {
            return await CommandFactory.createSendCpclFlushBufferCommand(printer).execute();
          }
        default:
          return Result.error('Unknown command type: $commandType', code: ErrorCodes.invalidArgument);
      }
    } catch (e, stack) {
      _logger.error('Command execution failed', e, stack);
      return Result.error('Command execution failed: $e', code: ErrorCodes.operationError, dartStackTrace: stack);
    }
  }
} 