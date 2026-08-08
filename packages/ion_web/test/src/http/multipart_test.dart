import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ion_web/src/http/multipart.dart';
import 'package:test/test.dart';

void main() {
  group('MultipartStreamTransformer Direct Unit Tests', () {
    test('throws ArgumentError when boundary is empty', () {
      expect(
        () => MultipartStreamTransformer(''),
        throwsArgumentError,
      );
    });

    test(
      'transforms Stream<List<int>> directly into MultipartPart stream',
      () async {
        const boundary = 'direct_boundary';
        const bodyText =
            '--direct_boundary\r\n'
            'Content-Disposition: form-data; name="greeting"\r\n'
            'Content-Type: text/plain\r\n\r\n'
            'Hello, World!\r\n'
            '--direct_boundary--\r\n';

        final byteStream = Stream.value(
          utf8.encode(bodyText),
        ).cast<List<int>>();
        final transformer = MultipartStreamTransformer(boundary);

        final parts = await byteStream.transform(transformer).toList();

        expect(parts.length, equals(1));
        expect(parts[0].name, equals('greeting'));
        expect(parts[0].filename, isNull);
        expect(parts[0].contentType, equals('text/plain'));
        expect(parts[0].headers['content-type'], equals('text/plain'));
        expect(await parts[0].text(), equals('Hello, World!'));
      },
    );

    test('parses multiple parts in a single stream directly', () async {
      const boundary = 'multi_direct';
      const bodyText =
          '--multi_direct\r\n'
          'Content-Disposition: form-data; name="field1"\r\n\r\n'
          'val1\r\n'
          '--multi_direct\r\n'
          'Content-Disposition: form-data; name="field2"\r\n\r\n'
          'val2\r\n'
          '--multi_direct--\r\n';

      final byteStream = Stream.value(utf8.encode(bodyText)).cast<List<int>>();
      final parts = await byteStream
          .transform(MultipartStreamTransformer(boundary))
          .toList();

      expect(parts.length, equals(2));
      expect(parts[0].name, equals('field1'));
      expect(await parts[0].text(), equals('val1'));
      expect(parts[1].name, equals('field2'));
      expect(await parts[1].text(), equals('val2'));
    });

    test('MultipartPart.bytes() reads raw Uint8List', () async {
      const boundary = 'bytes_boundary';
      final binaryPayload = Uint8List.fromList([0, 1, 2, 255, 254, 253]);

      final builder = BytesBuilder();
      builder.add(
        utf8.encode(
          '--bytes_boundary\r\n'
          'Content-Disposition: form-data; name="bin"\r\n\r\n',
        ),
      );
      builder.add(binaryPayload);
      builder.add(utf8.encode('\r\n--bytes_boundary--\r\n'));

      final byteStream = Stream.value(builder.toBytes()).cast<List<int>>();
      final transformer = MultipartStreamTransformer(boundary);
      final parts = await byteStream.transform(transformer).toList();

      expect(parts.length, equals(1));
      expect(await parts[0].bytes(), equals(binaryPayload));
    });

    test(
      'propagates errors from source stream to active part stream',
      () async {
        const boundary = 'err_boundary';
        final controller = StreamController<List<int>>();
        final transformer = MultipartStreamTransformer(boundary);

        final stream = controller.stream.transform(transformer);

        controller.add(
          utf8.encode(
            '--err_boundary\r\n'
            'Content-Disposition: form-data; name="field"\r\n\r\n'
            'partial data...',
          ),
        );

        scheduleMicrotask(() {
          controller.addError(const FormatException('Source socket error'));
        });

        var caughtError = false;
        try {
          await for (final part in stream) {
            await part.bytes();
          }
        } catch (e) {
          caughtError = true;
          expect(e, isA<FormatException>());
        }

        expect(caughtError, isTrue);
        await controller.close();
      },
    );

    test(
      'cancelling stream subscription disposes the parser cleanly',
      () async {
        const boundary = 'cancel_boundary';
        final controller = StreamController<List<int>>();
        final transformer = MultipartStreamTransformer(boundary);

        final stream = controller.stream.transform(transformer);
        final sub = stream.listen((_) {});

        controller.add(
          utf8.encode(
            '--cancel_boundary\r\n'
            'Content-Disposition: form-data; name="field"\r\n\r\n',
          ),
        );

        await sub.cancel();
        expect(controller.hasListener, isFalse);
        await controller.close();
      },
    );

    test(
      'emits MultipartException when header section exceeds maxHeaderSize',
      () async {
        const boundary = 'limit_boundary';
        final transformer = MultipartStreamTransformer(
          boundary,
          maxHeaderSize: 100,
        );

        final largeHeaderBody =
            '--limit_boundary\r\n'
            'X-Custom-Header: ${'A' * 200}\r\n\r\n'
            'data\r\n'
            '--limit_boundary--\r\n';

        final byteStream = Stream.value(
          utf8.encode(largeHeaderBody),
        ).cast<List<int>>();

        expect(
          () => byteStream.transform(transformer).toList(),
          throwsA(
            isA<MultipartException>().having(
              (e) => e.message,
              'message',
              contains('Multipart header section exceeds size limit'),
            ),
          ),
        );
      },
    );

    test('MultipartExceptions toString() formatting', () {
      expect(
        const MultipartException('test error').toString(),
        equals('MultipartException: test error'),
      );
      expect(
        const NotMultipartException().toString(),
        equals(
          "MultipartException: request Content-Type isn't multipart/form-data",
        ),
      );
      expect(
        const MissingBoundaryException().toString(),
        equals(
          'MultipartException: no multipart boundary param in Content-Type',
        ),
      );
    });
  });
}
