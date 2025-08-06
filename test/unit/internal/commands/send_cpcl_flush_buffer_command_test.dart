import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/commands/send_cpcl_flush_buffer_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class MockZebraPrinter extends Mock implements ZebraPrinter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final printer = MockZebraPrinter();
  final command = SendCpclFlushBufferCommand(printer);

  test('SendCpclFlushBufferCommand has correct operation name', () {
    expect(command.operationName, equals('Send CPCL Flush Buffer Command'));
  });

  test('SendCpclFlushBufferCommand has correct command string', () {
    expect(command.command, equals('\x03'));
  });
} 