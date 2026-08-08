import 'package:ion_web/src/http/status.dart';
import 'package:test/test.dart';

void main() {
  group('HttpStatusCode', () {
    test('values and reason phrases are mapped correctly', () {
      expect(HttpStatusCode.ok.value, equals(200));
      expect(HttpStatusCode.ok.reasonPhrase, equals('OK'));

      expect(HttpStatusCode.notFound.value, equals(404));
      expect(HttpStatusCode.notFound.reasonPhrase, equals('Not Found'));

      expect(HttpStatusCode.internalServerError.value, equals(500));
      expect(
        HttpStatusCode.internalServerError.reasonPhrase,
        equals('Internal Server Error'),
      );
    });

    test('compareTo orders status codes by numeric value', () {
      expect(
        HttpStatusCode.ok.compareTo(HttpStatusCode.notFound),
        lessThan(0),
      );
      expect(
        HttpStatusCode.notFound.compareTo(HttpStatusCode.ok),
        greaterThan(0),
      );
      expect(
        HttpStatusCode.ok.compareTo(HttpStatusCode.ok),
        equals(0),
      );
    });

    test('comparison operators work correctly', () {
      expect(HttpStatusCode.ok < HttpStatusCode.notFound, isTrue);
      expect(HttpStatusCode.notFound < HttpStatusCode.ok, isFalse);

      expect(HttpStatusCode.ok <= HttpStatusCode.notFound, isTrue);
      expect(HttpStatusCode.ok <= HttpStatusCode.ok, isTrue);
      expect(HttpStatusCode.notFound <= HttpStatusCode.ok, isFalse);

      expect(HttpStatusCode.notFound > HttpStatusCode.ok, isTrue);
      expect(HttpStatusCode.ok > HttpStatusCode.notFound, isFalse);

      expect(HttpStatusCode.notFound >= HttpStatusCode.ok, isTrue);
      expect(HttpStatusCode.ok >= HttpStatusCode.ok, isTrue);
      expect(HttpStatusCode.ok >= HttpStatusCode.notFound, isFalse);
    });
  });
}
