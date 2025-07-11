import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/parser_util.dart';
import 'package:zebrautil/models/host_status_info.dart';

void main() {
  group('ParserUtil - Host Status Parsing', () {
    group('parseHostStatus', () {
      test('should handle null status', () {
        final result = ParserUtil.parseHostStatus(null);
        expect(result.isOk, false);
        expect(result.errorCode, null);
        expect(result.errorMessage, 'No status response');
        expect(result.details, {});
      });

      test('should handle empty status', () {
        final result = ParserUtil.parseHostStatus('');
        expect(result.isOk, false);
        expect(result.errorCode, null);
        expect(result.errorMessage, 'No status response');
        expect(result.details, {});
      });

      test('should parse OK text status', () {
        final result = ParserUtil.parseHostStatus('OK');
        expect(result.isOk, true);
        expect(result.errorCode, null);
        expect(result.errorMessage, null);
        expect(result.details['rawStatus'], 'OK');
        expect(result.details['statusType'], 'text');
      });

      test('should parse Ready text status', () {
        final result = ParserUtil.parseHostStatus('Ready');
        expect(result.isOk, true);
        expect(result.errorCode, null);
        expect(result.errorMessage, null);
        expect(result.details['rawStatus'], 'Ready');
        expect(result.details['statusType'], 'text');
      });

      test('should parse error text status', () {
        final result = ParserUtil.parseHostStatus('Paper Out');
        expect(result.isOk, false);
        expect(result.errorCode, null);
        expect(result.errorMessage, 'Out of paper');
        expect(result.details['rawStatus'], 'Paper Out');
        expect(result.details['statusType'], 'text');
      });

      test('should parse comma-separated OK status', () {
        final result = ParserUtil.parseHostStatus('0,0,0,0,0,0,0,0,0,0,0,0');
        expect(result.isOk, true);
        expect(result.errorCode, 0);
        expect(result.errorMessage, null); // No error message for OK status
        expect(result.details['rawStatus'], '0,0,0,0,0,0,0,0,0,0,0,0');
        expect(result.details['statusType'], 'comma_separated');
        expect(result.details['fieldCount'], 12);
      });

      test('should parse comma-separated error status', () {
        final result =
            ParserUtil.parseHostStatus('159,0,0,2030,000,0,0,0,000,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 159);
        expect(result.errorMessage, 'Hardware error detected');
        expect(result.details['rawStatus'], '159,0,0,2030,000,0,0,0,000,0,0,0');
        expect(result.details['statusType'], 'comma_separated');
        expect(result.details['fieldCount'], 12);
        expect(result.details['field1'], 0);
        expect(result.details['field2'], 0);
        expect(result.details['field3'], 2030);
        expect(result.details['field4'],
            '000'); // field4 is kept as string (not parsed as int)
        expect(result.details['field5'], 0);
      });

      test('should parse out of paper error', () {
        final result = ParserUtil.parseHostStatus('100,1,0,0,0,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 100);
        expect(result.errorMessage, 'Out of paper/media');
      });

      test('should parse out of ribbon error', () {
        final result = ParserUtil.parseHostStatus('101,0,1,0,0,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 101);
        expect(result.errorMessage, 'Out of ribbon');
      });

      test('should parse head open error', () {
        final result = ParserUtil.parseHostStatus('102,0,0,1,0,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 102);
        expect(result.errorMessage, 'Print head is open');
      });

      test('should parse head cold error', () {
        final result = ParserUtil.parseHostStatus('103,0,0,0,1,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 103);
        expect(result.errorMessage, 'Print head is cold');
      });

      test('should parse head too hot error', () {
        final result = ParserUtil.parseHostStatus('104,0,0,0,0,1,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 104);
        expect(result.errorMessage, 'Print head is too hot');
      });

      test('should parse paused status', () {
        final result = ParserUtil.parseHostStatus('1,0,0,0,0,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 1);
        expect(result.errorMessage, 'Printer is paused');
      });

      test('should parse processing status', () {
        final result = ParserUtil.parseHostStatus('2,0,0,0,0,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 2);
        expect(result.errorMessage, 'Printer is processing');
      });

      test('should parse warming up status', () {
        final result = ParserUtil.parseHostStatus('4,0,0,0,0,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 4);
        expect(result.errorMessage, 'Printer is warming up');
      });

      test('should parse firmware error', () {
        final result = ParserUtil.parseHostStatus('160,0,0,0,0,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 160);
        expect(result.errorMessage, 'Firmware error');
      });

      test('should parse communication error', () {
        final result = ParserUtil.parseHostStatus('163,0,0,0,0,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 163);
        expect(result.errorMessage, 'Communication error');
      });

      test('should parse unknown error code', () {
        final result = ParserUtil.parseHostStatus('999,0,0,0,0,0,0,0,0,0,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 999);
        expect(result.errorMessage, 'Unknown error code: 999');
      });

      test('should handle short comma-separated status', () {
        final result = ParserUtil.parseHostStatus('159,0,0');
        expect(result.isOk, false);
        expect(result.errorCode, 159);
        expect(result.errorMessage, 'Hardware error detected');
        expect(result.details['fieldCount'], 3);
        expect(result.details['field1'], 0);
        expect(result.details['field2'], 0);
        expect(result.details['field3'], null); // Should not exist
      });

      test('should handle invalid comma-separated status', () {
        final result = ParserUtil.parseHostStatus(',');
        expect(result.isOk, false);
        expect(result.errorCode, null);
        expect(result.errorMessage, 'Invalid status format');
        expect(result.details['rawStatus'], ',');
      });

      test('should handle empty comma-separated status', () {
        final result = ParserUtil.parseHostStatus('');
        expect(result.isOk, false);
        expect(result.errorCode, null);
        expect(result.errorMessage, 'No status response');
        expect(result.details, {});
      });

      test('should normalize status with quotes', () {
        final result =
            ParserUtil.parseHostStatus('"159,0,0,2030,000,0,0,0,000,0,0,0"');
        expect(result.isOk, false);
        expect(result.errorCode, 159);
        expect(result.errorMessage, 'Hardware error detected');
        expect(result.details['rawStatus'], '159,0,0,2030,000,0,0,0,000,0,0,0');
      });

      test('should normalize status with extra whitespace', () {
        final result =
            ParserUtil.parseHostStatus('  159,0,0,2030,000,0,0,0,000,0,0,0  ');
        expect(result.isOk, false);
        expect(result.errorCode, 159);
        expect(result.errorMessage, 'Hardware error detected');
        expect(result.details['rawStatus'], '159,0,0,2030,000,0,0,0,000,0,0,0');
      });
    });

    group('HostStatusInfo', () {
      test('should convert to map correctly', () {
        final info = HostStatusInfo(
          isOk: false,
          errorCode: 159,
          errorMessage: 'Hardware error detected',
          details: {'test': 'value'},
        );

        final map = info.toMap();
        expect(map['isOk'], false);
        expect(map['errorCode'], 159);
        expect(map['errorMessage'], 'Hardware error detected');
        expect(map['details'], {'test': 'value'});
      });

      test('should convert to string correctly for OK status', () {
        final info = HostStatusInfo(
          isOk: true,
          errorCode: 0,
          errorMessage: null,
          details: {},
        );

        expect(info.toString(), 'HostStatusInfo(OK)');
      });

      test('should convert to string correctly for error status', () {
        final info = HostStatusInfo(
          isOk: false,
          errorCode: 159,
          errorMessage: 'Hardware error detected',
          details: {},
        );

        expect(info.toString(),
            'HostStatusInfo(Error: Hardware error detected [Code: 159])');
      });
    });

    group('parseErrorFromStatus (legacy compatibility)', () {
      test('should use new host status parsing for comma-separated format', () {
        final result =
            ParserUtil.parseErrorFromStatus('159,0,0,2030,000,0,0,0,000,0,0,0');
        expect(result, 'Hardware error detected');
      });

      test('should fallback to text parsing for simple errors', () {
        final result = ParserUtil.parseErrorFromStatus('Paper Out');
        expect(result, 'Out of paper');
      });

      test('should return null for OK status', () {
        final result = ParserUtil.parseErrorFromStatus('OK');
        expect(result, null);
      });
    });
  });
}
