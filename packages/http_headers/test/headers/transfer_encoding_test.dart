import 'package:http_headers/src/headers/transfer_encoding.dart';
import 'package:test/test.dart';

void main() {
  group('TransferEncodingHeader', () {
    test('decodes codings list correctly', () {
      final header = TransferEncodingHeader.decode(['gzip, chunked']);
      expect(header, isA<TransferEncodingHeader>());
      expect(
        header?.codings,
        equals([TransferCoding.gzip, TransferCoding.chunked]),
      );
      expect(header?.isChunked, isTrue);
      expect(header?.encode(), equals(['gzip, chunked']));
    });

    test('verifies chunked constructor and position check', () {
      const chunkedHdr = TransferEncodingHeader.chunked();
      expect(chunkedHdr.isChunked, isTrue);
      expect(chunkedHdr.hasChunked, isTrue);
      expect(chunkedHdr.isValid, isTrue);
      expect(chunkedHdr.encode(), equals(['chunked']));

      final notLastChunked = TransferEncodingHeader.decode(['chunked, gzip']);
      expect(notLastChunked?.isChunked, isFalse);
      expect(notLastChunked?.hasChunked, isTrue);
      expect(notLastChunked?.hasNonFinalChunkedConflict, isTrue);
      expect(notLastChunked?.isValid, isFalse);
    });

    test('returns null for empty values', () {
      expect(TransferEncodingHeader.decode([]), isNull);
    });
  });
}
