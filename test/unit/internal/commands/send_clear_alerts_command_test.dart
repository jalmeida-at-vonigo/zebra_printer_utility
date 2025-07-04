import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/commands/send_clear_alerts_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class _FakePrinter extends ZebraPrinter {
  _FakePrinter() : super('test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SendClearAlertsCommand has correct command and operation name', () {
    final cmd = SendClearAlertsCommand(_FakePrinter());
    expect(cmd.command, '! U1 setvar "alerts.clear" "ALL"\r\n');
    expect(cmd.operationName, 'Send Clear Alerts Command');
  });
} 