import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:zebrautil/internal/commands/send_zpl_flush_buffer_command.dart';
import 'package:zebrautil/zebra_printer.dart';

class MockZebraPrinter extends Mock implements ZebraPrinter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final printer = MockZebraPrinter();
  final command = SendZplFlushBufferCommand(printer);

  test('SendZplFlushBufferCommand has correct operation name', () {
    expect(command.operationName, equals('Send ZPL Flush Buffer Command'));
  });

  test('SendZplFlushBufferCommand has correct command string', () {
    expect(command.command, equals('\x03'));
  });
} 