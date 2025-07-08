import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/commands/command_factory.dart';
import 'package:zebrautil/internal/commands/send_clear_alerts_command.dart';
import 'package:zebrautil/internal/commands/send_cpcl_clear_buffer_command.dart';
import 'package:zebrautil/internal/commands/send_cpcl_clear_errors_command.dart';
import 'package:zebrautil/internal/commands/send_cpcl_flush_buffer_command.dart';
import 'package:zebrautil/internal/commands/send_set_cpcl_mode_command.dart';
import 'package:zebrautil/internal/commands/send_set_zpl_mode_command.dart';
import 'package:zebrautil/internal/commands/send_zpl_clear_buffer_command.dart';
import 'package:zebrautil/internal/commands/send_zpl_clear_errors_command.dart';
import 'package:zebrautil/internal/commands/send_zpl_flush_buffer_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class _FakePrinter extends ZebraPrinter {
  _FakePrinter() : super('test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final printer = _FakePrinter();

  test('CommandFactory creates ZPL/CPCL and generic commands', () {
    expect(CommandFactory.createSendZplClearBufferCommand(printer), isA<SendZplClearBufferCommand>());
    expect(CommandFactory.createSendCpclClearBufferCommand(printer), isA<SendCpclClearBufferCommand>());
    expect(CommandFactory.createSendZplClearErrorsCommand(printer), isA<SendZplClearErrorsCommand>());
    expect(CommandFactory.createSendCpclClearErrorsCommand(printer), isA<SendCpclClearErrorsCommand>());
    expect(CommandFactory.createSendZplFlushBufferCommand(printer), isA<SendZplFlushBufferCommand>());
    expect(CommandFactory.createSendCpclFlushBufferCommand(printer),
        isA<SendCpclFlushBufferCommand>());
    expect(CommandFactory.createSendSetZplModeCommand(printer), isA<SendSetZplModeCommand>());
    expect(CommandFactory.createSendSetCpclModeCommand(printer), isA<SendSetCpclModeCommand>());
    expect(CommandFactory.createSendClearAlertsCommand(printer), isA<SendClearAlertsCommand>());
  });
} 