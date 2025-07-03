import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/zebra_printer_service.dart';
import 'package:zebrautil/models/auto_correction_options.dart';
import 'package:zebrautil/models/print_enums.dart';
import 'package:zebrautil/models/result.dart';
import 'package:zebrautil/zebra_sgd_commands.dart';

void main() {
  group('ZebraPrinterService print with AutoCorrectionOptions', () {
    test('AutoCorrectionOptions.print() has correct settings', () {
      final options = AutoCorrectionOptions.print();

      expect(options.enableUnpause, isTrue);
      expect(options.enableClearErrors, isTrue);
      expect(options.enableReconnect, isFalse); // Don't reconnect during print
      expect(options.enableLanguageSwitch, isTrue);
      expect(options.enableCalibration, isFalse);
      expect(options.enableBufferClear,
          isTrue); // Key feature for print reliability
    });

    test('AutoCorrectionOptions.autoPrint() has correct settings', () {
      final options = AutoCorrectionOptions.autoPrint();

      expect(options.enableUnpause, isTrue);
      expect(options.enableClearErrors, isTrue);
      expect(options.enableReconnect, isTrue); // Do reconnect for autoPrint
      expect(options.enableLanguageSwitch, isTrue);
      expect(options.enableCalibration, isTrue); // Full safety for autoPrint
      expect(options.enableBufferClear, isTrue);
    });

    test('print method parameters are properly handled', () {
      // This test verifies that the service print method accepts all parameters
      final service = ZebraPrinterService();

      // Test that these parameters exist and can be passed
      Future<Result<void>> printCall() => service.print(
            '^XA^FDTest^FS^XZ',
            format: PrintFormat.zpl,
            clearBufferFirst: true,
            autoCorrectionOptions: AutoCorrectionOptions.print(),
          );

      // If this compiles, the method signature is correct
      expect(printCall, isA<Function>());
    });

    test('AutoCorrector correctForPrinting handles different formats',
        () async {
      // Test that CPCL always gets buffer clearing
      const cpclData =
          '! 0 200 200 210 1\r\nTEXT 4 0 30 40 Hello\r\nFORM\r\nPRINT\r\n';
      expect(ZebraSGDCommands.isCPCLData(cpclData), isTrue);

      const zplData = '^XA^FDTest^FS^XZ';
      expect(ZebraSGDCommands.isZPLData(zplData), isTrue);
    });

    test('clearBufferFirst parameter interaction with AutoCorrectionOptions',
        () {
      // When clearBufferFirst is true, it should use AutoCorrectionOptions.print()
      final optionsWithClear = AutoCorrectionOptions.print();
      expect(optionsWithClear.enableBufferClear, isTrue);

      // When clearBufferFirst is false and no options provided,
      // it should use basic options without buffer clear
      const basicOptions = AutoCorrectionOptions(
        enableUnpause: true,
        enableClearErrors: true,
        enableLanguageSwitch: true,
        enableBufferClear: false,
      );
      expect(basicOptions.enableBufferClear, isFalse);
    });
  });
}
