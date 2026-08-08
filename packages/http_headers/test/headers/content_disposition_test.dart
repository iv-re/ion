import 'package:http_headers/src/headers/content_disposition.dart';
import 'package:test/test.dart';

void main() {
  group('ContentDispositionHeader', () {
    test('decodes attachment correctly', () {
      final header = ContentDispositionHeader.decode([
        'attachment; filename="file.txt"',
      ]);
      expect(header, isA<ContentDispositionHeader>());
      expect(header?.value, equals('attachment; filename="file.txt"'));
      expect(header?.dispositionType, equals('attachment'));
      expect(header?.isAttachment, isTrue);
      expect(header?.isInline, isFalse);
      expect(header?.encode(), equals(['attachment; filename="file.txt"']));
    });

    test('decodes inline correctly', () {
      const inlineCd = ContentDispositionHeader.inline();
      expect(inlineCd.isInline, isTrue);
      expect(inlineCd.isAttachment, isFalse);
      expect(inlineCd.encode(), equals(['inline']));
    });

    test('returns null for empty values', () {
      expect(ContentDispositionHeader.decode([]), isNull);
      expect(ContentDispositionHeader.decode(['   ']), isNull);
    });
  });
}
