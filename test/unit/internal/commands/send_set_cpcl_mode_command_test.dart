import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/commands/send_set_cpcl_mode_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class _FakePrinter extends ZebraPrinter {
  _FakePrinter() : super('test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SendSetCpclModeCommand has correct command and operation name', () {
    final cmd = SendSetCpclModeCommand(_FakePrinter());
    expect(cmd.command, '! U1 setvar "device.languages" "line_print"\r\n');
    expect(cmd.operationName, 'Send Set CPCL Mode Command');
  });
} 