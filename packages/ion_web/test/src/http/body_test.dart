import 'package:ion_web/src/http/http.dart';
import 'package:test/test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('FixedLengthBodyController', () {
    test(
      'emits data and completes when full content-length is reached',
      () async {
        var onDoneCalled = false;
        final controller = FixedLengthBodyController(
          11,
          onDone: () {
            onDoneCalled = true;
          },
        );

        final emitted = <Uint8List>[];
        controller.stream.listen(emitted.add);

        expect(controller.isDone, false);

        final rest = controller.add(stringToBytes('hello world'));
        expect(rest, isEmpty);
        expect(controller.isDone, true);
        expect(onDoneCalled, true);

        await pumpEventQueue();
        expect(emitted.length, 1);
        expect(bytesToString(emitted.first), 'hello world');
      },
    );

    test('handles incremental byte chunks correctly', () async {
      var onDoneCalled = false;
      final controller = FixedLengthBodyController(
        5,
        onDone: () {
          onDoneCalled = true;
        },
      );

      final emitted = <Uint8List>[];
      controller.stream.listen(emitted.add);

      controller.add(stringToBytes('hel'));
      expect(controller.isDone, false);
      expect(onDoneCalled, false);

      controller.add(stringToBytes('lo'));
      expect(controller.isDone, true);
      expect(onDoneCalled, true);

      await pumpEventQueue();
      expect(emitted.length, 2);
      expect(bytesToString(emitted[0]), 'hel');
      expect(bytesToString(emitted[1]), 'lo');
    });

    test(
      'returns pipelined remaining data when data exceeds content length',
      () async {
        var onDoneCalled = false;
        final controller = FixedLengthBodyController(
          5,
          onDone: () {
            onDoneCalled = true;
          },
        );

        final emitted = <Uint8List>[];
        controller.stream.listen(emitted.add);

        final rest = controller.add(stringToBytes('helloEXTRA'));
        expect(controller.isDone, true);
        expect(onDoneCalled, true);
        expect(bytesToString(rest), 'EXTRA');

        await pumpEventQueue();
        expect(emitted.length, 1);
        expect(bytesToString(emitted.first), 'hello');
      },
    );

    test('buffers data prior to listener subscription', () async {
      final controller = FixedLengthBodyController(5, onDone: () {});

      controller.add(stringToBytes('hel'));
      final buffered = controller.takeBufferedData();
      expect(bytesToString(buffered), 'hel');

      controller.add(stringToBytes('lo'));

      final emitted = <Uint8List>[];
      controller.stream.listen(emitted.add);

      await pumpEventQueue();
      expect(emitted.length, 1);
      expect(bytesToString(emitted.first), 'lo');
    });

    test('addError forwards error to stream listener', () async {
      final controller = FixedLengthBodyController(10, onDone: () {});

      Object? caughtError;
      controller.stream.listen(
        (_) {},
        onError: (Object err) {
          caughtError = err;
        },
      );

      controller.addError(const BodyControllerException('Test error'));
      await pumpEventQueue();

      expect(caughtError, isA<BodyControllerException>());
      expect(
        (caughtError! as BodyControllerException).message,
        'Test error',
      );
    });
  });

  group('ChunkedBodyController', () {
    test('parses single chunked body correctly', () async {
      var onDoneCalled = false;
      final controller = ChunkedBodyController(
        onDone: () {
          onDoneCalled = true;
        },
      );

      final emitted = <Uint8List>[];
      controller.stream.listen(emitted.add);

      final rest = controller.add(stringToBytes('5\r\nhello\r\n0\r\n\r\n'));
      expect(rest, isEmpty);
      expect(controller.isDone, true);
      expect(onDoneCalled, true);

      await pumpEventQueue();
      expect(emitted.length, 1);
      expect(bytesToString(emitted.first), 'hello');
    });

    test('parses multiple chunks and ignores chunk extensions', () async {
      var onDoneCalled = false;
      final controller = ChunkedBodyController(
        onDone: () {
          onDoneCalled = true;
        },
      );

      final emitted = <Uint8List>[];
      controller.stream.listen(emitted.add);

      controller.add(
        stringToBytes(
          '5;ext=foo\r\nhello\r\n'
          '5;ext2=bar\r\nworld\r\n'
          '0;end=1\r\n\r\n',
        ),
      );
      expect(controller.isDone, true);
      expect(onDoneCalled, true);

      await pumpEventQueue();
      expect(emitted.length, 2);
      expect(bytesToString(emitted[0]), 'hello');
      expect(bytesToString(emitted[1]), 'world');
    });

    test('returns remaining pipelined bytes after final empty chunk', () async {
      final controller = ChunkedBodyController(onDone: () {});

      final emitted = <Uint8List>[];
      controller.stream.listen(emitted.add);

      final rest = controller.add(
        stringToBytes('5\r\nhello\r\n0\r\n\r\nNEXT_REQUEST'),
      );
      expect(controller.isDone, true);
      expect(bytesToString(rest), 'NEXT_REQUEST');

      await pumpEventQueue();
      expect(emitted.length, 1);
      expect(bytesToString(emitted.first), 'hello');
    });

    test('parses byte by byte correctly', () async {
      final controller = ChunkedBodyController(onDone: () {});

      final emitted = <Uint8List>[];
      controller.stream.listen(emitted.add);

      final raw = stringToBytes('5\r\nhello\r\n0\r\n\r\n');
      for (var i = 0; i < raw.length; i++) {
        controller.add(Uint8List.fromList([raw[i]]));
      }

      expect(controller.isDone, true);
      await pumpEventQueue();
      final combined = Uint8List.fromList(emitted.expand((x) => x).toList());
      expect(bytesToString(combined), 'hello');
    });

    test('handles HTTP trailers at end of chunked body', () async {
      var onDoneCalled = false;
      final controller = ChunkedBodyController(
        onDone: () {
          onDoneCalled = true;
        },
      );

      final emitted = <Uint8List>[];
      controller.stream.listen(emitted.add);

      const raw =
          '5\r\nhello\r\n0\r\nExpires: Wed, 21 Oct 2015 07:28:00 GMT\r\n\r\n';
      controller.add(stringToBytes(raw));

      expect(controller.isDone, true);
      expect(onDoneCalled, true);

      await pumpEventQueue();
      expect(emitted.length, 1);
      expect(bytesToString(emitted.first), 'hello');
    });

    test('throws BodyControllerException on invalid hex size', () {
      final controller = ChunkedBodyController(onDone: () {});
      expect(
        () => controller.add(stringToBytes('Z\r\n')),
        throwsA(
          isA<BodyControllerException>().having(
            (e) => e.message,
            'message',
            contains('Invalid chunk size'),
          ),
        ),
      );
    });

    test('throws BodyControllerException on chunk size overflow', () {
      final controller = ChunkedBodyController(onDone: () {});
      expect(
        () => controller.add(stringToBytes('8000000000000000\r\n')),
        throwsA(
          isA<BodyControllerException>().having(
            (e) => e.message,
            'message',
            contains('Chunk size too large'),
          ),
        ),
      );
    });

    test('throws BodyControllerException on missing CRLF after chunk data', () {
      final controller = ChunkedBodyController(onDone: () {});
      expect(
        () => controller.add(stringToBytes('5\r\nhelloXX')),
        throwsA(
          isA<BodyControllerException>().having(
            (e) => e.message,
            'message',
            contains('CRLF expected after chunk data'),
          ),
        ),
      );
    });

    test(
      'forwards Incomplete chunked body error when closed prematurely',
      () async {
        final controller = ChunkedBodyController(onDone: () {});

        Object? caughtError;
        controller.stream.listen(
          (_) {},
          onError: (Object err) {
            caughtError = err;
          },
        );

        controller.add(stringToBytes('5\r\nhel'));
        controller.close();

        await pumpEventQueue();

        expect(caughtError, isA<BodyControllerException>());
        expect(
          (caughtError! as BodyControllerException).message,
          'Incomplete chunked body',
        );
      },
    );

    test('throws BodyControllerException on chunk extension line too long', () {
      final controller = ChunkedBodyController(onDone: () {});
      final padding = 'a' * 4100;
      final longExt = ';ext=$padding';
      expect(
        () => controller.add(stringToBytes('5$longExt\r\nhello\r\n0\r\n\r\n')),
        throwsA(
          isA<BodyControllerException>().having(
            (e) => e.message,
            'message',
            contains('Chunk extension line too long'),
          ),
        ),
      );
    });

    test('throws BodyControllerException on trailers exceed limit', () {
      final controller = ChunkedBodyController(onDone: () {});
      final trailerVal = 'v' * 900;
      final longTrailers = 'X-Header: $trailerVal\r\n' * 20;
      expect(
        () => controller.add(stringToBytes('0\r\n$longTrailers\r\n')),
        throwsA(
          isA<BodyControllerException>().having(
            (e) => e.message,
            'message',
            contains('Chunk trailers exceed max size limit'),
          ),
        ),
      );
    });

    test(
      'throws BodyControllerException on bare semicolon in chunk extension',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        expect(
          () => controller.add(stringToBytes('5;\r\nhello\r\n0\r\n\r\n')),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid or missing chunk extension name'),
            ),
          ),
        );
      },
    );

    test(
      'throws BodyControllerException on invalid token character in '
      'chunk extension name',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        const raw = '5;ext@val=1\r\nhello\r\n0\r\n\r\n';
        expect(
          () => controller.add(stringToBytes(raw)),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid character in chunk extension name'),
            ),
          ),
        );
      },
    );

    test('throws BodyControllerException on NUL byte in chunk extension', () {
      final controller = ChunkedBodyController(onDone: () {});
      final bytes = Uint8List.fromList([
        ...utf8.encode('5;ext='),
        0x00,
        ...utf8.encode('\r\nhello\r\n0\r\n\r\n'),
      ]);
      expect(
        () => controller.add(bytes),
        throwsA(
          isA<BodyControllerException>().having(
            (e) => e.message,
            'message',
            contains('Invalid or missing chunk extension value'),
          ),
        ),
      );
    });

    test('throws BodyControllerException on bare CR in chunk extension', () {
      final controller = ChunkedBodyController(onDone: () {});
      expect(
        () => controller.add(
          stringToBytes('5;ext=foo\rbar\r\nhello\r\n0\r\n\r\n'),
        ),
        throwsA(
          isA<BodyControllerException>().having(
            (e) => e.message,
            'message',
            contains('Bare CR in chunk header line'),
          ),
        ),
      );
    });

    test(
      'parses valid chunk extensions (unquoted, quoted, multiple, with BWS)',
      () async {
        var onDoneCalled = false;
        final controller = ChunkedBodyController(
          onDone: () {
            onDoneCalled = true;
          },
        );

        final emitted = <Uint8List>[];
        controller.stream.listen(emitted.add);

        const chunkData =
            '5;foo=bar;baz="hello \\"world\\"" ; opt \r\nhello\r\n0\r\n\r\n';
        final rest = controller.add(stringToBytes(chunkData));

        expect(rest, isEmpty);
        expect(controller.isDone, true);
        expect(onDoneCalled, true);

        await pumpEventQueue();
        expect(emitted.length, 1);
        expect(bytesToString(emitted.first), 'hello');
      },
    );

    test(
      'throws BodyControllerException on empty extension value',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        expect(
          () => controller.add(stringToBytes('5;foo=\r\nhello\r\n0\r\n\r\n')),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid or missing chunk extension value'),
            ),
          ),
        );
      },
    );

    test(
      'throws BodyControllerException on unclosed quoted extension value',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        expect(
          () => controller.add(
            stringToBytes('5;foo="hello\r\nhello\r\n0\r\n\r\n'),
          ),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid character in quoted chunk extension value'),
            ),
          ),
        );
      },
    );

    test('throws BodyControllerException on bare CR in chunk size line', () {
      final controller = ChunkedBodyController(onDone: () {});
      expect(
        () => controller.add(stringToBytes('5\r5\r\nhello\r\n0\r\n\r\n')),
        throwsA(
          isA<BodyControllerException>().having(
            (e) => e.message,
            'message',
            contains('Bare CR in chunk header line'),
          ),
        ),
      );
    });

    test(
      'throws BodyControllerException on semicolon before any hex digits',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        expect(
          () => controller.add(stringToBytes(';\r\nhello\r\n0\r\n\r\n')),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid chunk size'),
            ),
          ),
        );
      },
    );

    test('throws BodyControllerException on bare CR in chunk trailers', () {
      final controller = ChunkedBodyController(onDone: () {});
      expect(
        () => controller.add(stringToBytes('0\r\nX-Trailer: val\r\r\n')),
        throwsA(
          isA<BodyControllerException>().having(
            (e) => e.message,
            'message',
            contains('Bare CR in chunk trailers'),
          ),
        ),
      );
    });

    test(
      'throws BodyControllerException on unexpected character after quoted '
      'extension value',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        expect(
          () => controller.add(
            stringToBytes('5;foo="val"X\r\nhello\r\n0\r\n\r\n'),
          ),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains(
                'Unexpected character after quoted chunk extension value',
              ),
            ),
          ),
        );
      },
    );

    test(
      'throws BodyControllerException on invalid escape sequence in quoted '
      'extension value',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        final invalidEscapeBytes = Uint8List.fromList([
          ...utf8.encode(r'5;foo="val\'),
          0x01, // invalid char after escape \
          ...utf8.encode('"\r\nhello\r\n0\r\n\r\n'),
        ]);
        expect(
          () => controller.add(invalidEscapeBytes),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains(
                'Invalid escape sequence in quoted chunk extension value',
              ),
            ),
          ),
        );
      },
    );

    test(
      'throws BodyControllerException on trailer line exceeding max limit',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        final longHeaderName = 'X-${'A' * 4100}';
        expect(
          () => controller.add(
            stringToBytes('0\r\n$longHeaderName: val\r\n\r\n'),
          ),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Trailer line too long'),
            ),
          ),
        );
      },
    );

    test(
      'parses quoted chunk extension value with escaped character',
      () async {
        var onDoneCalled = false;
        final controller = ChunkedBodyController(
          onDone: () {
            onDoneCalled = true;
          },
        );

        final emitted = <Uint8List>[];
        controller.stream.listen(emitted.add);

        controller.add(
          stringToBytes('5;ext="val\\"foo"\r\nhello\r\n0\r\n\r\n'),
        );

        expect(controller.isDone, true);
        expect(onDoneCalled, true);

        await pumpEventQueue();
        expect(emitted.length, 1);
        expect(bytesToString(emitted.first), 'hello');
      },
    );

    test('parses chunk extensions with surrounding whitespace', () async {
      var onDoneCalled = false;
      final controller = ChunkedBodyController(
        onDone: () {
          onDoneCalled = true;
        },
      );

      final emitted = <Uint8List>[];
      controller.stream.listen(emitted.add);

      controller.add(
        stringToBytes('5;ext = val ;next = "quoted"\r\nhello\r\n0\r\n\r\n'),
      );

      expect(controller.isDone, true);
      expect(onDoneCalled, true);

      await pumpEventQueue();
      expect(emitted.length, 1);
      expect(bytesToString(emitted.first), 'hello');
    });

    test('parses chunk trailers with LF-only line endings', () async {
      var onDoneCalled = false;
      final controller = ChunkedBodyController(
        onDone: () {
          onDoneCalled = true;
        },
      );

      final emitted = <Uint8List>[];
      controller.stream.listen(emitted.add);

      controller.add(
        stringToBytes('5\r\nhello\r\n0;ext=val\nTrailer: test\n\n'),
      );

      expect(controller.isDone, true);
      expect(onDoneCalled, true);

      await pumpEventQueue();
      expect(emitted.length, 1);
      expect(bytesToString(emitted.first), 'hello');
    });

    test(
      'throws BodyControllerException on invalid character in chunk '
      'extension name',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        expect(
          () => controller.add(
            stringToBytes('5;ext@name=val\r\nhello\r\n0\r\n\r\n'),
          ),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid character in chunk extension name'),
            ),
          ),
        );
      },
    );

    test(
      'throws BodyControllerException on unexpected character after chunk '
      'extension name',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        expect(
          () => controller.add(
            stringToBytes('5;ext @name=val\r\nhello\r\n0\r\n\r\n'),
          ),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Unexpected character after chunk extension name'),
            ),
          ),
        );
      },
    );

    test(
      'throws BodyControllerException on invalid or missing chunk extension '
      'value',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        expect(
          () => controller.add(
            stringToBytes('5;ext=@\r\nhello\r\n0\r\n\r\n'),
          ),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid or missing chunk extension value'),
            ),
          ),
        );
      },
    );

    test(
      'throws BodyControllerException on unexpected character after chunk '
      'extension value',
      () {
        final controller = ChunkedBodyController(onDone: () {});
        expect(
          () => controller.add(
            stringToBytes('5;ext=val@\r\nhello\r\n0\r\n\r\n'),
          ),
          throwsA(
            isA<BodyControllerException>().having(
              (e) => e.message,
              'message',
              contains('Invalid character in chunk extension value'),
            ),
          ),
        );
      },
    );
  });
}
