import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/commands/send_set_cpcl_mode_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class MockZebraPrinter extends Mock implements ZebraPrinter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final printer = MockZebraPrinter();
  final command = SendSetCpclModeCommand(printer);

  test('SendSetCpclModeCommand has correct operation name', () {
    expect(command.operationName, equals('Send Set CPCL Mode Command'));
  });

  test('SendSetCpclModeCommand has correct command string', () {
    expect(command.command,
        equals('! U1 setvar "device.languages" "line_print"\r\n'));
  });
} 