import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/commands/send_zpl_clear_buffer_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class _FakePrinter extends ZebraPrinter {
  _FakePrinter() : super('test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SendZplClearBufferCommand has correct command and operation name', () {
    final cmd = SendZplClearBufferCommand(_FakePrinter());
    expect(cmd.command, '\x18');
    expect(cmd.operationName, 'Send ZPL Clear Buffer Command');
  });
} 