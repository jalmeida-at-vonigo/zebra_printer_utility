import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/commands/send_clear_alerts_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class MockZebraPrinter extends Mock implements ZebraPrinter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final printer = MockZebraPrinter();
  final command = SendClearAlertsCommand(printer);

  test('SendClearAlertsCommand has correct operation name', () {
    expect(command.operationName, equals('Send Clear Alerts Command'));
  });

  test('SendClearAlertsCommand has correct command string', () {
    expect(command.command, equals('! U1 setvar "alerts.clear" "ALL"\r\n'));
  });
} 