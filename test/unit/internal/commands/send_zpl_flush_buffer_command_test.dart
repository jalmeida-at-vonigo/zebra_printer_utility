import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/commands/send_zpl_flush_buffer_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class _FakePrinter extends ZebraPrinter {
  _FakePrinter() : super('test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SendZplFlushBufferCommand has correct command and operation name', () {
    final cmd = SendZplFlushBufferCommand(_FakePrinter());
    expect(cmd.command, '\x03');
    expect(cmd.operationName, 'Send ZPL Flush Buffer Command');
  });
} 