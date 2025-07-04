import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/commands/send_zpl_clear_errors_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class _FakePrinter extends ZebraPrinter {
  _FakePrinter() : super('test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SendZplClearErrorsCommand has correct command and operation name', () {
    final cmd = SendZplClearErrorsCommand(_FakePrinter());
    expect(cmd.command, '~JA');
    expect(cmd.operationName, 'Send ZPL Clear Errors Command');
  });
} 