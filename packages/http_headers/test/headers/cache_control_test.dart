import 'package:http_headers/src/headers/cache_control.dart';
import 'package:test/test.dart';

void main() {
  group('CacheControlHeader', () {
    test('decodes no-cache and max-age correctly', () {
      final header = CacheControlHeader.decode(['no-cache, max-age=300']);
      expect(header, isNotNull);
      expect(header?.noCache, isTrue);
      expect(header?.maxAge, equals(const Duration(seconds: 300)));
      expect(header?.encode(), equals(['no-cache, max-age=300']));
    });

    test('decodes all flags and duration directives correctly', () {
      final header = CacheControlHeader.decode([
        // ignore: lines_longer_than_80_chars
        'no-store, no-transform, only-if-cached, must-revalidate, public, private, immutable, must-understand, proxy-revalidate, max-stale=10, min-fresh=20, s-maxage=30',
      ]);
      expect(header?.noStore, isTrue);
      expect(header?.noTransform, isTrue);
      expect(header?.onlyIfCached, isTrue);
      expect(header?.mustRevalidate, isTrue);
      expect(header?.isPublic, isTrue);
      expect(header?.isPrivate, isTrue);
      expect(header?.isImmutable, isTrue);
      expect(header?.mustUnderstand, isTrue);
      expect(header?.proxyRevalidate, isTrue);
      expect(header?.maxStale, equals(const Duration(seconds: 10)));
      expect(header?.minFresh, equals(const Duration(seconds: 20)));
      expect(header?.sMaxAge, equals(const Duration(seconds: 30)));
    });

    test('returns null for empty values', () {
      expect(CacheControlHeader.decode([]), isNull);
    });
  });
}
