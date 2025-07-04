import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/commands/send_set_zpl_mode_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class _FakePrinter extends ZebraPrinter {
  _FakePrinter() : super('test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SendSetZplModeCommand has correct command and operation name', () {
    final cmd = SendSetZplModeCommand(_FakePrinter());
    expect(cmd.command, '! U1 setvar "device.languages" "zpl"\r\n');
    expect(cmd.operationName, 'Send Set ZPL Mode Command');
  });
} 