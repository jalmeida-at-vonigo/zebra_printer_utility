import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/models/auto_correction_options.dart';

void main() {
  group('AutoCorrectionOptions', () {
    test('default values', () {
      const options = AutoCorrectionOptions();
      expect(options.enableUnpause, isTrue);
      expect(options.enableClearErrors, isTrue);
      expect(options.enableReconnect, isTrue);
      expect(options.enableLanguageSwitch, isFalse);
      expect(options.enableCalibration, isFalse);
      expect(options.maxAttempts, equals(3));
      expect(options.attemptDelayMs, equals(500));
    });

    test('all factory enables all options', () {
      final options = AutoCorrectionOptions.all();
      expect(options.enableUnpause, isTrue);
      expect(options.enableClearErrors, isTrue);
      expect(options.enableReconnect, isTrue);
      expect(options.enableLanguageSwitch, isTrue);
      expect(options.enableCalibration, isTrue);
    });

    test('none factory disables all options', () {
      final options = AutoCorrectionOptions.none();
      expect(options.enableUnpause, isFalse);
      expect(options.enableClearErrors, isFalse);
      expect(options.enableReconnect, isFalse);
      expect(options.enableLanguageSwitch, isFalse);
      expect(options.enableCalibration, isFalse);
    });

    test('safe factory enables only safe options', () {
      final options = AutoCorrectionOptions.safe();
      expect(options.enableUnpause, isTrue);
      expect(options.enableClearErrors, isTrue);
      expect(options.enableReconnect, isTrue);
      expect(options.enableLanguageSwitch, isFalse);
      expect(options.enableCalibration, isFalse);
    });

    test('copyWith returns identical object if no changes', () {
      const options = AutoCorrectionOptions();
      final copy = options.copyWith();
      expect(copy, isNot(same(options)));
      expect(copy.enableUnpause, equals(options.enableUnpause));
      expect(copy.enableClearErrors, equals(options.enableClearErrors));
      expect(copy.enableReconnect, equals(options.enableReconnect));
      expect(copy.enableLanguageSwitch, equals(options.enableLanguageSwitch));
      expect(copy.enableCalibration, equals(options.enableCalibration));
      expect(copy.maxAttempts, equals(options.maxAttempts));
      expect(copy.attemptDelayMs, equals(options.attemptDelayMs));
    });

    test('copyWith applies changes', () {
      const options = AutoCorrectionOptions();
      final copy = options.copyWith(
        enableUnpause: false,
        enableClearErrors: false,
        enableReconnect: false,
        enableLanguageSwitch: true,
        enableCalibration: true,
        maxAttempts: 10,
        attemptDelayMs: 1000,
      );
      expect(copy.enableUnpause, isFalse);
      expect(copy.enableClearErrors, isFalse);
      expect(copy.enableReconnect, isFalse);
      expect(copy.enableLanguageSwitch, isTrue);
      expect(copy.enableCalibration, isTrue);
      expect(copy.maxAttempts, equals(10));
      expect(copy.attemptDelayMs, equals(1000));
    });

    test('hasAnyEnabled returns true if any enabled', () {
      expect(const AutoCorrectionOptions().hasAnyEnabled, isTrue);
      expect(AutoCorrectionOptions.none().hasAnyEnabled, isFalse);
      expect(AutoCorrectionOptions.all().hasAnyEnabled, isTrue);
    });

    test('toString returns expected format', () {
      const options = AutoCorrectionOptions();
      final str = options.toString();
      expect(str, contains('unpause: true'));
      expect(str, contains('clearErrors: true'));
      expect(str, contains('reconnect: true'));
      expect(str, contains('languageSwitch: false'));
      expect(str, contains('calibration: false'));
      expect(str, contains('maxAttempts: 3'));
      expect(str, contains('attemptDelayMs: 500'));
    });
  });
}
