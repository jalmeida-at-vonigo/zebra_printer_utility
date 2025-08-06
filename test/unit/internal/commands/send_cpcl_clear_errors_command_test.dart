import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/commands/send_cpcl_clear_errors_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class MockZebraPrinter extends Mock implements ZebraPrinter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final printer = MockZebraPrinter();
  final command = SendCpclClearErrorsCommand(printer);

  test('SendCpclClearErrorsCommand has correct operation name', () {
    expect(command.operationName, equals('Send CPCL Clear Errors Command'));
  });

  test('SendCpclClearErrorsCommand has correct command string', () {
    expect(command.command, equals('! U1 setvar "alerts.clear" "ALL"\r\n'));
  });
} 