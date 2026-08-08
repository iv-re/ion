import 'package:http_headers/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('parseCsv', () {
    test('returns empty iterable for empty input', () {
      expect(parseCsv([]), isEmpty);
    });

    test('parses single item', () {
      expect(parseCsv(['gzip']), equals(['gzip']));
    });

    test('parses comma-separated string into list of trimmed strings', () {
      expect(
        parseCsv(['gzip, deflate, br']),
        equals(['gzip', 'deflate', 'br']),
      );
    });

    test('combines multiple header value entries', () {
      expect(
        parseCsv(['gzip, deflate', 'br, identity']),
        equals(['gzip', 'deflate', 'br', 'identity']),
      );
    });

    test('trims spaces, tabs, and newline characters around items', () {
      expect(
        parseCsv([' \tgzip \n, \rdeflate\t ']),
        equals(['gzip', 'deflate']),
      );
    });

    test('ignores empty elements resulting from consecutive commas', () {
      expect(
        parseCsv([',,gzip,, ,deflate,']),
        equals(['gzip', 'deflate']),
      );
    });

    test('ignores empty strings in values list', () {
      expect(
        parseCsv(['', 'gzip, deflate', '', 'br']),
        equals(['gzip', 'deflate', 'br']),
      );
    });

    test('preserves commas inside double quotes', () {
      expect(
        parseCsv(['"a, b", c, "d, e, f"']),
        equals(['"a, b"', 'c', '"d, e, f"']),
      );
    });

    test('handles quotes with whitespace properly', () {
      expect(
        parseCsv(['  " text with , commas " , normal ']),
        equals(['" text with , commas "', 'normal']),
      );
    });
  });

  group('isAsciiDigits', () {
    test('returns true for valid ASCII digits', () {
      expect(isAsciiDigits('1234567890'), isTrue);
      expect(isAsciiDigits('0'), isTrue);
    });

    test(
      'returns false for non-ASCII digits, signs, decimals, or whitespace',
      () {
        expect(isAsciiDigits(''), isFalse);
        expect(isAsciiDigits('123a'), isFalse);
        expect(isAsciiDigits('-10'), isFalse);
        expect(isAsciiDigits('+10'), isFalse);
        expect(isAsciiDigits(' 10'), isFalse);
        expect(isAsciiDigits('10.0'), isFalse);
      },
    );
  });
}
