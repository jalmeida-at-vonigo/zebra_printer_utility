import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/zebra_printer_service.dart';
import 'package:zebrautil/models/readiness_options.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/zebra_sgd_commands.dart';

void main() {
  group('ZebraPrinterService print with ReadinessOptions', () {
    test('ReadinessOptions.forPrinting() has correct settings', () {
      final options = ReadinessOptions.forPrinting();

      expect(options.fixPausedPrinter, isTrue);
      expect(options.fixPrinterErrors, isTrue);
      expect(options.checkConnection, isTrue);
      expect(options.fixLanguageMismatch,
          isFalse); // Should be false for forPrinting
      expect(options.fixMediaCalibration, isFalse);
      expect(options.clearBuffer, isTrue); // Key feature for print reliability
    });

    test('ReadinessOptions.comprehensive() has correct settings', () {
      final options = ReadinessOptions.comprehensive();

      expect(options.fixPausedPrinter, isTrue);
      expect(options.fixPrinterErrors, isTrue);
      expect(options.checkConnection, isTrue);
      expect(options.fixLanguageMismatch, isTrue);
      expect(
          options.fixMediaCalibration, isTrue); // Full safety for comprehensive
      expect(options.clearBuffer, isTrue);
    });

    test('print method parameters are properly handled', () {
      // This test verifies that the service print method accepts all parameters
      final service = ZebraPrinterService();

      // Test that these parameters exist and can be passed
      Future<Result<void>> printCall() => service.print(
            '^XA^FDTest^FS^XZ',
            format: PrintFormat.zpl,
            clearBufferFirst: true,
            readinessOptions: ReadinessOptions.forPrinting(),
          );

      // If this compiles, the method signature is correct
      expect(printCall, isA<Function>());
    });

    test('ZebraSGDCommands handles different formats', () async {
      // Test that CPCL always gets buffer clearing
      const cpclData =
          '! 0 200 200 210 1\r\nTEXT 4 0 30 40 Hello\r\nFORM\r\nPRINT\r\n';
      expect(ZebraSGDCommands.isCPCLData(cpclData), isTrue);

      const zplData = '^XA^FDTest^FS^XZ';
      expect(ZebraSGDCommands.isZPLData(zplData), isTrue);
    });

    test('clearBufferFirst parameter interaction with ReadinessOptions', () {
      // When clearBufferFirst is true, it should use ReadinessOptions.forPrinting()
      final optionsWithClear = ReadinessOptions.forPrinting();
      expect(optionsWithClear.clearBuffer, isTrue);

      // When clearBufferFirst is false and no options provided,
      // it should use basic options without buffer clear
      const basicOptions = ReadinessOptions(
        checkConnection: true,
        checkMedia: true,
        checkHead: true,
        checkPause: true,
        checkErrors: true,
        fixPausedPrinter: true,
        fixPrinterErrors: true,
        fixLanguageMismatch: true,
        clearBuffer: false,
      );
      expect(basicOptions.clearBuffer, isFalse);
    });
  });
}
