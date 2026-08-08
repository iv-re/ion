import 'package:http_headers/src/headers/trailer.dart';
import 'package:test/test.dart';

void main() {
  group('TrailerHeader', () {
    test('decodes single value correctly', () {
      final header = TrailerHeader.decode(['Expires']);
      expect(header, isNotNull);
      expect(header?.fieldNames, equals(['Expires']));
      expect(header?.encode(), equals(['Expires']));
    });

    test('decodes multiple values correctly', () {
      final header = TrailerHeader.decode(['Expires, Date']);
      expect(header, isNotNull);
      expect(header?.fieldNames, equals(['Expires', 'Date']));
      expect(header?.encode(), equals(['Expires, Date']));
    });

    test('decodes list of values correctly', () {
      final header = TrailerHeader.decode(['Expires', 'Date']);
      expect(header, isNotNull);
      expect(header?.fieldNames, equals(['Expires', 'Date']));
      expect(header?.encode(), equals(['Expires, Date']));
    });

    test('returns null for empty values', () {
      expect(TrailerHeader.decode([]), isNull);
      expect(TrailerHeader.decode(['   ']), isNull);
      expect(TrailerHeader.decode([', ,']), isNull);
    });

    test('toString is formatted correctly', () {
      const header = TrailerHeader(['Expires', 'Date']);
      expect(header.toString(), equals('TrailerHeader(Expires, Date)'));
    });
  });
}
