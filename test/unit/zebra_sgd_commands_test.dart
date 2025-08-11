import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/internal/parser_util.dart';

void main() {
  group('ParserUtil', () {
    test('parseResponse extracts value from SGD response', () {
      expect(ParserUtil.parseResponse('"foo" : "bar"'), equals('bar'));
      expect(ParserUtil.parseResponse('"bar"'), equals('bar'));
      expect(ParserUtil.parseResponse('baz'), equals('baz'));
      expect(ParserUtil.parseResponse(''), isNull);
    });
  });
}
