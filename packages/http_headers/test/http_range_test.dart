import 'package:http_headers/src/http_range.dart';
import 'package:test/test.dart';

void main() {
  group('HttpRange Exceptions', () {
    test('HttpRangeInvalidException toString()', () {
      const ex = HttpRangeInvalidException();
      expect(ex.toString(), 'invalid range');
    });

    test('HttpRangeNoOverlapException toString()', () {
      const ex = HttpRangeNoOverlapException();
      expect(ex.toString(), 'invalid range: failed to overlap');
    });
  });

  group('HttpRange Utility Methods', () {
    test('contentRange forms correct header string', () {
      const range = HttpRange(start: 10, length: 5);
      expect(range.contentRange(100), 'bytes 10-14/100');
    });
  });

  group('HttpRange.parse - Success Cases', () {
    test('returns empty list if header is empty', () {
      expect(HttpRange.parse('', 100), isEmpty);
    });

    test('parses full range to the end of file (start-)', () {
      final ranges = HttpRange.parse('bytes=10-', 100);
      expect(ranges, hasLength(1));
      expect(ranges.first.start, 10);
      expect(ranges.first.length, 90);
    });

    test('parses suffix range (-suffix_length)', () {
      final ranges = HttpRange.parse('bytes=-20', 100);
      expect(ranges, hasLength(1));
      expect(ranges.first.start, 80);
      expect(ranges.first.length, 20);
    });

    test('clamps suffix range if suffix_length > file size', () {
      final ranges = HttpRange.parse('bytes=-500', 100);
      expect(ranges, hasLength(1));
      expect(ranges.first.start, 0);
      expect(ranges.first.length, 100);
    });

    test('parses explicit bounded range (start-end)', () {
      final ranges = HttpRange.parse('bytes=10-20', 100);
      expect(ranges, hasLength(1));
      expect(ranges.first.start, 10);
      expect(ranges.first.length, 11);
    });

    test('clamps explicit bounded range if end > file size', () {
      final ranges = HttpRange.parse('bytes=90-150', 100);
      expect(ranges, hasLength(1));
      expect(ranges.first.start, 90);
      expect(ranges.first.length, 10);
    });

    test('parses multiple ranges', () {
      final ranges = HttpRange.parse('bytes=10-20, 30-40', 100);
      expect(ranges, hasLength(2));
      expect(ranges[0].start, 10);
      expect(ranges[0].length, 11);
      expect(ranges[1].start, 30);
      expect(ranges[1].length, 11);
    });

    test('ignores empty parts between commas', () {
      final ranges = HttpRange.parse('bytes=10-20, , 30-40,', 100);
      expect(ranges, hasLength(2));
    });

    test('ignores out-of-bounds ranges if at least one valid exists', () {
      final ranges = HttpRange.parse('bytes=150-200, 10-20', 100);
      expect(ranges, hasLength(1));
      expect(ranges.first.start, 10);
    });
  });

  group('HttpRange.parse - Failure Cases (Exceptions)', () {
    test('throws if missing "bytes=" prefix', () {
      expect(
        () => HttpRange.parse('chars=0-10', 100),
        throwsA(isA<HttpRangeInvalidException>()),
      );
    });

    test('throws if dash is missing', () {
      expect(
        () => HttpRange.parse('bytes=10', 100),
        throwsA(isA<HttpRangeInvalidException>()),
      );
    });

    test('throws if suffix range has no end number', () {
      expect(
        () => HttpRange.parse('bytes=-', 100),
        throwsA(isA<HttpRangeInvalidException>()),
      );
    });

    test('throws if suffix range has negative number (double dash)', () {
      expect(
        () => HttpRange.parse('bytes=--10', 100),
        throwsA(isA<HttpRangeInvalidException>()),
      );
    });

    test('throws if suffix range is not a number', () {
      expect(
        () => HttpRange.parse('bytes=-abc', 100),
        throwsA(isA<HttpRangeInvalidException>()),
      );
    });

    test('throws if start is not a number', () {
      expect(
        () => HttpRange.parse('bytes=abc-10', 100),
        throwsA(isA<HttpRangeInvalidException>()),
      );
    });

    test('throws if end is not a number', () {
      expect(
        () => HttpRange.parse('bytes=10-abc', 100),
        throwsA(isA<HttpRangeInvalidException>()),
      );
    });

    test('throws if start > end', () {
      expect(
        () => HttpRange.parse('bytes=20-10', 100),
        throwsA(isA<HttpRangeInvalidException>()),
      );
    });

    test('throws NoOverlapException if NO ranges overlap with content', () {
      expect(
        () => HttpRange.parse('bytes=150-200', 100),
        throwsA(isA<HttpRangeNoOverlapException>()),
      );

      expect(
        () => HttpRange.parse('bytes=150-200, 300-', 100),
        throwsA(isA<HttpRangeNoOverlapException>()),
      );
    });
  });
}
