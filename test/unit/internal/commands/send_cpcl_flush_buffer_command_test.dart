import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/commands/send_cpcl_flush_buffer_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class _FakePrinter extends ZebraPrinter {
  _FakePrinter() : super('test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SendCpclFlushBufferCommand has correct command and operation name', () {
    final cmd = SendCpclFlushBufferCommand(_FakePrinter());
    expect(cmd.command, '\x03');
    expect(cmd.operationName, 'Send CPCL Flush Buffer Command');
  });
} 