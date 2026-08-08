import 'package:http_headers/src/headers/te.dart';
import 'package:test/test.dart';

void main() {
  group('TeHeader', () {
    test('decodes codings list correctly', () {
      final header = TeHeader.decode(['trailers, deflate;q=0.5']);
      expect(header, isA<TeHeader>());
      expect(header?.codings, equals(['trailers', 'deflate;q=0.5']));
      expect(header?.encode(), equals(['trailers, deflate;q=0.5']));
    });

    test('trailers factory constructor works', () {
      const trailers = TeHeader.trailers();
      expect(trailers.codings, equals(['trailers']));
      expect(trailers.encode(), equals(['trailers']));
    });

    test('returns null for empty values', () {
      expect(TeHeader.decode([]), isNull);
    });
  });
}
