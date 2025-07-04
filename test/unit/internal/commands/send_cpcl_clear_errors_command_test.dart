import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/commands/send_cpcl_clear_errors_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class _FakePrinter extends ZebraPrinter {
  _FakePrinter() : super('test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SendCpclClearErrorsCommand has correct command and operation name', () {
    final cmd = SendCpclClearErrorsCommand(_FakePrinter());
    expect(cmd.command, '! U1 setvar "alerts.clear" "ALL"\r\n');
    expect(cmd.operationName, 'Send CPCL Clear Errors Command');
  });
} 