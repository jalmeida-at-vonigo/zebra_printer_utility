import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/parser_util.dart';

void main() {
  group('ParserUtil', () {
    group('toBool', () {
      test('returns true for true-like values', () {
        expect(ParserUtil.toBool(true), isTrue);
        expect(ParserUtil.toBool(1), isTrue);
        expect(ParserUtil.toBool('true'), isTrue);
        expect(ParserUtil.toBool('on'), isTrue);
        expect(ParserUtil.toBool('1'), isTrue);
        expect(ParserUtil.toBool('yes'), isTrue);
        expect(ParserUtil.toBool('y'), isTrue);
        expect(ParserUtil.toBool('enabled'), isTrue);
        expect(ParserUtil.toBool('active'), isTrue);
      });
      
      test('handles case-insensitive string values', () {
        expect(ParserUtil.toBool('TRUE'), isTrue);
        expect(ParserUtil.toBool('True'), isTrue);
        expect(ParserUtil.toBool('ON'), isTrue);
        expect(ParserUtil.toBool('Yes'), isTrue);
        expect(ParserUtil.toBool('FALSE'), isFalse);
        expect(ParserUtil.toBool('False'), isFalse);
      });
      
      test('handles whitespace in string values', () {
        expect(ParserUtil.toBool('  true  '), isTrue);
        expect(ParserUtil.toBool('\ttrue\n'), isTrue);
        expect(ParserUtil.toBool('  false  '), isFalse);
      });
      
      test('returns false for false-like values', () {
        expect(ParserUtil.toBool(false), isFalse);
        expect(ParserUtil.toBool(0), isFalse);
        expect(ParserUtil.toBool('false'), isFalse);
        expect(ParserUtil.toBool('off'), isFalse);
        expect(ParserUtil.toBool('0'), isFalse);
        expect(ParserUtil.toBool('no'), isFalse);
        expect(ParserUtil.toBool('n'), isFalse);
        expect(ParserUtil.toBool('disabled'), isFalse);
        expect(ParserUtil.toBool('inactive'), isFalse);
      });
      test('returns null for unknown values', () {
        expect(ParserUtil.toBool('maybe'), isNull);
        expect(ParserUtil.toBool(null), isNull);
        expect(ParserUtil.toBool([]), isNull);
      });
    });

    group('toInt', () {
      test('parses int and num', () {
        expect(ParserUtil.toInt(5), equals(5));
        expect(ParserUtil.toInt(5.7), equals(5));
      });
      test('parses string int', () {
        expect(ParserUtil.toInt('42'), equals(42));
        expect(ParserUtil.toInt('  42  '), equals(42));
      });
      test('parses string double', () {
        expect(ParserUtil.toInt('42.9'), equals(42));
      });
      test('extracts int from string', () {
        expect(ParserUtil.toInt('30 degrees'), equals(30));
        expect(ParserUtil.toInt('-15C'), equals(-15));
      });
      test('returns fallback for invalid', () {
        expect(ParserUtil.toInt('not a number', fallback: 7), equals(7));
        expect(ParserUtil.toInt(null, fallback: 9), equals(9));
      });
    });

    group('toDouble', () {
      test('parses double and num', () {
        expect(ParserUtil.toDouble(5.5), equals(5.5));
        expect(ParserUtil.toDouble(5), equals(5.0));
      });
      test('parses string double', () {
        expect(ParserUtil.toDouble('42.9'), equals(42.9));
        expect(ParserUtil.toDouble('  42.9  '), equals(42.9));
      });
      test('extracts double from string', () {
        expect(ParserUtil.toDouble('30.5 degrees'), equals(30.5));
        expect(ParserUtil.toDouble('-15.2C'), equals(-15.2));
      });
      test('returns fallback for invalid', () {
        expect(ParserUtil.toDouble('not a number', fallback: 7.1), equals(7.1));
        expect(ParserUtil.toDouble(null, fallback: 9.2), equals(9.2));
      });
    });

    group('safeToString', () {
      test('returns string for value', () {
        expect(ParserUtil.safeToString(123), equals('123'));
        expect(ParserUtil.safeToString('abc'), equals('abc'));
      });
      test('returns fallback for null', () {
        expect(ParserUtil.safeToString(null, fallback: 'none'), equals('none'));
      });
    });

    group('isStatusOk', () {
      test('returns true for ok/ready/normal/idle', () {
        expect(ParserUtil.isStatusOk('OK'), isTrue);
        expect(ParserUtil.isStatusOk('ready'), isTrue);
        expect(ParserUtil.isStatusOk('normal'), isTrue);
        expect(ParserUtil.isStatusOk('idle'), isTrue);
      });
      test('returns false for null or unknown', () {
        expect(ParserUtil.isStatusOk(null), isFalse);
        expect(ParserUtil.isStatusOk('error'), isFalse);
      });
    });

    group('hasMedia', () {
      test('returns true for loaded/ok/ready/present', () {
        expect(ParserUtil.hasMedia('loaded'), isTrue);
        expect(ParserUtil.hasMedia('ok'), isTrue);
        expect(ParserUtil.hasMedia('ready'), isTrue);
        expect(ParserUtil.hasMedia('present'), isTrue);
      });
      test('returns false for out/empty/missing/absent', () {
        expect(ParserUtil.hasMedia('out'), isFalse);
        expect(ParserUtil.hasMedia('empty'), isFalse);
        expect(ParserUtil.hasMedia('missing'), isFalse);
        expect(ParserUtil.hasMedia('absent'), isFalse);
      });
      test('returns false for null or unknown', () {
        expect(ParserUtil.hasMedia(null), isFalse);
        expect(ParserUtil.hasMedia('unknown'), isFalse);
      });
    });

    group('isHeadClosed', () {
      test('returns true for closed/ok/locked', () {
        expect(ParserUtil.isHeadClosed('closed'), isTrue);
        expect(ParserUtil.isHeadClosed('ok'), isTrue);
        expect(ParserUtil.isHeadClosed('locked'), isTrue);
      });
      test('returns false for open/unlocked', () {
        expect(ParserUtil.isHeadClosed('open'), isFalse);
        expect(ParserUtil.isHeadClosed('unlocked'), isFalse);
      });
      test('returns false for null or unknown', () {
        expect(ParserUtil.isHeadClosed(null), isFalse);
        expect(ParserUtil.isHeadClosed('unknown'), isFalse);
      });
    });

    group('parseErrorFromStatus', () {
      test('returns error string for known errors', () {
        expect(ParserUtil.parseErrorFromStatus('Paper out'),
            equals('Out of paper'));
        expect(ParserUtil.parseErrorFromStatus('Ribbon out'),
            equals('Out of ribbon'));
        expect(ParserUtil.parseErrorFromStatus('Head open'),
            equals('Print head open'));
        expect(ParserUtil.parseErrorFromStatus('Head cold'),
            equals('Print head cold'));
        expect(ParserUtil.parseErrorFromStatus('Head over temp'),
            equals('Print head overheated'));
        expect(
            ParserUtil.parseErrorFromStatus('Pause'), equals('Printer paused'));
        expect(ParserUtil.parseErrorFromStatus('error'), equals('error'));
      });
      test('returns null for no error', () {
        expect(ParserUtil.parseErrorFromStatus('OK'), isNull);
        expect(ParserUtil.parseErrorFromStatus(null), isNull);
      });
    });

    group('extractNumber', () {
      test('extracts number from string', () {
        expect(ParserUtil.extractNumber('203 dpi'), equals(203));
        expect(ParserUtil.extractNumber('-15.5C'), equals(-15.5));
      });
      test('returns null for no number', () {
        expect(ParserUtil.extractNumber('no number'), isNull);
        expect(ParserUtil.extractNumber(null), isNull);
      });
    });

    group('normalizeStatus', () {
      test('removes quotes and trims', () {
        expect(ParserUtil.normalizeStatus(' "OK" '), equals('OK'));
      });
      test('removes extra whitespace', () {
        expect(
            ParserUtil.normalizeStatus('  ready   now  '), equals('ready now'));
      });
      test('returns empty for null or empty', () {
        expect(ParserUtil.normalizeStatus(null), equals(''));
        expect(ParserUtil.normalizeStatus(''), equals(''));
      });
    });
  });
}
