import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/logger.dart';

void main() {
  group('Logger', () {
    test('logs at all levels with correct prefix', () {
      final messages = <String>[];
      final logger = Logger(
          prefix: 'Test',
          minimumLevel: LogLevel.debug,
          customLogger: messages.add);
      logger.debug('debug message');
      logger.info('info message');
      logger.warning('warning message');
      logger.error('error message');
      expect(messages[0], contains('[Test] DEBUG: debug message'));
      expect(messages[1], contains('[Test] INFO: info message'));
      expect(messages[2], contains('[Test] WARNING: warning message'));
      expect(messages[3], contains('[Test] ERROR: error message'));
    });

    test('respects minimumLevel', () {
      final messages = <String>[];
      final logger = Logger(
          prefix: 'Test',
          minimumLevel: LogLevel.warning,
          customLogger: messages.add);
      logger.debug('debug message');
      logger.info('info message');
      logger.warning('warning message');
      logger.error('error message');
      expect(messages, hasLength(2));
      expect(messages[0], contains('WARNING: warning message'));
      expect(messages[1], contains('ERROR: error message'));
    });

    test('error logs error and stack trace', () {
      final messages = <String>[];
      final logger = Logger(
          prefix: 'Test',
          minimumLevel: LogLevel.debug,
          customLogger: messages.add);
      final stack = StackTrace.current;
      logger.error('error message', 'error object', stack);
      expect(messages.any((m) => m.contains('error object')), isTrue);
      // Stack trace is only logged in debug mode, so we check for presence of 'Stack trace:'
      expect(messages.any((m) => m.contains('Stack trace:')), isTrue);
    });

    test('child logger appends suffix', () {
      final messages = <String>[];
      final logger = Logger(prefix: 'Parent', customLogger: messages.add);
      final child = logger.child('Child');
      child.info('child message');
      expect(messages[0], contains('[Parent.Child] INFO: child message'));
    });
  });
}
