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

    test(
      'parses a part larger than maxHeaderSize delivered in one chunk',
      () async {
        const boundary = 'big_boundary';
        final transformer = MultipartStreamTransformer(
          boundary,
          maxHeaderSize: 1024,
        );
        final value = 'v' * (100 * 1024);

        final parts =
            await Stream.value(
              utf8.encode(
                '--$boundary\r\n'
                'Content-Disposition: form-data; name="field"\r\n\r\n'
                '$value\r\n'
                '--$boundary--\r\n',
              ),
            ).cast<List<int>>().transform(transformer).asyncMap((part) async {
              return (part.name, await part.text());
            }).toList();

        expect(parts, [('field', value)]);
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

  group('MultipartStreamTransformer backpressure', () {
    const boundary = 'bp';

    Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

    /// Lets queued stream events and pause/resume callbacks run.
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    late StreamController<List<int>> source;
    late Stream<MultipartPart> parts;

    setUp(() {
      source = StreamController<List<int>>();
      parts = source.stream.transform(MultipartStreamTransformer(boundary));
    });

    void sendPartHead(String name) => source.add(
      bytes(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="$name"\r\n\r\n',
      ),
    );

    test('pauses the source while the part listener is paused', () async {
      final partSubscription = Completer<StreamSubscription<Uint8List>>();
      parts.listen((part) => partSubscription.complete(part.listen((_) {})));

      sendPartHead('file');
      source.add(bytes('x' * 1000));
      final subscription = await partSubscription.future;
      await settle();
      expect(source.isPaused, isFalse);

      subscription.pause();
      await settle();
      expect(source.isPaused, isTrue);

      subscription.resume();
      await settle();
      expect(source.isPaused, isFalse);
      await subscription.cancel();
    });

    test('pauses the source while the consumer is busy and has not '
        'started reading the part', () async {
      final gotPart = Completer<MultipartPart>();
      final busy = Completer<void>();
      final loop = () async {
        await for (final part in parts) {
          gotPart.complete(part);
          await busy.future; // busy before reading the part
          await part.drain<void>();
          break;
        }
      }();

      sendPartHead('file');
      source.add(bytes('x' * 1000));
      await gotPart.future;
      await settle();
      expect(source.isPaused, isTrue);

      busy.complete();
      await settle();
      expect(source.isPaused, isFalse);

      source.add(bytes('\r\n--$boundary--\r\n'));
      await loop;
    });

    test('keeps reading the rest of a cancelled part', () async {
      final values = <String>[];
      final done = () async {
        await for (final part in parts) {
          if (part.name == 'skip') {
            await part.listen((_) {}).cancel();
            continue;
          }
          values.add(await part.text());
        }
      }();

      sendPartHead('skip');
      source.add(bytes('${'x' * 1000}\r\n'));
      await settle();
      expect(source.isPaused, isFalse);
      sendPartHead('keep');
      source.add(bytes('value\r\n--$boundary--\r\n'));

      await done;
      expect(values, ['value']);
    });

    test('stops reading the source after the closing boundary', () async {
      final done = parts.drain<void>();
      source.add(bytes('--$boundary--\r\nepilogue'));
      await done;
      await settle();
      expect(source.hasListener, isFalse);
    });

    test('stops reading the source after a parse error', () async {
      final transformer = MultipartStreamTransformer(
        boundary,
        maxHeaderSize: 10,
      );
      final failing = source.stream.transform(transformer);
      final done = expectLater(
        failing.drain<void>(),
        throwsA(isA<MultipartException>()),
      );
      source.add(bytes('--$boundary\r\n${'h' * 100}'));
      await done;
      await settle();
      expect(source.hasListener, isFalse);
    });
  });
}
