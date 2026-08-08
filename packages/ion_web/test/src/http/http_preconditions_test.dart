import 'dart:io';

import 'package:ion_web/src/http/http.dart';
import 'package:test/test.dart';

void main() {
  final baseDate = HttpDate.parse('Wed, 21 Oct 2015 07:28:00 GMT');
  final baseDateWithMs = baseDate.add(const Duration(milliseconds: 500));
  final futureDate = baseDate.add(const Duration(hours: 1));
  final epochDate = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  const tag123 = ETagHeader(EntityTag('123'));
  const weakTag123 = ETagHeader(EntityTag.weak('123'));

  group('HttpPreconditions.checkIfMatch', () {
    test('returns null for null', () {
      expect(HttpPreconditions.checkIfMatch(null, tag123), isNull);
    });

    test('returns true for *', () {
      expect(
        HttpPreconditions.checkIfMatch(const IfMatchHeader.any(), tag123),
        isTrue,
      );
    });

    test('returns true if ETag matches', () {
      expect(
        HttpPreconditions.checkIfMatch(
          IfMatchHeader.etag(const EntityTag('123')),
          tag123,
        ),
        isTrue,
      );
    });

    test('returns false if ETag does not match or current is null', () {
      expect(
        HttpPreconditions.checkIfMatch(
          IfMatchHeader.etag(const EntityTag('456')),
          tag123,
        ),
        isFalse,
      );
      expect(
        HttpPreconditions.checkIfMatch(
          IfMatchHeader.etag(const EntityTag('123')),
          null,
        ),
        isFalse,
      );
    });
  });

  group('HttpPreconditions.checkIfUnmodifiedSince', () {
    test('returns null for null or zero date', () {
      expect(HttpPreconditions.checkIfUnmodifiedSince(null, baseDate), isNull);
      expect(
        HttpPreconditions.checkIfUnmodifiedSince(
          IfUnmodifiedSinceHeader(baseDate),
          epochDate,
        ),
        isNull,
      );
    });

    test('returns true if modTime is <= parsed time (with truncation)', () {
      expect(
        HttpPreconditions.checkIfUnmodifiedSince(
          IfUnmodifiedSinceHeader(baseDate),
          baseDate,
        ),
        isTrue,
      );
      expect(
        HttpPreconditions.checkIfUnmodifiedSince(
          IfUnmodifiedSinceHeader(baseDate),
          baseDateWithMs,
        ),
        isTrue,
      );
      expect(
        HttpPreconditions.checkIfUnmodifiedSince(
          IfUnmodifiedSinceHeader(futureDate),
          baseDate,
        ),
        isTrue,
      );
    });

    test('returns false if modTime is > parsed time', () {
      expect(
        HttpPreconditions.checkIfUnmodifiedSince(
          IfUnmodifiedSinceHeader(baseDate),
          futureDate,
        ),
        isFalse,
      );
    });
  });

  group('HttpPreconditions.checkIfNoneMatch', () {
    test('returns null for null', () {
      expect(HttpPreconditions.checkIfNoneMatch(null, tag123), isNull);
    });

    test('returns false for *', () {
      expect(
        HttpPreconditions.checkIfNoneMatch(
          const IfNoneMatchHeader.any(),
          tag123,
        ),
        isFalse,
      );
    });

    test('returns false if ETag matches', () {
      expect(
        HttpPreconditions.checkIfNoneMatch(
          IfNoneMatchHeader.etag(const EntityTag('123')),
          tag123,
        ),
        isFalse,
      );
    });

    test('returns true if ETag does not match or current is null', () {
      expect(
        HttpPreconditions.checkIfNoneMatch(
          IfNoneMatchHeader.etag(const EntityTag('456')),
          tag123,
        ),
        isTrue,
      );
      expect(
        HttpPreconditions.checkIfNoneMatch(
          IfNoneMatchHeader.etag(const EntityTag('123')),
          null,
        ),
        isTrue,
      );
    });
  });

  group('HttpPreconditions.checkIfModifiedSince', () {
    test('returns null if method is not GET or HEAD', () {
      expect(
        HttpPreconditions.checkIfModifiedSince(
          .post,
          IfModifiedSinceHeader(baseDate),
          baseDate,
        ),
        isNull,
      );
    });

    test('returns null for null or zero date', () {
      expect(
        HttpPreconditions.checkIfModifiedSince(.get, null, baseDate),
        isNull,
      );
      expect(
        HttpPreconditions.checkIfModifiedSince(
          .get,
          IfModifiedSinceHeader(baseDate),
          epochDate,
        ),
        isNull,
      );
    });

    test('returns false if modTime is <= parsed time (with truncation)', () {
      expect(
        HttpPreconditions.checkIfModifiedSince(
          .get,
          IfModifiedSinceHeader(baseDate),
          baseDate,
        ),
        isFalse,
      );
      expect(
        HttpPreconditions.checkIfModifiedSince(
          .get,
          IfModifiedSinceHeader(baseDate),
          baseDateWithMs,
        ),
        isFalse,
      );
    });

    test('returns true if modTime is > parsed time', () {
      expect(
        HttpPreconditions.checkIfModifiedSince(
          .get,
          IfModifiedSinceHeader(baseDate),
          futureDate,
        ),
        isTrue,
      );
    });
  });

  group('HttpPreconditions.checkIfRange', () {
    test('returns null if method is not GET or HEAD, or header is null', () {
      expect(
        HttpPreconditions.checkIfRange(
          .post,
          const IfRangeHeader.etag(ETagHeader(EntityTag('123'))),
          baseDate,
          tag123,
        ),
        isNull,
      );
      expect(
        HttpPreconditions.checkIfRange(.get, null, baseDate, tag123),
        isNull,
      );
    });

    test('handles ETag parsing first', () {
      final ifRange = IfRangeHeader.decode(['"123"']);
      expect(
        HttpPreconditions.checkIfRange(.get, ifRange, baseDate, tag123),
        isTrue,
      );
      expect(
        HttpPreconditions.checkIfRange(
          .get,
          IfRangeHeader.decode(['"456"']),
          baseDate,
          tag123,
        ),
        isFalse,
      );
      expect(
        HttpPreconditions.checkIfRange(.get, ifRange, baseDate, null),
        isFalse,
      );
      expect(
        HttpPreconditions.checkIfRange(
          .get,
          IfRangeHeader.decode(['W/"123"']),
          baseDate,
          weakTag123,
        ),
        isFalse,
      );
    });

    test('falls back to HTTP Date parsing if it is not an ETag', () {
      final ifRange = IfRangeHeader.decode([HttpDate.format(baseDate)]);
      expect(
        HttpPreconditions.checkIfRange(.get, ifRange, baseDate, null),
        isTrue,
      );
      expect(
        HttpPreconditions.checkIfRange(.get, ifRange, baseDateWithMs, null),
        isTrue,
      );
      expect(
        HttpPreconditions.checkIfRange(.get, ifRange, futureDate, null),
        isFalse,
      );
      expect(
        HttpPreconditions.checkIfRange(.get, ifRange, epochDate, null),
        isFalse,
      );
      expect(
        HttpPreconditions.checkIfRange(.get, ifRange, null, null),
        isFalse,
      );
    });
  });
}
