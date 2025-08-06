import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/commands/send_cpcl_clear_buffer_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class MockZebraPrinter extends Mock implements ZebraPrinter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final printer = MockZebraPrinter();
  final command = SendCpclClearBufferCommand(printer);

  test('SendCpclClearBufferCommand has correct operation name', () {
    expect(command.operationName, equals('Send CPCL Clear Buffer Command'));
  });

  test('SendCpclClearBufferCommand has correct command string', () {
    expect(command.command, equals('\x18'));
  });
} 