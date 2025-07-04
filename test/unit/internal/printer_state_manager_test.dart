import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:zebrautil/zebra_printer_state_manager.dart';
import 'package:zebrautil/models/auto_correction_options.dart';
import 'package:zebrautil/models/printer_readiness.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_sgd_commands.dart';

class MockPrinter extends ZebraPrinter {
  List<String> sentCommands = [];
  dynamic printResult;
  dynamic getSettingResult;
  int getSettingCallCount = 0;
  String? initialLanguage;
  String? targetLanguage;
  bool languageSwitchCommandSent = false;
  Map<String, String?> settingResults = {};

  MockPrinter() : super('mock');

  @override
  Future<Result<void>> print({required String data}) async {
    sentCommands.add(data);
    
    // Simulate language change if this is a language switch command
    if (data.contains('device.languages') &&
        (data.contains('"zpl"') || data.contains('"line_print"'))) {
      languageSwitchCommandSent = true;
    }
    
    if (printResult is Exception) throw printResult;
    if (printResult is Result) return printResult;

    return Result.success();
  }
  
  @override
  void sendCommand(String command) {
    sentCommands.add(command);
  }

  @override
  Future<String?> getSetting(String key) async {
    getSettingCallCount++;
    if (getSettingResult is Exception) throw getSettingResult;
    
    // Check if we have a specific result for this key
    if (settingResults.containsKey(key)) {
      return settingResults[key];
    }

    // Simulate language setting behavior
    if (key == 'device.languages') {
      if (!languageSwitchCommandSent) {
        return initialLanguage ?? getSettingResult; // Before switch
      } else {
        return targetLanguage ?? getSettingResult; // After switch
      }
    }

    return getSettingResult;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  group('PrinterStateManager', () {
    late MockPrinter printer;
    late PrinterStateManager stateManager;
    late AutoCorrectionOptions options;
    late List<String> statusLog;

    setUp(() {
      printer = MockPrinter();
      printer.languageSwitchCommandSent = false;
      printer.getSettingCallCount = 0;
      printer.initialLanguage = null;
      printer.targetLanguage = null;
      options = const AutoCorrectionOptions();
      statusLog = [];
      stateManager = PrinterStateManager(
        printer: printer,
        options: options,
        statusCallback: statusLog.add,
      );
    });

    test('correctReadiness returns false if no corrections enabled', () async {
      stateManager = PrinterStateManager(
        printer: printer,
        options: AutoCorrectionOptions.none(),
      );
      final readiness = PrinterReadiness();
      final result = await stateManager.correctReadiness(readiness);
      expect(result.success, isTrue);
      expect(result.data, isFalse);
    });

    test('correctReadiness unpauses if paused', () async {
      final readiness = PrinterReadiness()..isPaused = true;
      printer.printResult = Result.success();
      final result = await stateManager.correctReadiness(readiness);
      expect(result.success, isTrue);
      expect(result.data, isTrue);
      expect(statusLog.any((m) => m.contains('unpause')), isTrue);
    });

    test('correctReadiness clears errors if present', () async {
      final readiness = PrinterReadiness()..errors.add('Error');
      printer.printResult = Result.success();
      final result = await stateManager.correctReadiness(readiness);
      expect(result.success, isTrue);
      expect(result.data, isTrue);
      expect(statusLog.any((m) => m.contains('clear errors')), isTrue);
    });

    test('correctReadiness calibrates if no media', () async {
      final readiness = PrinterReadiness()..hasMedia = false;
      printer.printResult = Result.success();
      stateManager = PrinterStateManager(
        printer: printer,
        options: options.copyWith(enableCalibration: true),
        statusCallback: statusLog.add,
      );
      final result = await stateManager.correctReadiness(readiness);
      expect(result.success, isTrue);
      expect(result.data, isTrue);
      expect(statusLog.any((m) => m.contains('calibrate')), isTrue);
    });

    test('_unpausePrinter returns success', () async {
      printer.printResult = Result.success();
      final result =
          await stateManager
          .correctReadiness(PrinterReadiness()..isPaused = true);
      expect(result.success, isTrue);
    });

    test('_clearErrors returns success', () async {
      printer.printResult = Result.success();
      final result = await stateManager
          .correctReadiness(PrinterReadiness()..errors.add('Error'));
      expect(result.success, isTrue);
    });

    test('_calibratePrinter returns success', () async {
      printer.printResult = Result.success();
      stateManager = PrinterStateManager(
        printer: printer,
        options: options.copyWith(enableCalibration: true),
      );
      final result = await stateManager
          .correctReadiness(PrinterReadiness()..hasMedia = false);
      expect(result.success, isTrue);
    });

    test('switchLanguageForData returns true if language switch not enabled',
        () async {
      final result = await stateManager.switchLanguageForData('^XA');
      expect(result, isTrue);
    });

    test('switchLanguageForData switches language if needed', () async {
      stateManager = PrinterStateManager(
        printer: printer,
        options: options.copyWith(enableLanguageSwitch: true),
      );
      printer.initialLanguage = 'cpcl';
      printer.targetLanguage = 'zpl';
      printer.languageSwitchCommandSent = false;
      printer.printResult = Result.success();
      final result = await stateManager.switchLanguageForData('^XA');
      expect(result, isTrue);
    });

    test('switchLanguageForData returns false if switch fails', () async {
      stateManager = PrinterStateManager(
        printer: printer,
        options: options.copyWith(enableLanguageSwitch: true),
      );
      printer.initialLanguage = 'cpcl';
      printer.printResult = Result.error('fail');
      final result = await stateManager.switchLanguageForData('^XA');
      expect(result, isFalse);
    });

    group('error handling', () {
      // test('correctReadiness handles unpause failure gracefully', () async {
      //   // Create stateManager with only unpause enabled to isolate the test
      //   stateManager = PrinterStateManager(
      //     printer: printer,
      //     options: const AutoCorrectionOptions(
      //       enableUnpause: true,
      //       enableClearErrors: false,
      //       enableCalibration: false,
      //     ),
      //     statusCallback: statusLog.add,
      //   );
        
      //   final readiness = PrinterReadiness()..isPaused = true;
      //   printer.printResult = Result.error('Unpause failed');
      //   printer.getSettingResult = 'true'; // Simulate paused state
      //   final result = await stateManager.correctReadiness(readiness);
        
      //   expect(result.success, isTrue);
      //   expect(result.data, isFalse); // No correction made
      //   expect(statusLog.any((m) => m.contains('Failed to unpause')), isTrue);
      // });

      test('correctReadiness handles clear errors failure gracefully', () async {
        final readiness = PrinterReadiness()..errors.add('Error');
        printer.printResult = Result.error('Clear failed');
        final result = await stateManager.correctReadiness(readiness);
        expect(result.success, isTrue);
        expect(result.data, isFalse); // No correction made
        expect(statusLog.any((m) => m.contains('Failed to clear errors')), isTrue);
      });

      test('correctReadiness handles calibration failure gracefully', () async {
        final readiness = PrinterReadiness()..hasMedia = false;
        printer.printResult = Result.error('Calibration failed');
        stateManager = PrinterStateManager(
          printer: printer,
          options: options.copyWith(enableCalibration: true),
          statusCallback: statusLog.add,
        );
        final result = await stateManager.correctReadiness(readiness);
        expect(result.success, isTrue);
        expect(result.data, isFalse); // No correction made
        expect(statusLog.any((m) => m.contains('Failed to calibrate')), isTrue);
      });

      test('switchLanguageForData handles getSetting exception', () async {
        stateManager = PrinterStateManager(
          printer: printer,
          options: options.copyWith(enableLanguageSwitch: true),
        );
        printer.getSettingResult = Exception('Network error');
        final result = await stateManager.switchLanguageForData('^XA');
        expect(result, isFalse);
      });

      test('switchLanguageForData handles null language detection', () async {
        stateManager = PrinterStateManager(
          printer: printer,
          options: options.copyWith(enableLanguageSwitch: true),
        );
        // Invalid data that can't be detected as ZPL or CPCL
        final result = await stateManager.switchLanguageForData('invalid data');
        expect(result, isTrue); // Should return true when can't detect
      });

      test('switchLanguageForData handles null current language', () async {
        stateManager = PrinterStateManager(
          printer: printer,
          options: options.copyWith(enableLanguageSwitch: true),
        );
        printer.getSettingResult = null;
        final result = await stateManager.switchLanguageForData('^XA');
        expect(result, isTrue); // Should return true when can't verify
      });
    });

    group('multiple corrections', () {
      test('correctReadiness handles multiple issues', () async {
        final readiness = PrinterReadiness()
          ..isPaused = true
          ..errors.add('Paper out')
          ..hasMedia = false;
        
        printer.printResult = Result.success();
        stateManager = PrinterStateManager(
          printer: printer,
          options: options.copyWith(
            enableUnpause: true,
            enableClearErrors: true,
            enableCalibration: true,
          ),
          statusCallback: statusLog.add,
        );
        
        final result = await stateManager.correctReadiness(readiness);
        expect(result.success, isTrue);
        expect(result.data, isTrue);
        expect(statusLog.any((m) => m.contains('unpause')), isTrue);
        expect(statusLog.any((m) => m.contains('clear errors')), isTrue);
        expect(statusLog.any((m) => m.contains('calibrate')), isTrue);
      });
    });

    group('edge cases', () {
      test('handles CPCL data format detection', () async {
        stateManager = PrinterStateManager(
          printer: printer,
          options: options.copyWith(enableLanguageSwitch: true),
        );
        printer.initialLanguage = 'zpl';
        printer.targetLanguage = 'line_print';
        printer.printResult = Result.success();
        
        // CPCL format data
        final result = await stateManager.switchLanguageForData('! 0 200 200 210 1\r\nTEXT 4 0 30 40 Hello\r\nFORM\r\nPRINT\r\n');
        expect(result, isTrue);
      });

      test('handles already correct language', () async {
        stateManager = PrinterStateManager(
          printer: printer,
          options: options.copyWith(enableLanguageSwitch: true),
        );
        printer.getSettingResult = 'zpl';
        
        // ZPL data when already in ZPL mode
        final result = await stateManager.switchLanguageForData('^XA^XZ');
        expect(result, isTrue);
        expect(printer.sentCommands, isEmpty); // Should not send any commands
      });
    });
    
    group('correctForPrinting', () {
      test('clears buffer when enableBufferClear is true', () async {
        final stateManager = PrinterStateManager(
          printer: printer,
          options: const AutoCorrectionOptions(enableBufferClear: true),
          statusCallback: statusLog.add,
        );

        printer.printResult = Result.success();

        final result = await stateManager.correctForPrinting(
          data: '^XA^FDTest^FS^XZ',
          format: PrintFormat.zpl,
        );

        expect(result.success, isTrue);
        expect(result.data, isTrue); // Made corrections (buffer clearing)

        // Verify buffer clearing commands were sent via sendCommand
        expect(printer.sentCommands.contains('~JA'), isTrue); // ZPL cancel all
      });

      test('always clears buffer for CPCL even if not enabled', () async {
        final stateManager = PrinterStateManager(
          printer: printer,
          options: const AutoCorrectionOptions(enableBufferClear: false),
          statusCallback: statusLog.add,
        );

        printer.printResult = Result.success();

        final result = await stateManager.correctForPrinting(
          data:
              '! 0 200 200 210 1\r\nTEXT 4 0 30 40 Hello\r\nFORM\r\nPRINT\r\n',
          format: PrintFormat.cpcl,
        );

        expect(result.success, isTrue);
        expect(
            result.data, isTrue); // Made corrections (buffer clearing for CPCL)

        // Verify buffer clearing commands were sent via sendCommand
        expect(printer.sentCommands.contains('\x1B'), isTrue); // ESC
        expect(printer.sentCommands.contains('\x18'), isTrue); // CAN
      });

      test('switches language if needed', () async {
        final stateManager = PrinterStateManager(
          printer: printer,
          options: const AutoCorrectionOptions(
            enableLanguageSwitch: true,
            enableBufferClear: false,
          ),
          statusCallback: statusLog.add,
        );

        printer.settingResults['device.languages'] = 'line_print';

        final result = await stateManager.correctForPrinting(
          data: '^XA^FDTest^FS^XZ',
          format: PrintFormat.zpl,
        );

        expect(result.success, isTrue);

        // Verify language switch command was sent
        expect(printer.sentCommands.contains(ZebraSGDCommands.setZPLMode()),
            isTrue);
      });

      test('unpauses printer if paused', () async {
        final stateManager = PrinterStateManager(
          printer: printer,
          options: const AutoCorrectionOptions(
            enableUnpause: true,
            enableBufferClear: false,
          ),
          statusCallback: statusLog.add,
        );

        printer.settingResults['device.pause'] = 'true';
        printer.settingResults['device.host_status'] = 'ok';

        final result = await stateManager.correctForPrinting(
          data: '^XA^FDTest^FS^XZ',
        );

        expect(result.success, isTrue);

        // Verify unpause command was sent
        expect(printer.sentCommands.contains(ZebraSGDCommands.unpausePrinter()),
            isTrue);
      });

      test('clears errors if present', () async {
        final stateManager = PrinterStateManager(
          printer: printer,
          options: const AutoCorrectionOptions(
            enableClearErrors: true,
            enableBufferClear: false,
          ),
          statusCallback: statusLog.add,
        );

        printer.settingResults['device.pause'] = 'false';
        printer.settingResults['device.host_status'] = 'error:paper out';

        final result = await stateManager.correctForPrinting(
          data: '^XA^FDTest^FS^XZ',
        );

        expect(result.success, isTrue);

        // Verify clear errors command was sent
        expect(printer.sentCommands.contains(ZebraSGDCommands.clearAlerts()),
            isTrue);
      });

      test('handles errors gracefully', () async {
        final stateManager = PrinterStateManager(
          printer: printer,
          options: const AutoCorrectionOptions(
            enableLanguageSwitch: true,
            enableBufferClear: false,
          ),
          statusCallback: statusLog.add,
        );

        // Make getSetting throw an exception
        printer.getSettingResult = Exception('Network error');

        final result = await stateManager.correctForPrinting(
          data: '^XA^FDTest^FS^XZ',
        );

        expect(result.success, isFalse); // Should fail due to exception
        expect(result.error?.message, contains('Pre-print correction failed'));
      });
    });
  });
}
